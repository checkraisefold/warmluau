local filesystem = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local path_helpers = require("@util/path_helpers")
local process = require("@lute/process")
local resolver_types = require("./types")
local styled = require("@util/pretty_print")

type RequireAliases = resolver_types.RequireAliases

local function ASSERT<Value>(value: Value, message: string?)
	if value then
		return value
	end
	error(message or "Assertion Failed!", 2)
end

local homedir_nav = path.parse(process.homedir())

local cache: { [unknown]: RequireAliases } = {}
local function aliases_under_dir(module_directory: path.pathlike): RequireAliases
	local normalized_file_directory =
		ASSERT(path.resolve(module_directory), `could not resolve luaurc directory {styled(module_directory)}`)
	do
		local cached = cache[normalized_file_directory]
		if cached then
			return table.clone(cached)
		end
	end

	local all_aliases = {}

	local parent = normalized_file_directory
	while parent do
		if (not path.isabsolute(parent)) or (#parent.parts == 0) then
			break
		end
		local luaurc_parent = parent
		parent = path.normalize(path.dirname(parent))

		local luaurc_path = path.join(luaurc_parent, ".luaurc")
		local luaurc_path_str = path.format(luaurc_path)

		local file_eh = filesystem.exists(luaurc_path_str)
		if not file_eh then
			continue
		end

		local luaurc_content = filesystem.readfiletostring(luaurc_path_str)
		local luaurc_data: any = json.deserialize(luaurc_content)

		local luaurc_aliases: { [string]: any }? = luaurc_data.aliases

		if luaurc_aliases == nil then
			continue
		end

		for alias, target in luaurc_aliases do
			-- what the fuck, json deserializer?
			if type(alias) ~= "string" then
				continue
			end
			if all_aliases[alias] ~= nil then
				continue
			end

			if path_helpers.starts_with(target, "~") then
				local cloned_target = path.parse(target)
				table.remove(cloned_target.parts, 1)
				target = path.resolve(path.join(homedir_nav, cloned_target))
			else
				target = ASSERT(
					path.resolve(path.join(luaurc_parent, target)),
					`normalizing target for alias "{alias}" failed`
				)
			end

			if not path.isabsolute(target) then
				error(
					`Problem registering alias "{alias}": "{target}" in luaurc "{luaurc_path}",`
						.. ` path parent is not absolute.`
				)
			end

			all_aliases[alias] = path.format(target)
		end
	end

	cache[normalized_file_directory] = all_aliases

	return (table.clone(all_aliases))
end

return {
	under_dir = aliases_under_dir,
}
