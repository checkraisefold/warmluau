local analyzer = require("@util/syntax/analyzer")
local luau = require("@lute/luau")
local replacer = require("@self/replacer")
local resolve_constant = require("@warmluau/ingredients/resolve_constant")
local tokentool = require("@util/syntax/tokentool")
local triviatool = require("@util/syntax/triviatool")
local visitors = require("@util/syntax/visitors")
local warmluau = require("@warmluau/")

type Opts = resolve_constant.Opts

-- TODO: asttoolkit
local function cglobal(text: string): luau.AstExprGlobal
	return {
		tag = "global",
		name = {
			leadingTrivia = {},
			position = {
				line = 0,
				column = 0,
			},
			text = text,
			trailingTrivia = {},
		},
	}
end

local function import_to_constant(
	evaluate: () -> luau.AstExpr,
	indexer: index<resolve_constant.ImportChain, "index">
): analyzer.TableConstant
	local record: { [analyzer.ConstantData]: analyzer.Constant } = {}
	if indexer then
		for component, child in indexer do
			local value
			local child_indexer
			if type(child) == "table" then
				child_indexer = child.index
				local const = child._const
				if const then
					local function evaluator()
						return analyzer.constant_to_expression(const)
					end
					record[component] = import_to_constant(evaluator, child_indexer)
					continue
				end
				local child_value = child.value
				if type(child_value) == "table" then
					value = child_value.literal
				else
					value = child_value
				end
			else
				value = child
			end
			local function evaluator()
				return analyzer.value_to_expression(value)
			end
			record[component] = import_to_constant(evaluator, child_indexer)
		end
	end
	return {
		kind = "table",
		data = {
			record = record,
			evaluate = evaluate,
		},
	}
end

local function prepare_resolve_constant(opts: Opts): warmluau.PreparedIngredient<Opts>
	local injected_imports = opts.inject_imports

	local function process(parsley: warmluau.Parsley): ()
		local ast = parsley.root
		local statements = ast.statements
		if not next(statements) then
			return
		end

		local tracked = analyzer.track_variables(ast)

		if injected_imports then
			for name, global in tracked.globals do
				local injected_chain = injected_imports[name]
				if (not injected_chain) or (global.writes ~= 0) then
					continue
				end
				local function evaluate_global_import(): luau.AstExpr
					return cglobal(name)
				end
				global.init = import_to_constant(evaluate_global_import, injected_chain.index)
				global.writes = 1
			end
		end

		local computer = analyzer.create_from_tracked(tracked)
		local function processor(expression: luau.AstExpr): luau.AstExpr?
			local evaluated: analyzer.Constant
			if expression.tag == "call" then
				local result = { computer:evaluate_call(expression) }
				if #result ~= 1 then
					visitors.inner_visit_expression(expression)
					return nil
				end
				evaluated = result[1]
			else
				evaluated = computer:evaluate(expression)
			end
			if evaluated.kind == "unknown" then
				visitors.inner_visit_expression(expression)
				return nil
			end

			local trivia = triviatool.steal_from_expr(expression)
			local constant_as_expr = analyzer.constant_to_expression(evaluated)
			local firstlast = tokentool.firstlast_from_expr(constant_as_expr)
			if not firstlast then
				print(`a non-critical internal problem ocurred while resolving constants;\z 
			output should be stable, but whitespace might not be maintained.`)
			else
				triviatool.mutate.push_lead(trivia.leading, firstlast.first)
				triviatool.mutate.append_trail(trivia.trailing, firstlast.last)
			end

			return constant_as_expr
		end
		replacer.process_values(ast, processor)
	end

	local prepared_ingredient: warmluau.PreparedIngredient<Opts> = {
		process = process,
	}

	return prepared_ingredient
end

local ingredient: warmluau.Ingredient<Opts> = {
	prepare = prepare_resolve_constant,
}

return ingredient
