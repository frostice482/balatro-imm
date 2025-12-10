local UICT = require("imm.ui.confirm_toggle")
local co = require("imm.lib.co")
local util = require("imm.lib.util")
local funcs = UICT.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.download] = function (elm)
    --- @type imm.UI.ConfirmToggle
    local r = elm.config.ref_table

    co.create(function ()
        local down = r.ses.tasks:createDownloadCoSes()

        r.ses:showOverlay(true)
        for id,entries in pairs(r.list.missingDeps) do
            down:downloadMissingModEntry(id, util.values(entries))
        end
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.confirm] = function (elm)
    --- @type imm.UI.ConfirmToggle
    local r = elm.config.ref_table

    for id, act in pairs(r.list.actions) do
        if not act.impossible then
            local mod = act.mod
            if act.action == 'enable' or act.action == 'switch' then
                assert(r.ctrl:enableMod(mod))
            elseif act.action == 'disable' then
                assert(r.ctrl:disableMod(mod))
            end
        end
    end

    if r.ses then
        r.ses.hasChanges = true
        r.ses:showOverlay(true)
    else
        G.FUNCS.exit_overlay_menu()
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.confirmOne] = function (elm)
    --- @type imm.UI.ConfirmToggle
    local r = elm.config.ref_table

    local ok, err = r.ses.ctrl:enableMod(r.mod)
    r.ses.tasks.status:update(nil, err)
    r.ses:showOverlay(true)
    if ok then r.ses.hasChanges = true end
end

return funcs