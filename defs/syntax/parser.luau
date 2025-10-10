local parser = require("@util/syntax/parser")

export type Ast = parser.Ast
export type AstExpr = parser.AstExpr
export type Parsley = parser.Parsley

return {} :: typeof(parser)
