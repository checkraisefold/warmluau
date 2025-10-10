local warmluau = require("@warmluau/")

export type Opts = {
	functions: boolean?,
	variables: boolean?,
	branches: boolean?,
	loops: boolean?,
}

return {} :: warmluau.Ingredient<Opts>
