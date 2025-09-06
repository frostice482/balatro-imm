local Fetch = require("imm.lib.fetch")

--- @type imm.Fetch<nil, table<string, bmi.Meta>[]>
local fetch_list = Fetch('https://github.com/frostice482/balatro-mod-index-tiny/raw/master/out.json.gz', 'immcache/list', false, true)

--- @param data string
--- @return table<string, bmi.Meta[]>
function fetch_list:interpretRes(data)
    return JSON.decode(love.data.decompress("string", 'gzip', data))
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

local Repo = {
    list = fetch_list,
    thumbnails = fetch_thumb,
    github_releases = fetch_gh_releases,
    releases_generic = fetch_releases_generic,
    blob = fetch_blob
}

--- @class imm.RepoProvider: imm.HostInfo
--- @field provider? imm.RepoProviderType

--- @alias imm.RepoProviderType 'github' | 'generic'

--- @param repoUrl string
--- @return imm.RepoProvider
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

--- @param repoUrl string
--- @param cb fun(err?: string, res?: ghapi.Releases[])
function Repo.getReleases(repoUrl, cb)
    local prov = Repo.getProvider(repoUrl)
    if not prov.provider then
        cb(string.format('Unknown provider from given url %s', repoUrl))
        return
    end
    if prov.provider == 'github' then
        Repo.github_releases:fetch(prov.repo, cb)
    else
        Repo.releases_generic:fetch(prov, cb)
    end
end

return Repo