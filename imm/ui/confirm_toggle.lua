local constructor = require('imm.lib.constructor')
local UIBrowser = require('imm.ui.browser')
local ui = require('imm.lib.ui')
local util = require('imm.lib.util')
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
--- @field uiButtonConf balatro.UI.ButtonParam
local IUICT = {
    allowDownloadMissing = true,
    buttonDownload = funcs.download,
    buttonConfirm = funcs.confirm,
    buttonConfirmOne = funcs.confirmOne,
    buttonBack = browser_funcs.back,
}

--- @protected
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

    self.fontscale = ses.fontscale * 0.9
    self.fontscaleTitle = self.fontscale
    self.fontscaleVersion = self.fontscale * 0.70
    self.fontscaleSub = self.fontscale * 0.75

    self.uiButtonConf = {
        minh = 0.6,
        minw = 4,
        scale = self.ses.fontscale,
        col = true,
        ref_table = self
    }

    --- @type balatro.UIElement.Config
    self.entryConfig = {
        minw = 3,
        maxw = 3
    }

    local tgltext = self.isDisable and 'Disable' or 'Enable'
    self.titleText = self.mod and string.format('%s %s %s?', tgltext, self.mod.name, self.mod.version) or string.format('%s?', tgltext)
end

--- @protected
--- @param cols balatro.UIElement.Definition[][]
function IUICT:renderEntry(cols)
    for i, v in ipairs(cols) do
        cols[i] = { n = G.UIT.R, config = self.entryConfig, nodes = v }
    end
    return ui.C(cols)
end

--- @protected
--- @param act imm.LoadList.ModAction
function IUICT:partAct(act)
    local name = act.mod.name
    local version = act.mod.version
    local entryScale = self.fontscale

    --local byElm = act.cause and ui.TS(string.format(' (%s)', act.cause.mod), self.fontscaleSub, self.whoColor)
    local verElm = ui.TS(version, self.fontscaleVersion, self.versionColor)

    local t
    local t2 = {}

    if act.impossible then
        t = { ui.TS('! '..name, entryScale,G.C.RED) }
    elseif act.action == 'enable' then
        t = { ui.TS('+ '..name, entryScale,G.C.GREEN) }
    elseif act.action == 'disable' then
        t = { ui.TS('- '..name, entryScale,G.C.ORANGE) }
    elseif act.action == 'switch' then
        t = { ui.TS('/ '..name..' ', entryScale, G.C.YELLOW), }
        local from = (self.ses.ctrl.loadlist.loadedMods[act.mod.mod] or {}).version or '?'
        table.insert(t2, ui.TS(from, self.fontscaleVersion, self.versionColor))
        table.insert(t2, ui.TS(' ->', self.fontscaleVersion, G.C.UI.TEXT_LIGHT))
    end

    table.insert(t2, verElm)
    --table.insert(t2, byElm)

    return self:renderEntry({ t, t2 })
end

--- @protected
--- @return balatro.UIElement.Definition[] impossibleList
--- @return balatro.UIElement.Definition[] changeList
function IUICT:partActions()
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

    --- @type balatro.UIElement.Definition[]
    local impossibleList = {}
    for i,act in ipairs(impossibles) do table.insert(impossibleList, self:partAct(act)) end

    --- @type balatro.UIElement.Definition[]
    local changeList = {}
    for i,act in ipairs(actions) do table.insert(changeList, self:partAct(act)) end

    return impossibleList, changeList
end

--- @protected
--- @return balatro.UIElement.Definition[] list
function IUICT:partMissing()
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
            table.insert(modsRulesStr, table.concat(rulesStr, ' ') --[[string.format('%s (%s)', other.name, table.concat(rulesStr, ' '))]])
        end
        table.sort(modsRulesStr, function (a, b) return a < b end)
        table.insert(missings, { k, modsRulesStr })
    end
    table.sort(missings, function (a, b) return a[1] < b[1] end)

    --- @type balatro.UIElement.Definition[]
    local list = {}

    for i, entry in ipairs(missings) do
        local str = {}
        for i, entry in pairs(entry[2]) do table.insert(str, entry) end

        local base = self:renderEntry({
            {ui.TS(string.format('? %s', entry[1]), self.fontscale, G.C.YELLOW)},
            {ui.TS(' '..table.concat(str, ', '), self.fontscaleSub)}
        })
        table.insert(list, base)
    end

    return list
