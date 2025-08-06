local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")

type Failure = {
	value: unknown,
	trace: string,
	full: string,
}

local oven = {}

export type OvenOptions = {
	input: string,
	output: string,
	recursive: boolean,
	should_cache: boolean,
}

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
					error(
						`Could not ensure file {file_path} exists;`
							.. `mkdir errored while ensuring dir {dir_path}:\n{err}`
					) --
				end
			end
		end
	end

	local success, file_handle = pcall(filesystem.open, file_path, "w+" :: "w+")
	if not success then
		print(`Failed to open path '{file_path}', errored while opening handle:\n{file_handle}`) --
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

function oven.preheat(opts: OvenOptions): {
	read_paths: { string },
	read_handles: { filesystem.FileHandle },
	write_handles: { filesystem.FileHandle },
	bake: () -> (),
}
	local input_dir, output_dir = fspath.normalize(opts.input), fspath.normalize(opts.output)
	assert(input_dir, `Oven failed to preheat; input dir '{opts.input}' could not be normalized.`)
	assert(output_dir, `Oven failed to preheat; output dir '{opts.output}' could not be normalized.`)
	local should_cache = opts.should_cache

	local input_nav = fspath.to_nav(input_dir)
	local output_nav = fspath.to_nav(output_dir)

	local src_handles: { filesystem.FileHandle } = {}
	local dst_handles: { filesystem.FileHandle } = {}
	local src_paths: { string } = {}
	local count = 0
	local output_files = locate_luau_files(output_dir, true)
	for _, file_location in output_files do
		local src_path = fspath.to_str(fspath.push(file_location, output_nav))
		if filesystem.exists(src_path) then continue end
		local dst_path = fspath.to_str(fspath.push(file_location, input_nav))
		if filesystem.exists(dst_path) then filesystem.remove(dst_path) end
	end
	local input_files = locate_luau_files(input_dir, opts.recursive)
	for _, file_location in input_files do
		local src_path = fspath.to_str(fspath.push(file_location, input_nav))
		assert(filesystem.exists(src_path), "path does not exist")
		local dst_path = fspath.to_str(fspath.push(file_location, output_nav))
		if
			should_cache
			and filesystem.exists(dst_path)
			and (filesystem.stat(src_path).modified_at < filesystem.stat(dst_path).modified_at)
		then
			continue
		end

		local dst_handle = get_handle(output_nav, file_location)

		if not dst_handle then continue end

		local success, src_handle = pcall(filesystem.open, src_path, "r" :: "r")
		if not success then
			print(`Failed to open path '{src_path}', filesystem api errored:\n{src_handle}`) --
			continue
		end

		count += 1
		src_handles[count] = src_handle
		dst_handles[count] = dst_handle
		src_paths[count] = src_path
	end

	local function oven_bake()
		for index = 1, count do
			filesystem.close(src_handles[index])
			filesystem.close(dst_handles[index])
		end
	end

	return {
		read_paths = table.freeze(src_paths),
		read_handles = table.freeze(src_handles),
		write_handles = dst_handles,
		bake = oven_bake,
	}
end

return oven
