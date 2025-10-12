local Tasks = require("imm.lib.threadworker")
local imm = require("imm")
local threadcode = imm.resbundle and imm.resbundle.https_thread or assert(NFS.newFileData(imm.path..'/imm/https_thread.lua'))

--- @class imm.HttpsAgent.Options: luahttps.Options
--- @field restype? 'string' | 'data'

--- @class imm.HttpsAgent.Req
--- @field url string
--- @field options? imm.HttpsAgent.Options

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

--- @param options imm.HttpsAgent.Options
function agent.addUa(options)
    options.headers = options.headers or {}
    options.headers['user-agent'] = options.headers['user-agent'] or agent.userAgent
end

--- @param url string
--- @param options? imm.HttpsAgent.Options
--- @param cb fun(code: number, body?: string | love.Data, headers: table<string, string>)
function agent:request(url, options, cb)
    options = options or {}
    agent.addUa(options)
    self.task:runTask({ url = url, options = options}, function (res) cb(res[1], res[2], res[3]) end)
end

--- @async
--- @param url string
--- @param options? imm.HttpsAgent.Options
function agent:requestCo(url, options)
    options = options or {}
    agent.addUa(options)
    local r = self.task:runTaskCo({ url = url, options = options})
    return r[1], r[2], r[3]
end

return agent
