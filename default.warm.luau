local resolve_constant = require("@warmluau/ingredients/resolve_constant")
local warmluau = require("@warmluau/")

warmluau.bake(resolve_constant.prepare({
	inject_imports = {
		math = {
			index = {
				tau = 6.283185307179586,
				pi = { value = { literal = nil } },
			},
		},
	},
}))
