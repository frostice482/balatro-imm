--- @class imm.MP.SchematicImport: imm.Schematic
--- @field migrator table<number, fun(data: any, tar: Tar.Root): any, number>
local s = require('imm.lib.schematic')()
local ls = require("imm.mp.schematic.mp")

s.latest = 2

s.schematicStandard.mods = {
	type = "table",
	isArray = true,
	restProps = {
		type = "table",
		props = {
			id = { type = "string" },
			version = { type = "string" },
			url = { type = {"string", "nil"} },
		}
	}
}

s.schematic[1] = {
	type = 'table',
	props = {
		name = { type = "string" },
		author = { type = "string" },
		mods = s.schematicStandard.mods
	}
}
s.schematic[2] = {
	type = 'table',
	props = {
		name = { type = "string" },
		author = { type = "string" },
		mods = s.schematicStandard.mods,
		colors = ls.schematicStandard.colors
	}
}

s.migrator[1] = function (data)
	data.colors = copy_table(ls.defaultColors)
	return data, 2
end

return s
