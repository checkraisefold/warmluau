local luau = require("@lute/luau")

export type Base<State = unknown> = {
	state: State,

	read visit_ast_block: (self: Base<State>, node: luau.AstStatBlock, state: State) -> State,
	read visit_ast_statement: (self: Base<State>, node: luau.AstStat, state: State) -> State,
	read visit_ast_expression: (self: Base<State>, node: luau.AstExpr, state: State) -> State,
	read visit_ast_type: (self: Base<State>, node: luau.AstType, state: State) -> State,
	read visit_ast_type_pack: (self: Base<State>, node: luau.AstTypePack, state: State) -> State,
	read visit_ast_token: <Kind>(self: Base<State>, node: luau.Token<Kind>, state: State) -> State,

	vtoken: (luau.Token) -> (),
	vlocal: (luau.AstLocal) -> boolean,
	vfunction_body: (luau.AstFunctionBody) -> boolean,

	vexpression: (luau.AstExpr) -> boolean,
	eexpression: (luau.AstExpr) -> (),
	vstatement: (luau.AstStat) -> boolean,
	estatement: (luau.AstStat) -> (),
	vtype: (luau.AstType) -> boolean,
	etype: (luau.AstType) -> (),
	vtype_pack: (luau.AstTypePack) -> boolean,
	etype_pack: (luau.AstTypePack) -> (),

	vblock: (luau.AstStatBlock) -> boolean,
	vassign: (luau.AstStatAssign) -> boolean,
	vcompound_assign: (luau.AstStatCompoundAssign) -> boolean,
	vfor_in: (luau.AstStatForIn) -> boolean,
	vfor: (luau.AstStatFor) -> boolean,
	vfunction: (luau.AstStatFunction) -> boolean,
	vif: (luau.AstStatIf) -> boolean,
	vlocal_declaration: (luau.AstStatLocal) -> boolean,
	vlocal_function: (luau.AstStatLocalFunction) -> boolean,
	vrepeat: (luau.AstStatRepeat) -> boolean,
	vreturn: (luau.AstStatReturn) -> boolean,
	vtype_alias: (luau.AstStatTypeAlias) -> boolean,
	vtype_function: (luau.AstStatTypeFunction) -> boolean,
	vwhile: (luau.AstStatWhile) -> boolean,

	vboolean: (luau.AstExprConstantBool) -> boolean,
	vnil: (luau.AstExprConstantNil) -> boolean,
	vnumber: (luau.AstExprConstantNumber) -> boolean,
	vstring: (luau.AstExprConstantString) -> boolean,
	vvarargs: (luau.AstExprVarargs) -> boolean,
	vanonymous_function: (luau.AstExprAnonymousFunction) -> boolean,
	vbinary: (luau.AstExprBinary) -> boolean,
	vcall: (luau.AstExprCall) -> boolean,
	vglobal: (luau.AstExprGlobal) -> boolean,
	vgroup: (luau.AstExprGroup) -> boolean,
	vif_expression: (luau.AstExprIfElse) -> boolean,
	vindex_expr: (luau.AstExprIndexExpr) -> boolean,
	vindex_name: (luau.AstExprIndexName) -> boolean,
	vinterpolated_string: (luau.AstExprInterpString) -> boolean,
	vlocal_reference: (luau.AstExprLocal) -> boolean,
	vtable_item: (luau.AstExprTableItem) -> boolean,
	vtable: (luau.AstExprTable) -> boolean,
	vtype_assertion: (luau.AstExprTypeAssertion) -> boolean,
	vunary: (luau.AstExprUnary) -> boolean,
}

export type AddType = {
	read contains_type: true,
	type_varray: (luau.AstTypeArray) -> boolean,
	type_vboolean: (luau.AstTypeSingletonBool) -> boolean,
	type_vfunction: (luau.AstTypeFunction) -> boolean,
	type_vgroup: (luau.AstTypeGroup) -> boolean,
	type_vintersection: (luau.AstTypeIntersection) -> boolean,
	type_vreference: (luau.AstTypeReference) -> boolean,
	type_vstring: (luau.AstTypeSingletonString) -> boolean,
	type_vtable: (luau.AstTypeTable) -> boolean,
	type_vtypeof: (luau.AstTypeTypeof) -> boolean,
	type_vunion: (luau.AstTypeUnion) -> boolean,
	type_vexplicitpack: (luau.AstTypePackExplicit) -> boolean,
	type_vgenericpack: (luau.AstTypePackGeneric) -> boolean,
	type_vvariadicpack: (luau.AstTypePackVariadic) -> boolean,
}

