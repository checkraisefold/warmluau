local chef = require("@util/syntax/chef")
local luau = require("@lute/luau")

export type Processor = (luau.AstExpr) -> luau.AstExpr?
type VisitorState = Processor

local function EXHAUSTIVE_MATCH<Msg>(value: never, msg: Msg?): never
	error(msg or `Unknown value in exhaustive match: {value}`)
end

local value_visitor = chef.create() :: chef.Identity<VisitorState>

local zerospan: luau.span = luau.span.create({
	begincolumn = 0,
	beginline = 0,
	endcolumn = 0,
	endline = 0,
})

local function visitPunctuated<T, Separator>(
	list: luau.Punctuated<T, Separator>,
	apply: (T, chef.Identity<any>) -> ()
): ()
	for _, item in list do
		apply(item.node, value_visitor)
		if item.separator then
			value_visitor.visitToken(item.separator)
		end
	end
end

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

function value_visitor.visitStatLocalDeclaration(node: luau.AstStatLocal)
	visitPunctuated(node.variables, chef.visit)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	return false
end

function value_visitor.visitStatFor(node: luau.AstStatFor)
	chef.visit(node.variable, value_visitor)
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
	chef.visitblock(node.body, value_visitor)
	return false
end

function value_visitor.visitStatForIn(node: luau.AstStatForIn)
	chef.visittoken(node.forkeyword, value_visitor)
	visitPunctuated(node.variables, chef.visit)
	chef.visittoken(node.inkeyword, value_visitor)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	chef.visitblock(node.body, value_visitor)
	chef.visittoken(node.endkeyword, value_visitor)
	return false
end

function value_visitor.visitStatAssign(node: luau.AstStatAssign)
	visitPunctuated(node.variables, chef.visit)
	for _, value in node.values do
		local evaluated = try_eval(value.node)
		if evaluated then
			value.node = evaluated
		end
	end
	return false
end

function value_visitor.visitStatCompoundAssign(node: luau.AstStatCompoundAssign)
	chef.visitexpression(node.variable, value_visitor)
	local evaluated = try_eval(node.value)
	if evaluated then
		node.value = evaluated
	end
	return false
end

function value_visitor.visitExprCall(node: luau.AstExprCall)
	chef.visitexpression(node.func, value_visitor)
	for _, argument_pair in node.arguments do
		local evaluated = try_eval(argument_pair.node)
		if evaluated then
			argument_pair.node = evaluated
		end
	end
	return false
end


function value_visitor.visitExprUnary(node: luau.AstExprUnary)
	local evaluated = try_eval(node.operand)
	if evaluated then
		node.operand = evaluated
	end
	return false
end

function value_visitor.visitExprBinary(node: luau.AstExprBinary)
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

function value_visitor.visitTableExprItem(node: luau.AstTableExprItem)
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

function value_visitor.visitExprIndexName(node: luau.AstExprIndexName)
	do
		local evaluated = try_eval(node.expression)
		if evaluated then
			local group: luau.AstExprGroup = {
				kind = "expr",
				tag = "group",
				location = zerospan,
				openparens = {
					istoken = true,
					leadingtrivia = {},
					location = zerospan,
					text = "(",
					trailingtrivia = {},
				},
				expression = evaluated,
				closeparens = {
					istoken = true,
					leadingtrivia = {},
					location = zerospan,
					text = ")",
					trailingtrivia = {},
				},
			}
			node.expression = group
		end
	end
	return false
end

function value_visitor.visitExprInterpString(node: luau.AstExprInterpString)
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

function value_visitor.visitExprIfElse(node: luau.AstExprIfElse)
	do
		local evaluated = try_eval(node.condition)
		if evaluated then
			node.condition = evaluated
		end
	end
	do
		local evaluated = try_eval(node.thenexpr)
		if evaluated then
			node.thenexpr = evaluated
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
			local evaluated = try_eval(elseif_node.thenexpr)
			if evaluated then
				elseif_node.thenexpr = evaluated
			end
		end
	end
	do
		local evaluated = try_eval(node.elseexpr)
		if evaluated then
			node.elseexpr = evaluated
		end
	end
	return false
end

function value_visitor.visitTypeTypeof(node: luau.AstTypeTypeof)
	local evaluated = try_eval(node.expression)
	if evaluated then
		node.expression = evaluated
	end
	return false
end

local function process_values(ast: luau.AstStatBlock, with: Processor): ()
	chef.visitblockstate(ast, value_visitor, with)
end

return {
	process_values = process_values,
}
