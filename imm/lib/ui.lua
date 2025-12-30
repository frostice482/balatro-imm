local util = require("imm.lib.util")

local funcs = {
    cycle = 'imm_cycle',
    cycleInit = 'imm_cycle_init',
    inputUpdate = 'imm_text_input_update'
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
    local page = ev.to_key

    opts.currentPage = page

    ui.removeChildrens(opts.elm)

    local off = (page - 1) * opts.pagesize
    for i=1, opts.pagesize, 1 do
        local elm = opts.func(i+off)
        if elm then uibox:add_child(elm, opts.elm) end
    end

    uibox:recalculate()
    if opts.onCycle then opts.onCycle(page) end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.cycleInit] = function (elm)
    local r = elm.config.ref_table or {}
    elm.config.func = nil
    elm.config.ref_table = r.table

    --- @type imm.UI.CycleOptions
    local opts = r.opts
    opts.elm = elm.UIBox:get_UIE_by_ID(opts.id)
    opts.elmc = elm
    if not opts.noImmediate then
        ui.cycleExec(opts, opts.currentPage or 1)
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.inputUpdate] = function (elm)
    --- @type imm.UI.TextInputState
    local r = elm.config.ref_table or {}
    if r.val == r.prev then return end

    if r.opts.onChange then r.opts.onChange(r.val) end
    r.sleeper(r.opts.delay or 0.3)
    r.prev = r.val
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
                ui.R{padding = 0.2},
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
        config = {},
        nodes = {{
            n = row and G.UIT.C or G.UIT.R,
            config = { id = id },
            nodes = nodes
        }}
    }
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
    if elm.REMOVED then return end
    elm:remove()
    if not elm.parent then return end

    local i = get_index(elm.parent.children, elm)
    if not i then error('unknown child -> parent -> child') end
    table.remove(elm.parent.children, i)
end

local cycleexecswap = {
    cycle_config = {
        extra = 1
    },
    to_key = 1
}

--- @param opts imm.UI.CycleOptions
--- @param page? number
function ui.cycleExec(opts, page)
    page = page or opts.currentPage or 1
    cycleexecswap.cycle_config.extra = opts
    cycleexecswap.to_key = page
    G.FUNCS[funcs.cycle](cycleexecswap)
end

--- @param n number
function ui.cycleOptions(n)
    n = math.ceil(n)
    --- @type string[]
    local opts = {}
    for i=1, n, 1 do table.insert(opts, string.format('%d/%d', i, n)) end
    return  opts
end

--- @param cur number
--- @param len number
--- @param size number
function ui.cyclePage(cur, len, size)
    return math.max(math.min(cur, math.ceil(len / size)), 1)
end

--- @class imm.UI.CycleOptions
--- @field func fun(i: number): balatro.UIElement.Definition?
--- @field id string
--- @field length number
--- @field pagesize number
--- @field currentPage? number
--- @field noImmediate? boolean
--- @field onCycle? fun(page: number)
--- @field uibox? balatro.UIBox
--- @field elm? balatro.UIElement internal state, the target element to update
--- @field elmc? balatro.UIElement internal state, the cycle element

--- @param opts imm.UI.CycleOptions
--- @param cycleOpts? balatro.UI.OptionCycleParam
function ui.cycle(opts, cycleOpts)
    if opts.currentPage then opts.currentPage = ui.cyclePage(opts.currentPage, opts.length, opts.pagesize) end

    --- @type balatro.UI.OptionCycleParam
    local overopts = {
        options = ui.cycleOptions(opts.length / opts.pagesize),
        current_option = opts.currentPage or 1,
        opt_callback = funcs.cycle,
        extra = opts
    }
    setmetatable(overopts, { __index = cycleOpts })

    local elm = create_option_cycle(overopts)
    elm.config.ref_table = { opts = opts, table = elm.config.ref_table }
    elm.config.func = funcs.cycleInit

    return elm
end

--- @param opts imm.UI.CycleOptions
--- @param cycleopts? balatro.UI.OptionCycleParam
function ui.cycleUpdate(opts, cycleopts)
    if not opts.elmc then return end

    ui.replaceElement(opts.elmc, ui.cycle(opts, cycleopts))
    opts.elmc.UIBox:recalculate()
