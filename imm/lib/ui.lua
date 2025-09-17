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

--- @param elm balatro.UIElement
function ui.removeElement(elm)
    elm:remove()

    if not elm.parent then return end

    local i = get_index(elm.parent.children, elm)

    if not i then error('unknown child -> parent -> child') end
    table.remove(elm.parent.children, i)
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

--- @param rowSize number
--- @param colSize number
--- @param list balatro.UIElement.Definition[][]
--- @param firstRow? boolean
function ui.gapGrid(rowSize, colSize, list, firstRow)
    --- @type balatro.UIElement.Definition[]
    local gappedInside = {}
    for i,sublist in ipairs(list) do
        local nodes = firstRow and ui.gapList('C', colSize, sublist) or ui.gapList('R', rowSize, sublist)
        table.insert(gappedInside, { n = firstRow and G.UIT.R or G.UIT.C, nodes = nodes })
    end
    local g = firstRow and ui.gapList('R', rowSize, gappedInside) or ui.gapList('C', colSize, gappedInside)
    return g
end

--- @alias imm.UI.ConfigMix balatro.UIElement.Config | balatro.UIElement.Definition[] | { nodes?: balatro.UIElement.Definition[] }

--- @param config? imm.UI.ConfigMix
--- @param inherits? balatro.UIElement.Config
--- @param type number
function ui._T(config, inherits, type)
    config = config or {}
    if inherits then setmetatable(config, { __index = inherits }) end

    local nodes = {}
    if config.nodes then
        nodes = config.nodes
        config.nodes = nil
    else
        for i,v in ipairs(config) do
            nodes[i] = v
            config[i] = nil
        end
    end

    --- @type balatro.UIElement.Definition
    return { n = type, config = config, nodes = nodes }
end

--- @param config? imm.UI.ConfigMix
--- @param inherits? balatro.UIElement.Config
function ui.R(config, inherits)
    return ui._T(config, inherits, G.UIT.R)
end

--- @param config? imm.UI.ConfigMix
--- @param inherits? balatro.UIElement.Config
function ui.ROOT(config, inherits)
    config = config or {}
    config.colour = config.colour or G.C.CLEAR
    return ui._T(config, inherits, G.UIT.ROOT)
end

--- @param config? imm.UI.ConfigMix
--- @param inherits? balatro.UIElement.Config
function ui.C(config, inherits)
    return ui._T(config, inherits, G.UIT.C)
end

--- Text
--- @param text string
--- @param config? balatro.UIElement.Config
function ui.T(text, config)
    config = config or {}
    config.text = text
    config.scale = config.scale or 1
    return { n = G.UIT.T, config = config }
end

--- Simple text
--- @param text string
--- @param scale? number
--- @param color? ColorHex
--- @param config? balatro.UIElement.Config
function ui.TS(text, scale, color, config)
    config = config or {}
    config.text = text
    config.scale = scale or 1
    config.colour = color
    return { n = G.UIT.T, config = config }
end

--- Text with config
--- @param conf balatro.UIElement.Config
function ui.TC(conf)
    return { n = G.UIT.T, config = conf }
end

--- Text with reftable
--- @param reftable any
--- @param refvalue any
--- @param config? balatro.UIElement.Config
function ui.TRef(reftable, refvalue, config)
    config = config or {}
    config.ref_table = reftable
    config.ref_value = refvalue
    config.scale = config.scale or 1
    return { n = G.UIT.T, config = config }
end

--- Object
--- @param obj balatro.Moveable
--- @param config? balatro.UIElement.Config
function ui.O(obj, config)
    config = config or {}
    config.object = obj
    return { n = G.UIT.O, config = config }
end

--- Simple Row text
--- @param text string
--- @param scale? number
--- @param color? ColorHex
function ui.TRS(text, scale, color)
    return ui.R({ui.TS(text, scale, color)})
end

--- @param uibox balatro.UIBox
--- @param definition balatro.UIElement.Definition
function ui.changeRoot(uibox, definition)
    uibox.UIRoot:remove()
    uibox:set_parent_child(definition)
    uibox:recalculate()
end

function ui.boxContainer()
    return UIBox({ definition = { n = G.UIT.ROOT }, config = {} })
end

--- @param def balatro.UIElement.Definition
function ui.overlay(def)
    G.FUNCS.overlay_menu({definition = def})
end

return ui