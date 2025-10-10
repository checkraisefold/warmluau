local append_comment = require("@warmluau/ingredients/append_comment")
local luau = require("@lute/luau")
local visitors = require("@util/syntax/visitors")
local warmluau = require("@warmluau/")

type Opts = append_comment.Opts
type Mode = append_comment.Mode

-- Luau
local function INSERT<Item>(tbl: { Item }, value: Item): ()
	table.insert(tbl, value)
end

local function prepare_append_comment(opts: Opts): warmluau.PreparedIngredient<Opts>
	local mode: Mode = opts.mode or "early"

	local visitor = visitors.create() :: visitors.Create<true?>
	local function comment(): luau.SingleLineComment
		return {
			tag = "comment",
			text = opts.text,
			location = {
				begin = { column = 0, line = 0 },
				["end"] = { column = 0, line = 0 },
			},
		}
	end

	function visitor.vtoken(token)
		if visitor.state then
			return
		end
		visitor.state = true
		if mode == "late" then
			INSERT(token.leadingTrivia, comment())
		elseif mode == "early" then
			table.insert(token.leadingTrivia, 1, comment())
		else
			error("unreachable; exhaustive")
		end
	end

	local function process(parsley: warmluau.Parsley): ()
		local ast = parsley.root
		local statements = ast.statements
		if next(statements) then
			visitor:visit_ast_block(ast)
		else
			visitor:visit_ast_token(parsley.eof)
		end
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
