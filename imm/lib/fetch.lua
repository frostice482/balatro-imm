local constructor = require("imm.lib.constructor")
local util = require("imm.lib.util")
local co = require("imm.lib.co")
local https = require("imm.https.agent")
local logger= require("imm.logger")
local imm = require('imm')

--- @alias imm.Fetch.ResType 'json' | 'string' | 'data'
--- @alias imm.Fetch.SaveType 'json' | 'string' | 'filedata'

--- @class imm.Fetch.HttpOpts: imm.HttpsAgent.Options
--- @field refreshCache? boolean
--- @field useCache? boolean

--- @class imm.Fetch.InitOpts
--- If true, the data from response will be parsed as JSON data.
--- @field resType? imm.Fetch.ResType
--- If true, the data will be saved/loaded as imm.json.
--- @field cacheType? imm.Fetch.SaveType
--- Never cache response
--- @field neverCache? boolean
--- How long a cache should last, in seconds
--- @field cacheTime? number

--- @class imm.Fetch<A, T>: balatro.Object, {
---     fetch: fun(self, arg: A, cb: fun(err?: string, res?: T), opts?: imm.Fetch.HttpOpts);
---     fetchCo: async fun(self, arg: A, opts?: imm.Fetch.HttpOpts): string?, T;
--- }
--- @field resType imm.Fetch.ResType
--- @field cacheType imm.Fetch.SaveType
local IFetch = {
    cacheLasts = 3600 * 24,
    resType = 'string',
    cacheType = 'string',
    neverCache = false
}

--- @protected
--- @param url string
--- @param file string
--- @param opts? imm.Fetch.InitOpts
function IFetch:init(url, file, opts)
    opts = opts or {}
    self.url = url
    self.cacheFile = file

    self.resType = opts.resType
    self.cacheType = opts.cacheType
    self.neverCache = opts.neverCache
    self.cacheTime = opts.cacheTime
end

--- @param data any
--- @return string | love.Data
function IFetch:stringifyDataToCache(data)
    if self.cacheType == 'json' then
        return imm.json.encode(data)
    end
    return data
end

--- @param data string | love.FileData
--- @return any
function IFetch:parseCache(data)
    if self.cacheType == 'json' then
        return imm.json.decode(data)
    end
    return data
end

--- @param data any
--- @return any
function IFetch:interpretRes(data)
    return data
end

--- @param arg any
--- @return string
function IFetch:getUrl(arg)
    return type(arg) == 'string' and self.url:format(arg) or self.url
end

--- @param arg any
--- @return string
function IFetch:getCacheFileName(arg)
    return type(arg) == 'string' and self.cacheFile:format(util.sanitizename(arg)) or self.cacheFile
end

--- @param arg imm.Fetch.HttpOpts
function IFetch:transformOpts(arg) end

--- @param body string | love.Data
--- @return string? error
--- @return any? res
function IFetch:handleRes(body)
    local ok, res = true, body

    if self.resType == 'json' then
        ok, res = pcall(imm.json.decode, body)
    end
    if ok then
        ok, res = pcall(self.interpretRes, self, res)
    end

    if ok then return nil, res
    else return res, nil
    end
end

--- @param file string
--- @param data any
local function writeCache(file, data)
    local dir = util.dirname(file)
    local ok, err = true, nil
    if ok then
        ok = type(data) == 'string' or type(data) == "userdata" and data:typeOf("Data") --- @diagnostic disable-line
        if not ok then
            err = "Cache data to write must be a string, or a Data"
        end
    end
    if ok then
        ok, err = love.filesystem.createDirectory(dir)
    end
    if ok then
        ok, err = love.filesystem.write(file, data)
    end
    if not ok then
        logger.fmt("warn", "Failed saving cache for %s (%s): %s", file, dir, err or '?')
    end
end

--- @class imm.Fetch.ReqState
--- @field cachefile string
--- @field url string
--- @field opts? imm.Fetch.HttpOpts
--- @field n number

--- @async
--- @param state imm.Fetch.ReqState
--- @return string? err, any? res
function IFetch:runreqCo(state)
    if state.n < 1 then return 'Too many redirections' end
    local code, body, headers = https:requestCo(state.url, state.opts)

    local redirect = false
    if code == 302 or code == 301 then
        state.url = headers.location
        redirect = true
    end
    if redirect then
        return self:runreqCo(state)
    end
    if code ~= 200 then
        return string.format('HTTP Error %d (%s)', code, state.url)
    end

    local err, res = self:handleRes(body or '')
    if res and state.opts.useCache ~= false and not self.neverCache then
        writeCache(state.cachefile, self:stringifyDataToCache(res))
    end
    return err, res
end

--- @param file string
function IFetch:getCacheFile(file)
    local info = love.filesystem.getInfo(file)
    if not (info and info.modtime + self.cacheLasts > os.time()) then return end

    local data
    if self.cacheType == 'filedata' then
        data = love.filesystem.newFileData(file)
    else
        data = love.filesystem.read(file)
    end
    return data
end

--- @type imm.Fetch<any, any>
local IFetch2 = IFetch

--- @async
function IFetch2:fetchCo(arg, opts)
    opts = opts or {}

    self:transformOpts(opts)
    if self.resType == 'data' then
        opts = opts or {}
        opts.restype = self.resType == 'data' and 'data' or nil
    end

    local cachefile = self:getCacheFileName(arg)
    local cache = not opts.refreshCache and self:getCacheFile(cachefile)
    if cache then return nil, self:parseCache(cache) end

    return self:runreqCo({
        cachefile = cachefile,
        n = 10,
        url = self:getUrl(arg),
        opts = opts
    })
end

function IFetch2:fetch(arg, cb, opts)
    co.create(function ()
        cb(self:fetchCo(arg, opts))
    end)
end

--- @alias imm.Fetch.C p.Constructor<imm.Fetch, nil> | fun(url: string, file: string, opts?: imm.Fetch.InitOpts): imm.Fetch<any, any>
--- @type imm.Fetch.C
local Fetch = constructor(IFetch)
return Fetch