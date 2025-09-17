local constructor = require("imm.lib.constructor")
local UICT
local co = require("imm.lib.co")
local logger = require("imm.logger")
local ui = require("imm.lib.ui")

--- @class imm.Browser.Task.Update
--- @field newMods imm.Mod[]
--- @field status? imm.Browser.Task.UI.Status
local IUpdateCo = {
    allowNoReleaseUSeCommit = false,
    count = 0,
    done = 0,
    ignored = 0,
}

--- @protected
--- @param tasks imm.Browser.Tasks
function IUpdateCo:init(tasks)
    self.tasks = tasks
    self.down = tasks:createDownloadCoSes()
    self.ses = tasks.ses
    self.newMods = {}
end

function IUpdateCo:statusUpdate()
    if not self.status then return end
    self.status:update(string.format('Updating mods: %d/%d (%d new, %d error)', self.done, self.count, #self.down.modlist, #self.down.errors))
end

function IUpdateCo:statusDone()
    if not self.status then return end
    self.status:done(string.format('Done: %d/%d (%d new, %d error)', self.done, self.count, #self.down.modlist, #self.down.errors))
end

function IUpdateCo:statusAddDone()
    self.done = self.done + 1
    self:statusUpdate()
end

function IUpdateCo:statusAddIgnore()
    self.done = self.done + 1
    self.ignored = self.ignored + 1
    self:statusUpdate()
end

--- @param installed imm.Mod
--- @param latest imm.ModMeta.Release
function IUpdateCo:getModUpdate(installed, latest)
    -- does not have release info
    if not latest then
        return
    end
    -- have invalid release info
    if not latest.versionParsed then
        return logger.warn('Latest version of mod %s has invalid version %s, ignored', installed.mod, latest.version)
    end
    -- installed version is already latest
    if installed.versionParsed >= latest.versionParsed then
        return
    end
    return true
end

--- @async
--- @param installed imm.Mod
--- @param meta imm.ModMeta
function IUpdateCo:updateMod(installed, meta)
    --- @type imm.ModMeta.Release
    local latest
    local rel = meta:getReleasesCo()
    for i, v in ipairs(rel) do if not v.isPre then latest = v break end end

    if latest then
        if not self:getModUpdate(installed, latest) then return self:statusAddIgnore() end
    else
        if not (self.allowNoReleaseUSeCommit and meta.bmi) then return self:statusAddIgnore() end
        logger.warn('Mod %s does not have any release, using source')
        latest = { format = 'bmi', url = meta.bmi.download_url, version = 'Source' }
    end

    logger.fmt('log', 'Updating %s from %s to %s', meta:title(), installed.version, latest.version)
    self.down:download(latest.url, { name = meta:title()..' '..latest.version, size = latest.size })
    self:statusAddDone()
end

function IUpdateCo:enableAll()
    UICT = UICT or require("imm.ui.confirm_toggle")

    local ll = self.tasks.ses.ctrl:createLoadList()
    for i,v in ipairs(self.down.modlist) do
        if v.list.active then ll:tryEnable(v) end
    end

    if next(ll.actions) then
        local confirm = UICT(self.tasks.ses, ll)
        ui.overlay(confirm:render())
    end
end

--- @async
function IUpdateCo:updateAll()
    --self.ses.repo:clearList()
    self.ses.repo:clearReleases()
    self.status = self.tasks.status:new()

    local queues = {}
    for id, modlist in pairs(self.ses.ctrl.mods) do
        local meta = self.ses.repo.listMapped[id]
        local latest = modlist:list()[1]
        if latest and meta then
            self.count = self.count + 1
            table.insert(queues, function () return self:updateMod(latest, meta) end)
        end
    end

    self:statusUpdate()
    co.all(queues)
    self:statusDone()
    self:enableAll()
end

--- @alias imm.Browser.Task.Update.C p.Constructor<imm.Browser.Task.Update, nil> | fun(tasks: imm.Browser.Tasks): imm.Browser.Task.Update
--- @type imm.Browser.Task.Update.C
local UpdateCo = constructor(IUpdateCo)
return UpdateCo
