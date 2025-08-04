local fs = require("@lute/fs")
local parser = require("@std/syntax/parser")
local path = require("@util/path")
local printer = require("@std/syntax/printer")
local project = require("@project")
local rules = require("@self/rules")

local oven = {}

export type OvenOptions = {
	input: string,
	output: string,
	recursive: boolean,
	project: project.LoadedProject,
}

local function discover_luau_files(path_str: string, recurse: boolean): { string }
	local contents = fs.listdir(path_str)
	local files = {}

	for _, entry in contents do
		local entry_path = path.to_nav(path.push(entry.name, path_str))
		if entry.type == "dir" and recurse then
			local recursed_files = discover_luau_files(path.to_str(entry_path), recurse)

			for _, file in recursed_files do
				local file_path = path.push(file, entry_path)
				table.insert(files, path.to_str(file_path))
			end
		end
		if entry.type ~= "file" then
			continue
		end

		local extension = path.extension(entry_path)
		if extension ~= "luau" then
			continue
		end

		table.insert(files, path.to_str(entry_path))
	end

	return files
end

function oven.bake(opts: OvenOptions)
	local input_dir, output_dir = path.normalize(opts.input), path.normalize(opts.output)
	assert(input_dir and output_dir, "input and/or output path are invalid")

	local luau_files = discover_luau_files(input_dir, opts.recursive)
	for _, file in luau_files do
		local contents = fs.readfiletostring(file)
		local parse_success, parsed = pcall(parser.parse, contents)

		if not parse_success then
			print(`luau file at {file} failed to parse! error: {parsed}`)
			continue
		end

		for _, applied_rule in opts.project.rules do
			local rule = applied_rule.rule
			rule.process(parsed, applied_rule.opts)
		end

		local file_name = path.last(file)
		assert(file_name, `encountered a problem while processing file path for {file}`)

		local output_file = path.to_str(path.push(file_name, output_dir))
		fs.writestringtofile(output_file, printer.print(parsed))

		print(`processed and outputted {file} to {output_file}`)
	end
end

return oven
