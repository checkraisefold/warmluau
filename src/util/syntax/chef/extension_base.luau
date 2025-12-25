local luau = require("@lute/luau")
local types = require("./types")

local extension_base = {}

local function visit_function_body(node: luau.AstFunctionBody, chef: types.Chef)
	if node.self then
		table.insert(chef._pending_locals, node.self)
	end
	for _, parameter in node.parameters do
		table.insert(chef._pending_locals, parameter.node)
	end
end

local function visit_function_node(
	override: boolean,
	node: luau.AstNode & { body: luau.AstFunctionBody },
	chef: types.Chef
)
	if not override then
		return
	end

	visit_function_body(node.body, chef)
end

extension_base.visitStatFunction = visit_function_node
extension_base.visitExprAnonymousFunction = visit_function_node
extension_base.visitStatTypeFunction = visit_function_node

function extension_base.visitStatFor(override: boolean, node: luau.AstStatFor, chef: types.Chef)
	if not override then
		return
	end

	table.insert(chef._pending_locals, node.variable)
end

function extension_base.visitStatForIn(override: boolean, node: luau.AstStatForIn, chef: types.Chef)
	if not override then
		return
	end

	for _, variable in node.variables do
		table.insert(chef._pending_locals, variable.node)
	end
end

function extension_base.visitStatLocalDeclarationEnd(_, node: luau.AstStatLocal, chef: types.Chef)
	for index, variable in node.variables do
		local value_pair = node.values[index]
		local value = value_pair and value_pair.node
		chef.ext.visitScopeInsertLocal(variable.node, value)
	end
end

function extension_base.visitStatLocalFunction(override: boolean, node: luau.AstStatLocalFunction, chef: types.Chef)
	if not override then
		return
	end

	visit_function_body(node.body, chef)
	chef.ext.visitScopeInsertLocalFunction(node)
end

function extension_base.visitStatBlock(override: boolean, _, chef: types.Chef)
	if not override then
		return
	end
	chef.ext.visitScopeOpen()

	for _, pending in chef._pending_locals do
		chef.ext.visitScopeInsertLocal(pending)
	end
	table.clear(chef._pending_locals)
end

function extension_base.visitStatBlockEnd(_, _, chef: types.Chef)
	chef.ext.visitScopeClose()
end

return extension_base
