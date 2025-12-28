local Fetch = require("imm.lib.fetch")
local GRepo = require("imm.modrepo.generic")
local getmods = require("imm.mod.get")
local co = require("imm.lib.co")
local imm = require("imm")

--- @type imm.Fetch<nil, bmi.Meta[]>
local fetch_list = Fetch('https://github.com/frostice482/balatro-mod-index-tiny/raw/master/out.json.gz', 'immcache/list/bmi.json', {
    resType = 'data',
    cacheType = 'json',
    cacheTime = 3600 * 6
})

local excludeProps = {'metafmt'}

--- @param str love.Data
function fetch_list:interpretRes(str)
    --- @type bmi.Meta[]
    local list = imm.json.decode(love.data.decompress("string", 'gzip', str))
    for i,entry in ipairs(list) do
        for j, omitProp in ipairs(excludeProps) do entry[omitProp] = nil end
    end
    return list
end

--- @type imm.Fetch<string, ghapi.Releases>
local fetch_gh_releases = Fetch('https://api.github.com/repos/%s/releases', 'immcache/release/%s', { resType = 'json', cacheType = 'json' })

local excludeRelProps = {'id', 'upload_url', 'html_url', 'node_id', 'target_commitish', 'tarball_url', 'body', 'reactions', 'mentions_count', 'immutable', 'created_at', 'published_at', 'assets_url', 'author'}
local excludeAssetProps = {'id', 'node_id', 'label', 'uploader', 'content_type', 'state', 'digest', 'created_at'}

--- @param data ghapi.Releases[]
function fetch_gh_releases:interpretRes(data)
    for i, entry in ipairs(data) do
        for j, omitProp in ipairs(excludeRelProps) do entry[omitProp] = nil end
        for j, asset in ipairs(entry.assets) do
            for k, omitProp in ipairs(excludeAssetProps) do asset[omitProp] = nil end
        end
    end
    return data
end

function fetch_gh_releases:transformOpts(opts)
    opts.headers = opts.headers or {}
    opts.headers.Authorization = imm.config.githubToken and 'Bearer '..imm.config.githubToken or nil
end

--- @class imm.HostInfo
--- @field host string
--- @field repo string

--- @type imm.Fetch<imm.HostInfo, ghapi.Releases[]>
local fetch_releases_generic = Fetch('https://%s/api/v1/repos/%s/releases', 'immcache/release/%s', { resType = 'json', cacheType = 'json' })

function fetch_releases_generic:getUrl(arg)
    return self.url:format(arg.host, arg.repo)
end

--- @type imm.Fetch<string, love.Data>
local fetch_thumb = Fetch('https://raw.githubusercontent.com/skyline69/balatro-mod-index/main/mods/%s/thumbnail.jpg', 'immcache/thumb/%s', { resType = 'data', cacheType = 'filedata' })

--- @param data love.Data
function fetch_thumb:interpretRes(data)
    local img = love.graphics.newImage(data) --- @diagnostic disable-line
    local scale = 240 / img:getHeight()
    local wd, hd = math.floor(img:getWidth() * scale), math.floor(img:getHeight() * scale)

    local canv = love.graphics.newCanvas(wd, hd)
    local prevcanv = love.graphics.getCanvas()

    love.graphics.push()
    love.graphics.reset()
    love.graphics.setCanvas(canv)
    love.graphics.draw(img, 0, 0, 0, scale, scale)
    love.graphics.setCanvas(prevcanv)
    love.graphics.pop()

    return canv:newImageData():encode('png')
end

--- @class imm.Repo.BMI: imm.Repo.Generic
--- @field releasesCache table<string, ghapi.Releases[]>
--- @field releasesCb table<string, imm.Repo.ReleasesCb[]>
local IBMIRepo = {
    listApi = fetch_list,
    thumbApi = fetch_thumb,
    name = 'BMI'
}

--- @class imm.Repo.BMI.Static
--- @field getProvider fun(repoUrl: string): imm.RepoProvider

--- @alias imm.Repo.BMI.C imm.Repo.BMI.Static | p.Constructor<imm.Repo.BMI, nil> | fun(repo: imm.Repo): imm.Repo.BMI
--- @type imm.Repo.BMI.C
local BMIRepo = GRepo:extendTo(IBMIRepo)


function BMIRepo.getProvider(repoUrl)
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
--- @param repo imm.Repo
function IBMIRepo:init(repo)
    GRepo.proto.init(self, repo)
    self.api = {
        list = fetch_list,
        releases_github = fetch_gh_releases,
        releases_generic = fetch_releases_generic,
        thumbnail = fetch_thumb
    }
    self:clear()
end

function IBMIRepo:clear()
    GRepo.proto.clear(self)
    self:clearReleases()
end

function IBMIRepo:clearReleases()
    self.releasesCache = {}
    self.releasesCb = {}
end

--- @param repoUrl string
--- @param cb imm.Repo.ReleasesCb
--- @param cacheKey? string
function IBMIRepo:getReleases(repoUrl, cb, cacheKey)
    cacheKey = cacheKey or repoUrl
    local releasesCache = self.releasesCache
    local releasesCb = self.releasesCb

    if releasesCache[cacheKey] then return cb(nil, releasesCache[cacheKey]) end
    if releasesCb[repoUrl] then return table.insert(releasesCb[repoUrl], cb) end

    local prov = BMIRepo.getProvider(repoUrl)
    if not prov.provider then
        cb(string.format('Unknown provider from given url %s', repoUrl))
        return
    end

    local function handle(err, res)
        if res then releasesCache[cacheKey] = res end
        for i, cb in ipairs(releasesCb[repoUrl]) do
            cb(err, res)
        end
        releasesCb[repoUrl] = nil
    end

    releasesCb[repoUrl] = {cb}

    if prov.provider == 'github' then self.api.releases_github:fetch(prov.repo, handle)
    else self.api.releases_generic:fetch(prov, handle)
    end
end

--- @async
--- @param repoUrl string
--- @param cacheKey? string
--- @return string? err, ghapi.Releases[]? releases
function IBMIRepo:getReleasesCo(repoUrl, cacheKey)
    return co.wrapCallbackStyle(function (res) self:getReleases(repoUrl, res, cacheKey) end)
end

--- @param meta imm.ModMeta
function IBMIRepo:addProvides(meta)
    if not meta.bmi.provides then return end

    local listProviders = self.repo.listProviders
    for k, provideEntry in ipairs(meta.bmi.provides) do
        local providedId = getmods.parseSmodsProvides(provideEntry)
        if providedId then
            listProviders[providedId] = listProviders[providedId] or {}
            table.insert(listProviders[providedId], meta)
        end
    end
end

--- @param entry bmi.Meta
function IBMIRepo:updateList(entry)
    local meta = self.repo:getMetaEntry(entry.id)
    meta.bmi = entry
    self:addProvides(meta)
end

return BMIRepo