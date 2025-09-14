local ui = require("imm.lib.ui")
local co = require("imm.lib.co")

--- @class imm.ModBrowser.Funcs
local funcs = {
    v_deleteConfirm       = 'imm_ms_delete_confirm',
    v_delete              = 'imm_ms_delete',
    v_download            = 'imm_ms_download',
    v_toggle              = 'imm_ms_toggle',
    vt_confirm            = 'imm_ms_t_confirm',
    vt_confirmOne         = 'imm_ms_t_confirm_one',
    vt_download           = 'imm_ms_t_download',
    openUrl               = 'imm_ms_openurl',
    releasesInit          = 'imm_ms_releases_init',
    otherInit             = 'imm_ms_other_init'
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.openUrl] = function (elm)
    local r = elm.config.ref_table or {}
    love.system.openURL(r.url)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.releasesInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local mod = modses.mod
    elm.config.func = nil

    co.create(function ()
        local releases = mod:getReleasesCo()
        ui.removeChildrens(elm)
        modses:updateReleases(elm, releases)
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.otherInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local mod = modses.mod
    elm.config.func = nil

    co.create(function ()
        local releases = mod:getReleasesCo()
        ui.removeChildrens(elm)
        modses:updateOther(elm, releases)
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_download] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser, string, string?, number?
    local modses, ver, url, size = r.ses, r.ver, r.durl, r.dsize

    if not url then return end

    modses.ses:queueTaskInstall(url, {
        name = modses.mod:title()..' '..ver,
        size = size,
        cb = function (err) if not err then modses.ses:updateSelectedMod(modses.mod) end end
    })
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_delete] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser, string
    local modses, ver = r.ses, r.ver

    G.FUNCS.overlay_menu({ definition = modses:uiDeleteVersion(ver) })
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_toggle] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser, string, boolean
    local modses, ver, enabled = r.ses, r.ver, r.toggle
    local ses = modses.ses
    local modid = modses.mod:id()

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
        ses:updateSelectedMod(modses.mod)
        if ok then ses.hasChanges = true end
    else
        G.FUNCS.overlay_menu({definition = modses:uiConfirmModify(test, mod, enabled)})
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_deleteConfirm] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser
    local modses = r.ses
    local ses = modses.ses

    if r.confirm then
        local ok, err = ses.ctrl:uninstall(modses.mod:id(), r.ver)
        ses.errorText = err or ''
        if ok then ses.hasChanges = true end
    end

    ses:showOverlay(true)
end

G.FUNCS[funcs.vt_download] = function (elm)
    local r = elm.config.ref_table
    --- @type imm.Browser, imm.LoadList
    local ses, list = r.ses, r.list

    ses:showOverlay(true)
    for id,entries in pairs(list.missingDeps) do
        local rules = {}
        for mod, rule in pairs(entries) do table.insert(rules, rule) end
        ses:installMissingModEntry(id, rules)
    end
end

G.FUNCS[funcs.vt_confirm] = function (elm)
    local r = elm.config.ref_table
    --- @type imm.Browser, imm.LoadList
    local ses, list = r.ses, r.list

    for id, act in pairs(list.actions) do
        if not act.impossible then
            local mod = act.mod
            if act.action == 'enable' or act.action == 'switch' then
                assert(ses.ctrl:enableMod(mod))
            elseif act.action == 'disable' then
                assert(ses.ctrl:disableMod(mod))
            end
        end
    end

    ses.hasChanges = true
    ses:showOverlay(true)
end

G.FUNCS[funcs.vt_confirmOne] = function (elm)
    local r = elm.config.ref_table
    --- @type imm.Browser, imm.Mod
    local ses, mod = r.ses, r.mod

    local ok, err = ses.ctrl:enableMod(mod)
    ses.errorText = err or ''
    ses:showOverlay(true)
    if ok then ses.hasChanges = true end
end

return funcs