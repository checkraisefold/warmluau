local IMPL: any = nil

local defs = require("@warmluau/")
local requirer = require("@util/requirer")

local dst = requirer.override

local function dir<Children>(children: Children): Children
	local children = children :: { [string]: unknown }
	for index, value in children do
		children[index] = dst(index, value)
	end
	return children
end

return dst("@warmluau", IMPL :: typeof(defs), {
	ingredients = dst(
		"ingredients",
		nil,
		dir({
			append_comment = require("@lib/ingredients/append_comment"),
			resolve_require = require("@lib/ingredients/resolve_require"),
			resolve_constant = require("@lib/ingredients/resolve_constant"),
		})
	),
	syntax = dst(
		"syntax",
		nil,
		dir({
			analyzer = require("@util/syntax/analyzer"),
			parser = require("@util/syntax/parser"),
			printer = require("@util/syntax/printer"),
			visitors = require("@util/syntax/visitors"),
		})
	),
})
