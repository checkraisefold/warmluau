local chef = require("@util/syntax/chef")
local defs = require("./defs")
local luau = require("@lute/luau")

type Variable = defs.Variable
type Tracked = defs.Tracked

type Scope = { [string]: Variable? }

type VisitorState = {
	tracked: Tracked,
	scopes: { Scope },
}

-- Luau
local function INSERT<Item>(tbl: { Item }, value: Item): ()
	table.insert(tbl, value)
end

local function ASSERT<Value>(value: Value, message: string?)
	if value then
		return value
	end
	error(message or "Assertion Failed!", 2)
end

local function ensure_global(state: VisitorState, name: string): Variable
	local globals = state.tracked.globals
	do
		local variable = globals[name]
		if variable then
			return variable
		end
	end
	local variable: Variable = {
		global = true,
		writes = 0,
	}
	globals[name] = variable
	return variable
end

local visitor = chef.create() :: chef.Identity<VisitorState>

function visitor.ext.visitScopeOpen()
	local state = visitor.state
	INSERT(state.scopes, {} :: Scope)
end
function visitor.ext.visitScopeClose()
	local state = visitor.state
	ASSERT(
		table.remove(state.scopes),
		`Internal Error;\z 
		Invalid scoping - Value tracker closed more scopes than it opened.`
	)
end

local function scope_insert_local(identifier: luau.AstLocal, assignment: luau.AstExpr?): ()
	local state = visitor.state
	local scopes = state.scopes
	local scope = ASSERT(
		scopes[#scopes],
		`Internal Error;\z 
		Invalid scoping - Value tracker could not find a current scope while inserting a local.`
	)

	local var: Variable = {
		global = false,
		writes = 1,
		init_expr = assignment,
	}

	state.tracked.locals[identifier] = var
	scope[identifier.name.text] = var
end

visitor.ext.visitScopeInsertLocal = scope_insert_local

function visitor.ext.visitScopeInsertLocalFunction(node): ()
	scope_insert_local(node.name)
end

function visitor.visitStatAssign(node: luau.AstStatAssign)
	local state = visitor.state
	local scopes = state.scopes
	local scopes_count = #scopes
	for index, assignee_pair in node.variables do
		local assignee = assignee_pair.node
		if assignee.tag == "local" then
			local name = assignee.token.text
			local variable
			for scopes_index = scopes_count, 1, -1 do
				variable = scopes[scopes_index][name]
				if variable then
					break
				end
			end

			if variable then
				variable.writes += 1
			else
				error(`Internal Error;\z 
					Value tracker tried to reassign local '{name}',\z 
					but a value for '{name}' did not exist given the\z 
					current scope.`)
			end
		elseif assignee.tag == "global" then
			ensure_global(state, assignee.name.text).writes += 1
		end
	end

	return true
end

function visitor.visitExprGlobal(node: luau.AstExprGlobal)
	local state = visitor.state

	state.tracked.globals[node.name.text] = ensure_global(state, node.name.text)

	return false
end

local function local_tracked_variable(node: luau.AstLocal): Variable
	local scopes = visitor.state.scopes
	local scopes_count = #scopes

	local name = node.name.text

	local variable
	for scopes_index = scopes_count, 1, -1 do
		variable = scopes[scopes_index][name]
		if variable then
			break
		end
	end

	if variable then
		return variable
	else
		error(`Internal Error;\z 
			Value tracker tried to reference local '{name}',\z 
			but a value for '{name}' did not exist given the\z 
			current scope.`)
	end
end

function visitor.visitExprLocal(node: luau.AstExprLocal)
	local inner = node["local"]
	visitor.state.tracked.locals[inner] = local_tracked_variable(inner)

	return true
end

local function track_values(root: luau.AstStatBlock): Tracked
	local tracked: Tracked = {
		globals = {},
		locals = {},
		variables = {},
	}
	visitor.state = {
		tracked = tracked,
		scopes = {},
	}
	chef.visitblock(root, visitor)
	return tracked
end

return {
	track = track_values,
}
