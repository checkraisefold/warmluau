local defs = require("@self/defs")
local luau = require("@lute/luau")
local var_tracking = require("@self/var_tracking")

export type UnaryOperator = defs.UnaryOperator
export type BinaryOperator = defs.BinaryOperator
export type UnknownConstant = defs.UnknownConstant
export type NilConstant = defs.NilConstant
export type BooleanConstant = defs.BooleanConstant
export type NumberConstant = defs.NumberConstant
export type VectorConstant = defs.VectorConstant
export type StringConstant = defs.StringConstant
export type TableConstant = defs.TableConstant
export type Constant = defs.Constant
export type KnownConstant = defs.KnownConstant
export type SimpleConstant = defs.SimpleConstant
export type ConstantData = defs.ConstantData
export type Variable = defs.Variable
export type Tracked = defs.Tracked

local UNKNOWN: UnknownConstant = table.freeze({
	kind = "unknown" :: "unknown",
	data = nil,
})

local function EXHAUSTIVE_MATCH<Err>(value: never, err: Err?): never
	error(err or `Unknown value in exhaustive match: {value}`)
end

local function ASSERT<Value, Error>(value: Value, message: Error): typeof(assert(... :: Value))
	if value then
		return value
	end
	error(message)
end

local function truthy_eh(operand: KnownConstant): boolean
	if (operand.kind ~= "nil") and ((operand.kind ~= "boolean") or (operand.data ~= false)) then
		return true
	else
		return false
	end
end

local function cunknown(): UnknownConstant
	return UNKNOWN
end

local function cbool(data: boolean): BooleanConstant
	return {
		kind = "boolean",
		data = data,
	}
end

local function cnumber(data: number): NumberConstant
	return {
		kind = "number",
		data = data,
	}
end

local function cvector(data: vector): VectorConstant
	return {
		kind = "vector",
		data = data,
	}
end

local function cstring(data: string): StringConstant
	return {
		kind = "string",
		data = data,
	}
end

local function cnil(): NilConstant
	return {
		kind = "nil",
		data = nil,
	}
end

local analyzer = {}
local metatable = { __index = analyzer }
export type Identity = setmetatable<{
	tracked: Tracked,
	cache: { [luau.AstExpr]: Constant },
}, typeof(metatable)>
local function constructor(root: luau.AstStatBlock): Identity
	local tracked = var_tracking.track(root)
	return setmetatable({
		tracked = tracked,
		cache = {},
	}, metatable)
end
local function constructor_from_tracked(tracked: Tracked): Identity
	return setmetatable({
		tracked = tracked,
		cache = {},
	}, metatable)
end

function analyzer.truthy(self: Identity, operand: Constant): BooleanConstant | UnknownConstant
	if operand.kind == "unknown" then
		return cunknown()
	end
	return cbool(truthy_eh(operand))
end

function analyzer.equal(self: Identity, left: Constant, right: Constant): BooleanConstant | UnknownConstant
	if (left.kind == "unknown") or (right.kind == "unknown") then
		return cunknown()
	end
	if left.kind == "nil" then
		return cbool(right.kind == "nil")
	elseif left.kind == "boolean" then
		return cbool((right.kind == "boolean") and (left.data == right.data))
	elseif left.kind == "number" then
		return cbool((right.kind == "number") and (left.data == right.data))
	elseif left.kind == "vector" then
		return cbool((right.kind == "vector") and (left.data == right.data))
	elseif left.kind == "string" then
		return cbool((right.kind == "string") and (left.data == right.data))
	elseif left.kind == "table" then
		return cunknown()
	else
		return EXHAUSTIVE_MATCH(left.kind)
	end
end

