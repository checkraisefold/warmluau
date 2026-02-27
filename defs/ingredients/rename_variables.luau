local warmluau = require("@warmluau/")

export type Opts = {
	hash: ((string) -> string)?
}

return {} :: warmluau.Ingredient<Opts>
