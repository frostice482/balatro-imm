local constructor = require("imm.lib.constructor")
local V = require("imm.lib.version")
local co = require("imm.lib.co")
local logger = require("imm.logger")

--- @class imm.ModMeta.Release
--- @field url string
--- @field version string
--- @field isPre? boolean
--- @field versionParsed? Version
--- @field dependencies? string[]
--- @field size? number
---
--- @field format 'thunderstore' | 'bmi'
--- @field bmi? ghapi.Releases
--- @field ts? thunderstore.PackageVersion

local function transformVersion(tag)
    if tag:sub(1, 1) == "v" then tag = tag:sub(2) end
    return tag
end


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

--- @class imm.ModMeta
--- @field bmi? bmi.Meta
--- @field ts? thunderstore.Package
--- @field tsLatest? thunderstore.PackageVersion
--- @field tsVersionsCache? imm.ModMeta.Release[]
--- @field bmiVersionsCache? imm.ModMeta.Release[]
local IMeta = {}

--- @param repo imm.Repo
function IMeta:init(repo)
    self.repo = repo
end

function IMeta:resetReleases()
    self.tsVersionsCache = nil
    self.bmiVersionsCache = nil
end

function IMeta:_assertOne()
    if not self.ts and not self.bmi then error('Bmi / Thunderstore not initialized', 2) end
end

function IMeta:id()
    self:_assertOne()
    return self.ts and self.ts.name or self.bmi and self.bmi.id
end
function IMeta:title()
    self:_assertOne()
    return self.ts and self.ts.name or self.bmi and self.bmi.name
end
function IMeta:description()
    self:_assertOne()
    return self.tsLatest and self.tsLatest.description or self.bmi and self.bmi.description
end
function IMeta:categories()
    self:_assertOne()
    return self.ts and self.ts.categories or self.bmi and self.bmi.categories or {}
end
function IMeta:author()
    self:_assertOne()
    return self.ts and self.ts.owner or self.bmi and self.bmi.owner or '-'
end

--- @return string? err, love.Image? data
function IMeta:getImageCo()
    if self.tsLatest and self.tsLatest.icon then
        return self.repo.ts:getImageCo(self.tsLatest.icon)
    end
    if self.bmi and self.bmi.pathname then
        return self.repo.bmi:getImageCo(self.bmi.pathname)
    end
end

--- @protected
function IMeta:getReleasesTs()
    if self.tsVersionsCache then return self.tsVersionsCache end
    if not self.ts then return end

    self.tsVersionsCache = {}
    for i, ver in ipairs(self.ts.versions) do
        local v = transformVersion(ver.version_number)
        local vpok, vparsed = pcall(V, v) --- @diagnostic disable-line
        --- @type imm.ModMeta.Release
        local t = {
            url = ver.download_url,
            version = v,
            versionParsed = vpok and vparsed or nil,
            dependencies = ver.dependencies,
            size = ver.file_size,
            format = 'thunderstore',
            ts = ver
        }
        table.insert(self.tsVersionsCache, t)
    end
    return self.tsVersionsCache
end

--- @protected
function IMeta:getReleasesBmiCo()
    if self.bmiVersionsCache then return self.bmiVersionsCache end
    if not (self.bmi and self.bmi.repo) then return end

    local err, releases = self.repo.bmi:getReleasesCo(self.bmi.repo)
    if not releases then
        if err then logger.fmt('error', 'Failed getting BMI releases for %s: %s', self:id(), err) end
        return
    end

    self.bmiVersionsCache = {}
    for i, ver in ipairs(releases) do
        local v = transformVersion(ver.tag_name)
        local vpok, vparsed = pcall(V, v) --- @diagnostic disable-line
        --- @type imm.ModMeta.Release
        local t = {
            url = ver.zipball_url,
            version = v,
            versionParsed = vpok and vparsed or nil,
            isPre = ver.prerelease or ver.draft,
            format = 'bmi',
            bmi = ver
        }
        table.insert(self.bmiVersionsCache, t)
    end
    return self.bmiVersionsCache
end

--- @return imm.ModMeta.Release[]
function IMeta:getReleasesCo()
    self:getReleasesTs()
    self:getReleasesBmiCo()
    return self:getReleasesCached()
end

--- Gets releases that is in cache.
--- @return imm.ModMeta.Release[]
function IMeta:getReleasesCached()
    --- @type imm.ModMeta.Release[]
    local list = {}
    if self.tsVersionsCache then for i,v in ipairs(self.tsVersionsCache) do table.insert(list, v) end end
    if self.bmiVersionsCache then for i,v in ipairs(self.bmiVersionsCache) do table.insert(list, v) end end
    table.sort(list, compareVersion)
    return list
end

--- Gets what version of a mod to download for given version rules.
--- Will initializes releases if not yet done.
--- Prereleases are prioritized behind.
--- @param rulesList imm.Dependency.Rule[][]
--- @return imm.ModMeta.Release? release
--- @return boolean? pre
function IMeta:findModVersionToDownload(rulesList)
    local list = self:getReleasesCached()
    for i, release in ipairs(list) do
        if release.versionParsed and release.versionParsed:satisfiesAllAny(rulesList) then
            return release
        end
    end
end

--- @alias imm.ModMeta.C p.Constructor<imm.ModMeta, nil> | fun(repo: imm.Repo): imm.ModMeta
--- @type imm.ModMeta.C
local Meta = constructor(IMeta)
return Meta