function analyzer.unary(
	self: Identity,
	operator: UnaryOperator,
	operand: Constant
): BooleanConstant | NumberConstant | UnknownConstant
	if operand.kind == "unknown" then
		return cunknown()
	end
	if operator == "not" then
		return cbool(truthy_eh(operand))
	elseif operator == "-" then
		if operand.kind == "number" then
			return cnumber(operand.data)
		end
	elseif operator == "#" then
		if operand.kind == "string" then
			return cnumber(#operand.data)
		elseif operand.kind == "table" then
			local data = operand.data
			local metatable = data.metatable
			if metatable then
				local len = metatable.__len
				if len then
					return len(operand)
				end
			end
			local record = data.record
			if record then
				return cnumber(#record)
			end
		end
	else
		return EXHAUSTIVE_MATCH(operator)
	end
	return cunknown()
end

function analyzer.binary(
	self: Identity,
	lhs_operand: Constant,
	operator: BinaryOperator,
	rhs_operand: Constant
): Constant
	if (lhs_operand.kind == "unknown") or (rhs_operand.kind == "unknown") then
		return cunknown()
	end
	if operator == "+" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data + rhs_operand.data)
		elseif (lhs_operand.kind == "vector") and (rhs_operand.kind == "vector") then
			return cvector(lhs_operand.data + rhs_operand.data)
		end
	elseif operator == "-" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data - rhs_operand.data)
		elseif (lhs_operand.kind == "vector") and (rhs_operand.kind == "vector") then
			return cvector(lhs_operand.data - rhs_operand.data)
		end
	elseif operator == "*" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data * rhs_operand.data)
		elseif
			(lhs_operand.kind == "vector") and ((rhs_operand.kind == "vector") or (rhs_operand.kind == "number"))
		then
			return cvector(lhs_operand.data * rhs_operand.data :: vector | number)
		elseif (lhs_operand.kind == "number") and (rhs_operand.kind == "vector") then
			return cvector(lhs_operand.data * rhs_operand.data)
		end
	elseif operator == "/" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data / rhs_operand.data)
		elseif
			(lhs_operand.kind == "vector") and ((rhs_operand.kind == "vector") or (rhs_operand.kind == "number"))
		then
			return cvector(lhs_operand.data / rhs_operand.data :: vector | number)
		elseif (lhs_operand.kind == "number") and (rhs_operand.kind == "vector") then
			return cvector(lhs_operand.data / rhs_operand.data)
		end
	elseif operator == "//" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data // rhs_operand.data)
		elseif
			(lhs_operand.kind == "vector") and ((rhs_operand.kind == "vector") or (rhs_operand.kind == "number"))
		then
			return cvector(lhs_operand.data // rhs_operand.data :: vector | number)
		elseif (lhs_operand.kind == "number") and (rhs_operand.kind == "vector") then
			return cvector(lhs_operand.data // rhs_operand.data)
		end
	elseif operator == "%" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data % rhs_operand.data)
		end
	elseif operator == "^" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cnumber(lhs_operand.data ^ rhs_operand.data)
		end
	elseif operator == ".." then
		if (lhs_operand.kind == "table") or (rhs_operand.kind == "table") then
			return cunknown()
		end
		return cstring(lhs_operand.data :: any .. rhs_operand.data)
	elseif operator == "==" then
		return self:equal(lhs_operand, rhs_operand)
	elseif operator == "~=" then
		local equality = self:equal(lhs_operand, rhs_operand)
		if equality.kind == "boolean" then
			equality.data = not equality.data
		end
		return equality
	elseif operator == "<=" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cbool(lhs_operand.data <= rhs_operand.data)
		elseif (lhs_operand.kind == "string") and (rhs_operand.kind == "string") then
			return cbool(lhs_operand.data <= rhs_operand.data)
		end
	elseif operator == ">=" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cbool(lhs_operand.data >= rhs_operand.data)
		elseif (lhs_operand.kind == "string") and (rhs_operand.kind == "string") then
			return cbool(lhs_operand.data >= rhs_operand.data)
		end
	elseif operator == "<" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cbool(lhs_operand.data < rhs_operand.data)
		elseif (lhs_operand.kind == "string") and (rhs_operand.kind == "string") then
			return cbool(lhs_operand.data < rhs_operand.data)
		end
	elseif operator == ">" then
		if (lhs_operand.kind == "number") and (rhs_operand.kind == "number") then
			return cbool(lhs_operand.data < rhs_operand.data)
		elseif (lhs_operand.kind == "string") and (rhs_operand.kind == "string") then
			return cbool(lhs_operand.data < rhs_operand.data)
		end
	elseif operator == "and" then
		if truthy_eh(lhs_operand) then
			return rhs_operand
		else
			return lhs_operand
		end
	elseif operator == "or" then
		if truthy_eh(lhs_operand) then
			return lhs_operand
		else
			return rhs_operand
		end
	else
		return EXHAUSTIVE_MATCH(operator)
	end
	return cunknown()
end

function analyzer.evaluate_conditional(self: Identity, node: luau.AstExprIfElse): Constant
	local condition = self:evaluate_unit(node.condition)
	if condition.kind == "unknown" then
		return cunknown()
	end
	if truthy_eh(condition) then
		return (self:evaluate_unit(node.consequent))
	end
	for _, elif in node.elseifs do
		condition = self:evaluate_unit(elif.condition)
		if condition.kind == "unknown" then
			return cunknown()
		end
		if truthy_eh(condition) then
			return (self:evaluate_unit(elif.consequent))
		end
	end
	return (self:evaluate_unit(node.antecedent))
end

function analyzer.evaluate_interpstring(
	self: Identity,
	node: luau.AstExprInterpString
): StringConstant | UnknownConstant
	local str = ""
	local strings = node.strings
	local expressions = node.expressions
	for index = 1, #expressions do
		local expr = self:evaluate_unit(expressions[index])
		if (expr.kind == "unknown") or (expr.kind == "table") then
			return cunknown()
		end
		str ..= `{strings[index]}{expr.data}`
	end
	str ..= strings[#strings].text
	return {
		kind = "string" :: "string",
		data = str,
	}
end

function analyzer.evaluate_indexname(self: Identity, node: luau.AstExprIndexName): Constant
	local operand = self:evaluate_unit(node.expression)
	if operand.kind ~= "table" then
		if operand.kind ~= "vector" then
			return cunknown()
		end
		local text = string.lower(node.index.text)
		if text == "x" then
			return cnumber(operand.data.x)
		elseif text == "y" then
			return cnumber(operand.data.y)
		elseif text == "z" then
			return cnumber(operand.data.z)
		else
			return cunknown()
		end
	end
	local data: index<TableConstant, "data"> = operand.data
	local index = node.index.text

	local result: Constant?

	local record = data.record
	if record then
		result = record[index]
	end

	local metatable = not result and data.metatable
	if metatable then
		local indexer = metatable.__index
		if indexer then
			result = indexer(operand, cstring(index))
		end
	end

	return result or cunknown()
end

function analyzer.evaluate_indexexpr(self: Identity, node: luau.AstExprIndexExpr): Constant
	local operand = self:evaluate_unit(node.expression)
	if operand.kind ~= "table" then
		return cunknown()
	end
	local index = self:evaluate_unit(node.index)
	if (index.kind == "unknown") or (index.kind == "table") then
		return cunknown()
	end

	local data: index<TableConstant, "data"> = operand.data

	local result: Constant?

	local record = data.record
	if record then
		result = record[index.data]
	end

	local metatable = not result and data.metatable
	if metatable then
		local indexer = metatable.__index
		if indexer then
			result = indexer(operand, index)
		end
	end

	return result or cunknown()
end

function analyzer.evaluate_call(self: Identity, node: luau.AstExprCall): ...Constant
	local node_func = node.func
	local func = self:evaluate_unit(node_func)
	if func.kind ~= "table" then
		return cunknown()
	end

	local data: index<TableConstant, "data"> = func.data

	local metatable = data.metatable
	if not metatable then
		return cunknown()
	end

	local call = metatable.__call
	if not call then
		return cunknown()
	end

	local node_args = node.arguments

	local args_count = #node_args
	local args = table.create(args_count) :: { Constant }

	for index = 1, args_count do
		args[index] = self:evaluate(node_args[index].node)
	end

	return call(node.self, table.unpack(args))
end

local function CACHE(self: Identity, node: luau.AstExpr, output: Constant): Constant
	self.cache[node] = output
	return output
end

function analyzer.evaluate(self: Identity, node: luau.AstExpr): Constant
	do
		local cached = self.cache[node]
		if cached then
			return cached
		end
	end

	if node.tag == "boolean" then
		return CACHE(self, node, cbool(node.value))
	elseif node.tag == "number" then
		return CACHE(self, node, cnumber(node.value))
	elseif node.tag == "nil" then
		return CACHE(self, node, cnil())
	elseif node.tag == "string" then
		return CACHE(self, node, cstring(node.text))
	elseif node.tag == "unary" then
		return CACHE(self, node, self:unary(node.operator.text, self:evaluate_unit(node.operand)))
	elseif node.tag == "binary" then
		return CACHE(
			self,
			node,
			self:binary(
				self:evaluate_unit(node.lhsoperand),
				-- Lute
				node.operator.text :: any,
				self:evaluate_unit(node.rhsoperand)
			)
		)
		-- TODO: Should groups cancel evaluation?
	elseif node.tag == "group" then
		return CACHE(self, node, self:evaluate_unit(node.expression))
	elseif node.tag == "cast" then
		return CACHE(self, node, self:evaluate_unit(node.operand))
	elseif node.tag == "conditional" then
		return CACHE(self, node, self:evaluate_conditional(node))
	elseif node.tag == "interpolatedstring" then
		return CACHE(self, node, self:evaluate_interpstring(node))
	elseif node.tag == "indexname" then
		return CACHE(self, node, self:evaluate_indexname(node))
	elseif node.tag == "index" then
		return CACHE(self, node, self:evaluate_indexexpr(node))
	elseif (node.tag == "local") then
		local tracked = self.tracked.locals[node["local"]]
		if tracked then
			local init = tracked.init
			if init then
				return CACHE(self, node, init)
			end
			if tracked.writes == 1 then
				local init_expr = tracked.init_expr
				if init_expr then
					local evaluated = self:evaluate(init_expr)
					tracked.init = evaluated
					return CACHE(self, node, evaluated)
				end
			end
		end
	elseif node.tag == "global" then
		local tracked = self.tracked.globals[node.name.text]
		if tracked then
			local init = tracked.init
			if init then
				return CACHE(self, node, init)
			end
			if tracked.writes == 1 then
				local init_expr = tracked.init_expr
				if init_expr then
					local evaluated = self:evaluate(init_expr)
					tracked.init = evaluated
					return CACHE(self, node, evaluated)
				end
			end
		end
	end

	-- Luau
	return CACHE(self, (node :: any) :: luau.AstExpr, cunknown())
end

function analyzer.evaluate_unit(self: Identity, node: luau.AstExpr): Constant
	if node.tag == "call" then
		local out = { self:evaluate_call(node) }
		if #out ~= 1 then
			return cunknown()
		end
		return out[1]
	else
		return self:evaluate(node)
	end
end

local function value_to_expression(value: ConstantData): luau.AstExpr
	if type(value) == "boolean" then
		local output: luau.AstExprConstantBool = {
			leadingTrivia = {},
			position = {
				line = 0,
				column = 0,
			},
			text = if value then "true" else "false",
			value = value,
			trailingTrivia = {},
			tag = "boolean",
		}
		return output
	elseif type(value) == "number" then
		local output: luau.AstExprConstantNumber = {
			leadingTrivia = {},
			position = {
				line = 0,
				column = 0,
			},
			text = tostring(value),
			value = value,
			trailingTrivia = {},
			tag = "number",
		}
		return output
	elseif type(value) == "vector" then
		local z = value.z
		--[[
		im lazy xD
		]]
		if z == 0 then
			return luau.parseexpr(`vector.create({value.x}, {value.y})`)
		else
			return luau.parseexpr(`vector.create({value.x}, {value.y}, {value.z})`)
		end
	elseif type(value) == "string" then
		local output: luau.AstExprConstantString = {
			leadingTrivia = {},
			position = {
				line = 0,
				column = 0,
			},
			text = value,
			trailingTrivia = {},
			tag = "string",
			quoteStyle = "single",
			blockDepth = 0,
		}
		return output
	elseif type(value) == "nil" then
		local output: luau.AstExprConstantNil = {
			leadingTrivia = {},
			position = {
				line = 0,
				column = 0,
			},
			text = "nil",
			trailingTrivia = {},
			tag = "nil",
		}
		return output
	else
		error(`cannot convert value to expression - unknown type '{type(value)}'`)
	end
end

local function constant_to_expression(value: KnownConstant): luau.AstExpr
	if value.kind == "unknown" then
		error("Cannot convert constant to expression; Constant was 'unknown' type.")
	elseif value.kind == "table" then
		local evaluator = ASSERT(
			value.data.evaluate,
			"Cannot convert constant to expression;\z 
			No evaluator listed for table constant"
		)
		return evaluator()
	else
		return value_to_expression(value.data)
	end
end

return {
	create = constructor,
	create_from_tracked = constructor_from_tracked,
	value_to_expression = value_to_expression,
	constant_to_expression = constant_to_expression,

	truthy_eh = truthy_eh,

	cunknown = cunknown,
	cbool = cbool,
	cnumber = cnumber,
	cvector = cvector,
	cstring = cstring,
	cnil = cnil,

	track_variables = var_tracking.track,
}