--[=[
at the moment this API can lead to certain inconsistencies w.r.t types, not going to deal with it for now.
]=]
export type AddScope = {
	read contains_scope: true,
	-- called when a scope is opened
	scope_open: () -> (),
	-- called when a scope is closed
	scope_close: () -> (),

	-- insert a local into the current scope
	scope_insert_local: (identifier: luau.AstLocal, assignment: luau.AstExpr?) -> (),
	-- insert a local function into the current scope
	scope_insert_local_function: (fun: luau.AstStatLocalFunction) -> (),
}

export type AddProcess = {
	read contains_process: true,
	rexpression: (luau.AstExpr) -> boolean,
	rstatement: (luau.AstStat) -> boolean,
	rtype: (luau.AstType) -> boolean,
	rtype_pack: (luau.AstTypePack) -> boolean,
	replace_value: (luau.AstExpr) -> luau.AstExpr?,
}

type IdentityAny<State = unknown> =
	& Base<State>
	& (AddType | { contains_type: nil })
	& (AddScope | { contains_scope: nil })
	& (AddProcess | { contains_process: nil })

local function EXHAUSTIVE_MATCH<Msg>(value: never, msg: Msg?): never
	error(msg or `Unknown value in exhaustive match: {value}`)
end

local v: IdentityAny

local function visit_token<T>(token: luau.Token<T>)
	v.vtoken(token)
end

local function visit_punctuated<T, Separator>(list: luau.Punctuated<T, Separator>, apply: (T) -> ())
	for index, item in list do
		apply(item.node)
		if item.separator then
			visit_token(item.separator)
		end
	end
end

local function visit_local(node: luau.AstLocal)
	if not v.vlocal(node) then
		return
	end
	visit_token(node.name)
	if node.colon then
		visit_token(node.colon)
	end
	if node.annotation then
		visit_type(node.annotation)
	end
end

local vscope: AddScope?

local function visit_block(node: luau.AstStatBlock): ()
	if not v.vblock(node) then
		return
	end
	if vscope then
		vscope.scope_open()
		for _, statement in node.statements do
			visit_statement(statement)
		end
		vscope.scope_close()
	else
		for _, statement in node.statements do
			visit_statement(statement)
		end
		return
	end
end

local function visit_if(node: luau.AstStatIf)
	if not v.vif(node) then
		return
	end
	visit_token(node.ifkeyword)
	visit_expression(node.condition)
	visit_token(node.thenkeyword)
	visit_block(node.consequent)
	for _, elseif_node in node.elseifs do
		visit_token(elseif_node.elseifkeyword)
		visit_expression(elseif_node.condition)
		visit_token(elseif_node.thenkeyword)
		visit_block(elseif_node.consequent)
	end
	if node.elsekeyword then
		visit_token(node.elsekeyword)
	end
	if node.antecedent then
		visit_block(node.antecedent)
	end
	visit_token(node.endkeyword)
end

local function visit_while(node: luau.AstStatWhile)
	if not v.vwhile(node) then
		return
	end
	visit_token(node.whilekeyword)
	visit_expression(node.condition)
	visit_token(node.dokeyword)
	visit_block(node.body)
	visit_token(node.endkeyword)
end

local function visit_repeat(node: luau.AstStatRepeat)
	if not v.vrepeat(node) then
		return
	end
	visit_token(node.repeatKeyword)
	visit_block(node.body)
	visit_token(node.untilKeyword)
	visit_expression(node.condition)
end

local function visit_return(node: luau.AstStatReturn)
	if not v.vreturn(node) then
		return
	end
	visit_token(node.returnkeyword)
	visit_punctuated(node.expressions, visit_expression)
end

