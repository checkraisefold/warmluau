local luau = require("@lute/luau")
local types = require("./types")

local extension_base = {}

local function visit_function_body(node: luau.AstExprFunction, chef: types.Identity)
	if node.self then
		table.insert(chef._pending_locals, node.self)
	end
	for _, parameter in node.parameters do
		table.insert(chef._pending_locals, parameter.node)
	end
end

local function visit_function_node(
	self: types.Identity,
	override: boolean,
	node: luau.AstExprFunction
): boolean
	if not override then
		return override
	end

	visit_function_body(node, self)
	return true
end

function extension_base.visitStatFunction(self: types.Identity, override: boolean, node: luau.AstStatFunction)
	visit_function_node(self, override, node.func)
end
function extension_base.visitExprAnonymousFunction(self: types.Identity, override: boolean, node: luau.AstStatFunction)
	visit_function_node(self, override, node.func)
end
function extension_base.visitStatTypeFunction(self: types.Identity, override: boolean, node: luau.AstStatTypeFunction)
	visit_function_node(self, override, node.body)
end

function extension_base.visitStatFor(self: types.Identity, override: boolean, node: luau.AstStatFor): boolean
	if not override then
		return override
	end

	table.insert(self._pending_locals, node.variable)
	return true
end

function extension_base.visitStatForIn(self: types.Identity, override: boolean, node: luau.AstStatForIn): boolean
	if not override then
		return override
	end

	for _, variable in node.variables do
		table.insert(self._pending_locals, variable.node)
	end
	return true
end

function extension_base.visitStatLocalDeclarationEnd(self: types.Identity, override: boolean, node: luau.AstStatLocal)
	for index, variable in node.variables do
		local value_pair = node.values[index]
		local value = value_pair and value_pair.node
		self.ext.visitScopeInsertLocal(variable.node, value)
	end
end

function extension_base.visitStatLocalFunction(
	self: types.Identity,
	override: boolean,
	node: luau.AstStatLocalFunction
): boolean
	if not override then
		return override
	end

	visit_function_body(node.func, self)
	self.ext.visitScopeInsertLocalFunction(node)

	return true
end

function extension_base.visitStatBlock(self: types.Identity, override: boolean, _): boolean
	if not override then
		return override
	end
	self.ext.visitScopeOpen()

	for _, pending in self._pending_locals do
		self.ext.visitScopeInsertLocal(pending)
	end
	table.clear(self._pending_locals)

	return true
end

function extension_base.visitStatBlockEnd(self: types.Identity, _, _)
	self.ext.visitScopeClose()
end

return extension_base
