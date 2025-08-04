local defs = require("@warmluau")
local rules = require("./oven/rules")
local project = {}

type AppliedRule = {
	rule: rules.Rule,
	opts: rules.RuleOpts?,
}
export type LoadedProject = {
	rules: { AppliedRule },
	apply_rule: (rule: rules.Rule, opts: rules.RuleOpts?) -> nil,
	configure: (project: defs.ProjectConfig) -> nil,
}

local function apply_rule(data: LoadedProject, rule: rules.Rule, opts: rules.RuleOpts?)
	local applied_rule = {
		rule = rule,
		opts = opts,
	}
	table.insert(data.rules, applied_rule)

	return nil
end

local function configure(data: LoadedProject, project: defs.ProjectConfig)
	return nil
end

function project.new(): LoadedProject
	local new_api: LoadedProject = { rules = {} } :: LoadedProject

	function new_api.apply_rule(...)
		return apply_rule(new_api, ...)
	end

	function new_api.configure(...)
		return configure(new_api, ...)
	end

	return new_api
end

return project
