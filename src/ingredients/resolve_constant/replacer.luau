local chef = require("@util/syntax/chef")
local luau = require("@lute/luau")

export type Processor = (luau.AstExpr) -> luau.AstExpr?
type VisitorState = Processor

local function EXHAUSTIVE_MATCH<Msg>(value: never, msg: Msg?): never
	error(msg or `Unknown value in exhaustive match: {value}`)
end

local value_visitor = chef.create() :: chef.Chef<VisitorState>

local function try_eval(expression: luau.AstExpr): luau.AstExpr?
	local evaluated = value_visitor.state(expression)
	if not evaluated then
		chef.visitexpression(expression, value_visitor)
		return nil
	end

	return evaluated
end

function value_visitor.visitStatIf(node: luau.AstStatIf)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	chef.visitblock(node.thenblock, value_visitor)
	for _, elseif_node in node.elseifs do
		local evaluated = try_eval(elseif_node.condition)
		if evaluated then
			elseif_node.condition = evaluated
		end
		chef.visitblock(elseif_node.thenblock, value_visitor)
	end
	if node.elseblock then
		chef.visitblock(node.elseblock, value_visitor)
	end
	return false
end

function value_visitor.visitStatWhile(node: luau.AstStatWhile)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	chef.visitblock(node.body, value_visitor)
	return false
end

function value_visitor.visitStatRepeat(node: luau.AstStatRepeat)
	chef.visitblock(node.body, value_visitor)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	return false
end

function value_visitor.visitStatReturn(node: luau.AstStatReturn)
	for _, expression_pair in node.expressions do
		local evaluated = try_eval(expression_pair.node)
		if evaluated then
			expression_pair.node = evaluated
		end
	end
	return false
end

function value_visitor.visitStatLocalDeclaration(node)
	chef.inner_visit_punctuated(node.variables, chef.inner_visit_local)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	return false
end

function value_visitor.visitStatFor(node: luau.AstStatFor)
	chef.inner_visit_local(node.variable)
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
	chef.inner_visit_block(node.body)
	return false
end

function value_visitor.vfor_in(node)
	chef.inner_visit_token(node.forkeyword)
	chef.inner_visit_punctuated(node.variables, chef.inner_visit_local)
	chef.inner_visit_token(node.inkeyword)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	chef.inner_visit_block(node.body)
	chef.inner_visit_token(node.endkeyword)
	return false
end

function value_visitor.vassign(node)
	chef.inner_visit_punctuated(node.variables, chef.inner_visit_expression)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	return false
end

function value_visitor.vcompound_assign(node)
	chef.inner_visit_expression(node.variable)
	local evaluated = try_eval(node.value)
	if evaluated then
		node.value = evaluated
	end
	return false
end

function value_visitor.vcall(node)
	chef.inner_visit_expression(node.func)
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
