local analyzer = require("@util/syntax/analyzer")
local warmluau = require("@warmluau/")

export type ImportValue =
	| string --
	| number
	| boolean
	| vector

export type ImportChain = {
	value: ImportValue | {
		literal: analyzer.ConstantData,
	}?,
	index: {
		[string]: ImportValue | ImportChain,
	}?,
	_const: analyzer.KnownConstant?,
}

export type Opts = {
	inject_imports: { [string]: ImportChain }?,
}

return {} :: warmluau.Ingredient<Opts>
