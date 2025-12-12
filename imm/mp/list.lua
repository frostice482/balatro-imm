local constructor = require('imm.lib.constructor')
local MP = require("imm.mp.mp")
local getmods = require("imm.mod.get")
local util = require("imm.lib.util")
local a = require('imm.lib.assert')
local tarx = require('imm.tar.x')
local imm = require("imm")

--- @class imm.MPList.Opts
--- @field basedir? string
--- @field ctrl? imm.ModController
--- @field repo? imm.Repo

--- @class imm.MPList
--- @field modpacks table<string, imm.Modpack>
local IML = {
	basedir = 'imm_mp'
}

--- @alias imm.MPList.C imm.MPList.S | p.Constructor<imm.MPList, nil> | fun(opts?: imm.MPList.Opts): imm.MPList
--- @type imm.MPList.C
local ML = constructor(IML)

--- @class imm.MPList.S
local MLS = ML

--- @protected
--- @param opts? imm.MPList.Opts
function IML:init(opts)
	opts = opts or {}
	self.modpacks = {}
	self.basedir = opts.basedir
	self.ctrl = opts.ctrl or require"imm.ctrl"
	self.repo = opts.repo or require"imm.repo"
end

function IML:loadAll()
	local items = love.filesystem.getDirectoryItems(self.basedir)
	for i,item in ipairs(items) do
		local subpath = self.basedir .. '/' .. item
		local mp = MP.load(subpath, {
			ctrl = self.ctrl,
			repo = self.repo,
			id = item
		})
		if mp then self.modpacks[mp.id] = mp end
	end
end

function IML:list()
	return util.values(self.modpacks, function (va, vb)
		if va.name ~= vb.name then return va.name < vb.name end
		return va.path < vb.path
	end)
end

--- @param opts? imm.Modpack.Opts
function IML:new(opts)
	local id = util.random()
	local path = self.basedir .. '/' .. id

	opts = opts or {}
	opts.id = id
	opts.path = path
	opts.ctrl = self.ctrl
	local mp = MP(opts)

	assert(love.filesystem.createDirectory(path), "could not create directory " .. path)
	assert(mp:save())

	self.modpacks[id] = mp
	return mp
end

--- @param id string
function IML:remove(id)
	local ok, which = util.rmdir(self.basedir .. '/' .. id, false)
	if not ok then return "failed deleting " .. which end
	self.modpacks[id] = nil
end

--- @param data any
--- @param tar Tar.Root
--- @return any data
function MLS.parseData(data, tar)
	assert(type(data) == "table", "not a table")
	assert(type(data.version) == "number", "version is not a number")
	assert(MLS.schematic[data.version], "unknown modpack version " .. data.version)
	a.schema(data, "data", MLS.schematic[data.version])

	local v = data.version
	while v ~= MLS.latest do
		local m = MLS.migrator[v]
		assert(m, string.format("Unknown migration from %s", v))
		data, v = m(data, tar)
		assert(v, string.format("Unknown next migrator from %s", v))
	end

	return data
end

--- @param tar Tar.Root
--- @return imm.Modpack mp
function IML:importTar(tar)
	local infoFile = assert(tar:get('info.json'))
	infoFile:assertType("file")

	local data = MLS.parseData(JSON.decode(infoFile:getContentString()), tar)

	local desc
	local descFile = tar:get('description.txt')
	if descFile then
		descFile:assertType("file")
		desc = descFile:getContentString()
	end

	local thumb
	local thumbFile = tar:get('thumb')
	if thumbFile then
		thumbFile:assertType("file")
		thumb = thumbFile:getContentData()
	end

	local modsDir = assert(tar:get('mods'))
	modsDir:assertType("dir")

	local mp = self:new()
	mp.description = desc or ''
	mp.name = data.name
	mp.author = data.author
	if thumb then mp:saveThumb(thumb) end

	for i,e in ipairs(data.mods) do
		local dir = modsDir:get(tostring(i))
		if dir then dir:assertType("dir") end

		mp.mods[e.id] = {
			version = e.version,
			bundle = not not dir,
			url = e.url,
			init = true,
		}

		local mod = self.ctrl:getMod(e.id, e.version)
		if not mod and dir then
			local s = string.format('%s/%s-%s_%s', imm.modsDir, e.id, e.version, mp.id)
			NFS.createDirectory(s)
			dir:each(function (entry)
				local sub = s .. '/' .. entry:getPath(dir)
				if entry.type == "dir" then
					NFS.createDirectory(sub)
				elseif entry.type == "file" then
					NFS.write(sub, entry:getContentData())
				end
			end)

			local scan = getmods.getMods({ base = s, depthLimit = 1 })
			for k, modlist in pairs(scan) do
				if not self.ctrl.mods[k] then
					self.ctrl.mods[k] = modlist
				else
					for v, mod in pairs(modlist.versions) do
						self.ctrl.mods[k]:add(mod)
						self.ctrl:addEntry(mod)
					end
				end
			end
		end
	end

	mp:save()
	mp:saveDescription()

	return mp
end

--- @param data love.Data
--- @param release? boolean
--- @return imm.Modpack mp
function IML:import(data, release)
	local unzipped = love.data.decompress("data", 'gzip', data)
	if release then data:release() end
	local tar = tarx.parse(unzipped, true)
	return self:importTar(tar)
end

MLS.latest = 1

--- @type table<number, p.Assert.Schema>
MLS.schematic = {}
MLS.schematic[1] = {
	type = 'table',
	props = {
		name = { type = "string" },
		author = { type = "string" },
		mods = {
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
	}
}

--- @type table<number, fun(data, tar: Tar.Root): any, number>
MLS.migrator = {}

return ML
