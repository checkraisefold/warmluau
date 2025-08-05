local ALIAS_PATTERN = `^@(.+)`

local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local get_aliases = require("@self/get_aliases")
local resolver_types = require("@self/types")

type RequireAliases = resolver_types.RequireAliases

local get_aliases_from_luaurc = get_aliases.from_luaurc

local function ASSERT<Value>(value: Value, message: string?)
	if value then return value end
	error(message or "Assertion Failed!", 2)
end

local resolver = {}
local metatable = { __index = resolver }

export type Identity = setmetatable<{
	_aliases: RequireAliases,
	_directory: string,
}, typeof(metatable)>

local function resolver_from_path(file: string): Identity
	file = ASSERT(fspath.normalize(file), `could not normalize src file's path '{file}'`)
	do
		ASSERT(filesystem.exists(file), `Problem constructing resolver for path '{file}'; path does not exist.`)
		ASSERT(filesystem.type(file) == "file", `Problem constructing resolver for path '{file}'; path is not a file.`)
	end

	local requiring_dir = ASSERT(
		fspath.normalize(fspath.parent(file)),
		`Problem constructing resolver for path '{file}'; path's parent could not be normalized.`
	)

	local aliases = get_aliases_from_luaurc(requiring_dir)

	local filename = ASSERT(fspath.last(file), `Problem constructing resolver for path '{file}'; No filename??`)

	if (filename == "init.luau") or (filename == "init.lua") then
		aliases.self = requiring_dir --
		requiring_dir = ASSERT(
			fspath.normalize(fspath.parent(requiring_dir)),
			`Problem constructing resolver for path '{file}'; could not normalize module directory.`
		)
	end

	local self = setmetatable({
		_aliases = aliases,
		_directory = requiring_dir,
	}, metatable)

	return self
end

function resolver.resolve_path(self: Identity, path: string): string
	local nav = fspath.from_str(path)

	local path_begins = ASSERT(table.remove(nav, 1), `could not resolve path '{path}' because it is empty`)
	local alias = string.match(path_begins, ALIAS_PATTERN)

	local resolve_root: string

	if alias ~= nil then
		local aliases = self._aliases

		local alias_target: string? = aliases[alias]

		if alias_target == nil then
			error(`Could not resolve module for '{path}'; could not find alias "{alias}".`) --
		end

		resolve_root = alias_target
	elseif path_begins == ".." then
		resolve_root = fspath.parent(self._directory)
	elseif path_begins == "." then
		resolve_root = self._directory
	else
		error(`Could not resolve module for '{path}'; paths must begin with either "@<alias>/", "./", or "../"`)
	end

	local resolve_suffix = fspath.from_nav(nav)

	local full_resolve_path = ASSERT(
		fspath.normalize(fspath.push(resolve_suffix, resolve_root)),
		`Could not resolve module for '{path}'; resulting path could not be normalized.`
	)
	ASSERT(
		fspath.absolute_eh(full_resolve_path),
		`Could not resolve module for '{path}'; resulting path was not absolute.`
	)

	local try_list = {
		fspath.to_str(fspath.push("init.luau", full_resolve_path)),
		fspath.to_str(fspath.push("init.lua", full_resolve_path)),
		fspath.to_str(fspath.set_extension(full_resolve_path, "luau")),
		fspath.to_str(fspath.set_extension(full_resolve_path, "lua")),
	}

	local found_file: string
	for _, try in try_list do
		if not filesystem.exists(try) then
			continue
		elseif filesystem.type(try) ~= "file" then
			continue
		end
		ASSERT(
			not found_file,
			`Could not resolve module for '{path}'; found ambiguous filepaths: '{found_file}' and '{try}'`
		)
		found_file = try
	end

	ASSERT(
		found_file,
		`Could not resolve module for '{path}'; could not find a matching path.`
			.. ` Tried:\n{table.concat(try_list, ",\n")}`
	)

	found_file = ASSERT(
		fspath.normalize(found_file),
		`Could not resolve module for '{path}'; failed to normalize filename {found_file}??`
	)

	return found_file
end

return { from_path = resolver_from_path }
