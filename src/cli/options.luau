local cli = require("@batteries/cli")

local function add_options(parser: cli.Parser)
	parser:add("help", "flag", {
		help = "get help",
		aliases = { "h" },
	})
	parser:add("version", "flag", {
		help = "get the version",
		aliases = { "v" },
	})
	parser:add("bake", "flag", {
		help = "base mode (bake)",
		aliases = { "b" },
	})
	parser:add("recursive", "flag", {
		help = "recurse into subdirectories",
		aliases = { "r" },
	})

	parser:add("input", "option", {
		help = "input directory",
		aliases = { "i" },
	})
	parser:add("output", "option", {
		help = "output directory",
		aliases = { "o" },
	})
	parser:add("project", "option", {
		help = "project file path",
		aliases = { "p" },
	})
end

return {
	add_options = add_options,
}
