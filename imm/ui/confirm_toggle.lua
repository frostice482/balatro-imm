local constructor = require('imm.lib.constructor')
local UIBrowser = require('imm.ui.browser')
local ui = require('imm.lib.ui')
local browser_funcs = UIBrowser.funcs

--- @class imm.UI.ConfirmToggle.Funcs
local funcs = {
    confirm    = 'imm_ct_confirm',
    confirmOne = 'imm_ct_confirm_one',
    download   = 'imm_ct_download',
}

local actionsRank = {
    disable = 3,
    switch = 2,
    enable = 1,
}

--- @class imm.UI.ConfirmToggle
--- @field mod? imm.Mod
local IUICT = {}

--- @param ses imm.UI.Browser
--- @param list imm.LoadList
--- @param mod? imm.Mod
--- @param isDisable? boolean
function IUICT:init(ses, list, mod, isDisable)
    self.ses = ses
    self.list = list
    self.mod = mod
    self.isDisable = isDisable

    self.whoColor = G.C.WHITE
    self.versionColor = G.C.BLUE

    self.fontscale = ses.fontscale * 0.75
    self.fontscaleTitle = self.fontscale
    self.fontscaleVersion = self.fontscale
    self.fontscaleSub = self.fontscale * 0.75
end

--- @param act imm.LoadList.ModAction
function IUICT:partAct(act)
    local name = act.mod.name
    local version = act.mod.version
    local entryScale = self.fontscale

    --- @type balatro.UIElement.Definition?
    local byElm = act.cause and { n = G.UIT.T, config = { text = string.format(' (%s)', act.cause.mod), scale = self.fontscaleSub, colour = self.whoColor } }
    --- @type balatro.UIElement.Definition
    local verElm = { n = G.UIT.T, config = { text = ' '..version, scale = self.fontscaleVersion, colour = self.versionColor } }
    --- @type balatro.UIElement.Definition[]
    local t

    if act.impossible then
        t = {{ n = G.UIT.T, config = { text = '! '..name, scale = entryScale, colour = G.C.RED } }}
    elseif act.action == 'enable' then
        t = {{ n = G.UIT.T, config = { text = '+ '..name, scale = entryScale, colour = G.C.GREEN } }}
    elseif act.action == 'disable' then
        t = {{ n = G.UIT.T, config = { text = '- '..name, scale = entryScale, colour = G.C.ORANGE } }}
    elseif act.action == 'switch' then
        local from = (self.ses.ctrl.loadlist.loadedMods[act.mod.mod] or {}).version or '?'
        t = {
            { n = G.UIT.T, config = { text = '/ '..name..' ', scale = entryScale, colour = G.C.YELLOW } },
            { n = G.UIT.T, config = { text = from, scale = self.fontscaleVersion, colour = self.versionColor } },
            { n = G.UIT.T, config = { text = ' ->', scale = self.fontscaleVersion, colour = G.C.UI.TEXT_LIGHT } },
        }
    end

    table.insert(t, verElm)
    table.insert(t, byElm)

    --- @type balatro.UIElement.Definition
    return { n = G.UIT.R, nodes = t }
end

--- @param nodes balatro.UIElement.Definition[]
--- @return boolean hasImpossible, boolean hasChange
function IUICT:partActions(nodes)
    local hasImpossible, hasChange = false, false

    --- @type imm.LoadList.ModAction[]
    local impossibles = {}
    --- @type imm.LoadList.ModAction[]
    local actions = {}
    for k, act in pairs(self.list.actions) do
        if act.impossible or act.mod ~= self.mod then
            if act.action == 'enable' and self.ses.ctrl.loadlist.loadedMods[act.mod.mod] then act.action = 'switch' end
            table.insert(act.impossible and impossibles or actions, act)
        end
    end
    table.sort(impossibles, function (a, b)
        return a.mod.name < b.mod.name
    end)
    table.sort(actions, function (a, b)
        if a.action ~= b.action then return actionsRank[a.action] > actionsRank[b.action] end
        return a.mod.name < b.mod.name
    end)

    for i,act in ipairs(impossibles) do
        if not hasImpossible then
            table.insert(nodes, ui.simpleTextRow('These mods are in impossible condition to load:', self.fontscaleTitle))
            hasImpossible = true
        end
        table.insert(nodes, self:partAct(act))
    end

    for i,act in ipairs(actions) do
        if not hasChange then
            table.insert(nodes, ui.simpleTextRow('These mods will also take effect:', self.fontscaleTitle))
            hasChange = true
        end
        table.insert(nodes, self:partAct(act))
    end

    return hasImpossible, hasChange
