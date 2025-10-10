--!strict
local luau = require("@lute/luau")

export type Ast = luau.AstStatBlock
export type AstExpr = luau.AstExpr
export type Parsley = {
	root: Ast,
	eof: luau.Eof,
}

local function parse(source: string): Ast
	return luau.parse(source).root
end

local function parseexpr(source: string): AstExpr
	return luau.parseexpr(source)
end

local function parsefile(source: string): Parsley
	local result = luau.parse(source)
	return { root = result.root, eof = result.eof }
end

return {
	parse = parse,
	parseexpr = parseexpr,
	parsefile = parsefile,
}
