local append_comment = require("@warmluau/ingredients/append_comment")
local luau = require("@lute/luau")
local visitor = require("@ext/std/syntax/visitor")
local warmluau = require("@warmluau/")

type Opts = append_comment.Opts
type Mode = append_comment.Mode

local function prepare_append_comment(opts: Opts): warmluau.PreparedIngredient<Opts>
	local mode: Mode = opts.mode or "late"
	local function process(ast: warmluau.Ast): warmluau.Ast
		if not next(ast.statements) then return ast end

		local comment_visitor = visitor.createVisitor()
		local to_append: luau.SingleLineComment = {
			tag = "comment",
			text = opts.text,
			location = {
				begin = { column = 0, line = 0 },
				["end"] = { column = 0, line = 0 },
			},
		}

		comment_visitor.visitToken = function(token: luau.Token<string>)
			if mode == "late" then
				table.insert(token.leadingTrivia, to_append)
			elseif mode == "early" then
				table.insert(token.leadingTrivia, 1, to_append)
			else
				error("unreachable; exhaustive")
			end
			comment_visitor.visitToken = function()
				return false
			end

			return false
		end

		visitor.visitStatement(ast.statements[1], comment_visitor)
		return ast
	end

	local prepared_ingredient: warmluau.PreparedIngredient<Opts> = {
		process = process,
	}

	return prepared_ingredient
end

local ingredient: warmluau.Ingredient<Opts> = {
	prepare = prepare_append_comment,
}

return ingredient
