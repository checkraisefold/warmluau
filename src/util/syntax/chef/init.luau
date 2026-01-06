local extension_base = require("@self/extension_base")
local luau = require("@lute/luau")
local types = require("@self/types")
local visitor = require("@std/syntax/visitor")

local chef = {}

type AnyFunc = types.AnyFunc
type Overrides = types.Overrides
export type Identity<State = unknown> = types.Identity<State>
export type Extensions = types.Extensions

local function noop(...: any) end
local base_extensions = {
	visitScopeOpen = noop,
	visitScopeClose = noop,
	visitScopeInsertLocal = noop,
	visitScopeInsertLocalFunction = noop,
}

local function chef_new_override(self: Identity, key: any, value: any)
	local visitor_object = self._visitor :: { [any]: any }
	if self._reserved[key] then
		self._overrides[key] = value
	else
		visitor_object[key] = value
	end
end

local function chef_get_override(self: Identity, name: string): AnyFunc?
	return rawget(self._overrides, name)
end

function chef.create<State>(): Identity<State>
	local new_visitor = visitor.create()
	local overrides = setmetatable({}, { __index = new_visitor })
	local self: Identity<State> = setmetatable({
		_visitor = new_visitor,
		_overrides = overrides,
		_reserved = table.clone(extension_base :: { [string]: AnyFunc }),
		_pending_locals = {},
		ext = table.clone(base_extensions),
		state = nil,
	}, { __index = overrides, __newindex = chef_new_override })

	-- Wraps a reserved function to handle calling any override if one is present
	-- Gives the reserved function the override func return if present
	local function wrap<T...>(name: string, func: (Identity, any, T...) -> any): (T...) -> any
		return function(...)
			local override = chef_get_override(self, name)

			if not override then
				return func(self, true, ...)
			end

			local ret = override(...)
			func(self, ret, ...)

			return ret
		end
	end

	for key, value in self._reserved do
		local visitor_object = self._visitor :: { [any]: any }
		visitor_object[key] = wrap(key, value)
	end

	return self
end

-- Wraps forwarded functions to add state cleaning/returning
function state_wrap<State, T>(fun: (T, visitor.Visitor) -> ()): (T, Identity<State>, State) -> State
	return function(node, chef, state)
		local old = chef.state
		chef.state = state

		fun(node, chef :: visitor.Visitor)

		local new = chef.state
		chef.state = old

		return new
	end
end

-- Forwarded functions for easier types. Uses the old luacase for easier compatibility
chef.visitblock = visitor.visitblock :: <State>(block: luau.AstStatBlock, chef: Identity<State>) -> ()
chef.visitstatement = visitor.visitstatement :: <State>(statement: luau.AstStat, chef: Identity<State>) -> ()
chef.visitexpression = visitor.visitexpression :: <State>(expression: luau.AstExpr, chef: Identity<State>) -> ()
chef.visittype = visitor.visittype :: <State>(type: luau.AstType, chef: Identity<State>) -> ()
chef.visittypepack = visitor.visittypepack :: <State>(type: luau.AstTypePack, chef: Identity<State>) -> ()
chef.visittoken = visitor.visittoken :: <T, State>(token: luau.Token<T>, chef: Identity<State>) -> ()
chef.visit = visitor.visit :: <State>(node: luau.AstNode, chef: Identity<State>) -> ()

chef.visitblockstate =
	state_wrap(visitor.visitblock) :: <State>(block: luau.AstStatBlock, chef: Identity<State>, state: State) -> State
chef.visitstatementstate =
	state_wrap(visitor.visitstatement) :: <State>(statement: luau.AstStat, chef: Identity<State>, state: State) -> State
chef.visitexpressionstate =
	state_wrap(visitor.visitexpression) :: <State>(expression: luau.AstExpr, chef: Identity<State>, state: State) -> State
chef.visittypestate =
	state_wrap(visitor.visittype) :: <State>(type: luau.AstType, chef: Identity<State>, state: State) -> State
chef.visittypepackstate =
	state_wrap(visitor.visittypepack) :: <State>(type: luau.AstTypePack, chef: Identity<State>, state: State) -> State
chef.visittokenstate =
	state_wrap(visitor.visittoken) :: <T, State>(token: luau.Token<T>, chef: Identity<State>, state: State) -> State
chef.visitstate = state_wrap(visitor.visit) :: <State>(node: luau.AstNode, chef: Identity<State>, state: State) -> State

return chef
