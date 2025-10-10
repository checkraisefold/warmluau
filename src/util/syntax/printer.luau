--!strict
local DEFAULT_RESULT_SIZE = 1028

local luau = require("@lute/luau")
local visitors = require("./visitors")

local function exhaustive_match(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function print_trivia(trivia: luau.Trivia): string
	if trivia.tag == "whitespace" or trivia.tag == "comment" or trivia.tag == "blockcomment" then
		return trivia.text
	else
		return exhaustive_match(trivia.tag)
	end
end

local function print_trivia_list(trivia: { luau.Trivia })
	local result = ""
	for _, trivia in trivia do
		result ..= print_trivia(trivia)
	end
	return result
end

local function print_token(node: luau.Token): string
	return print_trivia_list(node.leadingTrivia) .. node.text .. print_trivia_list(node.trailingTrivia)
end

local function print_string(node: luau.AstExprConstantString | luau.AstTypeSingletonString): string
	local result = print_trivia_list(node.leadingTrivia)

	if node.quoteStyle == "single" then
		result ..= `'{node.text}'`
	elseif node.quoteStyle == "double" then
		result ..= `"{node.text}"`
	elseif node.quoteStyle == "block" then
		local equals = string.rep("=", node.blockDepth)
		result ..= `[{equals}[{node.text}]{equals}]`
	elseif node.quoteStyle == "interp" then
		result ..= "`" .. node.text .. "`"
	else
		return exhaustive_match(node.quoteStyle)
	end

	result ..= print_trivia_list(node.trailingTrivia)
	return result
end

local function print_interpolated_string(expr: luau.AstExprInterpString): string
	local result = ""

	for i = 1, #expr.strings do
		result ..= print_trivia_list(expr.strings[i].leadingTrivia)
		if i == 1 then
			result ..= "`"
		else
			result ..= "}"
		end
		result ..= expr.strings[i].text

		if i == #expr.strings then
			result ..= "`"
			result ..= print_trivia_list(expr.strings[i].trailingTrivia)
		else
			result ..= "{"
			result ..= print_trivia_list(expr.strings[i].trailingTrivia)
			result ..= print_expr(expr.expressions[i])
		end
	end

	return result
end

local buff = buffer.create(DEFAULT_RESULT_SIZE)
local byte_ptr = 0

local function write(str: string)
	local target_ptr = byte_ptr + #str

	local buffer_len = buffer.len(buff)
	if target_ptr >= buffer_len then
		repeat
			buffer_len *= 2
		until buffer_len >= target_ptr

		local new_buffer = buffer.create(buffer_len)
		buffer.copy(new_buffer, 0, buff)
		buff = new_buffer
	end

	buffer.writestring(buff, byte_ptr, str)
	byte_ptr = target_ptr
end

local visitor = visitors.create()

visitor.vtoken = function(node: luau.Token)
	write(print_token(node))
end

visitor.vstring = function(node: luau.AstExprConstantString)
	write(print_string(node))
	return false
end

visitor.type.vstring = function(node: luau.AstTypeSingletonString)
	write(print_string(node))
	return false
end

visitor.vinterpolated_string = function(node: luau.AstExprInterpString)
	write(print_interpolated_string(node))
	return false
end

--- Returns a string representation of an AstStatBlock
local function print_block(block: luau.AstStatBlock): string
	byte_ptr = 0
	visitor:visit_ast_block(block, visitor)
	return buffer.readstring(buff, 0, byte_ptr)
end

--- Returns a string representation of an AstExpr
function print_expr(block: luau.AstExpr): string
	byte_ptr = 0
	visitor:visit_ast_expression(block, visitor)
	return buffer.readstring(buff, 0, byte_ptr)
end

function printFile(result: { root: luau.AstStatBlock, eof: luau.Eof }): string
	byte_ptr = 0
	visitor:visit_ast_block(result.root, visitor)
	visitor:visit_ast_token(result.eof, visitor)
	return buffer.readstring(buff, 0, byte_ptr)
end

return {
	print = print_block,
	printexpr = print_expr,
	printfile = printFile,
}
