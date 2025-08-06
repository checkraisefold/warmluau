-- warmluau
-- darklua but warm
-- by checkraisefold
local INGREDIENT_REQUIRE_MATCH = "^@warmluau/ingredients/(.+)"
local API_REQUIRE_MATCH = "^@warmluau/"
local FAILED_OUTPUT_FILE = "return error('warmluau could not generate an output for this file');"

local api = require("@self/api")
local cli = require("@batteries/cli")
local defs = require("@warmluau/")
local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local luau = require("@lute/luau")
local meta = require("@util/meta")
local module_loader = require("@util/module_loader")
local options = require("@self/cli/options")
local oven = require("@self/oven")
local pretty_print = require("@util/pretty_print")
local printer = require("@std/syntax/printer")
local warmluau_ingredients = require("@self/ingredients")

type Failure = {
	value: unknown,
	trace: string,
	full: string,
}

local parser = cli.parser()
options.add_options(parser)

parser:parse({ ... })

if parser:has("help") then
	parser:help()
	return
end
if parser:has("version") then
	print(`warmluau {meta.version}`)
	return
end

local project_path = fspath.normalize(parser:get("project") or meta.default_project_name)
assert(project_path, "failed to normalize project path")
project_path = fspath.to_str(project_path)

assert(filesystem.exists(project_path), `project file at {pretty_print(project_path)} does not exist.`)
assert(filesystem.type(project_path) == "file", `project file at {pretty_print(project_path)} is not a file.`)

local project_file_contents = filesystem.readfiletostring(project_path)
project_file_contents = module_loader.prepend(project_file_contents)

local compiler_success, project_bytecode: luau.Bytecode = pcall(luau.compile, project_file_contents)
if not compiler_success then
	error(
		`Failed to load project at '{pretty_print(project_path)}'! Bytecode compiler errored:`
			.. `\n{pretty_print(project_bytecode)}`
	)
end

local success, loaded_project: defs.LoadedProject = pcall(luau.load, project_bytecode)
if not success then
	error(
		`Failed to load project at '{pretty_print(project_path)}'! luau.load errored:\n{pretty_print(loaded_project)}`
	) --
end

local mixing_paths: { string } = {}
local mixing_asts: { luau.AstStatBlock } = {}
local mixing_count = 0

local currently_mixing: boolean = false
local function mixer(recipe: defs.RecipeConfig, ingredient: defs.ConfiguredIngredient): ()
	if currently_mixing then
		error("already cooking") --
	end
	currently_mixing = true

	local process = ingredient.process

	for index = 1, mixing_count do
		local path = mixing_paths[index]
		local ast = mixing_asts[index]
		local new_ast = process(path, ast)
		if new_ast ~= ast then mixing_asts[index] = new_ast end
	end

	currently_mixing = false
end

local warmluau_lib = api.new(mixer)

local function warmluau_require<Path>(target: Path, ...: never): unknown
	assert(select("#", ...) == 0, "exactly 1 argument expected")
	if typeof(target) ~= "string" then return (require)(target) end
	if string.match(target, API_REQUIRE_MATCH) then
		local selected_ingredient = string.match(target, INGREDIENT_REQUIRE_MATCH)
		if selected_ingredient then
			-- could fix this but its fine
			local ingredient = (warmluau_ingredients :: any)[selected_ingredient]
			if not ingredient then error(`Could not find ingredient with name {pretty_print(ingredient)}.`) end
			return ingredient
		end
		return warmluau_lib
	end
	return (require)(target)
end

local preheated: typeof(oven.preheat(...))

if not parser:has("bake") then
	print("Not baking.")
else
	print("Preheating...")
	local input_dir = parser:get("input")
	local input_exists = input_dir and filesystem.exists(input_dir)
	assert(input_exists, `bake requires an input dir that exists, got {pretty_print(input_dir)}`)
	local output_dir = parser:get("output")
	local output_exists = output_dir and filesystem.exists(output_dir)
	assert(output_exists, `bake requires an output dir that exists, got {pretty_print(output_dir)}`)

	local parse_failure_ast = luau.parse(FAILED_OUTPUT_FILE).root

	preheated = oven.preheat({
		recursive = parser:has("recursive"),
		should_cache = parser:has("cached"),
		input = input_dir,
		output = output_dir,
	})

	local read_handles = preheated.read_handles
	mixing_paths = preheated.read_paths
	mixing_count = #read_handles
	for index = 1, mixing_count do
		local handle = read_handles[index]
		local contents = filesystem.read(handle)
		local parse_success, parse_result: luau.ParseResult = pcall(luau.parse, contents)
		if not parse_success then
			print(`failed to parse path {pretty_print(mixing_paths[index])}`)
			mixing_asts[index] = parse_failure_ast
		end
		mixing_asts[index] = parse_result.root
	end
end

print("Cooking...")

loaded_project(warmluau_require)

if preheated then
	local write_handles = preheated.write_handles
	for index = 1, mixing_count do
		local handle = write_handles[index]
		local block = mixing_asts[index]
		local code_output = printer.print(block)
		filesystem.write(handle, code_output)
	end
	preheated.bake()
end

print("Ding! Fries are done")
