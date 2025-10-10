local warmluau = require("@warmluau/")

export type Mode = "early" | "late"

export type Opts = {
	text: string,
	mode: Mode?,
}

return {} :: warmluau.Ingredient<Opts>
