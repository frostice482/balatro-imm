local util = require("imm.lib.util")
local ui = require("imm.lib.ui")

require("imm.init.config")

package.preload['imm.tasks'] = function () return require("imm.btasks.tasks")() end
package.preload['imm.repo'] = function () return require("imm.modrepo.repo")() end
package.preload['imm.modpacks'] = function ()
    local mp = require("imm.mp.list")()
    mp:loadAll()
    return mp
end

local funcs = {
    restartConf = 'imm_s_restart_conf',
    browse = 'imm_browse',
    modpacks = 'imm_modpacks',
    restart = 'imm_restart',
}

--- @class balatro.Functions.Uidef
--- @field imm_restart fun(): balatro.UIElement.Definition

--- @param text string
--- @param button string
--- @param col? boolean
local function wrap(text, button, col)
    --- @type balatro.UIElement.Definition
    return {
        n = col and G.UIT.C or G.UIT.R, config = { align = "cm", padding = 0.2, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK },
        nodes = {{
            n = G.UIT.R,
            config = { align = "cm", padding = 0.15, r = 0.1, hover = true, colour = G.C.PURPLE, shadow = true, button = button },
            nodes = {{
                n = G.UIT.T, config = { text = text, scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true }
            }}
        }}
    }
end

local exit_overlay = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function()
    local c = G.OVERLAY_MENU and G.OVERLAY_MENU.config
    if not c then return exit_overlay() end

    if c.imm then
        c.imm.repo.bmi.imageCache = {}
        c.imm.repo.ts.imageCache = {}

        if c.imm.hasChanges then
            return ui.overlay(G.UIDEF[funcs.restart]())
        end
    elseif c.imm_mplist then
        for k,v in pairs(c.imm_mplist.modpacks.modpacks) do
            v.icon = nil
        end
        if c.imm_mplist.hasChanges then
            return ui.overlay(G.UIDEF[funcs.restart]())
        end
    end

    return exit_overlay()
end

G.UIDEF[funcs.restart] = function()
    return ui.confirm(
        ui.TRS('Restart balatro now?', 0.6, nil, { align = 'cm' }),
        funcs.restartConf,
        {}
    )
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.restartConf] = function(elm)
    if not elm.config.ref_table.confirm then return G.FUNCS.exit_overlay_menu() end
    util.restart()
end

local Browser, MP

G.FUNCS[funcs.browse] = function()
    require('imm.ui.init_funcs')
    Browser = Browser or require("imm.ui.browser")

    local b = Browser()
    b:showOverlay(true)
    return b
end

G.FUNCS[funcs.modpacks] = function()
    require('imm.mpui.init_funcs')
    MP = MP or require("imm.mpui.list")

    local b = MP()
    b:showOverlay()
    return b
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, wrap("Modpacks", funcs.modpacks))
    table.insert(r.nodes[2].nodes, 1, wrap("Browse", funcs.browse))
    return r
end
