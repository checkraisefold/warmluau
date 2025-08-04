local module_loader = {}

local MODULE_LOADER_PREFIX = [[local __WARMLUAU_API, __WARMLUAU_RULES = ...
local __WARMLUAU_REQUIRE = require
function require(path, ...)
    if typeof(path) ~= "string" then
        return __WARMLUAU_REQUIRE(path, ...)
    end
    local rule_match = path:match("^@warmluau/rules/(.+)")
    if rule_match then
        return __WARMLUAU_RULES[rule_match]
    end
    if path:match("^@warmluau") then
        return {}
    end
    return __WARMLUAU_REQUIRE(path, ...)
end
]]

function module_loader.prepend(code: string): string
	return MODULE_LOADER_PREFIX .. code
end

return module_loader
