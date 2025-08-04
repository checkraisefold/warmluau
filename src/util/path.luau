--!optimize 2
--!native
local NAVIGATE_BACK = ".."
local NAVIGATE_HERE = "."
local SEPARATOR_MATCH = "[/\\]+"
local SEPARATOR = "/"

export type Nav = { string }
export type ValidPath = Nav | string

local BYTE = string.byte

local function to_nav(path: ValidPath): Nav
	if type(path) == "table" then
		return path
	end
	return (string.split(string.gsub(string.gsub(path, SEPARATOR_MATCH, SEPARATOR), `{SEPARATOR}$`, ""), SEPARATOR))
end

local function from_str(path: string): Nav
	return (string.split(string.gsub(string.gsub(path, SEPARATOR_MATCH, SEPARATOR), `{SEPARATOR}$`, ""), SEPARATOR))
end

local function clone_nav(path: ValidPath): Nav
	if type(path) == "table" then
		return table.clone(path)
	end
	return (string.split(string.gsub(string.gsub(path, SEPARATOR_MATCH, SEPARATOR), `{SEPARATOR}$`, ""), SEPARATOR))
end

local function to_str(path: ValidPath): string
	if type(path) == "string" then
		return path
	end
	return (table.concat(path, SEPARATOR))
end

local function from_nav(path: Nav): string
	return (table.concat(path, SEPARATOR))
end

local function has_root(path: ValidPath): boolean
	local str = to_str(path)
	if string.match(str, `^[a-zA-z]:{SEPARATOR_MATCH}`) or string.match(str, `^{SEPARATOR_MATCH}`) then
		return true
	end
	return false
end

local function absolute_eh(path: ValidPath): boolean
	if string.match(to_str(path), `^[a-zA-z]:{SEPARATOR_MATCH}`) then
		return true --
	end
	return false
end

local function parent(path: ValidPath): string
	return `{to_str(path)}{SEPARATOR}{NAVIGATE_BACK}`
end

local function starts_with(path: ValidPath, base: ValidPath): boolean
	local path_nav = to_nav(path)
	local base_nav = to_nav(base)

	local path_len = #path_nav
	local base_len = #base_nav

	if base_len > path_len then
		return false
	end

	for index = 1, base_len do
		if path_nav[index] ~= base_nav[index] then
			return false
		end
	end

	return true
end

local function stops_with(path: ValidPath, child: ValidPath): boolean
	local path_nav = to_nav(path)
	local child_nav = to_nav(child)

	local path_len = #path_nav
	local child_len = #child_nav

	if child_len > path_len then
		return false
	end

	local path_index = path_len
	for child_index = child_len, 1, -1 do
		if child_nav[child_index] ~= path_nav[path_index] then
			return false
		end
		path_index -= 1
	end

	return true
end

local function normalize(path: ValidPath): string?
	local nav = clone_nav(path)

	local nav_count = #nav
	local backnav_count = 0
	for nav_index = nav_count, 1, -1 do
		local component = nav[nav_index]
		if component == NAVIGATE_HERE then
			continue
		end
		if component == NAVIGATE_BACK then
			backnav_count += 1
			continue
		end
		if backnav_count > 0 then
			backnav_count -= 1
			table.remove(nav, nav_index)
		end
	end

	if backnav_count > 0 or not nav[1] then
		return nil
	end

	return (from_nav(nav))
end

local function real_parent(path: ValidPath): string?
	local nav = clone_nav(path)
	table.remove(nav, #nav)
	if nav[1] then
		return (from_nav(nav))
	end
	return nil
end

local function equal(first: ValidPath?, second: ValidPath?): boolean
	if first then
		first = normalize(first)
	end
	if second then
		second = normalize(second)
	end
	return first == second
end

local function last(path: ValidPath): string?
	local str = string.reverse(to_str(path))
	local separator_index = string.find(str, SEPARATOR_MATCH)
	if not separator_index then
		return nil
	end
	local after_separator = string.sub(str, 1, separator_index - 1)
	str = string.reverse(after_separator)
	if str == "" then
		str = nil
	end
	return str
end

local function set_last(path: ValidPath, to: string): string
	local str = string.reverse(to_str(path))
	local separator_index = string.find(str, SEPARATOR_MATCH)
	if not separator_index then
		return `{SEPARATOR}{to}`
	end
	local until_separator = string.reverse(string.sub(str, separator_index, #str))
	return `{until_separator}{to}`
end

local function stem(path: ValidPath): string?
	local filename = last(path)
	if not filename then
		return nil
	end
	if BYTE(filename, 1) == BYTE(".") then
		return filename
	end
	local stem = string.match(filename, "(.+)%.")
	if stem then
		return stem
	end
	return filename
end

local function extension(path: ValidPath): string?
	local filename = last(path)
	if not filename then
		return nil
	end
	if not string.find(filename, "%.", 2) then
		return nil
	end
	local reversed_filename = string.reverse(filename)
	local ext_stop = string.find(reversed_filename, "%.")
	if not ext_stop then
		return nil
	end
	local extension = string.reverse(string.sub(reversed_filename, 1, ext_stop - 1))
	return extension
end

local function set_extension(path: ValidPath, to: string): string
	local filename = last(path)
	if not filename then
		return `{SEPARATOR}.{to}`
	end
	local reversed_filename = string.reverse(filename)
	local ext_stop = string.find(reversed_filename, "%.")
	if not ext_stop then
		return `{filename}.{to}`
	end
	local until_extension = string.reverse(string.sub(reversed_filename, ext_stop, #filename))
	return `{until_extension}{to}`
end

local function push(path: ValidPath, onto: ValidPath): ValidPath
	if absolute_eh(path) then
		return path
	end
	local path_nav = to_nav(path)
	local onto_nav = clone_nav(onto)
	table.move(path_nav, 1, #path_nav, #onto_nav + 1, onto_nav)
	return onto_nav
end

local api = {
	to_nav = to_nav,
	from_str = from_str,
	clone_nav = clone_nav,
	to_str = to_str,
	from_nav = from_nav,
	has_root = has_root,
	absolute_eh = absolute_eh,
	parent = parent,
	starts_with = starts_with,
	stops_with = stops_with,
	normalize = normalize,
	real_parent = real_parent,
	equal = equal,
	last = last,
	set_last = set_last,
	stem = stem,
	extension = extension,
	set_extension = set_extension,
	push = push,

	SEPARATOR = SEPARATOR,
}

return api
