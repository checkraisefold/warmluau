local warmluau = require("@warmluau/")

export type IndexingStyle = "waitforchild" | "property"

export type Opts = {
	sourcemap_path: string,

	indexing: IndexingStyle?,
}

return {} :: warmluau.Ingredient<Opts>
