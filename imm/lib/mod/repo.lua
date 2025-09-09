local constructor = require("imm.lib.constructor")
local V = require("imm.lib.version")
local Fetch = require("imm.lib.fetch")
local getmods = require("imm.lib.mod.get")
local util = require("imm.lib.util")

--- @type imm.Fetch<nil, bmi.Meta>
local fetch_list = Fetch('https://github.com/frostice482/balatro-mod-index-tiny/raw/master/out.json.gz', 'immcache/list', false, true)

--- @param data string
--- @return bmi.Meta[]
function fetch_list:interpretRes(data)
    return JSON.decode(love.data.decompress("string", 'gzip', data)) --- @diagnostic disable-line
end

--- @type imm.Fetch<string, string>
local fetch_thumb = Fetch('https://raw.githubusercontent.com/skyline69/balatro-mod-index/main/mods/%s/thumbnail.jpg', 'immcache/thumb/%s')

--- @type imm.Fetch<string, ghapi.Releases>
local fetch_gh_releases = Fetch('https://api.github.com/repos/%s/releases', 'immcache/release/%s', true, true)

--- @class imm.HostInfo
--- @field host string
--- @field repo string

--- @type imm.Fetch<imm.HostInfo, ghapi.Releases[]>
local fetch_releases_generic = Fetch('https://%s/api/v1/repos/%s/releases', 'immcache/release/%s', true, true)

function fetch_releases_generic:getUrl(arg)
    return self.url:format(arg.host, arg.repo)
end

--- @type imm.Fetch<string, string>
local fetch_blob = Fetch('%s', 'immcache/blob/%s')

function fetch_blob:getCacheFileName(arg)
    return self.cacheFile:format(love.data.encode('string', 'hex', love.data.hash('md5', arg)))
end

--- @alias imm.Repo.ReleasesCb fun(err?: string, res?: ghapi.Releases[])

--- @class imm.Repo
--- @field list bmi.Meta[]
--- @field listMapped table<string, bmi.Meta>
--- @field listProviders table<string, bmi.Meta[]>
---
--- @field imageCache table<string, love.Image | false>
--- @field releasesCache table<string, ghapi.Releases[]>
--- @field releasesCb table<string, imm.Repo.ReleasesCb[]>
local IRepo = {
    listDone = false
}

--- @alias imm.RepoProviderType 'github' | 'generic'
--- @class imm.RepoProvider: imm.HostInfo
--- @field provider? imm.RepoProviderType

--- @class imm.Repo.Static
--- @field getProvider fun(repoUrl: string): imm.RepoProvider
--- @field transformTagVersion fun(tag: string): string

--- @alias imm.Repo.C imm.Repo.Static | p.Constructor<imm.Repo, nil> | fun(): imm.Repo
--- @type imm.Repo.C
local Repo = constructor(IRepo)

function Repo.transformTagVersion(tag)
    if tag:sub(1, 1) == "v" then tag = tag:sub(2) end
    return tag
end

function Repo.getProvider(repoUrl)
    local host, repo = repoUrl:match('^https://([%w%.]+)/([%w_%.%-]+/[%w_%.%-]+)')
    --- @type imm.RepoProvider
    local res = { host = host, repo = repo }

    if host == 'github.com' then
        res.provider = 'github'
    elseif host == 'codeberg.org' then
        res.provider = 'generic'
    end

    return res
end

--- @protected
function IRepo:init()
    self.api = {
        list = fetch_list,
        thumbnails = fetch_thumb,
        github_releases = fetch_gh_releases,
        releases_generic = fetch_releases_generic,
        blob = fetch_blob
    }
    self.releasesCb = {}
    self:clear()
end

function IRepo:clear()
    self.listDone = false
    self.list = {}
    self.listMapped = {}
    self.listProviders = {}
    self.imageCache = {}
    self.releasesCache = {}
end

--- Gets mod, or looks from provided mods if doesnt exist
--- @param mod string
function IRepo:getMod(mod)
    return self.listMapped[mod] or self.listProviders[mod] and self.listProviders[mod][1]
end

--- @param repoUrl string
--- @param cb imm.Repo.ReleasesCb
--- @param cacheKey? string
function IRepo:getReleases(repoUrl, cb, cacheKey)
    cacheKey = cacheKey or repoUrl
    if self.releasesCache[cacheKey] then return cb(nil, self.releasesCache[cacheKey]) end
    if self.releasesCb[repoUrl] then return table.insert(self.releasesCb[repoUrl], cb) end

    local prov = Repo.getProvider(repoUrl)
    if not prov.provider then
        cb(string.format('Unknown provider from given url %s', repoUrl))
        return
    end

    local function handle(err, res)
        if res then self.releasesCache[cacheKey] = res end
        for i, cb in ipairs(self.releasesCb[repoUrl]) do
            cb(err, res)
        end
        self.releasesCb[repoUrl] = nil
    end

    self.releasesCb[repoUrl] = {cb}

    if prov.provider == 'github' then self.api.github_releases:fetch(prov.repo, handle)
    else self.api.releases_generic:fetch(prov, handle)
    end