end

--- @protected
function IUICT:renderButtonDownload()
    --- @type balatro.UI.ButtonParam
    return {
        button = self.buttonDownload,
        label = {'Download missings'},
        colour = G.C.BLUE
    }
end

--- @protected
function IUICT:renderButtonConfirm(hasErr)
    --- @type balatro.UI.ButtonParam
    return {
        button = self.buttonConfirm,
        label = {hasErr and 'Confirm anyway' or 'Confirm'},
        colour = hasErr and G.C.ORANGE or G.C.BLUE
    }
end

--- @protected
function IUICT:renderButtonConfirmOne()
    --- @type balatro.UI.ButtonParam
    return {
        button = self.buttonConfirmOne,
        label = {'JUST '..self.mod.name},
        colour = G.C.ORANGE
    }
end

--- @protected
function IUICT:renderButtonCancel()
    --- @type balatro.UI.ButtonParam
    return {
        button = self.buttonBack,
        label = {'Cancel'},
        colour = G.C.GREY,
        ref_table = self.ses
    }
end

--- @protected
function IUICT:renderButtonOptions(hasMissing, hasErr)
    --- @type balatro.UI.ButtonParam[]
    local buttonOpts = {}

    table.insert(buttonOpts, hasMissing and self.allowDownloadMissing and self:renderButtonDownload() or nil)
    table.insert(buttonOpts, self:renderButtonConfirm(hasErr))
    table.insert(buttonOpts, self.mod and self:renderButtonConfirmOne() or nil)
    table.insert(buttonOpts, self:renderButtonCancel())

    return buttonOpts
end

--- @protected
function IUICT:renderButtons(hasMissing, hasErr)
    --- @type balatro.UIElement.Definition[]
    local buttons = {}
    local buttonOpts = self:renderButtonOptions(hasMissing, hasErr)
    for i,v in ipairs(buttonOpts) do
        table.insert(buttons, UIBox_button(setmetatable(v, { __index = self.uiButtonConf })))
    end
    return buttons
end

--- @protected
--- @param elms balatro.UIElement.Definition[]
function IUICT:renderGrid(elms)
    return ui.gapGrid(0.1, 0.1, util.grid(elms, 7), true)
end

--- @protected
function IUICT:renderContent()
    --- @type balatro.UIElement.Definition[]
    local nodes = {}
    table.insert(nodes, ui.TRS(self.titleText, self.fontscaleTitle * 1.25))

    local missings = self:partMissing()
    local impossibles, changes = self:partActions()
    local hasMissing = #missings ~= 0
    local hasImpossibles = #impossibles ~= 0
    local hasChanges = #changes ~= 0

    if hasImpossibles then
        table.insert(nodes, ui.TRS('These mods are impossible to load:', self.fontscale))
        table.insert(nodes, ui.R(self:renderGrid(impossibles)))
    end
    if hasMissing then
        table.insert(nodes, ui.TRS('These mods are missing:', self.fontscale))
        table.insert(nodes, ui.R(self:renderGrid(missings)))
    end
    if hasChanges then
        table.insert(nodes, ui.TRS('These mods will take effect:', self.fontscale))
        table.insert(nodes, ui.R(self:renderGrid(changes)))
    end

    local hasErr = hasMissing or hasImpossibles
    local buttons = self:renderButtons(hasMissing, hasErr)
    table.insert(nodes, ui.R(ui.gapList('C', 0.1, buttons)))

    return nodes
end

function IUICT:render()
    return create_UIBox_generic_options({
        contents = self:renderContent(),
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
