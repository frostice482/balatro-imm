local constructor = require("imm.lib.constructor")
local Queue = require("imm.lib.queue")
local co = require("imm.lib.co")
local logger = require("imm.logger")
local ui = require("imm.lib.ui")
local util = require("imm.lib.util")

local funcs = {
    statusInit = 'imm_bt_status_link',
    tasksInit = 'imm_bt_link'
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.statusInit] = function (elm)
    --- @type imm.Browser.TaskStatus
    local r = elm.config.ref_table
    elm.config.func = nil
    r.elm = elm

    if r.isRemoved then
        ui.removeElement(elm)
        elm.UIBox:recalculate()
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.tasksInit] = function (elm)
    --- @type imm.Browser.Tasks
    local r = elm.config.ref_table
    elm.config.func = nil
    r.listElm = elm
end

--- @class imm.Browser.TaskStatus
--- @field containerCfg balatro.UIElement.Config
--- @field labelCfg balatro.UIElement.Config
--- @field textCfg balatro.UIElement.Config
--- @field elm? balatro.UIElement
local IUITaskStatus = {
    text = '',
    isDone = false,
    isRemoved = false
}

--- @protected
function IUITaskStatus:init()
    self.containerCfg = { colour = G.C.CLEAR, func = funcs.statusInit, ref_table = self }
    self.labelCfg = { colour = G.C.WHITE, minw = 0.1 }
    self.textCfg = { ref_table = self, ref_value = 'text', scale = 0.3 } --- hardcoded value!

    self.doneColor = G.C.GREEN
    self.errorColor = G.C.ORANGE
end

--- @param text string
function IUITaskStatus:update(text)
    self.text = text
end

--- @param text string
function IUITaskStatus:done(text)
    self.text = text
    self.labelCfg.colour = self.doneColor
    self.isDone = true
end

--- @param text string
function IUITaskStatus:error(text)
    self.text = text
    self.labelCfg.colour = self.errorColor
    self.isDone = true
end

--- @param format string
function IUITaskStatus:updatef(format, ...)
    self.text = format:format(...)
end

--- @param format string
function IUITaskStatus:donef(format, ...)
    self:done(format:format(...))
end

--- @param format string
function IUITaskStatus:errorf(format, ...)
    self:error(format:format(...))
end

function IUITaskStatus:render()
    self.elm = nil

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = self.containerCfg,
        nodes = {
            { n = G.UIT.C, config = self.labelCfg },
            --- hardcoded value!
            ui.C{ padding = 0.05, },
            ui.C{ padding = 0.05, align = 'cm', { n = G.UIT.T, config = self.textCfg } }
        }
    }
end

--- @alias imm.Browser.TaskStatus.C p.Constructor<imm.Browser.TaskStatus, nil> | fun(): imm.Browser.TaskStatus
--- @type imm.Browser.TaskStatus.C
local UITaskStatus = constructor(IUITaskStatus)

--- @class imm.Browser.Tasks
--- @field statuses imm.Browser.TaskStatus[]
--- @field listElm? balatro.UIElement
local IUITasks = {
    noAutoDownloadMissing = false
}

--- @protected
--- @param ses imm.UI.Browser
function IUITasks:init(ses)
    self.queues = Queue(3)
    self.ses = ses
    self.statuses = {}
end

--- @param i number
function IUITasks:removeStatus(i)
    --- @type imm.Browser.TaskStatus
    local e = util.removeswap(self.statuses, i)
    if not e then error(string.format('index %d not found', i)) end

    if e.elm and not e.elm.REMOVED then ui.removeElement(e.elm) end
    e.isRemoved = true
end

--- @param status imm.Browser.TaskStatus
function IUITasks:addStatus(status)
    table.insert(self.statuses, status)
    if self.listElm then
        self.listElm.UIBox:add_child(status:render(), self.listElm)
    end
end

function IUITasks:removeDoneStatuses()
    local i = 1
    while i <= #self.statuses do
        local entry = self.statuses[i]
        if entry.isDone then
            self:removeStatus(i)
            i = i - 1
        end
        i = i + 1
    end
end

--- @param noRecalc? boolean
--- @param noRemoveDone? boolean
function IUITasks:newStatus(noRecalc, noRemoveDone)
    if not noRemoveDone then self:removeDoneStatuses() end
    local status = UITaskStatus()
    self:addStatus(status)
    if not noRecalc and self.listElm then self.listElm.UIBox:recalculate() end
    return status
