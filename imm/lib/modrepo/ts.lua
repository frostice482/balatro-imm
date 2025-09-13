local Fetch = require("imm.lib.fetch")
local GRepo = require("imm.lib.modrepo.generic")

--- @type imm.Fetch<nil, thunderstore.Package[]>
local fetch_list = Fetch('https://thunderstore.io/c/balatro/api/v1/package/', 'immcache/thunderstore_list.json', false, true)

local omitProps = { 'full_name', 'date_created', 'date_updated', 'uuid4', 'rating_score', 'has_nsfw_content'}
local omitVerProps = { 'full_name', 'downloads', 'date_created', 'is_active', 'uuid4' }
local blacklistedPackages = {
    r2modman = true
}

--- @param str string
function fetch_list:interpretRes(str)
    --- @type thunderstore.Package[]
    local parsed = JSON.decode(str)
    for _,package in ipairs(parsed) do
        if not blacklistedPackages[package.name] then
            package.format = 'thunderstore'
            for _, omitProp in ipairs(omitProps) do
                package[omitProp] = nil
            end
            for _, version in ipairs(package.versions) do
                version.format = 'thunderstore'
                for _, omitVerProp in ipairs(omitVerProps) do
                    version[omitVerProp] = nil
                end
            end
        end
    end
    return parsed
end

--- @class imm.Repo.TS: imm.Repo.Generic
local ITSRepo = {
    listApi = fetch_list
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