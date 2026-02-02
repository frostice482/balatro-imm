local constructor = require("imm.lib.constructor")
local util = require("imm.lib.util")
local co = require("imm.lib.co")

--- @class imm.ModMeta.Release
--- @field url string
--- @field version string
--- @field isPre? boolean
--- @field versionParsed? Version
--- @field dependencies? string[]
--- @field size? number
--- @field time? string | number
--- @field count? number
--- @field format 'thunderstore' | 'bmi'
--- @field bmi? ghapi.Releases
--- @field ts? thunderstore.PackageVersion

local providerRank = {
    thunderstore = 2,
    bmi = 1
}

--- @param a imm.ModMeta.Release
--- @param b imm.ModMeta.Release
local function compareVersion(a, b)
    if a.versionParsed and b.versionParsed then
        if a.versionParsed ~= b.versionParsed then
            return a.versionParsed > b.versionParsed
        end
    elseif not a.versionParsed then
        return false
    elseif not b.versionParsed then
        return true
    end

    if a.version ~= b.version then return a.version > b.version end
    return providerRank[a.format] > providerRank[b.format]
end

local function rankSort(a, b)
    return a.rank > b.rank
end

--- @class imm.ModMeta
--- @field bmi? bmi.Meta
--- @field ts? thunderstore.Package
--- @field tsLatest? thunderstore.PackageVersion
---
--- @field stacks table<string, imm.ModMetaStack>
--- @field stacksSorted imm.ModMetaStack[]
--- @field cachedReleases? imm.ModMeta.Release[]
local IMeta = {}

--- @param repo imm.Repo
function IMeta:init(repo)
    self.repo = repo
    self.stacks = {}
    self.stacksSorted = {}
end

--- @param stack imm.ModMetaStack
function IMeta:setStack(stack)
    if self.stacks[stack.type] == stack then return end
    self.stacks[stack.type] = stack
    self.stacksSorted = util.values(self.stacks, rankSort)
end

--- @param type string
--- @return any
--- @overload fun(self, type: 'bmi'): imm.ModMetaStack.BMI?
--- @overload fun(self, type: 'ts'): imm.ModMetaStack.TS?
--- @overload fun(self, type: 'photonmp'): imm.ModMetaStack.PhotonMP?
--- @return imm.ModMetaStack
function IMeta:getStack(type)
    return self.stacks[type]
end

--- @param attr string
function IMeta:getAttribute(attr)
    for i,v in ipairs(self.stacksSorted) do
        if v[attr] ~= nil then return v[attr] end
    end
end

--- @return string
function IMeta:id()
    return self:getAttribute('id') or ''
end

--- @return string
function IMeta:title()
    return self:getAttribute('title') or ''
end

--- @return string
function IMeta:author()
    return self:getAttribute('author') or ''
end

--- @return string
function IMeta:description()
    return self:getAttribute('description') or ''
end

--- @return string[]
function IMeta:categories()
    return self:getAttribute('categories') or {}
end

--- @return table?
function IMeta:badgeColor()
    local textcol = self:getAttribute('badgeColor')
    local bgcol = self:getAttribute('badgeTextColor')
    if textcol == bgcol or textcol and textcol:lower() == "ffffff" and not bgcol then return end

    if textcol and textcol:match('^%x%x%x%x%x%x$') then -- parse everytime & also potentially cause external crash
        return HEX(textcol)
    end
end

--- @return table?
function IMeta:badgeTextColor()
    local textcol = self:getAttribute('badgeColor')
    local bgcol = self:getAttribute('badgeTextColor')
    if textcol == bgcol then return end

    if bgcol and bgcol:match('^%x%x%x%x%x%x$') then -- parse everytime & also potentially cause external crash
        return HEX(bgcol)
    end
end

--- @async
--- @return love.Image? data, string? err
function IMeta:getImageCo()
    for i,v in ipairs(self.stacksSorted) do
        local img, err = v:getImage()
        if img then return img end
        if err then return nil, err end
    end
end

function IMeta:hasRelesaeInfo()
    for i,v in ipairs(self.stacksSorted) do
        if v:hasReleaseInfo() then return true end
    end
    return false
end

function IMeta:clearReleases()
    for i,v in ipairs(self.stacksSorted) do
        v:clearReleases()
    end
    self.cachedReleases = nil
end

--- @async
--- @return imm.ModMeta.Release[]
function IMeta:getReleasesCo()
    if self.cachedReleases then return self.cachedReleases end
    local releases = {}
    local colist = {}
    for i,v in ipairs(self.stacksSorted) do
        colist[i] = function()
            local rel = v:getReleasesCo()
            if rel then
                util.insertBatch(releases, rel)
            end
        end
    end
    co.all(colist)
    self.cachedReleases = releases
    table.sort(releases, compareVersion)
    return releases
end

--- Gets what version of a mod to download for given version rules.
--- Will return nothing if getReleasesCo is not called.
--- @param rulesList imm.Dependency.Rule[][]
--- @return imm.ModMeta.Release? release
--- @return boolean? pre
function IMeta:findModVersionToDownload(rulesList)
    if not self.cachedReleases then return end
    for i, release in ipairs(self.cachedReleases) do
        if release.versionParsed and release.versionParsed:satisfiesAllAny(rulesList) then
            return release
        end
    end
end

--- @alias imm.ModMeta.C p.Constructor<imm.ModMeta, nil> | fun(repo: imm.Repo): imm.ModMeta
--- @type imm.ModMeta.C
local Meta = constructor(IMeta)
return Meta
