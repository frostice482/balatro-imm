local UICT = require('imm.ui.confirm_toggle')
local UIVersion = require("imm.ui.version")
local ui = require("imm.lib.ui")
local co = require("imm.lib.co")
local funcs = UIVersion.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.download] = function(elm)
    --- @type imm.UI.Version
    local r = elm.config.ref_table
    if not r.opts.downloadUrl then return end

    co.create(function ()
        local res = r.ses.tasks:createDownloadCoSes():download(r.opts.downloadUrl, {
            name = r.mod..' '..r.ver,
            size = r.opts.downloadSize,
        })
        if not res then
            r.ses:updateSelectedMod(r.mod)
        end
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.delete] = function(elm)
    --- @type imm.UI.Version
    local r = elm.config.ref_table
    local mod = r:getMod()

    ui.overlay(
        ui.confirm(
            ui.TRS(string.format('Really delete %s %s?', mod.name, mod.version), 0.6, nil, { align = 'cm' }),
            UIVersion.funcs.deleteConfirm,
            { ses = r }
        )
    )
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.toggle] = function(elm)
    --- @type table
    local r = elm.config.ref_table
    --- @type imm.UI.Version, boolean
    local modses, enabled = r.ses, r.toggle

    local ses = modses.ses
    local modid = modses.mod
    local ver = modses.ver

    local mod = ses.ctrl:getMod(modid, ver)
    if not mod then
        ses.tasks.status:update(nil, string.format("Cannot find %s %s", modid, ver))
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

        ses.tasks.status:update(nil, err)
        modses:rerender()
        if ok then ses.hasChanges = true end
    else
        UICT(test, { ses = ses, mod = mod, isDisable = enabled }):showOverlay()
    end
end

G.FUNCS[funcs.lock] = function (elm)
    --- @type table
    local t = elm.config.ref_table
    --- @type imm.UI.Version, boolean
    local ver, locked = t.ver, t.locked
    local ses = ver.ses

    local m = ver:getMod()
    local ok, err = false, 'mod not found'
    if m and not locked then ok, err = m:lock() end
    if m and locked then ok, err = m:unlock() end

    ses.tasks.status:update(nil, err)
    ver:rerender()
end

G.FUNCS[funcs.hide] = function (elm)
    --- @type table
    local t = elm.config.ref_table
    --- @type imm.UI.Version, boolean
    local ver, hidden = t.ver, t.hidden
    local ses = ver.ses

    local m = ver:getMod()
    local ok, err = false, 'mod not found'
    if m and not hidden then ok, err = m:hide() end
    if m and hidden then ok, err = m:unhide() end

    ses.tasks.status:update(nil, err)
    ver:rerender()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.deleteConfirm] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.UI.Version
    local modses = r.ses

    local ses = modses.ses

    if r.confirm then
        local ok, err = ses.ctrl:uninstall(modses.mod, modses.ver)
        ses.tasks.status:update(nil, err)
    end

    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.init] = function(elm)
    elm.config.func = nil
    elm.config.ref_table.uie = elm
end

return funcs