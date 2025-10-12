local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")
local ui = require("imm.lib.ui")
local logger = require("imm.logger")
local imm = require("imm")
local UICT

--- @class imm.Task.Update
--- @field newMods imm.Mod[]
--- @field status? imm.Task.UI.Status
local IUpdateCo = {
    allowNoReleaseUseCommit = not imm.config.noUpdateUnreleasedMods,
    count = 0,
    done = 0,
    ignored = 0,
}

--- @protected
--- @param tasks imm.Tasks
function IUpdateCo:init(tasks)
    self.tasks = tasks
    self.down = tasks:createDownloadCoSes()
    self.down.allowNoReleaseUseCommit = false
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
        if not (self.allowNoReleaseUseCommit and meta.bmi) then return self:statusAddIgnore() end
        logger.fmt('warn', 'Mod %s does not have any release, using source', meta:id())
        latest = { format = 'bmi', url = meta.bmi.download_url, version = 'Source' }
    end

    logger.fmt('log', 'Updating %s from %s to %s', meta:title(), installed.version, latest.version)
    self.down:download(latest.url, { name = meta:title()..' '..latest.version, size = latest.size })
    self:statusAddDone()
end

function IUpdateCo:uiEnableAll()
    if not self.tasks.ses then return end

    UICT = UICT or require("imm.ui.confirm_toggle")

    local ll = self.tasks.ctrl:createLoadList()
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
    self.tasks.repo:clearReleases()
    self.status = self.tasks.status:new()

    local queues = {}
    for id, modlist in pairs(self.tasks.ctrl.mods) do
        local meta = self.tasks.repo.listMapped[id]
        local latest = modlist:list()[1]
        if latest and meta then
            self.count = self.count + 1
            table.insert(queues, function () return self:updateMod(latest, meta) end)
        end
    end

    self:statusUpdate()
    co.all(queues)
    self:statusDone()
    self:uiEnableAll()
end

--- @alias imm.Task.Update.C p.Constructor<imm.Task.Update, nil> | fun(tasks: imm.Tasks): imm.Task.Update
--- @type imm.Task.Update.C
local UpdateCo = constructor(IUpdateCo)
return UpdateCo
