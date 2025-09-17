local constructor = require("imm.lib.constructor")
local logger = require("imm.logger")
local co = require("imm.lib.co")

--- @class imm.Browser.Task.Download.Co
--- @field blacklistUrls? table<string>
local IBTaskDownCo = {
    installMissings = true
}

--- @class imm.Brower.Task.Download.Extra
--- @field name? string
--- @field size? number

--- @protected
--- @param tasks imm.Browser.Tasks
function IBTaskDownCo:init(tasks)
    self.tasks = tasks
    self.ses = tasks.ses
    self.blacklistUrls = {}
end

--- @async
--- @param url string
--- @param extra? imm.Brower.Task.Download.Extra
--- @return string? err
function IBTaskDownCo:download(url, extra)
    extra = extra or {}
    local name = extra.name or 'something'
    local size = extra.size

    local done = self.tasks.queues:queueCo()

    if self.blacklistUrls[url] then return done() end
    self.blacklistUrls[url] = true

    local status = self.tasks.status:new()
    status:updatef('Downloading %s (%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')

    local err, res = self.ses.repo.api.blob:fetchCo(url)
    if not res then
        self.blacklistUrls[url] = false
        status:errorf('Failed downloading %s: %s', name, err)
        done()
    else
        status:done('')
        done()
        self:installModFromZip(love.data.newByteData(res))
    end

    return err
end

--- @async
--- @param id string
--- @param list imm.Dependency.Rule[][]
function IBTaskDownCo:downloadMissingModEntry(id, list)
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

    self:download(release.url, { name = mod:title()..' '..release.version, size = release.size })
end

--- @async
--- @param mod imm.Mod
function IBTaskDownCo:downloadMissings(mod)
    local missings = self.ses.ctrl:getMissingDeps(mod.deps)

    local queues = {}
    for missingid, missingList in pairs(missings) do
        logger.fmt('log', 'Missing dependency %s by %s', missingid, mod.mod)
        table.insert(queues, function () self:downloadMissingModEntry(missingid, missingList) end)
    end
    co.all(queues)
end

--- @async
--- @param data love.Data
function IBTaskDownCo:installModFromZip(data)
    local modlist, list, errlist = self.tasks:installModFromZip(data)

    if self.installMissings then
        local queues = {}
        for i, mod in ipairs(list) do table.insert(queues, function() self:downloadMissings(mod) end) end
        co.all(queues)
    end

    return modlist, list, errlist
end

--- @alias imm.Browser.Task.Download.Co.C p.Constructor<imm.Browser.Task.Download.Co, nil> | fun(tasks: imm.Browser.Tasks): imm.Browser.Task.Download.Co
--- @type imm.Browser.Task.Download.Co.C
local BTaskDownCo = constructor(IBTaskDownCo)
return  BTaskDownCo
