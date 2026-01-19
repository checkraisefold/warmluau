local path = require("@std/path")

local override = {}
local metatable = { __index = override }

type InternalIdentity = setmetatable<{
	children: { [string]: InternalIdentity },
	path: path.path,
	value: unknown?,
}, typeof(metatable)>

export type Identity<Children = { [string]: InternalIdentity }> = InternalIdentity & {
	children: Children,
}

local function constructor<Value, Children>(path_input: string, value: Value, children: Children?): Identity<Children>
	local self = setmetatable({
		children = children or {},
		path = path.parse(path_input),
		value = value,
	}, metatable)

	return self
end

return { new = constructor }