end

--- @param opts imm.UI.CycleOptions
function ui.cycleReset(opts, cycleopts)
    if not opts.elmc then return end
    opts.elmc:remove()
    opts.elmc = nil
end

--- @param a balatro.UIElement
--- @param b balatro.UIElement.Definition
function ui.replaceElement(a, b)
    local p = a.parent
    if not p then return end
    ui.removeElement(a)
    a.UIBox:set_parent_child(b, p)
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
    if size == 0 then return list end

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
    --- @type balatro.UIElement.Definition
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
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.T, config = config }
end

--- Text with config
--- @param conf balatro.UIElement.Config
function ui.TC(conf)
    conf.scale = conf.scale or 1
    --- @type balatro.UIElement.Definition
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
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.T, config = config }
end

--- Object
--- @param obj balatro.Moveable
--- @param config? balatro.UIElement.Config
function ui.O(obj, config)
    config = config or {}
    config.object = obj
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.O, config = config }
end

--- Simple Row text
--- @param text string
--- @param scale? number
--- @param color? ColorHex
--- @param rowopts? balatro.UIElement.Config
function ui.TRS(text, scale, color, rowopts)
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.R, config = rowopts, nodes = {ui.TS(text, scale, color)} }
end

--- @param uibox balatro.UIBox
--- @param definition balatro.UIElement.Definition
function ui.changeRoot(uibox, definition)
    if uibox.REMOVED then return end
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

--- @param grid balatro.UIElement.Definition[][]
--- @param firstRow? boolean
function ui.grid(grid, firstRow)
    --- @type balatro.UIElement.Definition[]
    local gappedInside = {}
    for i,sublist in ipairs(grid) do
        table.insert(gappedInside, { n = firstRow and G.UIT.C or G.UIT.R, nodes = sublist })
    end
    --- @type balatro.UIElement.Definition
    return { n = firstRow and G.UIT.R or G.UIT.C, nodes = gappedInside }
end

--- @param obj any
--- @param n? number
--- @param conf? balatro.UIElement.Config
--- @param rowconf? balatro.UIElement.Config
function ui.TRARef(obj, n, conf, rowconf)
    n = n or #obj
    conf = conf or {}
    conf.ref_table = obj
    conf.colour = conf.colour or G.C.WHITE

    local texts = {}
    local meta = { __index = conf }
    for i=1, n do
        table.insert(texts, {
            n = G.UIT.R,
            config = rowconf,
            nodes = {{
                n = G.UIT.T,
                config = setmetatable({ ref_value = i }, meta)
            }}
        })
    end

    return ui.C(texts)
end

--- @class imm.UI.TextInputOpts: balatro.UI.TextInputParam
--- @field ref_table? table
--- @field initVal? string
--- @field delay? number
--- @field onChange? fun(v: string)
--- @field onSet? fun(v: string)

--- @class imm.UI.TextInputState
--- @field target_table? table
--- @field target_value? any
--- @field val string
--- @field prev string
--- @field opts imm.UI.TextInputOpts
--- @field sleeper fun(s: number)

--- @param opts imm.UI.TextInputOpts
function ui.textInput(opts)
    --- @type imm.UI.TextInputState
    local state
    local iv = opts.initVal or opts.ref_table and opts.ref_table[opts.ref_value] or ''
    state = {
        target_table = opts.ref_table,
        target_value = opts.ref_value,
        val = iv,
        prev = iv,
        opts = opts,
        sleeper = util.sleeperTimeout(function ()
            if state.target_table then state.target_table[state.target_value] = opts.ref_table.val end
            if opts.onSet then opts.onSet(opts.ref_table.val) end
        end)
    }
    opts.hooked_colour = opts.hooked_colour or opts.colour and darken(opts.colour, 0.2) --- @diagnostic disable-line
    opts.ref_table = state
    opts.ref_value = 'val'

    local t = create_text_input(opts)
    t.config.func = funcs.inputUpdate
    t.config.ref_table = state

    return t
end

return ui