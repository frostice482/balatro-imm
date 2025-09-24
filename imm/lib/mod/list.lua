local constructor = require("imm.lib.constructor")
local Mod = require("imm.lib.mod.mod")
local logger = require("imm.logger")

--- @class imm.ModList
--- @field versions table<string, imm.Mod>
--- @field active? imm.Mod
--- @field native? boolean
--- @field cachedList imm.Mod[]
local IModList = {
    listRequiresUpdate = false
}

--- @protected
--- @param mod string
--- @param native? boolean
function IModList:init(mod, native)
    self.mod = mod
    self.native = native
    self.versions = {}
    self.cachedList = {}
end

function IModList:errNative()
    return false, string.format('Mod %s is native and therefore cannot be edited', self.mod)
end

function IModList:errNotFound()
    return false, string.format('Mod %s not found', self.mod)
end

function IModList:errVerNotFound(version)
    return false, string.format('Mod %s with version %s not found', self.mod, version)
end

--- @param version string
--- @param opts? imm.ModOpts
--- @param enabled? boolean
function IModList:createVersion(version, opts, enabled)
    local m = Mod(self, version, opts)
    self.versions[version] = m
    if enabled then self.active = m end
    self.listRequiresUpdate = true
    return m
end

--- @param mod imm.Mod
function IModList:add(mod)
    mod.mod = self.mod
    mod.list = self
    self.versions[mod.version] = mod
    self.listRequiresUpdate = true
end

--- @return boolean ok, string? err
function IModList:disable()
    if self.native then return self:errNative() end
    if not self.active then return true end

    local ok, err = NFS.write(self.active.path .. '/.lovelyignore', '')
    if not ok then return false, err end

    logger.fmt('log', 'Disabled %s %s', self.mod, self.active.version)
    self.active = nil
    return true
end

--- @param version string
--- @return boolean ok, string? err
function IModList:enable(version)
    local mod = self.versions[version]
    if not mod or mod.list ~= self then return self:errVerNotFound(version) end
    return mod:enable()
end

--- @param version string
--- @return boolean ok, string? err
function IModList:uninstall(version)
    local mod = self.versions[version]
    if not mod or mod.list ~= self then return self:errVerNotFound(version) end
    self.listRequiresUpdate = true
    return mod:uninstall()
end

function IModList:list()
    if not self.listRequiresUpdate then return self.cachedList end
    self.listRequiresUpdate = false
    self.cachedList = {}
    for k,v in pairs(self.versions) do table.insert(self.cachedList, v) end
    table.sort(self.cachedList, function (a, b) return a.versionParsed > b.versionParsed end)
    return self.cachedList
end

--- @param repo imm.Repo
function IModList:createBmiMeta(repo)
    --- @type imm.Mod?
    local mod = self.active
    if not mod then
        for ver, other in pairs(self.versions) do
            if not mod or mod.versionParsed < other.versionParsed then mod = other end
        end
    end
    return mod and repo:createVirtualEntry(mod)
end

--- @param rules imm.Dependency.Rule[]
--- @param excludesOr? imm.Dependency.Rule[][]
function IModList:getVersionSatisfies(rules, excludesOr)
    if self.active
        and self.active.versionParsed:satisfiesAll(rules)
        and not (excludesOr and self.active.versionParsed:satisfiesAllAny(excludesOr))
    then
        return self.active
    end

    for i, mod in ipairs(self:list()) do
        if self.active ~= mod
            and mod.versionParsed:satisfiesAll(rules)
            and not (excludesOr and mod.versionParsed:satisfiesAllAny(excludesOr))
        then
            return mod
        end
    end
end

function IModList:latest()
    --- @type imm.Mod?
    local latest
    for k,v in pairs(self.versions) do
        if not latest or latest.versionParsed < v.versionParsed then latest = v end
    end
    return latest
end

function IModList:isExcluded()
    return self.mod == 'balatro_imm' or self.native
end

--- @alias imm.ModList.C p.Constructor<imm.ModList, nil> | fun(mod: string, native?: boolean): imm.ModList
--- @type imm.ModList.C
local Mod = constructor(IModList)
return Mod