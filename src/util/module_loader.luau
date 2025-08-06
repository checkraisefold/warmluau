local module_loader = {}

local MODULE_LOADER_PREFIX = "local require = ...;"

function module_loader.prepend(code: string): string
	return MODULE_LOADER_PREFIX .. code
end

return module_loader
