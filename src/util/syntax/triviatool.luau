local luau = require("@lute/luau")
local visitors = require("@util/syntax/visitors")

type VisitorState = {
	leading: { luau.Trivia },
	trailing: { luau.Trivia },
}
local visitor = visitors.create() :: visitors.Create<VisitorState>

local function add_token(token: luau.Token<string>): ()
	local leading = token.leadingtrivia
	local trailing = token.trailingtrivia

	local state = visitor.state
	local state_leading = state.leading
	local state_trailing = state.trailing
	table.move(leading, 1, #leading, #state_leading + 1, state_leading)
	table.move(trailing, 1, #trailing, #state_trailing + 1, state_trailing)
end

function visitor.vtoken(node)
	add_token(node)
end

local function steal_from_token<T>(token: luau.Token<T>, trivia: VisitorState?): VisitorState
	trivia = trivia or { leading = {}, trailing = {} }
	visitor:visit_ast_token(token, trivia)
	return trivia
end

local function steal_from_expr(expr: luau.AstExpr, trivia: VisitorState?): VisitorState
	trivia = trivia or { leading = {}, trailing = {} }
	visitor:visit_ast_expression(expr, trivia)
	return trivia
end

local function steal_from_statement(stat: luau.AstStat, trivia: VisitorState?): VisitorState
	trivia = trivia or { leading = {}, trailing = {} }
	visitor:visit_ast_statement(stat, trivia)
	return trivia
end

local function push(trivia: { luau.Trivia }, onto: { luau.Trivia }): { luau.Trivia }
	table.move(onto, 1, #onto, #trivia + 1, onto)
	table.move(trivia, 1, #trivia, 1, onto)
	return onto
end

local function append(trivia: { luau.Trivia }, onto: { luau.Trivia }): { luau.Trivia }
	table.move(trivia, 1, #trivia, #onto + 1, onto)
	return onto
end

local function push_lead<T>(trivia: { luau.Trivia }, token)
	return push(trivia, token.leadingtrivia)
end

local function append_lead<T>(trivia: { luau.Trivia }, token)
	return append(trivia, token.leadingtrivia)
end

local function push_trail<T>(trivia: { luau.Trivia }, token)
	return push(trivia, token.trailingtrivia)
end

local function append_trail<T>(trivia: { luau.Trivia }, token)
	return append(trivia, token.trailingtrivia)
end

return {
	steal_from_expr = steal_from_expr,
	steal_from_stat = steal_from_statement,
	steal_from_token = steal_from_token,

	mutate = {
		push = push,
		append = append,
		push_lead = push_lead,
		append_lead = append_lead,
		push_trail = push_trail,
		append_trail = append_trail,
	},
}