end

--- @param nodes balatro.UIElement.Definition[]
--- @return boolean hasMissing
function IUICT:partMissing(nodes)
    local hasMissing = false

    -- 1 month from now i will probably forget how this code does

    --- @type [string, string[]][]
    local missings = {}
    for k, missing in pairs(self.list.missingDeps) do
        --- @type string[]
        local modsRulesStr = {}
        for other, rules in pairs(missing) do
            --- @type string[]
            local rulesStr = {}
            for i, rule in ipairs(rules) do
                table.insert(rulesStr, rule.op..' '..rule.version.raw)
            end
            table.insert(modsRulesStr, string.format('%s (%s)', other.name, table.concat(rulesStr, ' ')))
        end
        table.sort(modsRulesStr, function (a, b) return a < b end)
        table.insert(missings, { k, modsRulesStr })
    end
    table.sort(missings, function (a, b) return a[1] < b[1] end)

    for i, entry in ipairs(missings) do
        if not hasMissing then
            table.insert(nodes, ui.simpleTextRow('These mods have missing dependencies:', self.fontscaleTitle))
            hasMissing = true
        end

        local base = ui.simpleTextRow(string.format('? %s', entry[1]), self.fontscale, G.C.YELLOW)
        table.insert(nodes, base)
        for i, entry in pairs(entry[2]) do
            table.insert(nodes, ui.simpleTextRow('    '..entry, self.fontscaleSub))
        end
    end

    return hasMissing
end

function IUICT:render()
    local tgltext = self.isDisable and 'Disable' or 'Enable'
    local titleText = self.mod and string.format('%s %s %s, but..', tgltext, self.mod.name, self.mod.version) or string.format('%s, but...', tgltext)

    --- @type balatro.UIElement.Definition[]
    local nodes = {}
    table.insert(nodes, ui.simpleTextRow(titleText, self.fontscaleTitle * 1.25))

    local hasMissing = self:partMissing(nodes)
    local hasImpossible, hasChange = self:partActions(nodes)
    local hasErr = hasMissing or hasImpossible

    local data = { list = self.list, ses = self.ses, mod = self.mod }
    local bconf = { __index = { scale = self.ses.fontscale, ref_table = data, minh = 0.6, minw = 4, col = true } }

    if hasMissing then
        table.insert(nodes, UIBox_button(setmetatable({ button = funcs.download, label = {'Download missings'}, colour = G.C.BLUE }, bconf)))
    end
    local labelModifyAll = 'Confirm'
    if hasErr then labelModifyAll = labelModifyAll..' anyway' end

    local buttons = {}

    table.insert(buttons, UIBox_button(setmetatable({
        button = funcs.confirm,
        label = {labelModifyAll},
        colour = hasErr and G.C.ORANGE or G.C.BLUE
    }, bconf)))

    if self.mod then table.insert(buttons, UIBox_button(setmetatable({
        button = funcs.confirmOne,
        label = {string.format('JUST %s', self.mod.name)},
        colour = G.C.ORANGE
    }, bconf))) end

    table.insert(buttons, UIBox_button(setmetatable({
        button = browser_funcs.back,
        label = {'Cancel'},
        colour = G.C.GREY, ref_table = self.ses
    }, bconf)))

    table.insert(nodes, { n = G.UIT.R, nodes = ui.gapList('C', 0.1, buttons) })

    return create_UIBox_generic_options({
        contents = nodes,
        no_back = true
    })
end

--- @class imm.UI.ConfirmToggle.Static
--- @field funcs imm.UI.ConfirmToggle.Funcs

--- @alias imm.UI.ConfirmToggle.C imm.UI.ConfirmToggle.Static | p.Constructor<imm.UI.ConfirmToggle, nil> | fun(ses: imm.UI.Browser, list: imm.LoadList, mod?: imm.Mod, disable?: boolean): imm.UI.ConfirmToggle
--- @type imm.UI.ConfirmToggle.C
local UICT = constructor(IUICT)
UICT.funcs = funcs
return UICT
