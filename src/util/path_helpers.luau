local path = require("@std/path")

local path_helpers = {}

function path_helpers.equal(first: path.pathlike, second: path.pathlike)
	return path.format(path.normalize(first)) == path.format(path.normalize(second))
end

function path_helpers.starts_with(base: path.pathlike, prefix: path.pathlike)
	local base_path = path.parse(base)
	local prefix_path = path.parse(prefix)

	-- FIXME: only uses pairs due to incorr. types with generalized iteration, idx/value are errtypes
	for idx, value in pairs(prefix_path.parts) do
		if base_path.parts[idx] ~= value then
			return false
		end
	end

	return true
end

return path_helpers
