local constructor = require('imm.lib.constructor')
local Tar = require('imm.tar.tar')
local tarc = require('imm.tar.c')
local a = require('imm.lib.assert')
local co = require('imm.lib.co')
local util = require('imm.lib.util')
local imm = require('imm')

--- @class imm.Modpack.Mod.Files
--- @field includes string[]
--- @field excludes string[]

--- @class imm.Modpack.Mod
--- @field version string
--- @field bundle? boolean
--- @field url? string
--- @field init? boolean

--- @class imm.Modpack.Opts
--- @field id? string
--- @field name? string
--- @field author? string
--- @field description? string
--- @field path? string
--- @field mods? imm.Modpack.Mod
--- @field ctrl? imm.ModController
--- @field repo? imm.Repo

--- @class imm.Modpack
--- @field mods table<string, imm.Modpack.Mod>
--- @field ctrl imm.ModController
--- @field icon? love.Image
local IMP = {
	id = '',
	name = 'Untitled Modpack',
	author = 'Me',
	description = 'A very cool modpack',
	path = ''
}

--- @alias imm.Modpack.C imm.Modpack.S | p.Constructor<imm.Modpack, nil> | fun(opts?: imm.Modpack.Opts): imm.Modpack
--- @type imm.Modpack.C
local MP = constructor(IMP)

--- @class imm.Modpack.S
local MPS = MP

MPS.latest = 1

--- @type table<number, fun(data): any, number>
MPS.migrator = {}

