local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")
local logger = require("imm.logger")

--- @class imm.Browser.Task.Update
local IUpdateCo = {}

--- @protected
--- @param tasks imm.Browser.Tasks
function IUpdateCo:init(tasks)
    self.tasks = tasks
    self.down = tasks:createDownloadCoSes()
    self.ses = tasks.ses
end

--- @param installed imm.Mod
--- @param meta imm.ModMeta
function IUpdateCo:getModUpdate(installed, meta)
    local rel = meta:getReleasesCached()
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
    if installed.versionParsed >= latest.versionParsed then
        return
    end

    return latest
end

--- @async
--- @param installed imm.Mod
--- @param meta imm.ModMeta
function IUpdateCo:updateMod(installed, meta)
    meta:getReleasesCo()

    local release = self:getModUpdate(installed, meta)
    if not release then return end

    logger.fmt('Updating %s from %s to %s', meta:title(), installed.version, release.version)

    self.down:download(release.url, {
        name = meta:title()..' '..release.version,
        size = release.size
    })
end

--- @async
function IUpdateCo:updateAll()
    local s = self.tasks.status:new()
    s:update('Updating all mods')

    local queues = {}
    for id, modlist in pairs(self.ses.ctrl.mods) do
        local meta = self.ses.repo.listMapped[id]
        local latest = modlist:list()[1]
        if latest and meta then
            table.insert(queues, function () return self:updateMod(latest, meta) end)
        end
    end
    co.all(queues)

    s:done('All mods updated')
end

--- @alias imm.Browser.Task.Update.C p.Constructor<imm.Browser.Task.Update, nil> | fun(tasks: imm.Browser.Tasks): imm.Browser.Task.Update
--- @type imm.Browser.Task.Update.C
local UpdateCo = constructor(IUpdateCo)
return UpdateCo
