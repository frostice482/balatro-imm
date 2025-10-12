local constructor = require("imm.lib.constructor")
local ModMeta = require("imm.modrepo.meta")
local BMIRepo = require("imm.modrepo.bmi")
local TSRepo = require("imm.modrepo.ts")
local PhotonRepo = require("imm.modrepo.photon")
local Fetch = require("imm.lib.fetch")
local util = require("imm.lib.util")

--- @type imm.Fetch<string, string>
local fetch_blob = Fetch('%s', 'immcache/blob/%s')
fetch_blob.cacheLasts = 3600 * 1

function fetch_blob:getCacheFileName(arg)
    return self.cacheFile:format(love.data.encode('string', 'hex', love.data.hash('md5', arg)))
end

--- @alias imm.Repo.ReleasesCb fun(err?: string, res?: ghapi.Releases[])

--- @class imm.Repo
--- @field list imm.ModMeta[]
--- @field listMapped table<string, imm.ModMeta>
--- @field listProviders table<string, imm.ModMeta[]>
local IRepo = {}

--- @alias imm.RepoProviderType 'github' | 'generic'
--- @class imm.RepoProvider: imm.HostInfo
--- @field provider? imm.RepoProviderType

--- @protected
function IRepo:init()
    self.api = {
        blob = fetch_blob
    }
    self.releasesCb = {}
    self.bmi = BMIRepo(self)
    self.ts = TSRepo(self)
    self.photon = PhotonRepo(self)
    self:clear()
end

function IRepo:clear()
    self:clearList(true)
    self.bmi:clear()
    self.ts:clear()
end

function IRepo:clearList(justThis)
    self.list = {}
    self.listMapped = {}
    self.listProviders = {}

    if justThis then return end

    util.rmdir(self.ts.api.list.cacheFile, false)
    util.rmdir(self.bmi.api.list.cacheFile, false)

    self.bmi.listDone = false
    self.ts.listDone = false
end

function IRepo:clearReleases()
    util.rmdir(util.dirname(self.bmi.api.releases_generic.cacheFile), false)
    util.rmdir(util.dirname(self.bmi.api.releases_github.cacheFile), false)

    for i, v in ipairs(self.list) do
        v:resetReleases()
    end
    self.bmi:clearReleases()
end

--- Gets mod, or looks from provided mods if doesnt exist
--- @param mod string
function IRepo:getMod(mod)
    return self.listMapped[mod] or self.listProviders[mod] and self.listProviders[mod][1]
end

--- @param id string
function IRepo:getMetaEntry(id)
    if not self.listMapped[id] then
        self.listMapped[id] = ModMeta(self)
        table.insert(self.list, self.listMapped[id])
    end
    return self.listMapped[id]
end

--- @param mod imm.Mod
function IRepo:createVirtualEntry(mod)
    local m = ModMeta(self)
    m.bmi = {
        categories = mod.info.categories,
        id = mod.mod,
        name = mod.name,
        owner = mod.info.author and table.concat(mod.info.author, ', '),
        version = mod.version,
        description = mod.description,
        provides = mod.info.provides
    }
    return m
end

--- @alias imm.Repo.C p.Constructor<imm.Repo, nil> | fun(): imm.Repo
--- @type imm.Repo.C
local Repo = constructor(IRepo)
return Repo