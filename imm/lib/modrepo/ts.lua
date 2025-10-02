local Fetch = require("imm.lib.fetch")
local GRepo = require("imm.lib.modrepo.generic")
local util  = require("imm.lib.util")
local logger= require("imm.logger")

--- @type imm.Fetch<nil, thunderstore.Package[]>
local fetch_list = Fetch('https://thunderstore.io/c/balatro/api/v1/package/', 'immcache/list/thunderstore.json', false, true)
fetch_list.cacheLasts = 3600 * 12

--- @type imm.Fetch<string, string>
local fetch_thumb_blob = Fetch('%s', 'immcache/thumb_blob/%s')

function fetch_thumb_blob:getCacheFileName(arg)
    return self.cacheFile:format(love.data.encode('string', 'hex', love.data.hash('md5', arg)))
end

local omitProps = { 'full_name', 'date_created', 'date_updated', 'uuid4', 'rating_score', 'has_nsfw_content'}
local omitVerProps = { 'full_name', 'downloads', 'date_created', 'is_active', 'uuid4' }
local blacklistedPackages = {
    r2modman = true,
    lovely = true
}

--- @param str string
function fetch_list:interpretRes(str)
    --- @type thunderstore.Package[]
    local parsed = JSON.decode(str)
    local i = 1
    while i <= #parsed do
        local package = parsed[i]
        if blacklistedPackages[package.name] or package.is_deprecated then
            logger.dbg('Ignored TS package', package.owner, package.name)
            util.removeswap(parsed, i)
            i = i - 1
        else
            for _, omitProp in ipairs(omitProps) do
                package[omitProp] = nil
            end
            for _, version in ipairs(package.versions) do
                for _, omitVerProp in ipairs(omitVerProps) do
                    version[omitVerProp] = nil
                end
            end
        end
        i = i + 1
    end
    return parsed
end

--- @class imm.Repo.TS: imm.Repo.Generic
local ITSRepo = {
    listApi = fetch_list,
    thumbApi = fetch_thumb_blob
}

--- @alias imm.Repo.TS.C p.Constructor<imm.Repo.TS, nil> | fun(repo: imm.Repo): imm.Repo.TS
--- @type imm.Repo.TS.C
local TSRepo = GRepo:extendTo(ITSRepo)

--- @protected
--- @param repo imm.Repo
function ITSRepo:init(repo)
    GRepo.proto.init(self, repo)
    self.api = {
        list = fetch_list
    }
    self:clear()
end

--- @param entry thunderstore.Package
function ITSRepo:updateList(entry)
    local meta = self.repo:getMetaEntry(entry.name)
    meta.ts = entry
    meta.tsLatest = entry.versions[1]
end

return TSRepo