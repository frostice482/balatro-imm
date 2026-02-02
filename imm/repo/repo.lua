local constructor = require("imm.lib.constructor")
local ModMeta = require("imm.meta.meta")
local BMIMeta = require("imm.meta.bmi")
local BMIRepo = require("imm.repo.bmi")
local TSRepo = require("imm.repo.ts")
local PhotonRepo = require("imm.repo.photon")
local Fetch = require("imm.lib.fetch")
local co = require("imm.lib.co")

--- @type imm.Fetch<string, love.Data>
local fetch_blob = Fetch('%s', 'immcache/blob/%s', {
    resType = 'data',
    cacheType = 'filedata',
    neverCache = true
})

function fetch_blob:getCacheFileName(arg)
    return self.cacheFile:format(love.data.encode('string', 'hex', love.data.hash('md5', arg)))
end

--- @class imm.Repo
--- @field list imm.ModMeta[]
--- @field listMapped table<string, imm.ModMeta>
--- @field listProviders table<string, imm.ModMeta[]>
--- @field repoList imm.Repo.Generic[]
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
    self.repoList = { self.bmi, self.ts, self.photon }

    self.list = {}
    self.listMapped = {}
    self.listProviders = {}
end

function IRepo:clear()
    self:clearList()
    self:clearReleases()
    self:clearThumbnails()
end

function IRepo:clearList()
    self.list = {}
    self.listMapped = {}
    self.listProviders = {}

    for i,v in ipairs(self.repoList) do
        v:clearListCache()
    end
end

function IRepo:clearReleases()
    for i,v in ipairs(self.repoList) do
        v:clearReleasesCache()
    end
    for i, v in ipairs(self.list) do
        v:clearReleases()
    end
end

function IRepo:clearThumbnails()
    for i,v in ipairs(self.repoList) do
        v:clearThumbCache()
    end
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
    m:setStack(BMIMeta(self.bmi, {
        categories = mod.info.categories,
        id = mod.mod,
        name = mod.name,
        owner = mod.info.author and table.concat(mod.info.author, ', '),
        version = mod.version,
        description = mod.description,
        provides = mod.info.provides
    }))
    return m
end

--- @param prog? fun(provider: imm.Repo.Generic, err?: string)
--- @param done? fun()
function IRepo:getLists(prog, done)
    local c = #self.repoList
    for i,v in ipairs(self.repoList) do
        v:getList(function (err)
            c = c - 1
            if prog then prog(v, err) end
            if c == 0 and done then done() end
        end)
    end
end

--- @param prog? fun(provider: imm.Repo.Generic, err?: string)
function IRepo:getListsCo(prog)
    co.wrapCallbackStyle(function (res)
        return self:getLists(prog, res)
    end)
end

--- @alias imm.Repo.C p.Constructor<imm.Repo, nil> | fun(): imm.Repo
--- @type imm.Repo.C
local Repo = constructor(IRepo)
return Repo