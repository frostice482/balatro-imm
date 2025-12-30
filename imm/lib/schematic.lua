local a = require('imm.lib.assert')
local constructor = require('imm.lib.constructor')

--- @class imm.Schematic
--- @field latest number
--- @field schematicStandard table<string, p.Assert.Schema>
--- @field schematic table<number, p.Assert.Schema>
--- @field migrator table<number, fun(data: any, ...): any, number>
local IS = {}

--- @protected
function IS:init()
	self.latest = 1
	self.schematic = {}
	self.schematicStandard = {}
	self.migrator = {}
end

function IS:parse(data, ...)
	assert(type(data) == "table", "not a table")
	assert(type(data.version) == "number", "version is not a number")
	assert(self.schematic[data.version], "unknown modpack version " .. data.version)
	a.schema(data, "data", self.schematic[data.version])

	local hasmigrate = false
	local v = data.version
	while v ~= self.latest do
		hasmigrate = true
		local m = self.migrator[v]
		assert(m, string.format("Unknown migration from %s", v))
		data, v = m(data, ...)
		assert(v, string.format("Unknown next migrator from %s", v))
	end

	return data, hasmigrate
end
--- @alias imm..C p.Constructor<imm.Schematic, nil> | fun(): imm.Schematic
--- @type imm..C
local S = constructor(IS)
return S
