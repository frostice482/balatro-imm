local Stack = require("imm.meta.stack")
local V = require("imm.lib.version")

--- @class imm.ModMetaStack.TS: imm.ModMetaStack
local ITSStack = {
    type = 'ts',
    rank = 2,
}

--- @param rel thunderstore.PackageVersion
local function transformTsRelease(rel)
    local ver = Stack.transformVersion(rel.version_number)
    local vpok, vparsed = pcall(V, ver) --- @diagnostic disable-line

    --- @type imm.ModMeta.Release
    return {
        url = rel.download_url,
        version = ver,
        versionParsed = vpok and vparsed or nil,
        size = rel.file_size,
        time = rel.date_created,
        count = rel.downloads,
        dependencies = rel.dependencies,
        format = 'thunderstore',
        ts = rel
    }
end

--- @protected
--- @param repo imm.Repo.TS
--- @param info thunderstore.Package
function ITSStack:init(repo, info)
	local latest = info.versions[1]
	self.repo = repo
	self.package = info
	self.latest = latest

	self.id = info.name
	self.title = info.name
    self.author = info.owner
    self.description = latest.description
	self.dependencies = latest.dependencies
	self.categories = info.categories

	self.releases = {}
	for i,v in ipairs(info.versions) do
		self.releases[i] = transformTsRelease(v)
	end
end

function ITSStack:hasReleaseInfo()
    return true
end

function ITSStack:getImage()
    return self.repo:getImageCo(self.latest.icon)
end

function ITSStack:getReleasesCo()
	return self.releases
end

function ITSStack:clearReleases()
	-- do nothing
end

--- @alias imm.ModMetaStack.TS.C p.Constructor<imm.ModMetaStack.TS.C, imm.ModMetaStack.C> | fun(repo: imm.Repo.TS, info: thunderstore.Package): imm.ModMetaStack.TS
--- @type imm.ModMetaStack.TS.C
local TSStack = Stack:extendTo(ITSStack)

return TSStack