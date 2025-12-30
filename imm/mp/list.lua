local constructor = require('imm.lib.constructor')
local MP = require("imm.mp.mp")
local importSchematic = require('imm.mp.schematic.import')
local getmods = require("imm.mod.get")
local logger = require("imm.logger")
local util = require("imm.lib.util")
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

--- @return string[] errs
function IML:loadAll()
	local errs = {}
	local items = love.filesystem.getDirectoryItems(self.basedir)
	for i,item in ipairs(items) do
		local subpath = self.basedir .. '/' .. item
		local mp, err = MP.load(subpath, {
			ctrl = self.ctrl,
			repo = self.repo,
			id = item,
			list = self
		})
		if mp then
			self.modpacks[mp.id] = mp
		else
			logger.fmt('error', 'modpack %s: %s', subpath, err)
			table.insert(errs, err)
		end
	end
	return errs
end

function IML:list()
	return util.values(self.modpacks, function (va, vb)
		return va.order > vb.order
	end)
end

function IML:highestOrder()
	local h = 0
	for i,v in pairs(self.modpacks) do
		if v.order > h then h = v.order end
	end
	return h
end

--- @param opts? imm.Modpack.Opts
function IML:new(opts)
	local id = util.random()
	local path = self.basedir .. '/' .. id

	opts = opts or {}
	opts.id = id
	opts.path = path
	opts.ctrl = self.ctrl
	opts.list = self
	local mp = MP(opts)
	mp.order = self:highestOrder() + 1

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

--- @param tar Tar.Root
--- @return imm.Modpack mp
function IML:importTar(tar)
	local infoFile = tar:openFile('info.json')
	local rawData = imm.json.decode(infoFile:getContentString())
	local data = importSchematic:parse(rawData, tar)

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

	local modsDir = tar:openDir('mods')

	local mp = self:new()
	mp.description = desc or ''
	mp.name = data.name
	mp.author = data.author
	mp.order = self:highestOrder() + 1
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
			imm.nfs.createDirectory(s)
			imm.nfs.write(s .. '/.lovelyignore', '')

			dir:each(function (entry)
				local sub = s .. '/' .. entry:getPath(dir)
				if entry.type == "dir" then
					imm.nfs.createDirectory(sub)
				elseif entry.type == "file" then
					imm.nfs.write(sub, entry:getContentData())
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

return ML
