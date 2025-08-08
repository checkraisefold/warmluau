-- test file for now
local append_comment = require("@warmluau/ingredients/append_comment")
local warmluau = require("@warmluau/")

local hello = append_comment.prepare({ text = "--hi there\n" })

local recipe1 = warmluau.recipe(
	hello --
)
local recipe2 = warmluau.recipe(
	append_comment.prepare({ text = "--would you like to sign my petition\n" }),
	append_comment.prepare({ text = "--sign it\n" })
)
local recipe3 = warmluau.recipe(
	append_comment.prepare({ text = "--we've been trying to reach you\n" }),
	append_comment.prepare({ text = "--about your car's extended warranty\n" })
)

local random = math.random(1, 3)

if random == 1 then
	warmluau.bake(recipe1, recipe2)
elseif random == 2 then
	warmluau.bake(recipe1, recipe3)
else
	warmluau.bake(recipe1, recipe2, hello, recipe3)
end
