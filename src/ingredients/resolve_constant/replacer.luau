local luau = require("@lute/luau")
local visitors = require("@util/syntax/visitors")

export type Processor = (luau.AstExpr) -> luau.AstExpr?
type VisitorState = Processor

local function EXHAUSTIVE_MATCH<Msg>(value: never, msg: Msg?): never
	error(msg or `Unknown value in exhaustive match: {value}`)
end

local value_visitor = visitors.create() :: visitors.Create<VisitorState>

local function try_eval(expression: luau.AstExpr): luau.AstExpr?
	local evaluated = value_visitor.state(expression)
	if not evaluated then
		visitors.inner_visit_expression(expression)
		return nil
	end

	return evaluated
end

function value_visitor.vif(node)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	visitors.inner_visit_block(node.consequent)
	for _, elseif_node in node.elseifs do
		local evaluated = try_eval(elseif_node.condition)
		if evaluated then
			elseif_node.condition = evaluated
		end
		visitors.inner_visit_block(elseif_node.consequent)
	end
	if node.antecedent then
		visitors.inner_visit_block(node.antecedent)
	end
	return false
end

function value_visitor.vwhile(node)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	visitors.inner_visit_block(node.body)
	return false
end

function value_visitor.vrepeat(node)
	visitors.inner_visit_block(node.body)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	return false
end

function value_visitor.vreturn(node)
	for _, expression_pair in node.expressions do
		local evaluated = try_eval(expression_pair.node)
		if evaluated then
			expression_pair.node = evaluated
		end
	end
	return false
end

function value_visitor.vlocal_declaration(node)
	visitors.inner_visit_punctuated(node.variables, visitors.inner_visit_local)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	return false
end

function value_visitor.vfor(node)
	visitors.inner_visit_local(node.variable)
	do
		local evaluated = try_eval(node.from)
		if evaluated then
			node.from = evaluated
		end
	end
	do
		local evaluated = try_eval(node.to)
		if evaluated then
			node.to = evaluated
		end
	end
	if node.step then
		local evaluated = try_eval(node.step)
		if evaluated then
			node.step = evaluated
		end
	end
	visitors.inner_visit_block(node.body)
	return false
end

function value_visitor.vfor_in(node)
	visitors.inner_visit_token(node.forkeyword)
	visitors.inner_visit_punctuated(node.variables, visitors.inner_visit_local)
	visitors.inner_visit_token(node.inkeyword)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	visitors.inner_visit_block(node.body)
	visitors.inner_visit_token(node.endkeyword)
	return false
end

function value_visitor.vassign(node)
	visitors.inner_visit_punctuated(node.variables, visitors.inner_visit_expression)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	return false
end

function value_visitor.vcompound_assign(node)
	visitors.inner_visit_expression(node.variable)
	local evaluated = try_eval(node.value)
	if evaluated then
		node.value = evaluated
	end
	return false
end

function value_visitor.vcall(node)
	visitors.inner_visit_expression(node.func)
	for _, argument_pair in node.arguments do
		local evaluated = try_eval(argument_pair.node)
		if evaluated then
			argument_pair.node = evaluated
		end
	end
	return false
end

function value_visitor.vunary(node)
	local evaluated = try_eval(node.operand)
	if evaluated then
		node.operand = evaluated
	end
	return false
end

function value_visitor.vbinary(node)
	do
		local evaluated = try_eval(node.lhsoperand)
		if evaluated then
			node.lhsoperand = evaluated
		end
	end
	do
		local evaluated = try_eval(node.rhsoperand)
		if evaluated then
			node.rhsoperand = evaluated
		end
	end
	return false
end

function value_visitor.vtable_item(node)
	if node.kind == "list" then
		local evaluated = try_eval(node.value)
		if evaluated then
			node.value = evaluated
		end
	elseif node.kind == "record" then
		local evaluated = try_eval(node.value)
		if evaluated then
			node.value = evaluated
		end
	elseif node.kind == "general" then
		do
			local evaluated = try_eval(node.key)
			if evaluated then
				node.key = evaluated
			end
		end
		do
			local evaluated = try_eval(node.value)
			if evaluated then
				node.value = evaluated
			end
		end
	else
		EXHAUSTIVE_MATCH(node.kind)
	end
	return false
end

function value_visitor.vindex_name(node)
	do
		local evaluated = try_eval(node.expression)
		if evaluated then
			local group: luau.AstExprGroup = {
				tag = "group",
				openparens = {
					leadingtrivia = {},
					position = {
						column = 0,
						line = 0,
					},
					text = "(",
					trailingtrivia = {},
				},
				expression = evaluated,
				closeparens = {
					leadingtrivia = {},
					position = {
						column = 0,
						line = 0,
					},
					text = ")",
					trailingtrivia = {},
				},
			}
			node.expression = group
		end
	end
	return false
end

function value_visitor.vinterpolated_string(node)
	for i = 1, #node.strings do
		local expressions = node.expressions
		if i <= #expressions then
			local evaluated = try_eval(expressions[i])
			if evaluated then
				expressions[i] = evaluated
			end
		end
	end
	return false
end

function value_visitor.vif_expression(node)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	do
		local evaluated = try_eval(node.consequent)
		if evaluated then
			node.consequent = evaluated
		end
	end
	for _, elseif_node in node.elseifs do
		do
			local evaluated = try_eval(elseif_node.condition)
			if evaluated then
				elseif_node.condition = evaluated
			end
		end
		do
			local evaluated = try_eval(elseif_node.consequent)
			if evaluated then
				elseif_node.consequent = evaluated
			end
		end
	end
	do
		local evaluated = try_eval(node.antecedent)
		if evaluated then
			node.antecedent = evaluated
		end
	end
	return false
end

function value_visitor.type_vtypeof(node)
	local evaluated = try_eval(node.expression)
	if evaluated then
		node.expression = evaluated
	end
	return false
end

local function process_values(ast: luau.AstStatBlock, with: Processor): ()
	value_visitor:visit_ast_block(ast, with)
end

return {
	process_values = process_values,
}
