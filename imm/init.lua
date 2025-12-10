local util = require("imm.lib.util")
local ui = require("imm.lib.ui")

package.preload['imm.tasks'] = function () return require("imm.btasks.tasks")() end
package.preload['imm.repo'] = function () return require("imm.modrepo.repo")() end

local funcs = {
    restartConf = 'imm_s_restart_conf',
    browse = 'imm_browse',
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
    local ses = G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm
    if not ses or not ses.hasChanges then return exit_overlay() end

    ui.overlay(G.UIDEF.imm_restart())
end

G.UIDEF[funcs.restart] = function()
    return ui.confirm( ui.TRS('Restart balatro now?', 0.6), funcs.restartConf, {} )
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.restartConf] = function(elm)
    if not elm.config.ref_table.confirm then return G.FUNCS.exit_overlay_menu() end
    util.restart()
end

local Browser

G.FUNCS[funcs.browse] = function()
    require('imm.ui.init_funcs')
    Browser = Browser or require("imm.ui.browser")

    local b = Browser()
    b:showOverlay(true)
    return b
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, wrap("Browse", funcs.browse))
    return r
end
