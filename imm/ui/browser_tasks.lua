local constructor = require("imm.lib.constructor")
local Queue = require("imm.lib.queue")
local co = require("imm.lib.co")
local logger = require("imm.logger")

local statusCounter = 0

--- @class imm.Browser.TaskStatus
--- @field containerCfg balatro.UIElement.Config
--- @field labelCfg balatro.UIElement.Config
--- @field textCfg balatro.UIElement.Config
local IUITaskStatus = {
    text = '',
    isDone = false
}

--- @protected
function IUITaskStatus:init()
    statusCounter = statusCounter + 1
    self.id = 'statuscounter-'..statusCounter
    self.containerCfg = { colout = G.C.CLEAR, id = self.id }
    self.labelCfg = { colour = G.C.WHITE, minw = 0.1 }
    self.textCfg = { ref_table = self, ref_value = 'text', padding = 0.05, scale = 1 }

    self.doneColor = G.C.GREEN
    self.errorColor = G.C.ORANGE
end

--- @param text string
function IUITaskStatus:status(text)
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

function IUITaskStatus:render()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = self.containerCfg,
        nodes = {
            { n = G.UIT.C, config = self.labelCfg },
            { n = G.UIT.T, config = self.textCfg }
        }
    }
end

--- @alias imm.Browser.TaskStatus.C p.Constructor<imm.Browser.TaskStatus, nil> | fun(): imm.Browser.TaskStatus
--- @type imm.Browser.TaskStatus.C
local UITaskStatus = constructor(IUITaskStatus)

--- @class imm.Browser.Tasks
local IUITasks = {}

--- @protected
--- @param ses imm.UI.Browser
function IUITasks:init(ses)
    self.queues = Queue()
    self.ses = ses
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
    local name = extra.name or 'something'
    local size = extra.size
    extra.blacklist = extra.blacklist or {}

    self.queues:queueCo()

    if extra.blacklist[url] then return end

    self.ses.taskText = string.format('Downloading %s (%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')
    logger.log(self.ses.taskText)

    local err, res = self.ses.repo.api.blob:fetchCo(url)
    if not res then
        err = err or 'unknown error'
        self.ses.taskText = string.format('Failed downloading %s: %s', name, err)
        if extra.cb then extra.cb(err) end
    else
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

    self.ses.errorText = table.concat(errlist, '\n')
    self.ses.taskText = #strlist ~= 0 and 'Installed '..table.concat(strlist, ', ') or 'Nothing is installed - Check that the zip has a valid metadata file'

    if not self.ses.noAutoDownloadMissing then
        for i, mod in ipairs(list) do
            self:downloadMissings(mod, blacklistState)
        end
    end

    return modlist, list, errlist
end

--- @alias imm.Browser.Tasks.C p.Constructor<imm.Browser.Tasks, nil> | fun(ses: imm.UI.Browser): imm.Browser.Tasks
--- @type imm.Browser.Tasks.C
local UIModSes = constructor(IUITasks)
return UIModSes
