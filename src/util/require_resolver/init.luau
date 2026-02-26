local ALIAS_PATTERN = `^@(.+)`

local filesystem = require("@std/fs")
local get_aliases = require("@self/get_aliases")
local path = require("@std/path")
local resolver_types = require("@self/types")

type RequireAliases = resolver_types.RequireAliases

local function ASSERT<Value>(value: Value, message: string?)
	if value then
		return value
	end
	error(message or "Assertion Failed!", 2)
end

local function resolve_module_path(file: path.pathlike): (path.pathlike, path.pathlike?)
	file = ASSERT(path.normalize(file), `could not normalize file's path '{file}'`)
	local requiring_dir = ASSERT(
		path.normalize(path.dirname(file)),
		`Problem resolving module for path '{file}'; path's parent could not be normalized.`
	)

	local filename = ASSERT(path.basename(file), `Problem getting module for path '{file}'; No filename??`)

	local init_path: path.pathlike?
	if (filename == "init.luau") or (filename == "init.lua") then
		init_path = requiring_dir
		requiring_dir = ASSERT(
			path.normalize(path.dirname(requiring_dir)),
			`Problem getting module for path '{file}'; could not normalize init module directory.`
		)
	end

	return requiring_dir, init_path
end

local resolver = {}
local metatable = { __index = resolver }

export type Identity = setmetatable<{
	_aliases: RequireAliases,
	_directory: string,
	_datamodules: boolean,
}, typeof(metatable)>

local function resolver_from_path(file: path.pathlike, data_modules: boolean?): Identity
	ASSERT(filesystem.exists(file), `Problem constructing resolver for path '{file}'; path does not exist.`)
	ASSERT(filesystem.type(file) == "file", `Problem constructing resolver for path '{file}'; path is not a file.`)

	local module_path, self_path = resolve_module_path(file)

	local aliases = table.clone(get_aliases.under_dir(module_path))

	if self_path then
		aliases.self = path.format(self_path)
	end

	local self = setmetatable({
		_aliases = aliases,
		_directory = path.format(module_path),
		_datamodules = if data_modules ~= nil then data_modules else true,
	}, metatable)

	return self
end

function resolver.resolve_path(self: Identity, path_to_resolve: path.pathlike): path.pathlike
	local nav = path.parse(path_to_resolve)

	local path_begins =
		ASSERT(table.remove(nav.parts, 1), `could not resolve path '{path.format(path_to_resolve)}' because it is empty`)
	local alias = string.match(path_begins, ALIAS_PATTERN)

	local resolve_root: string

	if alias ~= nil then
		local aliases = self._aliases

		local alias_target: string? = aliases[alias]

		if alias_target == nil then
			error(`Could not resolve module for '{path.format(path_to_resolve)}'; could not find alias "{alias}".`) --
		end

		resolve_root = alias_target
	elseif path_begins == ".." then
		resolve_root = path.dirname(self._directory)
	elseif path_begins == "." then
		resolve_root = self._directory
	else
		error(`Could not resolve module for '{path.format(path_to_resolve)}'; paths must begin with either "@<alias>/", "./", or "../"`)
	end

	local resolve_suffix = path.parse(nav)

	local full_resolve_path = ASSERT(
		path.normalize(path.join(resolve_root, resolve_suffix)),
		`Could not resolve module for '{path.format(path_to_resolve)}'; resulting path could not be normalized.`
	)
	ASSERT(
		path.isabsolute(full_resolve_path),
		`Could not resolve module for '{path.format(path_to_resolve)}'; resulting path was not absolute.\z
		\nResulting Path: {path.format(full_resolve_path)}`
	)

	local formatted = path.format(full_resolve_path)

	-- TODO: properly set extension
	local try_list = if self._datamodules then {
		path.format(path.join(full_resolve_path, "init.luau")),
		path.format(path.join(full_resolve_path, "init.lua")),
		path.format(`{formatted}.luau`),
		path.format(`{formatted}.lua`),
		path.format(`{formatted}.json`),
		path.format(`{formatted}.toml`),
		path.format(`{formatted}.yaml`),
		path.format(`{formatted}.yml`),
	} else {
		path.format(path.join(full_resolve_path, "init.luau")),
		path.format(path.join(full_resolve_path, "init.lua")),
		path.format(`{formatted}.luau`),
		path.format(`{formatted}.lua`)
	}

	local found_file: path.pathlike
	for _, try in try_list do
		if not filesystem.exists(try) then
			continue
		elseif filesystem.type(try) ~= "file" then
			continue
		end
		ASSERT(
			not found_file,
			`Could not resolve module for '{path.format(path_to_resolve)}'; found ambiguous filepaths: '{found_file}' and '{try}'`
		)
		found_file = try
	end

	ASSERT(
		found_file,
		`Could not resolve module for '{path.format(path_to_resolve)}'; could not find a matching path.`
			.. ` Tried:\n{table.concat(try_list, ",\n")}`
	)

	found_file = ASSERT(
		path.normalize(found_file),
		`Could not resolve module for '{path.format(path_to_resolve)}'; failed to normalize filename {found_file}??`
	)

	return found_file
end

return {
	from_path = resolver_from_path,
	get_module = resolve_module_path,
	get_aliases = get_aliases,
}
