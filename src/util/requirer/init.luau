local PREPEND = [[math.randomseed(0); local require = ...;]]

local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local luau = require("@lute/luau")
local override = require("@self/override")
local require_resolver = require("@util/require_resolver")
local styled = require("@util/pretty_print")

export type ResultCache = { [string]: { value: unknown } }

local function loader_prepend(file: string): string
	return `{PREPEND}{file}`
end

local function count_vararg(...: unknown): (unknown, number)
	local output = ...
	return output, select("#", ...)
end

local function try_find_override(
	path: fspath.ValidPath,
	base: override.Identity,
	prefix: { string }?
): override.Identity?
	prefix = prefix or {}
	path = fspath.to_nav(path)

	local base_path = fspath.push(base.path, prefix)

	if fspath.starts_with(path, base_path) and fspath.equal(path, base_path) then
		return base
	end

	for _, child in base.children do
		local found = try_find_override(path, child, base_path)
		if found then
			return found
		end
	end

	return nil
end

local function require_constructor(requiring_path: string, result_cache: ResultCache?, override: override.Identity?)
	local result_cache: ResultCache = result_cache or {}
	local resolver = require_resolver.from_path(requiring_path)

	local function warmluau_require<Path>(target: Path, ...: never): unknown
		assert(select("#", ...) == 0, "exactly 1 argument expected")
		if typeof(target) ~= "string" then
			return (require)(target)
		end
		local nav = fspath.to_nav(target)

		if override and fspath.starts_with(nav, override.path) then
			local found = try_find_override(nav, override)
			if not found then
				print(`Could not resolve overrided path for {styled(found)}.`)
			else
				return found.value
			end
		elseif nav[1] == "@lute" then
			return (require)(target)
		end

		local resolved_path = resolver:resolve_path(target)

		do
			local cached = result_cache[resolved_path]
			if cached then
				return cached.value
			end
		end

		local resolved_contents = filesystem.readfiletostring(resolved_path)
		resolved_contents = loader_prepend(resolved_contents)
		local resolved_bytecode = luau.compile(resolved_contents)
		local loaded = luau.load(resolved_bytecode, resolved_path)

		local env_require = require_constructor(resolved_path, result_cache, override)

		local output, count = count_vararg(loaded(env_require))

		if count ~= 1 then
			error("module cannot be required, did not return exactly 1 value", 2) --
		end

		result_cache[resolved_path] = { value = output }

		return output
	end

	return warmluau_require
end

return {
	prepend = loader_prepend,
	new = require_constructor,
	override = override.new,
}
