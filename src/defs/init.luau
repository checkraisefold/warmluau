local warmluau = {}
local luau = require("@lute/luau")

export type Ast = luau.AstStatBlock

export type ConfiguredIngredient<Options = nil> = {
	process: (path: string, block: Ast) -> Ast,
}
export type Ingredient<Options = nil> = {
	make: (opts: Options) -> ConfiguredIngredient<Options>,
}

export type RecipeConfig = {
	name: string?,
}

export type RecipeInterface = {
	mix: (ingredient: ConfiguredIngredient<any>) -> (),
}

export type LoadedProject = (require: <Path>(target: Path, ...never) -> unknown) -> unknown

function warmluau.recipe(recipe: RecipeConfig): RecipeInterface
	error("not implemented")
end

function warmluau.parse(src: string): Ast
	error("not implemented")
end

function warmluau.out(ast: Ast): string
	error("not implemented")
end

return warmluau
