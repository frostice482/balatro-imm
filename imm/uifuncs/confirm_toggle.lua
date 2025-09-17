local a = require("imm.lib.assert")
local UIBrowser = require("imm.ui.browser")
local LoadList = require("imm.lib.mod.loadlist")
local Mod = require("imm.lib.mod.mod")
local UICT = require("imm.ui.confirm_toggle")
local funcs = UICT.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.download] = function (elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Browser, imm.LoadList
    local ses, list = r.ses, r.list
    UIBrowser:assertInstance(ses, 'r.ses')
    LoadList:assertInstance(list, 'r.list')

    local down = ses.tasks:createDownloadSes()

    ses:showOverlay(true)
    for id,entries in pairs(list.missingDeps) do
        local rules = {}
        for mod, rule in pairs(entries) do table.insert(rules, rule) end
        down:downloadMissingEntry(id, rules)
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.confirm] = function (elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Browser, imm.LoadList
    local ses, list = r.ses, r.list
    UIBrowser:assertInstance(ses, 'r.ses')
    LoadList:assertInstance(list, 'r.list')

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

--- @param elm balatro.UIElement
G.FUNCS[funcs.confirmOne] = function (elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Browser, imm.Mod
    local ses, mod = r.ses, r.mod
    UIBrowser:assertInstance(ses, 'r.ses')
    Mod:assertInstance(mod, 'r.mod')

    local ok, err = ses.ctrl:enableMod(mod)
    ses.tasks.status:update(nil, err)
    ses:showOverlay(true)
    if ok then ses.hasChanges = true end
end

return funcs