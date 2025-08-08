local PREPEND = [[math.randomseed(0); local require = ...;]]

local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local ingredients = require("@lib/ingredients")
local luau = require("@lute/luau")
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

local function warmluau_require_new(api: any, requiring_path: string, result_cache: ResultCache?)
	local result_cache: ResultCache = result_cache or {}
	local resolver = require_resolver.from_path(requiring_path)

	local function warmluau_require<Path>(target: Path, ...: never): unknown
		assert(select("#", ...) == 0, "exactly 1 argument expected")
		if typeof(target) ~= "string" then
			return (require)(target)
		end
		local nav = fspath.to_nav(target)
		if nav[1] == "@warmluau" then
			local second = nav[2]
			if not second then
				return api --
			end
			if second == "ingredients" then
				local third = nav[3]
				local found = (ingredients :: any)[third]
				if not found then
					error(`Could not resolve warmluau ingredient path for {styled(target)}.`)
				else
					return found
				end
			else
				error(`Could not resolve warmluau path for {styled(target)}.`)
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

		local env_require = warmluau_require_new(api, resolved_path, result_cache)

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
	require_new = warmluau_require_new,
}
