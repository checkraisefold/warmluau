local fspath = require("@util/fspath")

local override = {}
local metatable = { __index = override }

type InternalIdentity = setmetatable<{
	children: { [string]: InternalIdentity },
	path: fspath.Nav,
	value: unknown?,
}, typeof(metatable)>

export type Identity<Children = { [string]: InternalIdentity }> = InternalIdentity & {
	children: Children,
}

local function constructor<Value, Children>(path: string, value: Value, children: Children?): Identity<Children>
	local self = setmetatable({
		children = children or {},
		path = fspath.to_nav(path),
		value = value,
	}, metatable)

	return self
end

return { new = constructor }
