local REQUIRE_GLOBAL = "require"
local DEFAULT_INDEXING_STYLE: IndexingStyle = "property"

local chef = require("@util/syntax/chef")
local defs = require("@warmluau/")
local filesystem = require("@std/fs")
local json = require("@std/json")
local luau = require("@lute/luau")
local path = require("@std/path")
local process = require("@lute/process")
local require_resolver = require("@util/require_resolver")
local resolve_require = require("@warmluau/ingredients/resolve_require")
local sourcemap = require("@util/sourcemap")
local styled = require("@util/pretty_print")

type Opts = resolve_require.Opts
type IndexingStyle = resolve_require.IndexingStyle

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
	sourcemap_parent: path.pathlike,
	rojo_sourcemap: sourcemap.Node,
	indexing_style: IndexingStyle
): { [string]: string }
	sourcemap_parent = path.parse(sourcemap_parent)

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
				local absolute_path
				if path.isabsolute(file_path) then
					absolute_path = file_path
				else
					absolute_path = ASSERT(
						path.normalize(path.join(sourcemap_parent, file_path)),
						`couldn't normalize path {styled(file_path)} from sourcemap`
					)
				end
				indices[path.format(path.parse(absolute_path))] = node_name
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
	local sourcemap_path = path.format(path.join(process.cwd(), opts.sourcemap_path))
	ASSERT(filesystem.exists(sourcemap_path), `sourcemap at {styled(sourcemap_path)} doesn't exist`)
	ASSERT(filesystem.type(sourcemap_path) == "file", `sourcemap at {styled(sourcemap_path)} is not a file`)
	local sourcemap_parent_path =
		ASSERT(path.normalize(path.join(sourcemap_path, "../")), `sourcemap's parent could not be normalized.`)

	local sourcemap_contents = filesystem.readfiletostring(sourcemap_path)
	local deserialized_sourcemap = json.deserialize(sourcemap_contents)
	local rojo_sourcemap = sourcemap.validate(deserialized_sourcemap)

	local indexing_style = opts.indexing or DEFAULT_INDEXING_STYLE

	local indices = rojo_sourcemap_indices(sourcemap_parent_path, rojo_sourcemap, indexing_style)

	local resolving_visitor = chef.create() :: chef.Identity<VisitorState>

	function resolving_visitor.visitExprCall(node: luau.AstExprCall)
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
		local success, resolved = pcall(state.resolver.resolve_path, state.resolver, call_expr.text)
		if not success then
			print(`problem happened while resolving a path:\n{resolved}\n`)
			return true
		end

		local roblox_target = indices[path.format(path.parse(resolved))]
		if roblox_target then
			call_expr = luau.parseexpr(roblox_target)
			arg.node = call_expr
		else
			print(
				`Could not resolve sourcemap path for "{call_expr.text}" \z
				at {state.path}:{func.name.location.beginline}:\n\z
				\tresolved path: {path.format(resolved)}`
			)
		end

		return true
	end

	local function process(parsley: defs.Parsley, oven: defs.Cooking): ()
		local ast = parsley.root
		if not next(ast.statements) then
			return
		end

		local src_path = oven.cooking_file.src_path
		chef.visitblockstate(ast, resolving_visitor, {
			path = src_path,
			resolver = require_resolver.from_path(src_path, opts.import_json_yml_toml),
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
