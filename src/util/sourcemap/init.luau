local pretty_print = require("@util/pretty_print")

export type Node = {
	name: string,
	filePaths: { string }?,
	children: { Node }?,
}

local function ASSERT<Value, Message>(value: Value, message: Message?)
	if value then
		return value
	end
	error(message, 2)
end

local function validate<Value>(node: Value): Node
	ASSERT(type(node) == "table", `node in rojo sourcemap was not a table: {pretty_print(node)}`)
	node = node :: { [string]: unknown }
	ASSERT(type(node.name) == "string", `node in rojo sourcemap does not have a valid name, node: {pretty_print(node)}`)
	local file_paths = node.filePaths
	if file_paths then
		ASSERT(
			type(file_paths) == "table",
			`node's filePaths in rojo sourcemap was not valid, node: {pretty_print(node)}`
		)
	end
	local children = node.children
	if children then
		ASSERT(
			type(children) == "table",
			`node's children in rojo sourcemap was not a table, node: {pretty_print(node)}`
		)
		for _, child in children do
			validate(child)
		end
	end
	-- Luau
	return node :: any
end

return {
	validate = validate,
}
