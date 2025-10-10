local luau = require("@lute/luau")
local visitors = require("@util/syntax/visitors")

local first_last_visitor = visitors.create() :: visitors.Create<{
	first: luau.Token,
	last: luau.Token,
}?>

function first_last_visitor.vtoken(node): ()
	local state = first_last_visitor.state
	if state then
		state.last = node
	else
		state = {
			first = node,
			last = node,
		}
		first_last_visitor.state = state
	end
end

local function from_expr(node: luau.AstExpr)
	return first_last_visitor:visit_ast_expression(node)
end

local function from_block(node: luau.AstStatBlock)
	return first_last_visitor:visit_ast_block(node)
end

local function from_stat(node: luau.AstStat)
	return first_last_visitor:visit_ast_statement(node)
end

local function from_type(node: luau.AstType)
	return first_last_visitor:visit_ast_type(node)
end

local function from_type_pack(node: luau.AstTypePack)
	return first_last_visitor:visit_ast_type_pack(node)
end

local function first_from_expr(node)
	local out = from_expr(node)
	return out and out.first
end
local function first_from_block(node)
	local out = from_block(node)
	return out and out.first
end
local function first_from_stat(node)
	local out = from_stat(node)
	return out and out.first
end
local function first_from_type(node)
	local out = from_type(node)
	return out and out.first
end
local function first_from_type_pack(node)
	local out = from_type_pack(node)
	return out and out.first
end
local function last_from_expr(node)
	local out = from_expr(node)
	return out and out.last
end
local function last_from_block(node)
	local out = from_block(node)
	return out and out.last
end
local function last_from_stat(node)
	local out = from_stat(node)
	return out and out.last
end
local function last_from_type(node)
	local out = from_type(node)
	return out and out.last
end
local function last_from_type_pack(node)
	local out = from_type_pack(node)
	return out and out.last
end

return {
	firstlast_from_expr = from_expr,
	firstlast_from_block = from_block,
	firstlast_from_stat = from_stat,
	firstlast_from_type = from_type,
	firstlast_from_type_pack = from_type_pack,
	first_from_expr = first_from_expr,
	first_from_block = first_from_block,
	first_from_stat = first_from_stat,
	first_from_type = first_from_type,
	first_from_type_pack = first_from_type_pack,
	last_from_expr = last_from_expr,
	last_from_block = last_from_block,
	last_from_stat = last_from_stat,
	last_from_type = last_from_type,
	last_from_type_pack = last_from_type_pack,
}
