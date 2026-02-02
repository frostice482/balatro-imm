local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")

--- @class imm.Repo.Generic
--- @field thumbCache table<string, love.Image | false>
--- @field listApi imm.Fetch<any, any>
--- @field thumbApi imm.Fetch<any, love.Data>
--- @field releasesCache table<string, any[]>
--- @field releasesCb table<string, function[]>
local IGRepo = {
    listDone = false,
    listBusy = false,
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
    self.listBusy = false
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

--- @param cb fun(err?: string)
function IGRepo:getList(cb)
    if self.listDone then return cb(nil) end
    if self.listBusy then
        table.insert(self.listCb, cb)
        return
    end
    self.listBusy = true
    self.listCb = { cb }

    local function handle (res, err)
        if res then
            self.listDone = true
            for i, entry in pairs(res) do self:updateList(entry) end
        end
        self.listBusy = false
        for i,v in ipairs(self.listCb) do v(err) end
    end
    self.listApi:fetch(nil, handle)
end

--- @async
--- @return string? err
function IGRepo:getListCo()
    return co.wrapCallbackStyle(function (res) self:getList(res) end)
end

--- @async
--- @param url string
--- @param cacheKey? string
--- @return love.Image? data, string? err
function IGRepo:getImageCo(url, cacheKey)
    cacheKey = cacheKey or url
    if self.thumbCache[cacheKey] ~= nil then return self.thumbCache[cacheKey] or nil end
    local res, err = self.thumbApi:fetchCo(url)

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
    local ck = self:mapReleaseCacheKey(arg, ...)
    cacheKey = cacheKey or ck

    if self.releasesCache[cacheKey] then
        return self.releasesCache[cacheKey], nil
    end
    if self.releasesCb[ck] then
        return co.wrapCallbackStyle(function(h)
            return table.insert(self.releasesCb[ck], h)
        end)
    end

    self.releasesCb[ck] = {}
    local res, err = self:handleGetReleases(arg, ...)
    if res then self.releasesCache[cacheKey] = res end
    for i, cb in ipairs(self.releasesCb[ck]) do cb(res, err) end
    self.releasesCb[ck] = nil

    return res, err
end

return GRepo