local ui = require("imm.lib.ui")
local Browser = require("imm.browser")

local function browse_button()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.T, config = { text = "Browse", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true }
    }
end

function G.FUNCS.imm_browse()
    G.SETTINGS.paused = true
    local state = Browser()
    G.FUNCS.overlay_menu({ definition = state:container() })
    state.uibox = G.OVERLAY_MENU
    state:prepare()
end

local o1 = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local r = o1()
    table.insert(r.nodes[2].nodes, 1, ui.wrap({browse_button()}, 'imm_browse'))
    return r
end

return ui
