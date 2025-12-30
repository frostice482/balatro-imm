--- @class imm.MP.Schematic: imm.Schematic
--- @field migrator table<number, fun(data: any, mp: imm.Modpack): any, number>
local s = require('imm.lib.schematic')()

s.latest = 2

s.defaultColors = {
	fg = "009dff",
	bg = "646eb7",
	text = "ffffff"
}

s.schematicStandard.mods = {
	type = "table",
	restProps = {
		type = "table",
		props = {
			version = { type = "string" },
			url = { type = {"string", "nil"} },
			init = { type = {"boolean", "nil"} },
			bundle = { type = {"boolean", "nil"} },
		}
	}
}

s.colorPattern = '^%x%x%x%x%x%x$'

s.schematicStandard.colors = {
	type = "table",
	props = {
		bg = { type = "string", pattern = s.colorPattern },
		fg = { type = "string", pattern = s.colorPattern },
		text = { type = "string", pattern = s.colorPattern },
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
		order = { type = "number" },
		mods = s.schematicStandard.mods,
		colors = s.schematicStandard.colors
	}
}

s.migrator[1] = function (data, mp)
	data.colors = copy_table(s.defaultColors)
	data.order = mp.list and mp.list:highestOrder() + 1 or 0
	return data, 2
end

return s