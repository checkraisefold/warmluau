local warmluau = {}
local luau = require("@lute/luau")

export type Ast = luau.AstStatBlock
export type Opts = { [string]: any }
export type Rule<O = Opts?> = {
	process: (ast: Ast, opts: O) -> Ast,
	validate: ((opts: O) -> boolean)?,
}

export type ProjectConfig = {
	name: string,
}

function warmluau.apply_rule<O>(rule: Rule<O>, opts: O): nil
	error("not implemented")
end

function warmluau.configure(project: ProjectConfig): nil
	error("not implemented")
end

return warmluau
