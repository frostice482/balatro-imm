local ui = require("imm.lib.ui")
local co = require("imm.lib.co")
local UIMod = require("imm.ui.mod")
local funcs = UIMod.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.openUrl] = function (elm)
    local r = elm.config.ref_table or {}
    love.system.openURL(r.url)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.releasesInit] = function(elm)
    --- @type imm.UI.Mod
    local modses = elm.config.ref_table
    UIMod:assertInstance(modses, 'ref_table')

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
    --- @type imm.UI.Mod
    local modses = elm.config.ref_table
    UIMod:assertInstance(modses, 'ref_table')

    local mod = modses.mod
    elm.config.func = nil

    co.create(function ()
        local releases = mod:getReleasesCo()
        ui.removeChildrens(elm)
        modses:updateOther(elm, releases)
    end)
end

return funcs