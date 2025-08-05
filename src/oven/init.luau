local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local parser = require("@std/syntax/parser")
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
	local luau_files: { string } = {}
	local luau_files_count = 0

	local entries = filesystem.listdir(path_str)
	local entries_count = #entries

	local entries_index = 0
	while entries_index < entries_count do
		entries_index += 1
		local entry = entries[entries_index]
		local entry_path = fspath.to_str(fspath.push(entry.name, path_str))

		local entry_type = entry.type

		if entry_type ~= "file" then
			if entry_type == "dir" and recurse then
				local child_entries = filesystem.listdir(entry_path)
				local child_entries_count = #child_entries
				table.move(child_entries, 1, child_entries_count, entries_count + 1, entries)
				entries_count += child_entries_count
			end
			continue
		elseif fspath.extension(entry_path) ~= "luau" then
			continue
		end

		luau_files_count += 1
		luau_files[luau_files_count] = entry_path
	end

	return luau_files
end

function oven.bake(opts: OvenOptions)
	local input_dir, output_dir = fspath.normalize(opts.input), fspath.normalize(opts.output)
	assert(input_dir and output_dir, "input and/or output path are invalid")

	for _, rule_config in opts.project.rules do
		local rule = rule_config.rule
		local validate = rule.validate
		if validate then
			if not validate(rule_config.opts) then
				print("wtf failed to validate")
				return
			end
		end
	end

	local luau_files = discover_luau_files(input_dir, opts.recursive)
	for _, file in luau_files do
		local contents = filesystem.readfiletostring(file)
		local parse_success, parsed = pcall(parser.parse, contents)

		if not parse_success then
			print(`luau file at {file} failed to parse! error: {parsed}`)
			continue
		end

		for _, rule_config in opts.project.rules do
			local rule = rule_config.rule
			rule.process(file, parsed, rule_config.opts)
		end

		local file_name = fspath.last(file)
		assert(file_name, `encountered a problem while processing file path for {file}`)

		local output_file = fspath.to_str(fspath.push(file_name, output_dir))
		filesystem.writestringtofile(output_file, printer.print(parsed))

		print(`processed and outputted {file} to {output_file}`)
	end
end

return oven
