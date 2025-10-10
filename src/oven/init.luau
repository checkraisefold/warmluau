local FAILED_OUTPUT_FILE = "return error('warmluau could not generate an output for this file');"

local defs = require("@warmluau/")
local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local luau = require("@lute/luau")
local styled = require("@util/pretty_print")

type Process = index<defs.PreparedIngredient, "process">

local function get_handle(root: fspath.Nav, file: fspath.Nav): filesystem.FileHandle?
	local file_path = fspath.to_str(fspath.push(file, root))
	if not filesystem.exists(file_path) then
		local merged = table.clone(root)
		local merged_count = #merged
		for file_index = 1, #file - 1 do
			merged_count += 1
			merged[merged_count] = file[file_index]
			local dir_path = fspath.to_str(merged)
			if not filesystem.exists(dir_path) then
				local success, err = pcall(filesystem.mkdir, dir_path)
				if not success then
					print(
						`Could not ensure file {file_path} exists;`
							.. `mkdir errored while ensuring dir {dir_path}:\n{err}`
					) --
					return nil
				end
			end
		end
	end

	local success, file_handle = pcall(filesystem.open, file_path, "w+" :: "w+")
	if not success then
		print(`Failed to open path {styled(file_path)}, errored while opening handle:\n{file_handle}`) --
		return nil
	end

	return file_handle
end

local function locate_luau_files(directory_path: string, recurse: boolean): { fspath.Nav }
	local file_positions: { fspath.Nav } = {}
	local file_positions_count = 0

	local entries = filesystem.listdir(directory_path)
	local entries_count = #entries

	local entries_index = 0
	while entries_index < entries_count do
		entries_index += 1
		local entry = entries[entries_index]

		local entry_name = entry.name
		local entry_nav = fspath.to_nav(entry_name)

		if entry.type ~= "file" then
			if entry.type == "dir" and recurse then
				local full_dir = fspath.to_str(fspath.push(entry_nav, directory_path))
				local child_entries = filesystem.listdir(full_dir)
				local child_entries_count = #child_entries
				for child_index = 1, child_entries_count do
					local child = child_entries[child_index]
					child.name = fspath.to_str(fspath.push(child.name, entry_nav))
				end
				table.move(child_entries, 1, child_entries_count, entries_count + 1, entries)
				entries_count += child_entries_count
			end
			continue
		elseif fspath.extension(entry_name) ~= "luau" then
			continue
		end

		file_positions_count += 1
		file_positions[file_positions_count] = entry_nav
	end

	return file_positions
end

local function oven_preheat(preheat: defs.OvenPreheat): defs.Oven
	local parse_failure = luau.parse(FAILED_OUTPUT_FILE)

	local input_dir, output_dir = fspath.normalize(preheat.input), fspath.normalize(preheat.output)
	assert(input_dir, `Oven failed to preheat; input dir {styled(preheat.input)} could not be normalized.`)
	assert(output_dir, `Oven failed to preheat; output dir {styled(preheat.output)} could not be normalized.`)
	local should_cache = preheat.should_cache

	local input_nav = fspath.to_nav(input_dir)
	local output_nav = fspath.to_nav(output_dir)

	--[[
	TODO: Is this really necessary?
	]]
	if filesystem.exists(output_dir) then
		local output_files = locate_luau_files(output_dir, true)
		for output_files_index = 1, #output_files do
			local file_location = output_files[output_files_index]
			local src_path = fspath.to_str(fspath.push(file_location, output_nav))
			if filesystem.exists(src_path) then
				continue
			end
			local dst_path = fspath.to_str(fspath.push(file_location, input_nav))
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
		local src_path = fspath.to_str(fspath.push(file_location, input_nav))
		assert(filesystem.exists(src_path), "path does not exist")
		local dst_path = fspath.to_str(fspath.push(file_location, output_nav))
		if should_cache then
			local src_modified = filesystem.stat(src_path).modified_at
			if project_modified and project_modified > src_modified then
				src_modified = project_modified --
			end
			local cached_eh = --
				filesystem.exists(dst_path) --
				and (src_modified < filesystem.stat(dst_path).modified_at)
			if cached_eh then
				continue
			end
		end

		local dst_handle = get_handle(output_nav, file_location)

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
