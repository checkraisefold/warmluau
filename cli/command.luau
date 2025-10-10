-- warmluau
-- darklua but warm and luau
-- by checkraisefold
local PROJECT_FILE_EXTENSION = "warm.luau"
local PROJECT_FILE_MATCH = "^(.*)%.warm%.luau?$"

local cli = require("@batteries/cli")
local defs = require("@warmluau/")
local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local luau = require("@lute/luau")
local meta = require("@lib/meta")
local options = require("./options")
local oven = require("@lib/oven")
local printer = require("@util/syntax/printer")
local process = require("@lute/process")
local recipe = require("@lib/oven/recipe")
local require_vfs = require("@lib/require_vfs")
local requirer = require("@util/requirer")
local styled = require("@util/pretty_print")

type Process = index<defs.PreparedIngredient, "process">

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
if not string.match(project_path, PROJECT_FILE_MATCH) then
	if fspath.extension(project_path) ~= "luau" then
		error(`project path {styled(project_path)} is not a luau file.`) --
	end
	project_path = fspath.set_extension(project_path, PROJECT_FILE_EXTENSION)
end
project_path = fspath.to_str(fspath.push(project_path, process.cwd()))

if not filesystem.exists(project_path) then
	error(`project file at {styled(project_path)} does not exist.`, 2) --
end

assert(filesystem.exists(project_path), `project file at {styled(project_path)} does not exist.`)
assert(filesystem.type(project_path) == "file", `project file at {styled(project_path)} is not a file.`)

local project_modified = filesystem.stat(project_path).modified_at

local preheated: typeof(oven.preheat(...))

if not parser:has("bake") then
	print("Not preheating.")
else
	print("Preheating...")
	local input_dir = parser:get("input")
	local input_exists = input_dir and filesystem.exists(input_dir)
	assert(input_exists, `bake requires an input dir that exists, got {styled(input_dir)}`)
	local output_dir = parser:get("output")
	if not filesystem.exists(output_dir) then
		filesystem.mkdir(output_dir)
	end

	preheated = oven.preheat({
		project_modified = project_modified,
		recursive = parser:has("recursive"),
		should_cache = parser:has("cached"),
		input = input_dir,
		output = output_dir,
	})
end

local function get_processors(steps: { defs.Recipe | defs.PreparedIngredient }, list: { Process })
	for steps_index = 1, #steps do
		local step = steps[steps_index]
		if step._steps then
			get_processors(step._steps, list)
		else
			table.insert(list, step.process)
		end
	end
end

local function warmluau_bake(...: defs.PreparedIngredient | defs.Recipe)
	assert(preheated, "failed; did you forget to specify --bake?")
	preheated.bake(...)
end

local function warmluau_recipe(...: defs.Recipe | defs.PreparedIngredient)
	return recipe.create(...)
end

local function warmluau_batch(...: defs.Recipe | defs.PreparedIngredient): defs.PreparedIngredient
	local processors: { Process } = {}
	get_processors({ ... }, processors)
	local processors_count = #processors

	local function batch_process(parsed: defs.Parsley, oven: defs.Cooking): ()
		for processors_index = 1, processors_count do
			processors[processors_index](parsed, oven)
		end
	end

	local prepared_ingredient: defs.PreparedIngredient = {
		process = batch_process,
	}

	return prepared_ingredient
end

local function warmluau_oven(preheat)
	return oven.preheat(preheat)
end

local function warmluau_forwarded(): { string }
	local forwarded = parser:forwarded()
	if forwarded then
		return table.clone(forwarded)
	end
	forwarded = {}
	return forwarded
end

local api: typeof(defs) = {
	recipe = warmluau_recipe,
	batch = warmluau_batch,
	bake = warmluau_bake,
	oven = warmluau_oven,
	forwarded = warmluau_forwarded,
}

require_vfs.value = api

local project_file_contents = filesystem.readfiletostring(project_path)
project_file_contents = requirer.prepend(project_file_contents)

local compiler_success, project_bytecode: luau.Bytecode = pcall(luau.compile, project_file_contents)
if not compiler_success then
	error(
		`Failed to load project at {styled(project_path)}! Bytecode compiler errored:` .. `\n{styled(project_bytecode)}`
	)
end

local success, loaded_project: defs.LoadedProject = pcall(luau.load, project_bytecode, "warmluau project")
if not success then
	error(`Failed to load project at {styled(project_path)}! luau.load errored:\n{styled(loaded_project)}`) --
end

local warmluau_require = requirer.new(project_path, {}, require_vfs)

print("Cooking...")

loaded_project(warmluau_require)

if preheated then
	for _, file in preheated.files do
		local handle = file.write_handle
		local code_output = printer.printfile(file.parsed)
		filesystem.write(handle, code_output)
		filesystem.close(handle)
	end
end

print("Ding! Fries are done")
