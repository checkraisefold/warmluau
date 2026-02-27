local chef = require("@util/syntax/chef")
local luau = require("@lute/luau")
local rename_variables = require("@warmluau/ingredients/rename_variables")
local warmluau = require("@warmluau/")

type Opts = rename_variables.Opts

local function prepare_rename_variables(opts: Opts): warmluau.PreparedIngredient<Opts>
	local visitor = chef.create() :: chef.Identity<{
		map: { [string]: string },
		next_var: number,
	}>

	local hash = opts.hash
		or function(name: string): string
			local state = visitor.state
			local var_map = state.map
			local cached = var_map[name]
			if cached then
				return cached
			end
			local new_name = `v{state.next_var}`
			var_map[name] = new_name
			state.next_var += 1
			return new_name
		end

	function visitor.visitLocal(identifier: luau.AstLocal)
		identifier.name.text = hash(identifier.name.text)
	end

	function visitor.visitExprLocal(identifier: luau.AstExprLocal)
		identifier.token.text = hash(identifier.token.text)
	end

	local function process(parsley: warmluau.Parsley): ()
		local ast = parsley.root

		chef.visitblockstate(ast, visitor, {
			map = {} :: { [string]: string },
			next_var = 0,
		})
	end

	local prepared_ingredient: warmluau.PreparedIngredient<Opts> = {
		process = process,
	}

	return prepared_ingredient
end

local ingredient: warmluau.Ingredient<Opts> = {
	prepare = prepare_rename_variables,
}

return ingredient