local function visit_local_statement(node: luau.AstStatLocal)
	if not v.vlocal_declaration(node) then
		return
	end
	visit_token(node.localkeyword)
	visit_punctuated(node.variables, visit_local)
	if node.equals then
		visit_token(node.equals)
	end
	visit_punctuated(node.values, visit_expression)
	if vscope then
		for index, variable in node.variables do
			local value_pair = node.values[index]
			local value = value_pair and value_pair.node
			vscope.scope_insert_local(variable.node, value)
		end
	end
end

local function visit_for(node: luau.AstStatFor)
	if not v.vfor(node) then
		return
	end
	visit_token(node.forkeyword)
	visit_local(node.variable)
	visit_token(node.equals)
	visit_expression(node.from)
	visit_token(node.tocomma)
	visit_expression(node.to)
	if node.stepcomma then
		visit_token(node.stepcomma)
	end
	if node.step then
		visit_expression(node.step)
	end
	visit_token(node.dokeyword)
	if not vscope then
		visit_block(node.body)
	else
		if v.vblock(node.body) then
			vscope.scope_open()
			vscope.scope_insert_local(node.variable)
			for _, statement in node.body.statements do
				visit_statement(statement)
			end
			vscope.scope_close()
		end
	end
	visit_token(node.endkeyword)
end

local function visit_for_in(node: luau.AstStatForIn)
	if not v.vfor_in(node) then
		return
	end
	visit_token(node.forkeyword)
	visit_punctuated(node.variables, visit_local)
	visit_token(node.inkeyword)
	visit_punctuated(node.values, visit_expression)
	visit_token(node.dokeyword)
	if not vscope then
		visit_block(node.body)
	else
		if v.vblock(node.body) then
			vscope.scope_open()
			for _, variable in node.variables do
				vscope.scope_insert_local(variable.node)
			end
			for _, statement in node.body.statements do
				visit_statement(statement)
			end
			vscope.scope_close()
		end
	end
	visit_token(node.endkeyword)
end

local function visit_assign(node: luau.AstStatAssign)
	if not v.vassign(node) then
		return
	end
	visit_punctuated(node.variables, visit_expression)
	visit_token(node.equals)
	visit_punctuated(node.values, visit_expression)
end

local function visit_compound_assign(node: luau.AstStatCompoundAssign)
	if not v.vcompound_assign(node) then
		return
	end
	visit_expression(node.variable)
	visit_token(node.operand)
	visit_expression(node.value)
end

local vtype: AddType?

local function visit_generic(node: luau.AstGenericType)
	visit_token(node.name)
	if node.equals then
		visit_token(node.equals)
	end
	if node.default then
		visit_type(node.default)
	end
end

local function visit_generic_pack(node: luau.AstGenericTypePack)
	visit_token(node.name)
	visit_token(node.ellipsis)
	if node.equals then
		visit_token(node.equals)
	end
	if node.default then
		visit_type_pack(node.default)
	end
end

local function visit_type_alias(node: luau.AstStatTypeAlias)
	if not v.vtype_alias(node) then
		return
	end
	if node.export then
		visit_token(node.export)
	end
	visit_token(node.typeToken)
	visit_token(node.name)
	if node.opengenerics then
		visit_token(node.opengenerics)
	end
	if node.generics then
		visit_punctuated(node.generics, visit_generic)
	end
	if node.genericpacks then
		visit_punctuated(node.genericpacks, visit_generic_pack)
	end
	if node.closegenerics then
		visit_token(node.closegenerics)
	end
	visit_token(node.equals)
	visit_type(node.type)
end

local function visit_string(node: luau.AstExprConstantString)
	if not v.vstring(node) then
		return
	end
	visit_token(node)
end

local function visit_nil(node: luau.AstExprConstantNil)
	if not v.vnil(node) then
		return
	end
	visit_token(node)
end

local function visit_boolean(node: luau.AstExprConstantBool)
	if not v.vboolean(node) then
		return
	end
	visit_token(node)
end

local function visit_number(node: luau.AstExprConstantNumber)
	if not v.vnumber(node) then
		return
	end
	visit_token(node)
end

