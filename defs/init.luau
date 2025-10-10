local filesystem = require("@lute/fs")
local parser = require("@util/syntax/parser")

export type Ast = parser.Ast
export type AstExpr = parser.AstExpr
export type Parsley = parser.Parsley

export type LoadedProject = (require: <Path>(target: Path, ...never) -> unknown) -> ...unknown

export type File = {
	read parsed: parser.Parsley,
	read dense: number,
	read src_path: string,
	read dst_path: string,
	read write_handle: filesystem.FileHandle,
}

export type Ingredient<Options = any> = {
	read prepare: (with: Options) -> PreparedIngredient<Options>,
}

export type PreparedIngredient<Options = any> = {
	read process: (parsley: parser.Parsley, cooking: Cooking) -> (),
	-- stupid hack to make this safely discriminated with Recipe
	read _steps: nil,
}

export type Recipe = {
	read add: (adding: { Recipe | PreparedIngredient }) -> (),
	read _steps: { Recipe | PreparedIngredient },
}

export type Oven = {
	cooking_file: File?,
	files: { File },
	bake: (...Recipe | PreparedIngredient) -> (),
}

export type Cooking = Oven & { cooking_file: File }

export type OvenPreheat = {
	input: string,
	output: string,
	recursive: boolean,
	should_cache: boolean,
	project_modified: number?,
}

local warmluau = {}

function warmluau.recipe(...: Recipe | PreparedIngredient): Recipe
	error()
end

function warmluau.batch(...: Recipe | PreparedIngredient): PreparedIngredient
	error()
end

function warmluau.bake(...: Recipe | PreparedIngredient): ()
	error()
end

function warmluau.oven(preheat: OvenPreheat): Oven
	error()
end

function warmluau.forwarded(): { string }
	error()
end

local function WARMLUAU_API_FAIL()
	error("api not implemented; did you forget to use the cli?")
end

(setmetatable :: any)(warmluau, {
	__index = WARMLUAU_API_FAIL,
});
(table.clear :: any)(warmluau)

return warmluau
