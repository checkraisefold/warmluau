local REQUIRE_GLOBAL = "require"
local DEFAULT_INDEXING_STYLE: IndexingStyle = "property"

local convert_require = require("@warmluau/ingredients/resolve_require")
local defs = require("@warmluau/")
local filesystem = require("@lute/fs")
local fspath = require("@util/fspath")
local json = require("@batteries/json")
local luau = require("@lute/luau")
local process = require("@lute/process")
local require_resolver = require("@util/require_resolver")
local sourcemap = require("@util/sourcemap")
local styled = require("@util/pretty_print")
local visitors = require("@util/syntax/visitors")

type Opts = convert_require.Opts
type IndexingStyle = convert_require.IndexingStyle

type VisitorState = {
	path: string,
	resolver: require_resolver.Identity,
}

local function ASSERT<Value>(value: Value, message: string?)
	if value then
		return value
	end
	error(message or "Assertion Failed!", 2)
end

local function sanitized(str: string): string
	str = string.gsub(str, '"', '\\"')
	str = string.gsub(str, "\\", "\\\\")
	return str
end

local function rojo_sourcemap_indices(
	sourcemap_parent: fspath.ValidPath,
	rojo_sourcemap: sourcemap.Node,
	indexing_style: IndexingStyle
): { [string]: string }
	sourcemap_parent = fspath.to_nav(sourcemap_parent)

	local indices: { [string]: string } = {}

	local nodes = rojo_sourcemap.children
	if not nodes then
		return {}
	end
	nodes = table.clone(nodes)
	local nodes_count = #nodes
	for index = 1, nodes_count do
		local service = nodes[index]
		service.name = `game:GetService("{sanitized(service.name)}")`
	end

	local index = 0
	while index < nodes_count do
		index += 1
		local node = nodes[index]
		local node_name = node.name

		local file_paths = node["filePaths"]
		if file_paths then
			local file_paths_count = #file_paths
			for file_paths_index = 1, file_paths_count do
				local file_path = file_paths[file_paths_index]
				local absolute_path = ASSERT(
					fspath.normalize(fspath.push(file_path, sourcemap_parent)),
					`couldn't normalize path {styled(file_path)} from sourcemap`
				)
				indices[absolute_path] = node_name
			end
		end
		local children = node.children
		if children then
			local children_count = #children
			if indexing_style == "property" then
				for children_index = 1, children_count do
					local child = children[children_index]
					child.name = `{node_name}["{sanitized(child.name)}"]`
				end
			elseif indexing_style == "waitforchild" then
				for children_index = 1, children_count do
					local child = children[children_index]
					child.name = `{node_name}:WaitForChild("{sanitized(child.name)}")`
				end
			else
				error("unreachable")
			end
			table.move(children, 1, children_count, nodes_count + 1, nodes)
			nodes_count += children_count
		end
	end

	return indices
end

local function prepare(opts: Opts): defs.PreparedIngredient<Opts>
	local sourcemap_path = fspath.to_str(fspath.push(opts.sourcemap_path, process.cwd()))
	ASSERT(filesystem.exists(sourcemap_path), `sourcemap at {styled(sourcemap_path)} doesn't exist`)
	ASSERT(filesystem.type(sourcemap_path) == "file", `sourcemap at {styled(sourcemap_path)} is not a file`)
	local sourcemap_parent_path =
		ASSERT(fspath.normalize(fspath.parent(sourcemap_path)), `sourcemap's parent could not be normalized.`)

	local sourcemap_contents = filesystem.readfiletostring(sourcemap_path)
	local deserialized_sourcemap = json.deserialize(sourcemap_contents)
	local rojo_sourcemap = sourcemap.validate(deserialized_sourcemap)

	local indexing_style = opts.indexing or DEFAULT_INDEXING_STYLE

	local indices = rojo_sourcemap_indices(sourcemap_parent_path, rojo_sourcemap, indexing_style)

	local resolving_visitor = visitors.create() :: visitors.Create<VisitorState>

	function resolving_visitor.vcall(node)
		local func = node.func
		if (func.tag ~= "global") or (func.name.text ~= REQUIRE_GLOBAL) then
			return true
		end
		local arg = node.arguments[1]
		if not arg then
			return true
		end
		local call_expr = arg.node
		if call_expr.tag ~= "string" then
			return true
		end
		local state = resolving_visitor.state
		local resolved = state.resolver:resolve_path(call_expr.text)

		local roblox_target = indices[resolved]
		if roblox_target then
			call_expr = luau.parseexpr(roblox_target)
			arg.node = call_expr
		else
			print(`Could not resolve roblox path for "{call_expr.text}" at {state.path}:{func.name.position.line}:`)
		end

		return true
	end

	local function process(parsley: defs.Parsley, oven: defs.Cooking): ()
		local ast = parsley.root
		if not next(ast.statements) then
			return
		end

		local src_path = oven.cooking_file.src_path
		resolving_visitor:visit_ast_block(ast, {
			path = src_path,
			resolver = require_resolver.from_path(src_path),
		})
	end

	local prepared_ingredient: defs.PreparedIngredient<Opts> = {
		process = process,
	}

	return prepared_ingredient
end

local ingredient: defs.Ingredient<Opts> = {
	prepare = prepare,
}

return ingredient