local function visit_varargs(node: luau.AstExprVarargs)
	if not v.vvarargs(node) then
		return
	end
	visit_token(node)
end

local function visit_local_reference(node: luau.AstExprLocal)
	if not v.vlocal_reference(node) then
		return
	end
	visit_token(node.token)
end

local function visit_global(node: luau.AstExprGlobal)
	if not v.vglobal(node) then
		return
	end
	visit_token(node.name)
end

local function visit_call(node: luau.AstExprCall)
	if not v.vcall(node) then
		return
	end
	visit_expression(node.func)
	if node.openparens then
		visit_token(node.openparens)
	end
	visit_punctuated(node.arguments, visit_expression)
	if node.closeparens then
		visit_token(node.closeparens)
	end
end

local function visit_unary(node: luau.AstExprUnary)
	if not v.vunary(node) then
		return
	end
	visit_token(node.operator)
	visit_expression(node.operand)
end

local function visit_binary(node: luau.AstExprBinary)
	if not v.vbinary(node) then
		return
	end
	visit_expression(node.lhsoperand)
	visit_token(node.operator)
	visit_expression(node.rhsoperand)
end

local function visit_function_body(node: luau.AstFunctionBody, local_fun: luau.AstStatLocalFunction?)
	if not v.vfunction_body(node) then
		-- need to make sure the local fun gets inserted regardless of if the body is visited
		if vscope and local_fun then
			vscope.scope_insert_local_function(local_fun)
		end
		return
	end
	if node.opengenerics then
		visit_token(node.opengenerics)
	end
	if node.generics then
		visit_punctuated(node.generics, visit_generic)
	end
	if node.genericpacks then
		visit_punctuated(node.genericpacks, visit_generic_pack)
	end
	if node.closegenerics then
		visit_token(node.closegenerics)
	end
	visit_token(node.openparens)
	local parameters = node.parameters
	visit_punctuated(parameters, visit_local)
	if node.vararg then
		visit_token(node.vararg)
	end
	if node.varargcolon then
		visit_token(node.varargcolon)
	end
	if node.varargannotation then
		visit_type_pack(node.varargannotation)
	end
	visit_token(node.closeparens)
	if node.returnspecifier then
		visit_token(node.returnspecifier)
	end
	if node.returnannotation then
		visit_type_pack(node.returnannotation)
	end

	if not vscope then
		visit_block(node.body)
	else
		if local_fun then
			vscope.scope_insert_local_function(local_fun)
		end
		if v.vblock(node.body) then
			vscope.scope_open()
			local self = node.self
			if self then
				vscope.scope_insert_local(self)
			end
			for _, parameter in node.parameters do
				vscope.scope_insert_local(parameter.node)
			end
			for _, statement in node.body.statements do
				visit_statement(statement)
			end
			vscope.scope_close()
		end
	end
	visit_token(node.endkeyword)
end

local function visit_attribute(node: luau.AstAttribute)
	visit_token(node)
end

local function visit_anonymous_function(node: luau.AstExprAnonymousFunction)
	if not v.vanonymous_function(node) then
		return
	end
	for _, attribute in node.attributes do
		visit_attribute(attribute)
	end
	visit_token(node.functionkeyword)
	visit_function_body(node.body)
end

local function visit_function(node: luau.AstStatFunction)
	if not v.vfunction(node) then
		return
	end
	for _, attribute in node.attributes do
		visit_attribute(attribute)
	end
	visit_token(node.functionkeyword)
	visit_expression(node.name)
	visit_function_body(node.body)
end

local function visit_local_function(node: luau.AstStatLocalFunction)
	if not v.vlocal_function(node) then
		return
	end
	for _, attribute in node.attributes do
		visit_attribute(attribute)
	end
	visit_token(node.localkeyword)
	visit_token(node.functionkeyword)
	visit_local(node.name)
	if vscope then
		vscope.scope_insert_local_function(node)
	end
	visit_function_body(node.body)
end

local function visit_stat_type_function(node: luau.AstStatTypeFunction)
	if not v.vtype_function(node) then
		return
	end
	if node.export then
		visit_token(node.export)
	end
	visit_token(node.type)
	visit_token(node.functionkeyword)
	visit_token(node.name)
	visit_function_body(node.body)
