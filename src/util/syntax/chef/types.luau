local luau = require("@lute/luau")
local visitor = require("@std/syntax/visitor")

-- The metatable setup here will cause any nil indexes on `Chef` to first look into the overrides table. If nothing's
-- there, we resort to checking the actual visitor object. This behavior is somewhat opaque, not ideal, and has minor
-- performance ramifications. However, the alternative is to bundle a full rewrite of the Lute visitor module with the
-- project, which introduces significantly more headaches for maintenance and updates down the line.
export type AnyFunc = (...any) -> ...any
export type Overrides = setmetatable<{ [string]: AnyFunc }, { __index: visitor.Visitor }>
export type Chef<State = unknown> = setmetatable<{
	_visitor: visitor.Visitor,
	_overrides: Overrides,
	_reserved: { [string]: AnyFunc },
	_pending_locals: { luau.AstLocal },
	ext: Extensions,
	state: State,
}, { __index: Overrides }>

-- CamelCase is picked to match the Lute visitor library, since we're using it internally and the Chef type is
-- overall compatible/interchangeable with the Lute `Visitor` type.
export type Extensions = {
	visitScopeOpen: () -> (),
	visitScopeClose: () -> (),
	visitScopeInsertLocal: (identifier: luau.AstLocal, assignment: luau.AstExpr?) -> (),
	visitScopeInsertLocalFunction: (fun: luau.AstStatLocalFunction) -> (),
}

return {}