--- @type table<number, p.Assert.Schema>
MPS.schematic = {}
MPS.schematic[1] = {
	type = 'table',
	props = {
		name = { type = "string" },
		author = { type = "string" },
		mods = {
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
	}
}
--- @protected
--- @param opts? imm.Modpack.Opts
function IMP:init(opts)
	opts = opts or {}
	self.id = opts.id
	self.name = opts.name
	self.author = opts.author
	self.description = opts.description
	self.path = opts.path
	self.mods = opts.mods or {}
	self.ctrl = opts.ctrl or require("imm.ctrl")
	self.repo = opts.repo or require("imm.repo")
end

function IMP:json()
	return {
		name = self.name,
		author = self.author,
		mods = self.mods,
		version = MPS.latest
	}
end

function IMP:save()
	return love.filesystem.write(self:pathInfo(), imm.json.encode(self:json()))
end

function IMP:saveDescription()
	return love.filesystem.write(self:pathDesc(), self.description)
end

--- @param icon string | love.Data
function IMP:saveThumb(icon)
	return love.filesystem.write(self:pathIcon(), icon)
end

function IMP:load()
	local data = MPS.parseData(imm.json.decode(assert(love.filesystem.read(self:pathInfo()))))

	self.name = data.name
	self.author = data.author
	self.mods = data.mods

	self:loadDescription()
end

function IMP:loadDescription()
	local desc = love.filesystem.read(self:pathDesc())
	if desc then self.description = desc end
end

--- @param refresh? boolean
--- @return love.Image? img, string? err
function IMP:getIcon(refresh)
	if self.icon and not refresh then return self.icon end

	local ok, img = pcall(love.graphics.newImage, self:pathIcon())
	if not ok then return nil, img end --- @diagnostic disable-line
	self.icon = img
	return img
end

--- @class imm.Modpack.Diff
--- @field enables imm.Mod[]
--- @field disables imm.Mod[]
--- @field switches imm.Mod[]
--- @field missings table<string, string>
--- @field empty boolean
--- @field mergeEmpty boolean

function IMP:diff()
	--- @type imm.Modpack.Diff
	local diff = {
		enables = {},
		disables = {},
		switches = {},
		missings = {},
		empty = true,
		mergeEmpty = true
	}

	for id, loaded in pairs(self.ctrl.loadlist.loadedMods) do
		local supposedver = self.mods[id] and self.mods[id].version
		if not supposedver then
			if not loaded:isExcluded() then
				diff.empty = false
				table.insert(diff.disables, loaded)
			end
		else
			local supposed = supposedver and self.ctrl:getMod(id, supposedver)
			if not supposed then
				diff.missings[id] = supposedver
			elseif supposed ~= loaded then
				if not supposed:isExcluded() then
					diff.empty = false
					diff.mergeEmpty = false
					table.insert(diff.switches, supposed)
				end
			end
		end
	end

	for id, info in pairs(self.mods) do
		if not self.ctrl.loadlist.loadedMods[id] then
			local supposed = self.ctrl:getMod(id, info.version)
			if supposed then
				if not supposed:isExcluded() then
					diff.empty = false
					diff.mergeEmpty = false
					table.insert(diff.enables, supposed)
				end
			else
				diff.empty = false
				diff.mergeEmpty = false
				diff.missings[id] = info.version
			end
		end
	end

	return diff
end

function IMP:exportJson()
	local o = {
		version = MPS.latest,
		name = self.name,
		author = self.author,
		mods = {}
	}
	for k,v in pairs(self.mods) do
		table.insert(o.mods, {
			id = k,
			version = v.version,
			url = v.url
		})
	end
	return o
end

--- @param sub? string
function IMP:subpath(sub)
	return sub and self.path .. '/' .. sub or self.path
end

function IMP:pathInfo()
	return self:subpath('info.json')
end

function IMP:pathDesc()
	return self:subpath('description.txt')
end

function IMP:pathIcon()
	return self:subpath('thumb')
end

function IMP:fileURL()
	return string.format('file:///%s/%s', love.filesystem.getSaveDirectory(), self.path)
end

local tempid = 0
--- @type imm.Modpack.Mod.Files
local blocklist = {
	includes = {},
	excludes = {
		'%.lovelyignore',
		'%.immlock',
		'^%.git',
		'.zip$',
	}
}

--- @param tar? Tar.Root
function IMP:export(tar)
	if not tar then tar = Tar() end

	local info = self:exportJson()
	assert(tar:openFile('info.json')):setContentString(imm.json.encode(info))
	assert(tar:openFile('description.txt')):setContentString(self.description)
	local thumb = love.filesystem.newFileData(self:pathIcon())
	if thumb then assert(tar:openFile('thumb')):setContentString(thumb) end

	local mods = assert(tar:openDir("mods"))
	for i, e in ipairs(info.mods) do
		local xe = self.mods[e.id]
		local tobundle = xe and xe.bundle and self.ctrl:getMod(e.id, xe.version)
		if tobundle then
			local bfiles = imm.nfs.read(tobundle.path..'/.immbfiles')
			local allowlist = bfiles and MPS.parseFileList(bfiles) or nil
			if allowlist then
				table.insert(allowlist.excludes, '^%.git')
				table.insert(allowlist.excludes, '^%.lovelyignore')
			end

			tempid = tempid + 1
			local temp = '_immmp_tmp'..tempid
			assert(imm.nfs.mount(tobundle.path, temp), string.format('mount failed: %s -> %s', tobundle.path, temp))
			assert(mods:openDir(tostring(i))):addFrom(temp, nil, function (sub, path) return MPS.testFileList(allowlist or blocklist, sub) end)
			assert(imm.nfs.unmount(tobundle.path), 'unmount failed')
		end
	end

	return tar
end

--- @param tar? Tar.Root
function IMP:exportToFile(tar)
	tar = self:export(tar)
	local data = tarc.createTar(tar)
	tar = nil
	collectgarbage("collect")
	local zipped = love.data.compress('data', "gzip", data)
	data:release()
	love.filesystem.write(self:subpath('export.tar.gz'), zipped)
	zipped:release()
end

--- @param id string
--- @param entry imm.Modpack.Mod
function IMP:initModCo(id, entry)
	self.repo:getListsCo()

	entry.init = true

	local mod = self.repo:getMod(id)
	if not mod then return end

	local releases = mod:getReleasesCo()
	--- @type imm.ModMeta.Release
	local matching
	for i,v in ipairs(releases) do
		if v.version == entry.version then
			matching = v
			break
		end
	end
	if not matching then return end

	entry.url = matching.url
	entry.bundle = false
	self:save()
end

--- @param id string
--- @param entry imm.Modpack.Mod
function IMP:initMod(id, entry)
	return co.create(function ()
		return self:initModCo(id, entry)
	end)
end

--- @param id string
--- @param ver string
--- @param noInit? boolean
function IMP:addMod(id, ver, noInit)
	if self.mods[id] and self.mods[id].version == ver then return end
	self.mods[id] = { version = ver, bundle = true }

	if not noInit then
		self:initMod(id, self.mods[id])
	end
end

--- @param reinit? boolean
function IMP:initVersions(reinit)
	for i,entry in pairs(self.mods) do
		if not entry.init or reinit then
			self:initMod(i, entry)
		end
	end
end

local dummymod
local V

--- @param filter imm.Modpack.Mod.Files
--- @param path string
function MPS.testFileList(filter, path)
	local found = #filter.includes == 0
	for i,v in ipairs(filter.includes) do
		if path:find(v) then
			found = true
			break
		end
	end
	if not found then return false end

	for i,v in ipairs(filter.excludes) do
		if path:find(v) then
			return false
		end
	end

	return true
end

--- @param list string
function MPS.parseFileList(list)
	local lines = util.strsplit(list, '\r?\n')
	local incl = {}
	local excl = {}
	for i,v in ipairs(lines) do
		if v:sub(1, 1) == "!" then
			table.insert(excl, v:sub(2))
		else
			table.insert(excl, v)
		end
	end

	--- @type imm.Modpack.Mod.Files
	return {
		excludes = excl,
		includes = incl
	}
end

--- @param data any
--- @return any data
function MPS.parseData(data)
	assert(type(data) == "table", "not a table")
	assert(type(data.version) == "number", "version is not a number")
	assert(MPS.schematic[data.version], "unknown modpack version " .. data.version)
	a.schema(data, "data", MPS.schematic[data.version])

	local v = data.version
	while v ~= MPS.latest do
		local m = MPS.migrator[v]
		assert(m, string.format("Unknown migration from %s", v))
		data, v = m(data)
		assert(v, string.format("Unknown next migrator from %s", v))
	end

	return data
end

--- @param diff imm.Modpack.Diff
--- @param ll imm.LoadList
--- @param merge? boolean
function MPS.applyDiff(diff, ll, merge)
	for i,mod in ipairs(diff.switches) do
		ll:action(mod, "switch")
	end
	for i,mod in ipairs(diff.enables) do
		ll:action(mod, "enable")
	end
	if not merge then
		for i,mod in ipairs(diff.disables) do
			ll:action(mod, "disable")
		end
	end
	for k,v in pairs(diff.missings) do
		if not dummymod then
			dummymod = require"imm.ctrl":getMod("", "1.0.0")
		end
		ll.missingDeps[k] = {}
		if dummymod then
			V = V or require("imm.lib.version")
			ll.missingDeps[k][dummymod] = {{ op = "==", version = V(v) }}
		end
	end
	return ll
end

--- @param path string
--- @param opts? imm.Modpack.Opts
--- @return imm.Modpack? mp
--- @return string? err
function MPS.load(path, opts)
	opts = opts or {}
	opts.path = path
	local mp = MP(opts)

	local ok, err = pcall(mp.load, mp)
	if not ok then return nil, err end

	return mp
end

return MP
