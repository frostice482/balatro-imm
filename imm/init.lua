local util = require("imm.lib.util")
local ui = require("imm.lib.ui")
local m = require('imm.config')

--- Processing configs

if m.config.nextEnable then
    local ctrl = require('imm.modctrl')
    local logger = require('imm.logger')

    local mods = util.strsplit(m.config.nextEnable, '%s*==%s*')
    for i,entry in ipairs(mods) do
        local mod, ver = entry:match('^([^=]+)=(.*)')
        if mod and ver then
            local ok, err = ctrl:enable(mod, ver)
            if ok then logger.log('Postenabled:', mod, ver)
            else logger.err('Failed postenable:', err or '?') end
        end
    end

    m.config.nextEnable = nil
    util.saveconfig()
end

--- UI-related

local funcs = {
    restartConf = 'imm_s_restart_conf',
}

local exit_overlay = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function()
    local ses = G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm
    if not ses or not ses.hasChanges then return exit_overlay() end

    ui.overlay(
        ui.confirm(
            ui.TRS('Restart balatro now?', 0.6),
            funcs.restartConf,
            {}
        )
    )
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.restartConf] = function(elm)
    if not elm.config.ref_table.confirm then return G.FUNCS.exit_overlay_menu() end
    util.restart()
end

-- Taken from balamod, modified
-- https://github.com/balamod/balamod_lua/blob/main/src/balamod_uidefs.lua
--- @param content balatro.UIElement.Definition[]
--- @param button string
--- @param col? boolean
local function wrap(content, button, col)
    --- @type balatro.UIElement.Definition
    return {
        n = col and G.UIT.C or G.UIT.R, config = { align = "cm", padding = 0.2, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK },
        nodes = {{
            n = G.UIT.R,
            config = { align = "cm", padding = 0.15, r = 0.1, hover = true, colour = G.C.PURPLE, shadow = true, button = button },
            nodes = content
        }}
    }
end

local function browse_button()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.T, config = { text = "Browse", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true }
    }
end

function G.FUNCS.imm_browse()
    require('imm.init_ui')
    Browser = Browser or require("imm.ui.browser")
    G.SETTINGS.paused = true
    Browser():showOverlay(true)
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, wrap({browse_button()}, 'imm_browse'))
    return r
end

--- @type p.Assert.Schema
local def = {
    type = 'table',
    props = {
        n = { type = 'number' },
        nodes = {
            type = {'table', 'nil'},
            isArray = true
        }
    }
}
def.props.nodes.restProps = def

--[[
local a = UIBox.set_parent_child
function UIBox.set_parent_child(s, n, p)
    require('imm.lib.assert').schema(n, 'n', def)
    a(s, n, p)
end
]]