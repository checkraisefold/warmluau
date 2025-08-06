local defs = require("@warmluau/")
local luau = require("@lute/luau")
local printer = require("@std/syntax/printer")

local function warmluau_new(mixer: (defs.RecipeConfig, defs.ConfiguredIngredient) -> ()): typeof(defs)
	local function recipe_new(config: defs.RecipeConfig): defs.RecipeInterface
		local function recipe_mix(ingredient: defs.ConfiguredIngredient): ()
			mixer(config, ingredient)
		end
		local recipe_interface: defs.RecipeInterface = {
			mix = recipe_mix,
		}
		return recipe_interface
	end

	local function warmluau_recipe(config: defs.RecipeConfig): defs.RecipeInterface
		return recipe_new(config)
	end
	local function warmluau_parse(source: string): luau.AstStatBlock
		return luau.parse(source).root
	end
	local function warmluau_out(ast: luau.AstStatBlock): string
		return printer.print(ast)
	end

	local warmluau: typeof(defs) = {
		recipe = warmluau_recipe,
		parse = warmluau_parse,
		out = warmluau_out,
	}

	return warmluau
end

return {
	new = warmluau_new,
}