end

local function visit_table_item(node: luau.AstExprTableItem)
	if not v.vtable_item(node) then
		return
	end
	if node.kind == "list" then
		visit_expression(node.value)
	elseif node.kind == "record" then
		visit_token(node.key)
		visit_token(node.equals)
		visit_expression(node.value)
	elseif node.kind == "general" then
		visit_token(node.indexeropen)
		visit_expression(node.key)
		visit_token(node.indexerclose)
		visit_token(node.equals)
		visit_expression(node.value)
	else
		EXHAUSTIVE_MATCH(node.kind)
	end

	if node.separator then
		visit_token(node.separator)
	end
end

local function visit_table(node: luau.AstExprTable)
	if not v.vtable(node) then
		return
	end
	visit_token(node.openbrace)
	for _, item in node.entries do
		visit_table_item(item)
	end
	visit_token(node.closebrace)
end

local function visit_index_name(node: luau.AstExprIndexName)
	if not v.vindex_name(node) then
		return
	end
	visit_expression(node.expression)
	visit_token(node.accessor)
	visit_token(node.index)
end

local function visit_index_expr(node: luau.AstExprIndexExpr)
	if not v.vindex_expr(node) then
		return
	end
	visit_expression(node.expression)
	visit_token(node.openbrackets)
	visit_expression(node.index)
	visit_token(node.closebrackets)
end

local function visit_group(node: luau.AstExprGroup)
	if not v.vgroup(node) then
		return
	end
	visit_token(node.openparens)
	visit_expression(node.expression)
	visit_token(node.closeparens)
end

local function visit_interpolated_string(node: luau.AstExprInterpString)
	if not v.vinterpolated_string(node) then
		return
	end
	for i = 1, #node.strings do
		visit_token(node.strings[i])
		if i <= #node.expressions then
			visit_expression(node.expressions[i])
		end
	end
end

local function visit_type_assertion(node: luau.AstExprTypeAssertion)
	if not v.vtype_assertion(node) then
		return
	end
	visit_expression(node.operand)
	visit_token(node.operator)
	visit_type(node.annotation)
end

local function visit_if_expression(node: luau.AstExprIfElse)
	if not v.vif_expression(node) then
		return
	end
	visit_token(node.ifkeyword)
	visit_expression(node.condition)
	visit_token(node.thenkeyword)
	visit_expression(node.consequent)
	for _, elseifs in node.elseifs do
		visit_token(elseifs.elseifkeyword)
		visit_expression(elseifs.condition)
		visit_token(elseifs.thenkeyword)
		visit_expression(elseifs.consequent)
	end
	visit_token(node.elsekeyword)
	visit_expression(node.antecedent)
end

local function visit_type_or_pack(node: luau.AstType | luau.AstTypePack)
	if node.tag == "explicit" or node.tag == "generic" or node.tag == "variadic" then
		visit_type_pack(node)
	else
		visit_type(node)
	end
end

local function visit_type_reference(node: luau.AstTypeReference)
	if vtype and vtype.type_vreference(node) then
		if node.prefix then
			visit_token(node.prefix)
		end
		if node.prefixpoint then
			visit_token(node.prefixpoint)
		end
		visit_token(node.name)
		if node.openparameters then
			visit_token(node.openparameters)
		end
		if node.parameters then
			visit_punctuated(node.parameters, visit_type_or_pack)
		end
		if node.closeparameters then
			visit_token(node.closeparameters)
		end
	end
end

local function visit_type_boolean(node: luau.AstTypeSingletonBool)
	if vtype and vtype.type_vboolean(node) then
		visit_token(node)
	end
end

local function visit_type_string(node: luau.AstTypeSingletonString)
	if vtype and vtype.type_vstring(node) then
		visit_token(node)
	end
end

local function visit_type_typeof(node: luau.AstTypeTypeof)
	if vtype and vtype.type_vtypeof(node) then
		visit_token(node.typeof)
		visit_token(node.openparens)
		visit_expression(node.expression)
		visit_token(node.closeparens)
	end
