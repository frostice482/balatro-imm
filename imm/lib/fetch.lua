local constructor = require("imm.lib.constructor")
local util = require("imm.lib.util")
local co = require("imm.lib.co")
local https = require("imm.https_agent")
local logger= require("imm.logger")

--- @class imm.Fetch<A, T>: balatro.Object, {
---     fetch: fun(self, arg: A, cb: fun(err?: string, res?: T), refreshCache?: boolean, useCache?: boolean);
---     fetchCo: async fun(self, arg: A, refreshCache?: boolean, useCache?: boolean): string?, T;
--- }
local IFetch = {
    cacheLasts = 3600 * 24
}

--- @protected
--- @param url string
--- @param file string
--- @param isResJson? boolean
--- @param isJson? boolean
function IFetch:init(url, file, isResJson, isJson)
    self.url = url
    self.cacheFile = file
    self.isResJson = isResJson
    self.isJson = isJson
end

--- @param data any
--- @return string
function IFetch:stringifyDataToCache(data)
    return self.isJson and JSON.encode(data) or data
end

--- @param str string
--- @return any
function IFetch:parseCache(str)
    return self.isJson and JSON.decode(str) or str
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

--- @param arg any
--- @return luahttps.Options?
function IFetch:getReqOpts(arg) end

--- @param body string
--- @return string? error
--- @return any? res
function IFetch:handleRes(body)
    local ok, res

    if self.isResJson then
        ok, res = pcall(JSON.decode, body)
    else
        ok, res = pcall(self.interpretRes, self, body)
    end

    if ok then return nil, res
    else return res, nil
    end
end

--- @class imm.Fetch.ReqState
--- @field cachefile string
--- @field useCache? boolean
--- @field url string
--- @field opts? luahttps.Options
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
    if res and state.useCache ~= false then
        local dir = util.dirname(state.cachefile)
        local ok, err = love.filesystem.createDirectory(dir)
        if ok then ok, err = love.filesystem.write(state.cachefile, self:stringifyDataToCache(res)) end
        if not ok then logger.fmt("warn", "Failed saving cache for %s (%s): %s", state.cachefile, dir, err or '?') end
    end
    return err, res
end

--- @param file string
function IFetch:getCacheFile(file)
    local info = love.filesystem.getInfo(file)
    if not (info and info.modtime + self.cacheLasts > os.time()) then return end
    local data = love.filesystem.read(file)
    return data
end

--- @type imm.Fetch<any, any>
local IFetch2 = IFetch

--- @async
function IFetch2:fetchCo(arg, refreshCache, useCache)
    local cachefile = self:getCacheFileName(arg)
    local cache = not refreshCache and self:getCacheFile(cachefile)
    if cache then return nil, self:parseCache(cache) end

    return self:runreqCo({
        cachefile = cachefile,
        useCache = useCache,
        n = 10,
        url = self:getUrl(arg),
        opts = self:getReqOpts(arg)
    })
end

function IFetch2:fetch(arg, cb, refreshCache, useCache)
    co.create(function ()
        cb(self:fetchCo(arg, refreshCache, useCache))
    end)
end

--- @alias imm.Fetch.C p.Constructor<imm.Fetch, nil> | fun(url: string, file: string, isResJson?: boolean, isJson?: boolean): imm.Fetch<any, any>
--- @type imm.Fetch.C
local Fetch = constructor(IFetch)
return Fetch