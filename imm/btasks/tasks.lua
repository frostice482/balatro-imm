local constructor = require("imm.lib.constructor")
local Queue = require("imm.lib.queue")
local UITaskStatusReg = require("imm.btasks.status")
local TaskDownload = require("imm.btasks.download")
local co = require("imm.lib.co")
local logger = require("imm.logger")

--- @class imm.Browser.Tasks
local IBTasks = {}

--- @protected
--- @param ses imm.UI.Browser
function IBTasks:init(ses)
    self.queues = Queue(3)
    self.ses = ses
    self.status = UITaskStatusReg()
end

function IBTasks:createDownloadSes()
    return TaskDownload(self)
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

--- @param modlist imm.ModList
--- @param meta imm.ModMeta
function IBTasks:getModUpdate(modlist, meta)
    local lastInstalled = modlist:list()[1]
    if not lastInstalled then return end

    local rel = meta:getReleasesCo()
    --- @type imm.ModMeta.Release
    local latest
    for i, v in ipairs(rel) do if not v.isPre then latest = v break end end
    -- does not have release info
    if not latest then
        return
    end
    -- have invalid release info
    if not latest.versionParsed then
        return logger.warn('Latest version of mod %s has invalid version %s, ignored', meta:title(), latest.version)
    end
    -- installed version is already latest
    if lastInstalled.versionParsed >= latest.versionParsed then
        return
    end

    return latest
end

--- @param modlist imm.ModList
--- @param meta imm.ModMeta
function IBTasks:updateModCo(modlist, meta)
    local nver = self:getModUpdate(modlist, meta)
end

function IBTasks:updateAllMods()
    local s = self.status:new()
    s:update('Updating all mods')

    for id, modlist in pairs(self.ses.ctrl.mods) do
        local meta = self.ses.repo.listMapped[id]
        if meta then co.create(self.updateModCo, self, modlist, meta) end
    end
end

--- @alias imm.Browser.Tasks.C p.Constructor<imm.Browser.Tasks, nil> | fun(ses: imm.UI.Browser): imm.Browser.Tasks
--- @type imm.Browser.Tasks.C
local IBtasks = constructor(IBTasks)
return IBtasks