end

local function visit_type_group(node: luau.AstTypeGroup)
	if vtype and vtype.type_vgroup(node) then
		visit_token(node.openparens)
		visit_type(node.type)
		visit_token(node.closeparens)
	end
end

local function visit_type_union(node: luau.AstTypeUnion)
	if vtype and vtype.type_vunion(node) then
		if node.leading then
			visit_token(node.leading)
		end
		visit_punctuated(node.types, visit_type)
	end
end

local function visit_type_intersection(node: luau.AstTypeIntersection)
	if vtype and vtype.type_vintersection(node) then
		if node.leading then
			visit_token(node.leading)
		end
		visit_punctuated(node.types, visit_type)
	end
end

local function visit_type_array(node: luau.AstTypeArray)
	if vtype and vtype.type_varray(node) then
		visit_token(node.openbrace)
		if node.access then
			visit_token(node.access)
		end
		visit_type(node.type)
		visit_token(node.closebrace)
	end
end

local function visit_type_table(node: luau.AstTypeTable)
	if vtype and vtype.type_vtable(node) then
		visit_token(node.openbrace)
		for _, entry in node.entries do
			if entry.access then
				visit_token(entry.access)
			end
			if entry.kind == "indexer" then
				visit_token(entry.indexeropen)
				visit_type(entry.key)
				visit_token(entry.indexerclose)
			elseif entry.kind == "stringproperty" then
				visit_token(entry.indexeropen)
				visit_type_string(entry.key)
				visit_token(entry.indexerclose)
			else
				visit_token(entry.key)
			end
			visit_token(entry.colon)
			visit_type(entry.value)
			if entry.separator then
				visit_token(entry.separator)
			end
		end
		visit_token(node.closebrace)
	end
end

local function visit_type_function_parameter(node: luau.AstTypeFunctionParameter)
	if node.name then
		visit_token(node.name)
	end
	if node.colon then
		visit_token(node.colon)
	end
	visit_type(node.type)
end

local function visit_type_function(node: luau.AstTypeFunction)
	if vtype and vtype.type_vfunction(node) then
		if node.opengenerics then
			visit_token(node.opengenerics)
		end
		if node.generics then
			visit_punctuated(node.generics, visit_generic)
		end
		if node.genericpacks then
			visit_punctuated(node.genericpacks, visit_generic_pack)
		end
		if node.closegenerics then
			visit_token(node.closegenerics)
		end
		visit_token(node.openparens)
		visit_punctuated(node.parameters, visit_type_function_parameter)
		if node.vararg then
			visit_type_pack(node.vararg)
		end
		visit_token(node.closeparens)
		visit_token(node.returnarrow)
		visit_type_pack(node.returntypes)
	end
end

local function visit_type_pack_explicit(node: luau.AstTypePackExplicit)
	if vtype and vtype.type_vexplicitpack(node) then
		if node.openparens then
			visit_token(node.openparens)
		end
		visit_punctuated(node.types, visit_type)
		if node.tailtype then
			visit_type_pack(node.tailtype)
		end
		if node.closeparens then
			visit_token(node.closeparens)
		end
	end
end

local function visit_type_pack_generic(node: luau.AstTypePackGeneric)
	if vtype and vtype.type_vgenericpack(node) then
		visit_token(node.name)
		visit_token(node.ellipsis)
	end
end

local function visit_type_pack_variadic(node: luau.AstTypePackVariadic)
	if vtype and vtype.type_vvariadicpack(node) then
		if node.ellipsis then
			visit_token(node.ellipsis)
		end
		visit_type(node.type)
	end
end

