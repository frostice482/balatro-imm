local funcs = {
    cycle = 'imm_cycle',
    cycleInit = 'imm_cycle_init'
}

local ui = {
    funcs = funcs
}

--- @type balatro.UI.ButtonParam
local ui_def_yes = {
    col = true,
    padding = 0,
    label = {'Yes'},
    colour = G.C.RED,
}
--- @type balatro.UI.ButtonParam
local ui_def_no = {
    col = true,
    padding = 0,
    label = {'No'},
    colour = G.C.GREY,
}

--- @param ev balatro.UI.CycleCallbackParam
G.FUNCS[funcs.cycle] = function (ev)
    --- @type imm.UI.CycleOptions
    local opts = ev.cycle_config.extra
    local uibox = opts.uibox or opts.elm.UIBox

    ui.removeChildrens(opts.elm)

    local off = (ev.to_key - 1) * opts.pagesize
    for i=1, opts.pagesize, 1 do
        local elm = opts.func(i+off)
        if elm then uibox:add_child(elm, opts.elm) end
    end

    uibox:recalculate()
    if opts.onCycle then opts.onCycle(ev.to_key) end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.cycleInit] = function (elm)
    local r = elm.config.ref_table or {}
    elm.config.func = nil
    elm.config.ref_table = r.table

    local opts = r.opts
    opts.elm = elm.UIBox:get_UIE_by_ID(opts.id)
    if not opts.noImmediate then
        G.FUNCS[funcs.cycle]({
            cycle_config = { extra = opts },
            to_key = opts.currentPage or 1
        })
    end
end

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
        config = { align = 'cm', padding = 0.2 },
        nodes = {
            UIBox_button(yesButton),
            UIBox_button(noButton)
        }
    }
end

--- Confirmation message. The button callback will receive an additional `confirm: boolean` property
--- @param contentColumn balatro.UIElement.Definition
--- @param button string
--- @param ref_table any
--- @param yesButton? balatro.UI.ButtonParam
--- @param noButton? balatro.UI.ButtonParam
function ui.confirm(contentColumn, button, ref_table, yesButton, noButton)
    return create_UIBox_generic_options({
        contents = {{
            n = G.UIT.C,
            nodes = {
                contentColumn,
                ui.yesno(button, ref_table, yesButton, noButton)
            }
        }},
        no_back = true
    })
end

--- @param id? string
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

--- @param mode 'R' | 'C'
--- @param size number
function ui.gap(mode, size)
    --- @type balatro.UIElement.Definition
    return {
        n = mode == 'R' and G.UIT.R or G.UIT.C,
        config = {
            minw = mode == 'C' and size or nil,
            minh = mode == 'R' and size or nil
        }
    }
end

--- @class imm.UI.CycleOptions
--- @field func fun(i: number): balatro.UIElement.Definition?
--- @field length number
--- @field pagesize number
--- @field currentPage? number
--- @field noImmediate? boolean
--- @field onCycle? fun(page: number)
--- @field id string
--- @field elm? balatro.UIElement
--- @field uibox? balatro.UIBox

--- @param opts imm.UI.CycleOptions
--- @param cycleOpts? balatro.UI.OptionCycleParam
function ui.cycle(opts, cycleOpts)
    --- @type balatro.UI.OptionCycleParam
    local overopts = {
        options = ui.cycleOptions(opts.length / opts.pagesize),
        current_option = 1,
        opt_callback = funcs.cycle,
        extra = opts
    }
    setmetatable(overopts, { __index = cycleOpts })

    local elm = create_option_cycle(overopts)
    elm.config.ref_table = {
        opts = opts,
        table = elm.config.ref_table
    }
    elm.config.func = funcs.cycleInit
    return elm
end

--- @param mode 'R' | 'C'
--- @param size number
--- @param list balatro.UIElement.Definition[]
function ui.gapList(mode, size, list)
    local gapElm = ui.gap(mode, size)
    --- @type balatro.UIElement.Definition[]
    local gapped = {}
    for i, elm in ipairs(list) do
        if i ~= 1 then table.insert(gapped, gapElm) end
        table.insert(gapped, elm)
    end
    return gapped
end

--- @param text string
--- @param scale? number
--- @param color? ColorHex
function ui.simpleTextRow(text, scale, color)
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.R, nodes = {{ n = G.UIT.T, config = { text = text, scale = scale or 1, colour = color or G.C.UI.TEXT_LIGHT } }} }
end

return ui