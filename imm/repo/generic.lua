local constructor = require("imm.lib.constructor")
local SingleRequest = require("imm.lib.singlereq")
local co = require("imm.lib.co")

--- @class imm.Repo.Generic
--- @field thumbCache table<string, love.Image | false>
--- @field listApi imm.Fetch<any, any>
--- @field thumbApi imm.Fetch<any, love.Data>
--- @field releasesCache table<string, any[]>
--- @field releasesCb table<string, function[]>
local IGRepo = {
    listDone = false,
    name = 'Generic'
}

--- @alias imm.Repo.Generic.C p.Constructor<imm.Repo.Generic, nil> | fun(repo: imm.Repo): imm.Repo.Generic
--- @type imm.Repo.Generic.C
local GRepo = constructor(IGRepo)

--- @protected
--- @param repo imm.Repo
function IGRepo:init(repo)
    self.repo = repo
    if not self.listApi then self.listApi = self.repo.api.blob end
    if not self.thumbApi then self.thumbApi = self.repo.api.blob end

    self.listCb = {}
    self.thumbCache = {}
    self.releasesCache = {}
    self.releasesCb = {}

    self.singleList = SingleRequest()
    self.singleThumb = SingleRequest()
    self.singleReleases = SingleRequest()
end

function IGRepo:clearReleases()
    self.releasesCache = {}
    self.releasesCb = {}
end
function IGRepo:clearThumbImages()
    self.thumbCache = {}
end

function IGRepo:clearListCache()
    self.listDone = false
    self.thumbApi:clearCacheFile()
end
function IGRepo:clearReleasesCache()
    self:clearReleases()
end
function IGRepo:clearThumbCache()
    self:clearThumbImages()
    self.thumbApi:clearCacheDir()
end

function IGRepo:updateList(entry) end

--- @async
--- @return string? err
function IGRepo:getListCo()
    if self.listDone then return end
    return self.singleList:invoke('', self._getListCo, self)
end

--- @protected
--- @async
--- @return string? err
function IGRepo:_getListCo()
    local res, err = self.listApi:fetchCo(nil)
    if not res then return err end

    self.listDone = true
    for i, entry in pairs(res) do self:updateList(entry) end
end

--- @protected
function IGRepo:mapImageCacheKey(arg)
    return arg
end

--- @async
--- @param arg any
--- @param cacheKey? string
--- @return love.Image? data, string? err
function IGRepo:getImageCo(arg, cacheKey)
    cacheKey = cacheKey or self:mapImageCacheKey(arg)
    if self.thumbCache[cacheKey] ~= nil then return self.thumbCache[cacheKey] or nil end
    return self.singleThumb:invoke(cacheKey, self._getImageCo, self, arg, cacheKey)
end

--- @protected
--- @async
--- @param arg any
--- @param cacheKey string
--- @return love.Image? data, string? err
function IGRepo:_getImageCo(arg, cacheKey)
    local res, err = self.thumbApi:fetchCo(arg)

    --- @type boolean, any?
    local ok, img = false, err
    if res then
        ok, img = pcall(love.graphics.newImage, res)
    end
    if not ok then
        self.thumbCache[cacheKey] = false
        return nil, img
    end

    self.thumbCache[cacheKey] = img
    return img, nil
end

--- @protected
function IGRepo:mapReleaseCacheKey(arg, ...)
    return arg
end

--- @protected
--- @param arg any
--- @return any? ret, string? err
function IGRepo:handleGetReleases(arg, ...)
end

--- @protected
--- @async
--- @param arg any
--- @param cacheKey? string
--- @return any releases, string? err
function IGRepo:getReleasesCo(arg, cacheKey, ...)
    cacheKey = cacheKey or self:mapReleaseCacheKey(arg, ...)
    if self.releasesCache[cacheKey] then return self.releasesCache[cacheKey], nil end
    return self.singleReleases:invoke(cacheKey, self._getReleasesCo, self, arg, cacheKey, ...)
end

--- @protected
--- @async
--- @param arg any
--- @param ck string
function IGRepo:_getReleasesCo(arg, ck, ...)
    local res, err = self:handleGetReleases(arg, ...)
    if res then self.releasesCache[ck] = res end
    return res, err
end

return GRepo