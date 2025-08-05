local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local json = require("@batteries/json")
local resolver_types = require("./types")

type RequireAliases = resolver_types.RequireAliases

local function ASSERT<Value>(value: Value, message: string?)
	if value then return value end
	error(message or "Assertion Failed!", 2)
end

local cache: { [unknown]: RequireAliases } = {}
local function get_luaurc_aliases(module_directory: string): RequireAliases
	local normalized_file_directory =
		ASSERT(fspath.normalize(module_directory), `could not normalize luaurc directory '{module_directory}'`)
	do
		local cached = cache[normalized_file_directory]
		if cached then return table.clone(cached) end
	end

	local all_aliases = {}

	local parent = normalized_file_directory
	while parent do
		if not fspath.absolute_eh(parent) then break end
		local luaurc_parent = parent
		parent = fspath.normalize(fspath.parent(parent))

		local luaurc_path = fspath.push(".luaurc", luaurc_parent)

		local luaurc_path_str = fspath.to_str(luaurc_path)

		local file_eh = filesystem.exists(luaurc_path_str)
		if not file_eh then continue end

		local luaurc_content = filesystem.readfiletostring(luaurc_path_str)
		local luaurc_data: any = json.deserialize(luaurc_content)

		local luaurc_aliases: { [string]: any }? = luaurc_data.aliases

		if luaurc_aliases == nil then continue end

		for alias, target in luaurc_aliases do
			if all_aliases[alias] ~= nil then continue end

			local full_target = ASSERT(
				fspath.normalize(fspath.push(target, luaurc_parent)),
				`normalizing target for alias "{alias}" failed`
			)

			if not fspath.absolute_eh(full_target) then
				error(
					`Problem registering alias "{alias}": "{target}" in luaurc "{luaurc_path}",`
						.. ` path parent is not absolute.`
				)
			end

			all_aliases[alias] = full_target
		end
	end

	cache[normalized_file_directory] = all_aliases

	return (table.clone(all_aliases))
end

return {
	from_luaurc = get_luaurc_aliases,
}
