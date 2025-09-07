local Tasks = require("imm.lib.tasks")
local immpath = require("imm.config").path
local threadcode = assert(NFS.newFileData(immpath..'/imm/https_thread.lua'))

--- @class imm.HttpsAgent.Req
--- @field url string
--- @field options? luahttps.Options

--- @class imm.HttpsAgent.Res
--- @field [1]? number
--- @field [2]? string
--- @field [3]? table<string, string>

--- @class imm.HttpsAgent
local agent = {
    --- @type imm.Tasks<imm.HttpsAgent.Req, imm.HttpsAgent.Res>
    task = Tasks(threadcode, 6)
}

--- @param url string
--- @param options? luahttps.Options
--- @param cb fun(code: number, body?: string, headers: table<string, string>)
function agent:request(url, options, cb)
    options = options or {}
    options.headers = options.headers or {}
    options.headers['user-agent'] = 'imm (https://github.com/frostice482/balatro-imm)'

    self.task:runTask({ url = url, options = options}, function (res) cb(res[1], res[2], res[3]) end)
end

return agent
