local ui = require("imm.lib.ui")
local di

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
    di = di or require('imm.dropinstall')
    Browser = Browser or require("imm.lib.browser")

    G.SETTINGS.paused = true
    Browser():showOverlay(true)
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, wrap({browse_button()}, 'imm_browse'))
    return r
end

return ui
