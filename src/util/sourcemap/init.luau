local pretty_print = require("@util/pretty_print")

export type Node = {
	name: string,
	filePaths: { string }?,
	children: { Node }?,
}

local function ASSERT<Value, Message>(value: Value, message: Message?)
	if value then return value end
	error(message, 2)
end

-- save repetitive allocations
local reused_nodes_list: { Node } = {}

local function validate<Value>(value: Value): Node
	local nodes = reused_nodes_list
	nodes[1] = value
	local nodes_count = 1

	local index = 0
	while index < nodes_count do
		index += 1
		local node = nodes[index]
		ASSERT(type(node) == "table", `node in rojo sourcemap was not a table: {pretty_print(value)}`)
		node = node :: { [string]: unknown }
		local name = node["name"]
		ASSERT(name, `node in rojo sourcemap does not have a name: {pretty_print(value)}`)
		ASSERT(type(name) == "string", `node's name in rojo sourcemap was not a string, node: {pretty_print(value)}`)
		local file_paths = node["filePaths"]
		if file_paths then
			ASSERT(
				type(file_paths) == "table",
				`node's filePaths in rojo sourcemap was not a table, node: {pretty_print(value)}`
			)
		end
		local children = node["children"]
		if children then
			ASSERT(
				type(children) == "table",
				`node's children in rojo sourcemap was not a table, node: {pretty_print(value)}`
			)
			children = children :: { Node }
			local children_count = #children
			table.move(children, 1, children_count, nodes_count + 1, nodes)
			nodes_count += children_count
		end
	end

	table.clear(nodes)

	return value
end

return {
	validate = validate,
}
