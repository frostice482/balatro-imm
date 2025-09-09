local constructor = require("imm.lib.constructor")
local Mod = require("imm.lib.mod.mod")

--- @class imm.ModList
--- @field versions table<string, imm.Mod>
--- @field active? imm.Mod
--- @field native? boolean
local IModList = {}

--- @protected
--- @param mod string
--- @param native? boolean
function IModList:init(mod, native)
    self.mod = mod
    self.native = native
    self.versions = {}
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
    return m
end

function IModList:disable()
    if self.native then return self:errNative() end
    if not self.active then return true end

    local ok, err = NFS.write(self.active.path .. '/.lovelyignore', '')
    if not ok then return ok, err end

    self.active = nil
    return true
end

--- @param version string
function IModList:enable(version)
    local mod = self.versions[version]
    if not mod or mod.list ~= self then return self:errVerNotFound(version) end
    return mod:enable()
end

--- @param version string
function IModList:uninstall(version)
    local mod = self.versions[version]
    if not mod or mod.list ~= self then return self:errVerNotFound(version) end
    return mod:uninstall()
end

--- @param ascending? boolean Sorts version by oldest first, defaults to false (latest first)
function IModList:list(ascending)
    --- @type imm.Mod[]
    local list = {}
    for k,v in pairs(self.versions) do table.insert(list, v) end
    table.sort(list, function (a, b)
        if ascending then return a.versionParsed < b.versionParsed end
        return a.versionParsed > b.versionParsed
    end)
    return list
end

--- @return bmi.Meta?
function IModList:createBmiMeta()
    --- @type imm.Mod?
    local mod = self.active
    if not mod then
        for ver, other in pairs(self.versions) do
            if not mod or mod.versionParsed < other.versionParsed then mod = other end
        end
    end
    return mod and mod:createBmiMeta()
end

--- @param rules imm.Dependency.Rule[]
function IModList:getVersionSatisfies(rules)
    if self.active and self.active.versionParsed:satisfies(rules) then return self.active end

    for i, mod in pairs(self.versions) do
        if self.active ~= mod and mod.versionParsed:satisfies(rules) then return mod end
    end
end

--- @alias imm.ModList.C p.Constructor<imm.ModList, nil> | fun(mod: string, native?: boolean): imm.ModList
--- @type imm.ModList.C
local Mod = constructor(IModList)
return Mod