end

--- @param suc? string
--- @param err? string
function IUITasks:updateStatusImm(suc, err)
    self:removeDoneStatuses()

    if suc and suc:len() ~= 0 then
        self:newStatus(true, true):done(suc)
        logger.log(suc)
    end
    if err and err:len() ~= 0 then
        self:newStatus(true, true):error(err)
        logger.err(err)
    end

    if self.listElm then self.listElm.UIBox:recalculate() end
end

--- @class imm.ModSession.QueueDownloadExtraInfo
--- @field name? string
--- @field size? number
--- @field blacklist? table<string>
--- @field cb? fun(err?: string)

--- @protected
--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function IUITasks:downloadCo(url, extra)
    extra = extra or {}
    extra.blacklist = extra.blacklist or {}

    local name = extra.name or 'something'
    local size = extra.size

    self.queues:queueCo()

    if extra.blacklist[url] then
        self.queues:next()
        return
    end

    local status = self:newStatus()
    status:updatef('Downloading %s (%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')

    local err, res = self.ses.repo.api.blob:fetchCo(url)
    if not res then
        status:errorf('Failed downloading %s: %s', name, err)
        if extra.cb then extra.cb(err) end
    else
        status:done('')
        extra.blacklist[url] = true
        self:installModFromZip(love.filesystem.newFileData(res, 'swap'), extra.blacklist)
        if extra.cb then extra.cb(err) end
    end

    return self.queues:next()
end

--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function IUITasks:download(url, extra)
    co.create(self.downloadCo, self, url, extra)
end

--- @protected
--- @param id string
--- @param list imm.Dependency.Rule[][]
--- @param blacklistState? table<string>
function IUITasks:_downloadMissingModEntryCo(id, list, blacklistState)
    local mod = self.ses.repo:getMod(id)
    if not mod then return logger.fmt('warn', 'Mod id %s does not exist in repo', id) end

    mod:getReleasesCo()
    local release, pre = mod:findModVersionToDownload(list)
    if not release then
        logger.fmt('warn', 'Failed to download missing dependencies %s', mod:title())
        return
    end

    if pre then
        logger.fmt('warn', 'A prerelease version %s %s is being downloaded', mod:title(), release.version)
    end

    self:downloadCo(release.url, {
        name = mod:title()..' '..release.version,
        blacklist = blacklistState
    })
end

--- @param id string
--- @param list imm.Dependency.Rule[][]
--- @param blacklistState? table<string>
function IUITasks:downloadMissingEntry(id, list, blacklistState)
    co.create(self._downloadMissingModEntryCo, self, id, list, blacklistState)
end

--- @param mod imm.Mod
--- @param blacklistState? table<string>
function IUITasks:downloadMissings(mod, blacklistState)
    local missings = self.ses.ctrl:getMissingDeps(mod.deps)
    for missingid, missingList in pairs(missings) do
        logger.fmt('log', 'Missing dependency %s by %s', missingid, mod.mod)
        self:downloadMissingEntry(missingid, missingList, blacklistState)
    end
end

---@param blacklistState? table<string>
function IUITasks:installModFromZip(data, blacklistState)
    local modlist, list, errlist = self.ses.ctrl:installFromZip(data)

    local strlist = {}
    for i,v in ipairs(list) do table.insert(strlist, v.mod..' '..v.version) end
    local hasInstall = #strlist ~= 0

    if not hasInstall and #errlist == 0 then table.insert(errlist, 'Nothing is installed') end
    self:updateStatusImm( hasInstall and 'Installed '..table.concat(strlist, ', ') or nil, table.concat(errlist, '\n') )

    if not self.noAutoDownloadMissing then
        for i, mod in ipairs(list) do self:downloadMissings(mod, blacklistState) end
    end

    return modlist, list, errlist
end

function IUITasks:render()
    local list = {}
    for i,v in ipairs(self.statuses) do table.insert(list, v:render()) end

    self.listElm = nil

    return ui.C{
        func = funcs.tasksInit,
        ref_table = self,
        nodes = list
    }
end

--- @alias imm.Browser.Tasks.C p.Constructor<imm.Browser.Tasks, nil> | fun(ses: imm.UI.Browser): imm.Browser.Tasks
--- @type imm.Browser.Tasks.C
local UIModSes = constructor(IUITasks)
return UIModSes
