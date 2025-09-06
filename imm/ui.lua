local ses
local ui = {}

-- Taken from balamod, modified
-- https://github.com/balamod/balamod_lua/blob/main/src/balamod_uidefs.lua
--- @param content balatro.UIElement.Definition[]
function ui.wrap(content, button, col)
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

function ui.browse_button()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.T, config = { text = "Browse", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true }
    }
end

function G.FUNCS.imm_browse()
    ses = ses or require("imm.uises")
    G.SETTINGS.paused = true
    local state = ses()
    G.FUNCS.overlay_menu({ definition = state:container() })
    state.uibox = G.OVERLAY_MENU
    state:prepare()
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, ui.wrap({ui.browse_button()}, 'imm_browse'))
    return r
end

return ui
