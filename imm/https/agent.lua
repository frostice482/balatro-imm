local Tasks = require("imm.lib.threadworker")
local imm = require("imm")
local curlh = assert(NFS.newFileData(imm.path..'/imm/https/curl.h'))
local threadcode = assert(NFS.newFileData(imm.path..'/imm/https/thread.lua'))

--- @class imm.HttpsAgent.Options: luahttps.Options
--- @field restype? 'string' | 'data'
--- @field onProgress? fun(dltotal: number, dlnow: number, ultotal: number, ulnow: number): ...

--- @class imm.HttpsAgent.Req
--- @field url string
--- @field options? imm.HttpsAgent.Options
--- @field progress? boolean

--- @class imm.HttpsAgent.Res
--- @field [1]? number
--- @field [2]? string | love.Data
--- @field [3]? table<string, string>

--- @class imm.HttpsAgent
local agent = {
    --- @type imm.ThreadWorker<imm.HttpsAgent.Req, imm.HttpsAgent.Res>
    task = Tasks(threadcode, tonumber(imm.config.httpsThreads) or 6), --- @diagnostic disable-line
    userAgent = 'imm (https://github.com/frostice482/balatro-imm)'
}
agent.task.autoRecountThreads = true

function agent.task:handleSpawnAdditionalParams(thread)
    return curlh, imm.config.enforceCurl
end

--- @protected
--- @param options imm.HttpsAgent.Options
function agent.addUa(options)
    options.headers = options.headers or {}
    options.headers['user-agent'] = options.headers['user-agent'] or agent.userAgent
end

--- @protected
--- @param url string
--- @param options imm.HttpsAgent.Options
function agent.transform(url, options)
    agent.addUa(options)
    --- @type imm.HttpsAgent.Req
    return {
        url = url,
        options = setmetatable({
            data = options.data,
            headers = options.headers,
            method = options.method,
            restype = options.restype,
        }, {
            __index = options
        }),
        progress = options.onProgress and true or nil
    }
end

--- @param url string
--- @param options? imm.HttpsAgent.Options
--- @param cb fun(code: number, body?: string | love.Data, headers: table<string, string>)
function agent:request(url, options, cb)
    self.task:runTask(agent.transform(url, options or {}), function (res) cb(res[1], res[2], res[3]) end)
end

--- @async
--- @param url string
--- @param options? imm.HttpsAgent.Options
function agent:requestCo(url, options)
    local r = self.task:runTaskCo(agent.transform(url, options or {}))
    return r[1], r[2], r[3]
end

function love.handlers.imm_https_progress(data)
    local e = agent.task.pendings[data[2]]
    local fn = e and e.req.options.onProgress
    if not fn then return end
    fn(unpack(data, 3, 6))
end

return agent