end

--- @param repoUrl string
--- @param cacheKey? string
--- @return string? err
--- @return ghapi.Releases[]? releases
function IRepo:getReleasesCo(repoUrl, cacheKey)
    return util.co(function (res) self:getReleases(repoUrl, res, cacheKey) end)
end

--- @param mod string | bmi.Meta
--- @param cb imm.Repo.ReleasesCb
function IRepo:getModReleases(mod, cb)
    local mod = type(mod) == 'string' and self:getMod(mod) or mod
    if not mod then return cb(nil, nil) end
    self:getReleases(mod.repo, cb, mod.id)
end

--- @param mod string | bmi.Meta
--- @return string? err
--- @return ghapi.Releases[]? releases
function IRepo:getModReleasesCo(mod)
    return util.co(function (res) self:getModReleases(mod, res) end)
end

--- @param url string
--- @param cb fun(err?: string, data?: love.Image)
--- @param cacheKey? string
function IRepo:getImage(url, cb, cacheKey)
    cacheKey = cacheKey or url
    if self.imageCache[cacheKey] ~= nil then return cb(nil, self.imageCache[cacheKey] or nil) end

    self.api.thumbnails:fetch(url, function (err, res)
        --- @type boolean, any?
        local ok, img = false, err

        if res then
            ok, img = pcall(love.graphics.newImage, love.filesystem.newFileData(res, url))
        end

        if ok then
            self.imageCache[cacheKey] = img
            cb(nil, img)
        else
            self.imageCache[cacheKey] = false
            cb(img, nil)
        end
    end)
end

--- @param url string
--- @param cacheKey? string
--- @return string? err
--- @return love.Image? data
function IRepo:getImageCo(url, cacheKey)
    return util.co(function (res) self:getImage(url, res, cacheKey) end)
end

--- @param res bmi.Meta[]
function IRepo:updateList(res)
    self.listDone = true
    self.list = res
    self.listMapped = {}
    self.listProviders = {}

    for i, entry in ipairs(res) do
        self.listMapped[entry.id] = entry
        if entry.provides then
            for k, provideEntry in ipairs(entry.provides) do
                local providedId = getmods.parseSmodsProvides(provideEntry)
                if providedId then
                    self.listProviders[providedId] = self.listProviders[providedId] or {}
                    table.insert(self.listProviders[providedId], entry)
                end
            end
        end
    end
end

--- @param cb fun(err?: string, list?: bmi.Meta[])
function IRepo:getList(cb)
    if self.listDone then cb(nil, self.list) end

    local ocb = cb
    cb = function (err, res)
        if res then self:updateList(res) end
        return ocb(err, res)
    end

    self.api.list:fetch(nil, cb)
end

--- @return string? err
--- @return bmi.Meta[]? list
function IRepo:getListCo()
    return util.co(function (res) self:getList(res) end)
end

--- Note that this function may return only the direct downloadURL instead of releases
--- if the releases of the mod is not initialized.
--- You should use this within `getReleases` callback.
--- @param mod string
--- @param rulesList imm.Dependency.Rule[][]
--- @return string? url
--- @return ghapi.Releases? release
function IRepo:findModVersionToDownload(mod, rulesList)
    local releases = self.releasesCache[mod]
    if releases then
        --- @type ghapi.Releases/
        local lastRelease
        for i,release in ipairs(releases) do
            if #rulesList == 0 then
                return release.zipball_url, release
            end

            lastRelease = lastRelease or release
            local ok, parsed
            if not release.draft and not release.prerelease then
                ok, parsed = pcall(V, Repo.transformTagVersion(release.tag_name)) --- @diagnostic disable-line
            end
            if ok and parsed then
                for j, rules in ipairs(rulesList) do
                    if parsed:satisfies(rules) then return release.zipball_url, release end
                end
            end
        end
        --[[
        if lastRelease then
            return lastRelease.zipball_url, lastRelease
        end
        ]]
    end

    local relatedMod = self.listMapped[mod]
    if relatedMod then return relatedMod.downloadURL end

    local relatedProviders = self.listProviders[mod]
    if relatedProviders and relatedProviders[1] then return relatedProviders[1].downloadURL end
end

return Repo