function visit_expression(node: luau.AstExpr)
	if v.vexpression(node) then
		if node.tag == "nil" then
			visit_nil(node)
		elseif node.tag == "boolean" then
			visit_boolean(node)
		elseif node.tag == "number" then
			visit_number(node)
		elseif node.tag == "string" then
			visit_string(node)
		elseif node.tag == "local" then
			visit_local_reference(node)
		elseif node.tag == "global" then
			visit_global(node)
		elseif node.tag == "vararg" then
			visit_varargs(node)
		elseif node.tag == "call" then
			visit_call(node)
		elseif node.tag == "unary" then
			visit_unary(node)
		elseif node.tag == "binary" then
			visit_binary(node)
		elseif node.tag == "function" then
			visit_anonymous_function(node)
		elseif node.tag == "table" then
			visit_table(node)
		elseif node.tag == "indexname" then
			visit_index_name(node)
		elseif node.tag == "index" then
			visit_index_expr(node)
		elseif node.tag == "group" then
			visit_group(node)
		elseif node.tag == "interpolatedstring" then
			visit_interpolated_string(node)
		elseif node.tag == "cast" then
			visit_type_assertion(node)
		elseif node.tag == "conditional" then
			visit_if_expression(node)
		else
			EXHAUSTIVE_MATCH(node.tag)
		end
		v.eexpression(node)
	end
end

function visit_statement(node: luau.AstStat)
	if v.vstatement(node) then
		if node.tag == "block" then
			visit_block(node)
		elseif node.tag == "conditional" then
			visit_if(node)
		elseif node.tag == "expression" then
			visit_expression(node.expression)
		elseif node.tag == "local" then
			visit_local_statement(node)
		elseif node.tag == "return" then
			visit_return(node)
		elseif node.tag == "while" then
			visit_while(node)
		elseif node.tag == "break" then
			visit_token(node)
		elseif node.tag == "continue" then
			visit_token(node)
		elseif node.tag == "repeat" then
			visit_repeat(node)
		elseif node.tag == "for" then
			visit_for(node)
		elseif node.tag == "forin" then
			visit_for_in(node)
		elseif node.tag == "assign" then
			visit_assign(node)
		elseif node.tag == "compoundassign" then
			visit_compound_assign(node)
		elseif node.tag == "function" then
			visit_function(node)
		elseif node.tag == "localfunction" then
			visit_local_function(node)
		elseif node.tag == "typealias" then
			visit_type_alias(node)
		elseif node.tag == "typefunction" then
			visit_stat_type_function(node)
		else
			EXHAUSTIVE_MATCH(node.tag)
		end
		v.estatement(node)
	end
end

function visit_type(node: luau.AstType)
	if v.vtype(node) then
		if node.tag == "reference" then
			visit_type_reference(node)
		elseif node.tag == "boolean" then
			visit_type_boolean(node)
		elseif node.tag == "string" then
			visit_type_string(node)
		elseif node.tag == "typeof" then
			visit_type_typeof(node)
		elseif node.tag == "group" then
			visit_type_group(node)
		elseif node.tag == "union" then
			visit_type_union(node)
		elseif node.tag == "intersection" then
			visit_type_intersection(node)
		elseif node.tag == "optional" then
			visit_token(node)
		elseif node.tag == "array" then
			visit_type_array(node)
		elseif node.tag == "table" then
			visit_type_table(node)
		elseif node.tag == "function" then
			visit_type_function(node)
		else
			EXHAUSTIVE_MATCH(node.tag)
		end
		v.etype(node)
	end
end

function visit_type_pack(node: luau.AstTypePack)
	if v.vtype_pack(node) then
		if node.tag == "explicit" then
			visit_type_pack_explicit(node)
		elseif node.tag == "generic" then
			visit_type_pack_generic(node)
		elseif node.tag == "variadic" then
			visit_type_pack_variadic(node)
		else
			EXHAUSTIVE_MATCH(node.tag)
		end
		v.etype_pack(node)
	end
end

local function always_explore(any: any): boolean
	return true
end
local function noop(...: any): () end

