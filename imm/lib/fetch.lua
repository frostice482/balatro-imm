local constructor = require("imm.lib.constructor")
local https = require("imm.https_agent")
local util = require("imm.lib.util")
local logger = require("imm.logger")

--- @class imm.Fetch<A, T>: balatro.Object, {
---     fetch: fun(self, arg: A, cb: fun(err?: string, res?: T), refreshCache?: boolean, useCache?: boolean);
--- }
local IFetch = {}

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

--- @param body string
--- @return string? error
--- @return any? list
function IFetch:handleRes(body)
    local ok, res
    if self.isResJson then
        --- @type boolean, ghapi.Contents[]
        ok, res = pcall(JSON.decode, body)
        if not ok then
            return res --- @diagnostic disable-line
        end
    else
        res = body
    end

    return nil, self:interpretRes(res)
end

--- @param cachefile string
--- @param cb fun(err?: string, data?: any)
--- @param useCache? boolean
--- @param url string
--- @param n number
function IFetch:runreq(cachefile, cb, useCache, url, n)
    https:request(
        url,
        nil,
        function (code, body, headers)
            local redirect = false
            if code == 302 or code == 301 then
                url = headers.location
                redirect = true
            end
            if redirect then
                self:runreq(cachefile, cb, useCache, url, n - 1)
                return
            end
            if code ~= 200 then
                logger.fmt('error', "%s: HTTP %d\n%s", url, code, body)
                cb(string.format('%s: HTTP Error %d', url, code))
                return
            end

            local err, res = self:handleRes(body or '')
            cb(err, res)
            if res and useCache ~= false then
                love.filesystem.createDirectory(util.dirname(cachefile))
                love.filesystem.write(cachefile, self:stringifyDataToCache(res))
            end
        end
    )
end

local IFetch2 = IFetch

function IFetch2:fetch(arg, cb, refreshCache, useCache) --- @diagnostic disable-line
    local cachefile = self:getCacheFileName(arg)
    local cache = not refreshCache and love.filesystem.read(cachefile)
    if cache then return cb(nil, self:parseCache(cache)) end
    self:runreq(cachefile, cb, useCache, self:getUrl(arg), 10)
end

--- @alias imm.Fetch.C p.Constructor<imm.Fetch, nil> | fun(url: string, file: string, isResJson?: boolean, isJson?: boolean): imm.Fetch<any, any>
--- @type imm.Fetch.C
local Fetch = constructor(IFetch)
return Fetch