local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")
local logger = require("imm.logger")

--- @class imm.Browser.Task.Download.Co
--- @field blacklistUrls? table<string>
--- @field modlist imm.Mod[]
--- @field errors string[]
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
    self.modlistSets = {}
    self.modlist = {}
    self.errors = {}
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
    local t = string.format('Downloading %s', name)
    if size then t = string.format('%s (%.1fMB)', t, size / 1048576) end
    status:update(t)

    local err, res = self.ses.repo.api.blob:fetchCo(url)
    if not res then
        self.blacklistUrls[url] = false
        local errfmt = string.format('Failed downloading %s: %s', name, err)
        status:error(errfmt)
        table.insert(self.errors, errfmt)
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
--- @param info imm.InstallResult
function IBTaskDownCo:handleInstallResult(info)
    if self.installMissings then
        local queues = {}
        for i, mod in ipairs(info.installed) do table.insert(queues, function() self:downloadMissings(mod) end) end
        co.all(queues)
    end

    for i,v in ipairs(info.installed) do table.insert(self.modlist, v) end
    for i,v in ipairs(info.errors) do table.insert(self.errors, v) end

    return info
end

--- @async
--- @param data love.Data
function IBTaskDownCo:installModFromZip(data)
    return self:handleInstallResult(self.tasks:installModFromZip(data))
end

---@async
---@param dir string
---@param sorucenfs boolean
function IBTaskDownCo:installModFromDir(dir, sorucenfs)
    return self:handleInstallResult(self.tasks:installModFromDir(dir, sorucenfs))
end

--- @alias imm.Browser.Task.Download.Co.C p.Constructor<imm.Browser.Task.Download.Co, nil> | fun(tasks: imm.Browser.Tasks): imm.Browser.Task.Download.Co
--- @type imm.Browser.Task.Download.Co.C
local BTaskDownCo = constructor(IBTaskDownCo)
return  BTaskDownCo
