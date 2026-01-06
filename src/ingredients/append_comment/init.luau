local append_comment = require("@warmluau/ingredients/append_comment")
local chef = require("@util/syntax/chef")
local luau = require("@lute/luau")
local warmluau = require("@warmluau/")

type Opts = append_comment.Opts
type Mode = append_comment.Mode

-- Luau
local function INSERT<Item>(tbl: { Item }, value: Item): ()
	table.insert(tbl, value)
end

local function prepare_append_comment(opts: Opts): warmluau.PreparedIngredient<Opts>
	local mode: Mode = opts.mode or "early"

	local visitor = chef.create() :: chef.Identity<true?>
	local function comment(): luau.SingleLineComment
		return {
			tag = "comment",
			text = opts.text,
			location = luau.span.create({
				begincolumn = 0,
				beginline = 0,
				endcolumn = 0,
				endline = 0,
			}),
		}
	end

	function visitor.visitToken(token: luau.Token<string>)
		if visitor.state then
			return
		end
		visitor.state = true
		if mode == "late" then
			INSERT(token.leadingtrivia, comment())
		elseif mode == "early" then
			table.insert(token.leadingtrivia, 1, comment())
		else
			error("unreachable; exhaustive")
		end
	end

	local function process(parsley: warmluau.Parsley): ()
		local ast = parsley.root
		local statements = ast.statements
		if next(statements) then
			chef.visitblockstate(ast, visitor, nil)
		else
			chef.visittokenstate(parsley.eof, visitor, nil)
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
