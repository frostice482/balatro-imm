local UICT = require("imm.ui.confirm_toggle")
local a = require("imm.lib.assert")
local co = require("imm.lib.co")
local funcs = UICT.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.download] = function (elm)
    --- @type imm.UI.ConfirmToggle
    local r = elm.config.ref_table
    UICT:assertInstance(r, 'ref_table')

    co.create(function ()
        local down = r.ses.tasks:createDownloadCoSes()

        r.ses:showOverlay(true)
        for id,entries in pairs(r.list.missingDeps) do
            local rules = {}
            for mod, rule in pairs(entries) do table.insert(rules, rule) end
            down:downloadMissingModEntry(id, rules)
        end
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.confirm] = function (elm)
    --- @type imm.UI.ConfirmToggle
    local r = elm.config.ref_table
    UICT:assertInstance(r, 'ref_table')

    for id, act in pairs(r.list.actions) do
        if not act.impossible then
            local mod = act.mod
            if act.action == 'enable' or act.action == 'switch' then
                assert(r.ses.ctrl:enableMod(mod))
            elseif act.action == 'disable' then
                assert(r.ses.ctrl:disableMod(mod))
            end
        end
    end

    r.ses.hasChanges = true
    r.ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.confirmOne] = function (elm)
    --- @type imm.UI.ConfirmToggle
    local r = elm.config.ref_table
    UICT:assertInstance(r, 'ref_table')

    local ok, err = r.ses.ctrl:enableMod(r.mod)
    r.ses.tasks.status:update(nil, err)
    r.ses:showOverlay(true)
    if ok then r.ses.hasChanges = true end
end

return funcs