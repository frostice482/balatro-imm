local constructor = require('imm.lib.constructor')
local V = require('imm.lib.version')
local util = require('imm.lib.util')

--- @class imm.ProvidedList.Entry.Version
--- @field version string
--- @field parsed Version
--- @field mods table<imm.Mod, boolean>

--- @class imm.ProvidedList.Entry
--- @field id string
--- @field versions table<string, imm.ProvidedList.Entry.Version>
local IProvidedEntry = {}

--- @param id string
function IProvidedEntry:init(id)
    self.id = id
    self.versions = {}
end

--- @param info imm.Mod
--- @param version string
function IProvidedEntry:add(info, version)
    if not self.versions[version] then
        self.versions[version] = {
            version = version,
            parsed = V(version),
            mods = {}
        }
    end
    self.versions[version].mods[info] = true
end

--- @param info imm.Mod
--- @param version string
function IProvidedEntry:delete(info, version)
    if not self.versions[version] then return end
    self.versions[version].mods[info] = nil
    if not next(self.versions[version].mods) then self.versions[version] = nil end
end

--- @param ascending? boolean Sorts version by oldest first, defaults to false (latest first)
--- @param modsAscending? boolean Sorts version by oldest first, defaults to false (latest first)
function IProvidedEntry:list(ascending, modsAscending)
    --- @type [Version, imm.Mod[]][]
    local versions = {}
    for str, list in pairs(self.versions) do
        local mods = util.keys(list. mods, function (a, b)
            if a.mod ~= b.mod then
                if modsAscending then return a.mod < b.mod end
                return a.mod > b.mod
            end
            return a > b
        end)
        table.insert(versions, {list.parsed, mods})
    end
    table.sort(versions, function (a, b)
        if ascending then return a[1] < b[1] end
        return a[1] > b[1]
    end)

    return versions
end

--- @return Version?
--- @return imm.Mod?
function IProvidedEntry:latest()
    --- @type imm.ProvidedList.Entry.Version?
    local max
    for k, list in pairs(self.versions) do
        if not max or max.parsed < list.parsed then max = list end
    end
    if not max then return end

    --- @type imm.Mod?
    local modMax
    for mod in pairs(max.mods) do
        if not modMax or modMax.versionParsed < mod.versionParsed then modMax = mod end
    end

    return max.parsed, modMax
end

--- @param rules imm.Dependency.Rule[]
--- @param excludesOr? imm.Dependency.Rule[][]
--- @return imm.Mod?
--- @return Version?
function IProvidedEntry:getVersionSatisfies(rules, excludesOr)
    for i, entry in ipairs(self:list()) do
        local ver, mods = entry[1], entry[2]
        if ver:satisfiesAll(rules) and not (excludesOr and ver:satisfiesAllAny(excludesOr)) then return mods[1], ver end
    end
end

--- @alias imm.ProvidedList.Entry.C p.Constructor<imm.ProvidedList.Entry, nil> | fun(id: string): imm.ProvidedList.Entry
--- @type imm.ProvidedList.Entry.C
local ProvidedListEntry = constructor(IProvidedEntry)

--- @class imm.ProvidedList
--- @field provideds table<string, imm.ProvidedList.Entry>
local IProvidedList = {}

--- @protected
function IProvidedList:init()
    self.provideds = {}
end

--- @param info imm.Mod
function IProvidedList:add(info)
    for k, v in pairs(info.provides) do
        if not self.provideds[k] then self.provideds[k] = ProvidedListEntry(k) end
        self.provideds[k]:add(info, v)
    end

end

--- @param info imm.Mod
function IProvidedList:remove(info)
    for k, v in pairs(info.provides) do
        if self.provideds[k] then self.provideds[k]:delete(info, v) end
    end
end

--- @alias imm.ProvidedList.C p.Constructor<imm.ProvidedList, nil> | fun(): imm.ProvidedList
--- @type imm.ProvidedList.C
local ProvidedList = constructor(IProvidedList)
return ProvidedList
