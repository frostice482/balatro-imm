local constructor = require("imm.lib.constructor")
local logger = require("imm.logger")
local co = require("imm.lib.co")

--- @class imm.Browser.Task.Download
--- @field blacklistUrls? table<string>
local IBTaskDown = {}

--- @class imm.ModSession.QueueDownloadExtraInfo
--- @field name? string
--- @field size? number

--- @protected
--- @param tasks imm.Browser.Tasks
function IBTaskDown:init(tasks)
    self.tasks = tasks
    self.ses = tasks.ses
    self.blacklistUrls = {}
end

--- @protected
--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function IBTaskDown:downloadCo(url, extra)
    extra = extra or {}
    local name = extra.name or 'something'
    local size = extra.size

    self.tasks.queues:queueCo()

    if self.blacklistUrls[url] then
        self.tasks.queues:next()
        return
    end

    local status = self.tasks.status:new()
    status:updatef('Downloading %s (%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')

    local err, res = self.ses.repo.api.blob:fetchCo(url)
    if not res then
        status:errorf('Failed downloading %s: %s', name, err)
    else
        status:done('')
        self.blacklistUrls[url] = true
        self:installModFromZip(love.data.newByteData(res))
    end

    self.tasks.queues:next()
    return err
end

--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function IBTaskDown:download(url, extra)
    co.create(self.downloadCo, self, url, extra)
end

--- @protected
--- @param id string
--- @param list imm.Dependency.Rule[][]
function IBTaskDown:_downloadMissingModEntryCo(id, list)
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

    self:downloadCo(release.url, { name = mod:title()..' '..release.version, size = release.size })
end

--- @param id string
--- @param list imm.Dependency.Rule[][]
function IBTaskDown:downloadMissingEntry(id, list)
    co.create(self._downloadMissingModEntryCo, self, id, list)
end

--- @param mod imm.Mod
function IBTaskDown:downloadMissings(mod)
    local missings = self.ses.ctrl:getMissingDeps(mod.deps)
    for missingid, missingList in pairs(missings) do
        logger.fmt('log', 'Missing dependency %s by %s', missingid, mod.mod)
        self:downloadMissingEntry(missingid, missingList)
    end
end

--- @param data love.Data
function IBTaskDown:installModFromZip(data)
    local modlist, list, errlist = self.tasks:installModFromZip(data)
    for i, mod in ipairs(list) do self:downloadMissings(mod) end
end

--- @alias imm.Browser.Task.Download.C p.Constructor<imm.Browser.Task.Download, nil> | fun(tasks: imm.Browser.Tasks): imm.Browser.Task.Download
--- @type imm.Browser.Task.Download.C
local BTaskDown = constructor(IBTaskDown)
return  BTaskDown
