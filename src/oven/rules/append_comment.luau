local luau = require("@lute/luau")
local types = require("./types")
local visitor = require("@std/syntax/visitor")

export type Opts = {
	text: string,
}

local function validate(opts: types.Opts?)
	if (not opts) or not opts.text then
		return false
	end
	if typeof(opts.text) ~= "string" then
		return false
	end

	return true
end

local function process(ast: types.Ast, opts: Opts)
	assert(opts and opts.text, "append_comment requires a `text` option!")
	if not next(ast.statements) then
		return ast
	end

	local comment_visitor = visitor.createVisitor()
	local has_appended = false
	local to_append: luau.SingleLineComment = {
		tag = "comment",
		text = opts.text,
		location = {
			begin = { column = 0, line = 0 },
			["end"] = { column = 0, line = 0 },
		},
	}

	comment_visitor.visitToken = function(token: luau.Token<string>)
		if not has_appended then
			table.insert(token.leadingTrivia, 1, to_append)
			has_appended = true
		end

		return false
	end

	visitor.visitStatement(ast.statements[1], comment_visitor)
	return ast
end

local append_comment: types.Rule<Opts> = {
	process = process,
}

return append_comment
