local types = require("@self/types")
local rules = {
	append_comment = require("@self/append_comment"),
}

export type RuleOpts = types.Opts
export type Rule<O = RuleOpts?> = types.Rule<O>
export type BuiltinRules = typeof(rules)
export type BuiltinRuleIdentifier = keyof<BuiltinRules>

return rules :: { [BuiltinRuleIdentifier]: Rule }
