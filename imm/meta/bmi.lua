local Stack = require("imm.meta.stack")
local V = require("imm.lib.version")

--- @class imm.ModMetaStack.BMI: imm.ModMetaStack
--- @field id? string
--- @field protected cachedGhReleases? ghapi.Releases[]
--- @field protected cachedIntrReleases? imm.ModMeta.Release[]
local IBMIStack = {
    type = 'bmi',
    rank = 1
}

--- @param rel ghapi.Releases
local function transformBmiRelease(rel)
    local ver = Stack.transformVersion(rel.tag_name)
    local c = 0
    for i,v in ipairs(rel.assets) do c = c + v.download_count end
    local vpok, vparsed = pcall(V, ver) --- @diagnostic disable-line

    --- @type imm.ModMeta.Release
    return {
        url = rel.zipball_url,
        version = ver,
        versionParsed = vpok and vparsed or nil,
        isPre = rel.prerelease or rel.draft,
        time = rel.updated_at,
        count = #rel.assets ~= 0 and c or nil,
        format = 'bmi',
        bmi = rel
    }
end

--- @protected
--- @param repo imm.Repo.BMI
--- @param info bmi.Meta
function IBMIStack:init(repo, info)
	self.repo = repo
    self.info = info

    self.id = info.id
    self.title = info.name
    self.author = info.owner
    self.description = info.description
    self.categories = info.categories
    self.badgeColor = info.badge_colour
    self.badgeTextColor = info.badge_text_colour
end

function IBMIStack:getImage()
    if not self.info.pathname then return end
    return self.repo:getImageCo(self.info.pathname)
end

function IBMIStack:hasReleaseInfo()
    return not not self.info.repo
end

--- @async
--- @return ghapi.Releases[]?, string? err
function IBMIStack:getGithubReleasesCo()
    if self.cachedGhReleases then return self.cachedGhReleases end
    if not self.info.repo then return end

    local rel, err = self.repo:getReleasesCo(self.info.repo)
    if not rel then return nil, err end

    self.cachedGhReleases = rel
    return self.cachedGhReleases
end

--- @async
--- @return imm.ModMeta.Release[]?, string? err
function IBMIStack:getReleasesCo()
    if self.cachedIntrReleases then return self.cachedIntrReleases end
	local rel, err = self:getGithubReleasesCo()
    if not rel then return nil, err end

    self.cachedIntrReleases = {}
    for i,v in ipairs(rel) do self.cachedIntrReleases[i] = transformBmiRelease(v) end
    return self.cachedIntrReleases
end

function IBMIStack:clearReleases()
	self.cachedGhReleases = nil
    self.cachedIntrReleases = nil
end

--- @alias imm.ModMetaStack.BMI.C p.Constructor<imm.ModMetaStack.BMI.C, imm.ModMetaStack.C> | fun(repo: imm.Repo.BMI, info: bmi.Meta): imm.ModMetaStack.BMI
--- @type imm.ModMetaStack.BMI.C
local BMIStack = Stack:extendTo(IBMIStack)

return BMIStack