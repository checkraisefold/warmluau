-- warmluau
-- darklua but warm
-- by checkraisefold

local cli = require("@batteries/cli")
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local meta = require("@util/meta")
local module_loader = require("@util/module_loader")
local options = require("@self/cli/options")
local oven = require("@self/oven")
local path = require("@util/path")
local project = require("@project")
local rules = require("@self/oven/rules")

local loaded_project: project.LoadedProject
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

local function load_project(project_file: string)
	if loaded_project then
		return
	end

	local project_path = path.normalize(project_file)
	assert(project_path, "invalid project file path")

	local project_success, project_type = pcall(fs.type, project_path)
	assert(project_success and (project_type == "file"), "project file does not exist or is not a file")

	local project_file_contents = fs.readfiletostring(project_path)
	local module = module_loader.prepend(project_file_contents)
	local loaded_project_file = luau.load(luau.compile(module))
	assert(typeof(loaded_project_file) == "function", `project file failed to load: {loaded_project_file}`)

	loaded_project = project.new()
	loaded_project_file(loaded_project, rules)
end

local project_file = parser:get("project")
if parser:get("project") then
	load_project(project_file)
else
	load_project(meta.default_project_name)
end

if parser:has("bake") then
	assert(loaded_project, "a loaded project is required to bake")

	local input_dir, output_dir = parser:get("input"), parser:get("output")
	assert(input_dir and output_dir, "no input dir or no output dir")

	local input_success, input_type = pcall(fs.type, input_dir)
	local output_success, output_type = pcall(fs.type, output_dir)
	assert(input_success and output_success, "input dir or output dir does not exist")
	assert(input_type == "dir" and output_type == "dir", "input dir or output dir is not a directory")

	oven.bake({
		input = input_dir,
		output = output_dir,
		recursive = not not parser:has("recursive"),
		project = loaded_project,
	})
end
