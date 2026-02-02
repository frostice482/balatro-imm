local BMI = require("imm.meta.bmi")
local PMP = require("imm.meta.photonmp")
local Fetch = require("imm.lib.fetch")
local GRepo = require("imm.repo.generic")
local util = require("imm.lib.util")

--- @type imm.Fetch<nil, bmi.Meta[]>
local fetch_list = Fetch('https://photonmodmanager.onrender.com/data', 'immcache/list/photon.json', {
    resType = 'json',
    cacheType = 'json',
    cacheTime = 3600 * 24
})

local excludeProps = {'git_owner', 'git_repo', 'mod_path', 'subpath', 'download_suffix', 'update_mandatory', 'target_version', 'type', 'published_at', 'readme', 'badge_colour', 'favourites'}
--- @param parsed table<string, photon.Package | photon.Modpack>
function fetch_list:interpretRes(parsed)
    local l = {}
    for k,v in pairs(parsed) do
        if v.versionHistory then
            for k,v in ipairs(v.versionHistory) do
                v.body = nil
            end
        end
        v.key = k
        table.insert(l, v)
    end
    return l
end

--- @type imm.Fetch<string, photon.Version.Success>
local fetch_releases = Fetch('https://photonmodmanager.onrender.com/api/version-history/%s', 'immcache/release/photon/%s', {
    resType = 'json',
    cacheType = 'json'
})

--- @param data photon.Version.Success
function fetch_releases:interpretRes(data)
    for k,v in ipairs(data.versionHistory) do
        v.body = nil
    end
    return data
end

--- @class imm.Repo.Photon: imm.Repo.Generic
--- @field mods table<string, photon.Package>
--- @field modpacks table<string, photon.Modpack>
local IPhotonRepo = {
    listApi = fetch_list,
    name = 'Photon'
}

--- @alias imm.Repo.Photon.C imm.Repo.Photon.Static | p.Constructor<imm.Repo.Photon, nil> | fun(repo: imm.Repo): imm.Repo.Photon
--- @type imm.Repo.Photon.C
local PRepo = GRepo:extendTo(IPhotonRepo)

--- @class imm.Repo.Photon.Static
local PRS = PRepo

PRS.tagTransform = {
    ['Textures'] = 'Resource Packs',
    ['SFX / Music'] = 'Resource Packs',
    ['Vanilla Plus'] = 'Content',
    ['Jokers'] = 'Joker',
    ['Consumables'] = 'Content',
    ['Cards'] = 'Content',
    ['Blinds'] = 'Content',
    ['Modifiers'] = 'Content',
    ['Mechanics'] = 'Technical',
    ['Misc'] = 'Miscellaneous',
    ['JokerForge'] = 'Content',

    ['Gameplay'] = 'Content',
    ['Overhaul'] = 'Content',
    ['Complete'] = 'Content',
    --['Lightweight'] = 'Content',
    ['Visual'] = 'Resources',
}

--- @return string user, string repo
function PRS.parseUserRepo(key)
    local repo, user = unpack(util.strsplit(key, '@', true, 2))
    repo = repo or '?'
    user = user or '?'
    return user, repo
end

function PRS.transformMod(entry)
    local user, repo = PRS.parseUserRepo(entry.key)

    local bmi_categories = {}
    for i, tag in ipairs(entry.tags or {}) do
        table.insert(bmi_categories, PRS.tagTransform[tag] or tag)
    end

    --- @type bmi.Meta
    return {
        id = entry.id,
        categories = bmi_categories,
        name = entry.name,
        owner = table.concat(entry.author, ', '),
        description = entry.description,
        pathname = user..'@'..repo,
        repo = string.format('https://github.com/%s/%s', user, repo),
        badge_colour = entry.badge_colour,
        provides = entry.provides
    }
end

--- @protected
--- @param repo imm.Repo
function IPhotonRepo:init(repo)
    GRepo.proto.init(self, repo)
    self.api = {
        list = fetch_list,
        releases = fetch_releases
    }
    self.mods = {}
    self.modpacks = {}
end

IPhotonRepo.parseUserRepo = PRS.parseUserRepo

function IPhotonRepo:clearReleases()
    self.mods = {}
    self.modpacks = {}
    GRepo.proto.clearReleases(self)
end

function IPhotonRepo:clearReleasesCache()
    self.api.releases:clearCacheDir()
    self:clearReleases()
end

--- @param entry photon.Package
function IPhotonRepo:updateListMod(entry)
    self.mods[entry.key] = entry
    local meta = self.repo:getMetaEntry(entry.id)
    if not meta:getStack"bmi" then meta:setStack(BMI(self.repo.bmi, PRS.transformMod(entry))) end
end

--- @param entry photon.Modpack
function IPhotonRepo:updateListModpack(entry)
    self.modpacks[entry.key] = entry
    self.repo:getMetaEntry(entry.id):setStack(PMP(self, entry))
end

--- @param entry photon.Package | photon.Modpack
function IPhotonRepo:updateList(entry)
    if entry.type == 'Mod' then
        return self:updateListMod(entry)
    elseif entry.type == 'Modpack' then
        return self:updateListModpack(entry)
    end
end

--- @protected
--- @param key string
function IPhotonRepo:handleGetReleases(key)
    local m = self.mods[key]
    if m and m.versionHistory then return m.versionHistory end

    local res, err = self.api.releases:fetchCo(key)
    if not res then return nil, err end
    if not res.success then return nil, 'failed' end

    return res.versionHistory
end

--- @async
--- @param key string
--- @return photon.Version[]? releases, string? err
function IPhotonRepo:getReleasesCo(key, cacheKey)
    return GRepo.proto.getReleasesCo(self, key, cacheKey)
end

return PRepo