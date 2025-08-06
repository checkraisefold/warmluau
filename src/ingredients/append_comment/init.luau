local append_comment = require("@warmluau/ingredients/append_comment")
local defs = require("@warmluau/")
local luau = require("@lute/luau")
local visitor = require("@std/syntax/visitor")

type Opts = append_comment.Opts

local function configure_append_comment(opts: Opts): defs.ConfiguredIngredient<Opts>
	local function process(_, ast: defs.Ast): defs.Ast
		if not next(ast.statements) then return ast end

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

	local configured_rule: defs.ConfiguredIngredient<Opts> = {
		process = process,
	}

	return configured_rule
end

local rule: defs.Ingredient<Opts> = {
	make = configure_append_comment,
}

return rule
