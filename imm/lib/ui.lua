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

--- @type balatro.UI.ButtonParam
local ui_def_yes = {
    col = true,
    padding = 0,
    label = {'Yes'},
}
--- @type balatro.UI.ButtonParam
local ui_def_no = {
    col = true,
    padding = 0,
    label = {'No'},
    colour = G.C.GREY,
}

--- @param button string
--- @param ref_table any
--- @param yesButton? balatro.UI.ButtonParam
--- @param noButton? balatro.UI.ButtonParam
function ui.yesno(button, ref_table, yesButton, noButton)
    yesButton = yesButton or {}
    setmetatable(yesButton, { __index = ui_def_yes })
    yesButton.button = button
    yesButton.ref_table = setmetatable({ confirm = true }, { __index = ref_table })

    noButton = noButton or {}
    setmetatable(noButton, { __index = ui_def_no })
    noButton.button = button
    noButton.ref_table = setmetatable({ confirm = false }, { __index = ref_table })

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'cm' },
        nodes = {
            UIBox_button(yesButton),
            UIBox_button(noButton)
        }
    }
end

--- Confirmation message. The button callback will receive an additional `confirm: boolean` property
--- @param contentColumns balatro.UIElement.Definition[]
--- @param button string
--- @param ref_table any
--- @param yesButton? balatro.UI.ButtonParam
--- @param noButton? balatro.UI.ButtonParam
function ui.confirm(contentColumns, button, ref_table, yesButton, noButton)
    return create_UIBox_generic_options({
        contents = {{
            n = G.UIT.C,
            nodes = {
                contentColumns,
                ui.yesno(button, ref_table, yesButton, noButton)
            }
        }}
    })
end

--- @param id string
--- @param row? boolean
--- @param nodes? balatro.UIElement.Definition[]
function ui.container(id, row, nodes)
    --- @type balatro.UIElement.Definition
    return {
        n = row and G.UIT.R or G.UIT.C,
        nodes = {{
            n = row and G.UIT.C or G.UIT.R,
            config = { id = id },
            nodes = nodes
        }}
    }
end

--- @param n number
function ui.cycleOptions(n)
    n = math.ceil(n)
    --- @type string[]
    local opts = {}
    for i=1, n, 1 do table.insert(opts, string.format('%d/%d', i, n)) end
    return  opts
end

--- @param elm balatro.Node
function ui.removeChildrens(elm)
    local keys = {}
    for k in pairs(elm.children) do table.insert(keys, k) end
    for i, k in ipairs(keys) do
        elm.children[k]:remove()
        elm.children[k] = nil
    end
end

return ui