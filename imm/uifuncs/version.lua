local a = require("imm.lib.assert")
local ConfirmToggle = require('imm.ui.confirm_toggle')
local UIVerDel = require('imm.ui.version_delete')
local UIVersion = require("imm.ui.version")
local ui        = require("imm.lib.ui")
local funcs = UIVersion.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.download] = function(elm)
    --- @type imm.UI.Version
    local r = elm.config.ref_table
    UIVersion:assertInstance(r, 'ref_table')

    if not r.opts.downloadUrl then return end

    r.ses:queueTaskInstall(r.opts.downloadUrl, {
        name = r.mod..' '..r.ver,
        size = r.opts.downloadSize,
        cb = function (err) if not err then r.ses:updateSelectedMod(r.ses.repo.listMapped[r.mod]) end end
    })
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.delete] = function(elm)
    --- @type imm.UI.Version
    local r = elm.config.ref_table
    UIVersion:assertInstance(r, 'ref_table')

    ui.overlay(UIVerDel(r.ses, r.mod, r.ver):render())
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.toggle] = function(elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Version, boolean
    local modses, enabled = r.ses, r.toggle
    UIVersion:assertInstance(modses, 'r.ses')
    a.type(enabled, 'r.toggle', 'boolean')

    local ses = modses.ses
    local modid = modses.mod
    local ver = modses.ver

    local mod = ses.ctrl:getMod(modid, ver)
    if not mod then
        ses.errorText = string.format("Cannot find %s %s", modid, ver)
        return
    end

    local test = enabled and ses.ctrl:tryDisable(mod) or ses.ctrl:tryEnable(mod)

    local c = 0
    local hasErr
    hasErr = not not next(test.missingDeps)
    for k,act in pairs(test.actions) do
        c = c + 1
        hasErr = hasErr or act.impossible
    end

    if c <= 1 and not hasErr then
        local ok, err
        if enabled then ok, err = ses.ctrl:disable(modid)
        else ok, err = ses.ctrl:enable(modid, ver)
        end

        ses.errorText = err or ''
        ses:updateSelectedMod()
        if ok then ses.hasChanges = true end
    else
        ui.overlay(ConfirmToggle(ses, test, mod, enabled):render())
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.deleteConfirm] = function(elm)
    local r = elm.config.ref_table or {}

    --- @type imm.UI.VerDel
    local modses = r.ses
    UIVerDel:assertInstance(modses, 'r.ses')

    local ses = modses.ses

    if r.confirm then
        local ok, err = ses.ctrl:uninstall(modses.mod, modses.ver)
        ses.errorText = err or ''
        if ok then ses.hasChanges = true end
    end

    ses:showOverlay(true)
end

return funcs