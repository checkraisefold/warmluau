local FAILED_OUTPUT_FILE = "return error('warmluau could not generate an output for this file');"

local defs = require("@warmluau/")
local filesystem = require("@std/fs")
local luau = require("@lute/luau")
local process = require("@lute/process")
local path = require("@std/path")
local styled = require("@util/pretty_print")

-- why do they call it oven when you of in the cold food of hot eat the food

type Process = index<defs.PreparedIngredient, "process">

local function get_handle(root: path.pathlike, file: path.pathlike): filesystem.file?
	local file_path = path.format(path.join(root, file))
	if not filesystem.exists(file_path) then
		local success, err = pcall(filesystem.createdirectory :: any, root, { makeparents = true })
		if not success then
			print(`Could not ensure file {file_path} exists; mkdir errored while ensuring dir {root}:\n{err}`)
		end
	end

	local success, file_handle = pcall(filesystem.open, file_path, "w+" :: "w+")
	if not success then
		print(`Failed to open path {styled(file_path)}, errored while opening handle:\n{file_handle}`)
		return nil
	end

	return file_handle
end

local function locate_luau_files(directory_path: path.pathlike, recurse: boolean): { path.pathlike }
	local file_positions: { path.pathlike } = {}
	local file_positions_count = 0

	local entries = filesystem.listdirectory(directory_path)
	local entries_count = #entries

	local entries_index = 0
	while entries_index < entries_count do
		entries_index += 1
		local entry = entries[entries_index]

		local entry_name = entry.name
		local entry_nav = path.parse(entry_name)

		if entry.type ~= "file" then
			if entry.type == "dir" and recurse then
				local full_dir = path.format(path.join(directory_path, entry_nav))
				local child_entries = filesystem.listdirectory(full_dir)
				local child_entries_count = #child_entries
				for child_index = 1, child_entries_count do
					local child = child_entries[child_index]
					child.name = path.format(path.join(entry_nav, child.name))
				end
				table.move(child_entries, 1, child_entries_count, entries_count + 1, entries)
				entries_count += child_entries_count
			end
			continue
		elseif path.extname(entry_name) ~= ".luau" then
			continue
		end

		file_positions_count += 1
		file_positions[file_positions_count] = entry_nav
	end

	return file_positions
end

local function oven_preheat(preheat: defs.OvenPreheat): defs.Oven
	local parse_failure = luau.parse(FAILED_OUTPUT_FILE)

	local input_dir, output_dir = path.normalize(preheat.input), path.normalize(preheat.output)
	assert(input_dir, `Oven failed to preheat; input dir {styled(preheat.input)} could not be normalized.`)
	assert(output_dir, `Oven failed to preheat; output dir {styled(preheat.output)} could not be normalized.`)
	local should_cache = preheat.should_cache
	
	input_dir = path.join(process.cwd(), input_dir)
	output_dir = path.join(process.cwd(), output_dir)

	--[[
	TODO: Is this really necessary?
	]]
	if filesystem.exists(output_dir) then
		local output_files = locate_luau_files(output_dir, true)
		for output_files_index = 1, #output_files do
			local file_location = output_files[output_files_index]
			local src_path = path.format(path.join(output_dir, file_location))
			if filesystem.exists(src_path) then
				continue
			end
			local dst_path = path.format(path.join(input_dir, file_location))
			if filesystem.exists(dst_path) then
				filesystem.remove(dst_path)
			end
		end
	end

	local project_modified = preheat.project_modified

	local files: { defs.File } = {}
	local files_count = 0
	local input_files = locate_luau_files(input_dir, preheat.recursive)
	for input_files_index = 1, #input_files do
		local file_location = input_files[input_files_index]
		local src_path = path.format(path.join(input_dir, file_location))
		assert(filesystem.exists(src_path), "path does not exist")
		local dst_path = path.format(path.join(output_dir, file_location))
		if should_cache then
			local src_modified = filesystem.metadata(src_path).modified
			if (project_modified - src_modified):toseconds() > 0 then
				src_modified = project_modified --
			end
			local cached_eh = --
				filesystem.exists(dst_path) --
				and (filesystem.metadata(dst_path).modified - src_modified):toseconds() > 0
			if cached_eh then
				continue
			end
		end

		local dst_handle = get_handle(output_dir, file_location)

		if not dst_handle then
			continue
		end

		local read_success, src_contents: string = pcall(filesystem.readfiletostring, src_path)
		if not read_success then
			print(`Failed to open path {styled(src_path)}, filesystem api errored:\n{src_contents}`)
			continue
		end

		local parse_success, parse_result: luau.ParseResult = pcall(luau.parse, src_contents)
		if not parse_success then
			print(`Failed to parse path {styled(src_path)}, parser errored:\n{parse_result}`)
			parse_result = parse_failure
		end

		files_count += 1
		files[files_count] = {
			parsed = parse_result,
			dense = files_count,
			src_path = src_path,
			dst_path = dst_path,
			write_handle = dst_handle,
		}
	end

	local oven: defs.Oven

	--[[
	workaround for Luau typestate
	]]
	local function process_file(process: Process, file: defs.File)
		assert(oven.cooking_file)
		process(file.parsed, oven)
	end

	local function bake_steps(steps: { defs.Recipe | defs.PreparedIngredient }): ()
		for steps_index = 1, #steps do
			local step = steps[steps_index]
			if step._steps then
				bake_steps(step._steps) --
			else
				local process = step.process
				for files_index = 1, files_count do
					local file = files[files_index]
					oven.cooking_file = file
					process_file(process, file)
				end
			end
		end
	end

	local function oven_bake(...: defs.Recipe | defs.PreparedIngredient): ()
		if oven.cooking_file then
			error("already cooking", 2)
		end
		bake_steps({ ... })
		oven.cooking_file = nil
	end

	local value: defs.Oven = {
		cooking_file = nil :: defs.File?,
		files = files,

		bake = oven_bake,
	}
	oven = value

	return oven
end

return {
	preheat = oven_preheat,
}
