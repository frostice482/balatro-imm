local Fetch = require("imm.lib.fetch")
local GRepo = require("imm.modrepo.generic")
local util = require("imm.lib.util")

--- @type imm.Fetch<nil, bmi.Meta[]>
local fetch_list = Fetch('https://photonmodmanager.onrender.com/data', 'immcache/list/photon.json', {
    resType = 'json',
    cacheType = 'json',
    cacheTime = 3600 * 24
})

local excludeProps = {'git_owner', 'git_repo', 'mod_path', 'subpath', 'download_suffix', 'update_mandatory', 'target_version', 'type', 'published_at', 'readme', 'badge_colour', 'favourites'}
local tagTransform = {
    ['Textures'] = 'Resource Packs',
    ['SFX / Music'] = 'Resource Packs',
    ['Vanilla Plus'] = 'Content',
    ['Jokers'] = 'Joker',
    ['Consumables'] = 'Content',
    ['Cards'] = 'Content',
    ['Blinds'] = 'Content',
    ['Modifiers'] = 'Content',
    ['Mechanics'] = 'Technical',
    ['Misc'] = 'Miscellaneous'
}

--- @param parsed table<string, photon.Package>
function fetch_list:interpretRes(parsed)
    --- @type bmi.Meta[]
    local interpreted = {}
    for k, entry in pairs(parsed) do
        local repo, user = unpack(util.strsplit(k, '@', true, 2))
        repo = repo or '?'
        user = user or '?'

        local bmi_categories = {}
        for i, tag in ipairs(entry.tags or {}) do
            table.insert(bmi_categories, tagTransform[tag] or tag)
        end

        --- @type bmi.Meta
        local bmi_compat = {
            id = entry.id,
            categories = bmi_categories,
            name = entry.name,
            owner = table.concat(entry.author, ', '),
            description = entry.description,
            pathname = user..'@'..repo,
            repo = string.format('https://github.com/%s/%s', user, repo)
        }
        table.insert(interpreted, bmi_compat)
    end

    return interpreted
end

--- @class imm.Repo.Photon: imm.Repo.Generic
local IPhotonRepo = {
    listApi = fetch_list,
    name = 'Photon'
}

--- @alias imm.Repo.Photon.C p.Constructor<imm.Repo.Photon, nil> | fun(repo: imm.Repo): imm.Repo.Photon
--- @type imm.Repo.Photon.C
local TSRepo = GRepo:extendTo(IPhotonRepo)

--- @protected
--- @param repo imm.Repo
function IPhotonRepo:init(repo)
    GRepo.proto.init(self, repo)
    self.api = {
        list = fetch_list
    }
    self:clear()
end

--- @param entry bmi.Meta
function IPhotonRepo:updateList(entry)
    local meta = self.repo:getMetaEntry(entry.name)
    meta.bmi = meta.bmi or entry
end

return TSRepo