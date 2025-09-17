local constructor = require("imm.lib.constructor")
local Queue = require("imm.lib.queue")
local UITaskStatusReg = require("imm.btasks.status")
local TaskDownloadCo = require("imm.btasks.download_co")
local TaskUpdateCo = require("imm.btasks.update_co")

--- @class imm.Browser.Tasks
local IBTasks = {}

--- @protected
--- @param ses imm.UI.Browser
function IBTasks:init(ses)
    self.queues = Queue(3)
    self.ses = ses
    self.status = UITaskStatusReg()
    self.updaterCo = TaskUpdateCo(self)
end

function IBTasks:createDownloadCoSes()
    return TaskDownloadCo(self)
end

---@param data love.Data
function IBTasks:installModFromZip(data)
    local modlist, list, errlist = self.ses.ctrl:installFromZip(data)

    local strlist = {}
    for i,v in ipairs(list) do table.insert(strlist, v.mod..' '..v.version) end
    local hasInstall = #strlist ~= 0

    if not hasInstall and #errlist == 0 then table.insert(errlist, 'Nothing is installed') end
    self.status:update( hasInstall and 'Installed '..table.concat(strlist, ', ') or nil, table.concat(errlist, '\n') )

    return modlist, list, errlist
end

--- @alias imm.Browser.Tasks.C p.Constructor<imm.Browser.Tasks, nil> | fun(ses: imm.UI.Browser): imm.Browser.Tasks
--- @type imm.Browser.Tasks.C
local BTasks = constructor(IBTasks)
return BTasks
