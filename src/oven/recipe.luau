local defs = require("@warmluau/")

local function recipe_create(...: defs.Recipe | defs.PreparedIngredient): defs.Recipe
	local steps: { defs.Recipe | defs.PreparedIngredient } = { ... }
	local steps_count = #steps

	local function recipe_add(adding: { defs.Recipe | defs.PreparedIngredient }): ()
		local adding_count = #adding
		table.move(adding, 1, adding_count, steps_count + 1, steps)
		steps_count += adding_count
	end

	return {
		_steps = steps,
		add = recipe_add,
	}
end

return {
	create = recipe_create,
}
