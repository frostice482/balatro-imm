local a = require("imm.lib.assert")
local util = require("imm.lib.util")
local ui = require("imm.lib.ui")
local ModMeta = require("imm.lib.modrepo.meta")
local UIBrowser = require("imm.ui.browser")
local UIOpts = require("imm.ui.options")
local funcs = UIBrowser.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.back] = function(elm)
    --- @type imm.UI.Browser
    local e = elm.config.ref_table
    UIBrowser:assertInstance(e, 'ref_table')

    e:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.setCategory] = function(elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Browser, string
    local ses, cat = r.ses, r.cat
    UIBrowser:assertInstance(ses, 'r.ses')
    a.type(cat, 'r.cat', 'string')

    ses.tags[cat] = not ses.tags[cat]
    elm.config.colour = ses.tags[cat] and G.C.ORANGE or G.C.RED
    ses:queueUpdate()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.update] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    if ses.prevSearch ~= ses.search then
        ses.prevSearch = ses.search
        ses:queueUpdate()
    end
end

--- @param elm balatro.UI.CycleCallbackParam
G.FUNCS[funcs.cyclePage] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.cycle_config._ses
    UIBrowser:assertInstance(ses, 'cycle_config._ses')

    ses.listPage = elm.to_key
    ses:updateMods()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.chooseMod] = function(elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Browser, imm.ModMeta
    local ses, mod = r.ses, r.mod
    UIBrowser:assertInstance(ses, 'r.ses')
    ModMeta:assertInstance(mod, 'r.mod')

    ses:selectMod(mod)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.refresh] = function(elm)
    util.rmdir('immcache', false)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    ses.repo:clear()
    ses.prepared = false
    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.options] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    ui.overlay(UIOpts(ses):render())
end

return funcs