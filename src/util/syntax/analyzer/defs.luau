local luau = require("@lute/luau")

export type UnaryOperator = "not" | "-" | "#"
export type BinaryOperator =
	| "^"
	| "*"
	| "/"
	| "//"
	| "%"
	| "+"
	| "-"
	| ".."
	| "<"
	| ">"
	| "<="
	| ">="
	| "~="
	| "=="
	| "and"
	| "or"

export type UnknownConstant = {
	read kind: "unknown",
	read data: nil,
}

export type NilConstant = {
	kind: "nil",
	data: nil,
}

export type BooleanConstant = {
	kind: "boolean",
	data: boolean,
}

export type NumberConstant = {
	kind: "number",
	data: number,
}

export type VectorConstant = {
	kind: "vector",
	data: vector,
}

export type StringConstant = {
	kind: "string",
	data: string,
}

export type TableConstant = {
	kind: "table",
	data: {
		record: { [ConstantData]: Constant }?,
		metatable: {
			__len: ((self: TableConstant) -> NumberConstant)?,
			__index: ((self: TableConstant, index: Constant) -> Constant)?,
			__call: ((self: boolean, ...Constant) -> ...Constant)?,
		}?,
		evaluate: (() -> luau.AstExpr)?,
	},
}

export type Constant =
	| UnknownConstant --
	| NilConstant
	| BooleanConstant
	| NumberConstant
	| VectorConstant
	| StringConstant
	| TableConstant

export type KnownConstant =
	| NilConstant --
	| BooleanConstant
	| NumberConstant
	| VectorConstant
	| StringConstant
	| TableConstant

export type SimpleConstant =
	| UnknownConstant --
	| NilConstant
	| BooleanConstant
	| NumberConstant
	| VectorConstant
	| StringConstant

export type ConstantData = index<SimpleConstant, "data">

export type Variable = {
	writes: number,
	init: Constant?,
	init_expr: luau.AstExpr?,
}

export type Tracked = {
	globals: { [string]: Variable },
	locals: { [luau.AstLocal]: Variable },
}

return nil
