local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")

--- @class imm.Repo.Generic
--- @field imageCache table<string, love.Image | false>
--- @field listApi imm.Fetch<any, any>
--- @field thumbApi imm.Fetch<any, any>
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

    self.listBusy = false
    self.listCb = {}
end

function IGRepo:clear()
    self.listDone = false
    self.imageCache = {}
end

function IGRepo:updateList(entry) end

--- @param cb fun(err?: string)
function IGRepo:getList(cb)
    if self.listDone then cb(nil) end
    if self.listBusy then
        table.insert(self.listCb, cb)
        return
    end
    self.listBusy = true
    self.listCb = { cb }

    local function handle (err, res)
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
--- @return string? err, love.Image? data
function IGRepo:getImageCo(url, cacheKey)
    cacheKey = cacheKey or url
    if self.imageCache[cacheKey] ~= nil then return nil, self.imageCache[cacheKey] or nil end
    local err, res = self.thumbApi:fetchCo(url)

    --- @type boolean, any?
    local ok, img = false, err
    if res then ok, img = pcall(love.graphics.newImage, res) end
    if not ok then
        self.imageCache[cacheKey] = false
        return img, nil
    end

    self.imageCache[cacheKey] = img
    return nil, img
end

return GRepo