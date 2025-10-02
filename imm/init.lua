local util = require("imm.lib.util")
local ui = require("imm.lib.ui")
local m = require('imm.config')

local updateConfig = false

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
            else logger.err('Postenable failed:', err or '?') end
        else
            logger.fmt('invalid nextEnable entry "%s"', entry)
        end
    end

    m.config.nextEnable = nil
    updateConfig = true
end

if not m.config.init then
    local ctrl = require('imm.modctrl')
    local hasOtherMod = false
    for i, list in ipairs(ctrl:list()) do
        if not list:isExcluded() then
            hasOtherMod = true
            break
        end
    end
    if not hasOtherMod then
        require("imm.welcome")
    else
        m.config.init = true
        updateConfig = true
    end
end

if updateConfig then
    _imm.saveconfig()
end

--- UI-related

local funcs = {
    restartConf = 'imm_s_restart_conf',
}

local exit_overlay = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function()
    local ses = G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm
    if not ses or not ses.hasChanges then return exit_overlay() end

    ui.overlay(G.UIDEF.imm_restart())
end

G.UIDEF.imm_restart = function()
    return ui.confirm( ui.TRS('Restart balatro now?', 0.6), funcs.restartConf, {} )
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

    local b = Browser()
    b:showOverlay(true)
    return b
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, wrap({browse_button()}, 'imm_browse'))
    return r
end
