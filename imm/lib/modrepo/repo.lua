local constructor = require("imm.lib.constructor")
local ModMeta = require("imm.lib.modrepo.meta")
local BMIRepo = require("imm.lib.modrepo.bmi")
local TSRepo = require("imm.lib.modrepo.ts")
local Fetch = require("imm.lib.fetch")
local V = require("imm.lib.version")
local co = require("imm.lib.co")

--- @type imm.Fetch<string, string>
local fetch_blob = Fetch('%s', 'immcache/blob/%s')

function fetch_blob:getCacheFileName(arg)
    return self.cacheFile:format(love.data.encode('string', 'hex', love.data.hash('md5', arg)))
end

--- @alias imm.Repo.ReleasesCb fun(err?: string, res?: ghapi.Releases[])

--- @class imm.Repo
--- @field list imm.ModMeta[]
--- @field listMapped table<string, imm.ModMeta>
--- @field listProviders table<string, imm.ModMeta>
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
    self:clear()
end

function IRepo:clear()
    self.list = {}
    self.listMapped = {}
    self.listProviders = {}
    self.bmi:clear()
    self.ts:clear()
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
        format = 'bmi',
        metafmt = 'smods',
        categories = mod.info.categories,
        id = mod.mod,
        name = mod.name,
        owner = mod.info.author,
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