-- this is so cursed
local function api_wrapper<Node, State>(fun: (node: Node) -> ()): (self: Base<State>, node: Node, state: State) -> State
	local function visit_ast(self: IdentityAny<State>, node: Node, state: State): State
		local oldv = v
		v = self
		local oldtype = vtype
		vtype = if self.contains_type then self else nil
		local oldscope = vscope
		vscope = if self.contains_scope then self else nil
		local began = self.state
		self.state = state
		fun(node)
		local stopped = self.state
		self.state = began
		v, vtype, vscope = oldv, oldtype, oldscope
		return stopped
	end
	-- :(
	return visit_ast :: any
end

local visit_ast_block = api_wrapper(visit_block)
local visit_ast_statement = api_wrapper(visit_statement)
local visit_ast_expression = api_wrapper(visit_expression)
local visit_ast_type = api_wrapper(visit_type)
local visit_ast_type_pack = api_wrapper(visit_type_pack)
local visit_ast_token = api_wrapper(visit_token)

local function visitor_base<State>(): Base<State>
	local created: Base<State> = {
		state = nil,

		visit_ast_block = visit_ast_block,
		visit_ast_statement = visit_ast_statement,
		visit_ast_expression = visit_ast_expression,
		visit_ast_type = visit_ast_type,
		visit_ast_type_pack = visit_ast_type_pack,
		visit_ast_token = visit_ast_token :: <Kind>(self: Base<State>, node: luau.Token<Kind>, state: State) -> State,

		vtoken = noop,

		vlocal = always_explore,
		vfunction_body = always_explore,

		vexpression = always_explore,
		eexpression = noop,
		vstatement = always_explore,
		estatement = noop,
		vtype = always_explore,
		etype = noop,
		vtype_pack = always_explore,
		etype_pack = noop,

		vblock = always_explore,
		vassign = always_explore,
		vcompound_assign = always_explore,
		vfor_in = always_explore,
		vfor = always_explore,
		vfunction = always_explore,
		vif = always_explore,
		vlocal_declaration = always_explore,
		vlocal_function = always_explore,
		vrepeat = always_explore,
		vreturn = always_explore,
		vtype_alias = always_explore,
		vtype_function = always_explore,
		vwhile = always_explore,

		vboolean = always_explore,
		vnil = always_explore,
		vnumber = always_explore,
		vstring = always_explore,
		vvarargs = always_explore,
		vanonymous_function = always_explore,
		vbinary = always_explore,
		vcall = always_explore,
		vglobal = always_explore,
		vgroup = always_explore,
		vif_expression = always_explore,
		vindex_expr = always_explore,
		vindex_name = always_explore,
		vinterpolated_string = always_explore,
		vlocal_reference = always_explore,
		vtable_item = always_explore,
		vtable = always_explore,
		vtype_assertion = always_explore,
		vunary = always_explore,

		scope = nil,
		type = nil,
		typepack = nil,
	}

	return created
end

local default_type: AddType = {
	contains_type = true,
	type_varray = always_explore,
	type_vboolean = always_explore,
	type_vfunction = always_explore,
	type_vgroup = always_explore,
	type_vintersection = always_explore,
	type_vreference = always_explore,
	type_vstring = always_explore,
	type_vtable = always_explore,
	type_vtypeof = always_explore,
	type_vunion = always_explore,

	type_vexplicitpack = always_explore,
	type_vgenericpack = always_explore,
	type_vvariadicpack = always_explore,
}
local default_scope: AddScope = {
	contains_scope = true,
	scope_open = noop,
	scope_close = noop,

	scope_insert_local = noop,
	scope_insert_local_function = noop,
}
local function add_type<Visitor>(visitor: Visitor): Visitor & AddType
	-- :(
	visitor = visitor :: any
	for key, value in default_type :: any do
		visitor[key] = value
	end
	return visitor
end
local function add_scope<Visitor>(visitor: Visitor): Visitor & AddScope
	-- :(
	visitor = visitor :: any
	for key, value in default_scope :: any do
		visitor[key] = value
	end
	return visitor
end

export type Create<State = unknown> = Base<State> & AddType

--[=[
Creates a visitor with type and typepack visiting.
]=]
local function visitor_create<State>(): Create<State>
	return add_type(visitor_base())
end

return {
	create = visitor_create,
	base = visitor_base,

	add_type = add_type,
	add_scope = add_scope,

	inner_visit_block = visit_block,
	inner_visit_statement = visit_statement,
	inner_visit_expression = visit_expression,
	inner_visit_type = visit_type,
	inner_visit_type_pack = visit_type_pack,
	inner_visit_token = visit_token,
	inner_visit_local = visit_local,
	inner_visit_punctuated = visit_punctuated,
}
