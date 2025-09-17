local constructor = require("imm.lib.constructor")
local LoveMoveable = require("imm.lib.love_moveable")
local UIMod = require("imm.ui.mod")
local BrowserTask = require("imm.btasks.tasks")
local ui = require("imm.lib.ui")
local co = require("imm.lib.co")
local logger = require("imm.logger")

--- @class imm.UI.Browser.Funcs
local funcs = {
    refresh     = 'imm_b_refresh',
    setCategory = 'imm_b_setcat',
    update      = 'imm_b_update',
    cyclePage   = 'imm_b_cycle',
    chooseMod   = 'imm_b_choosemod',
    back        = 'imm_b_back',
    options     = 'imm_b_opts'
}

--- @class imm.UI.Container: balatro.UIElement.Config
--- @field object balatro.UIBox

--- @class imm.UI.Browser
--- @field uibox balatro.UIBox
--- @field tags table<string, boolean>
--- @field filteredList imm.ModMeta[]
--- @field selectedMod? imm.ModMeta
---
--- @field contMods balatro.UIBox[]
--- @field contCycle balatro.UIBox
--- @field contSelect balatro.UIBox
local IUISes = {
    search = '',
    prevSearch = '',
    queueTimer = 0.3,
    queueCount = 0,

    maxPage = 1,
    listPage = 1,
    listW = 3,
    listH = 3,
    fontscale = 0.4,
    spacing = 0.1,
    updateId = 0,
    thumbW = 16 * .2,
    thumbH = 9 * .2,
    w = 0,
    h = 0,

    prepared = false,
    hasChanges = false,

    noThumbnail = false,

}

--- @protected
--- @param modctrl? imm.ModController
--- @param repo? imm.Repo
function IUISes:init(modctrl, repo)
    self.ctrl = modctrl or require('imm.modctrl')
    self.repo = repo or require('imm.repo')
    self.tags = {}
    self.filteredList = {}
    self.categories = {
        {'Content'},
        {'Joker'},
        {'QoL', 'Quality of Life'},
        {'Misc', 'Miscellaneous'},
        {'Resources', 'Resource Packs'},
        {'Technical'},
        {'API'},
        {'Libraries'},
        {'Tools'},
    }
    self.tasks = BrowserTask(self)
end

function IUISes:updateContainers()
    self.contCycle = ui.boxContainer()
    self.contSelect = ui.boxContainer()
    self.contMods = {}
    for i_col=1, self.listH, 1 do
        for i_row=1, self.listW, 1 do
            local i = (i_col - 1) * self.listW + i_row
            self.contMods[i] = ui.boxContainer()
        end
    end
end

--- @param text string
--- @param scale? number
--- @param col? ColorHex
function IUISes:uiText(text, scale, col)
    return ui.T(text, { scale = (scale or 1) * self.fontscale, colour = col })
end

--- @param text string
--- @param scale? number
--- @param col? ColorHex
function IUISes:uiTextRow(text, scale, col)
    return ui.TRS(text, (scale or 1) * self.fontscale, col)
end

--- @param title string
--- @param maxw? number
function IUISes:uiModText(title, maxw)
    local obj = DynaText({
        string = title,
        scale = self.fontscale,
        colours = {G.C.UI.TEXT_LIGHT},
        maxw = maxw,
        bump = true,
    })
    obj:pulse()

    return ui.R{
        align = 'cm',
        minh = self.fontscale * 0.8,
        ui.O(obj)
    }
end

function IUISes:uiCategory(label, category)
    category = category or label
    return ui.R{
        align = 'm',
        colour = self.tags[category] and G.C.ORANGE or G.C.RED,
        minw = 2,
        padding = 0.1,
        shadow = true,
        hover = true,
        res = self.fontscale,
        r = true,
        button = funcs.setCategory,
        ref_table = { ses = self, cat = category },
        self:uiText(label)
    }
end

--- @type balatro.UIElement.Config
local someWeirdBase = { padding = 0.15, r = true, hover = true, shadow = true, colour = G.C.BLUE }

function IUISes:uiSidebarHeaderExit()
    return ui.C({
        tooltip = { text = {'Exit'} },
        button = 'exit_overlay_menu',

        self:uiText('X')
    }, someWeirdBase)
end

function IUISes:uiSidebarHeaderRefresh()
    return ui.C({
        tooltip = { text = {'Refresh'} },
        button = funcs.refresh,
        ref_table = self,

        self:uiText('R')
    }, someWeirdBase)
end

function IUISes:uiSidebarHeaderOptions()
    return ui.C({
        tooltip = { text = {'More Options'} },
        button = funcs.options,
        ref_table = self,

        self:uiText('O')
    }, someWeirdBase)
end

function IUISes:uiSidebarHeader()
    local uis = {
        self:uiSidebarHeaderExit(),
        self:uiSidebarHeaderRefresh(),
        self:uiSidebarHeaderOptions(),
    }
    return ui.R{
        align = 'm',
        nodes = ui.gapList('C', self.spacing, uis)
    }
end

function IUISes:uiSidebar()
    local categories = {}
    table.insert(categories, self:uiSidebarHeader())
    for i,entry in ipairs(self.categories) do table.insert(categories, self:uiCategory(entry[1], entry[2])) end
    return ui.C(ui.gapList('R', self.spacing, categories))
end

--- @param mod imm.ModMeta
function IUISes:uiModEntry(mod)
    local w, textDescs
    local desc = mod:description()
    if desc then
        w, textDescs = G.LANG.font.FONT:getWrap(desc, G.TILESCALE * G.TILESIZE * 20 * 4)

        for i, v in ipairs(textDescs) do
            if i > 5 then textDescs[i] = nil
            else textDescs[i] = v == "" and " " or v --- why smods??
            end
        end
    end

    local thumb = LoveMoveable(nil, 0, 0, self.thumbW, self.thumbH)

    return ui.ROOT{
        ref_table = { thumb = thumb },
        padding = self.spacing / 2,

        ui.C{
            padding = 0.1,
            colour = G.C.RED,
            hover = true,
            shadow = true,
            r = true,
            button = funcs.chooseMod,
            ref_table = { ses = self, mod = mod },
            on_demand_tooltip = textDescs and {
                text = textDescs,
                text_scale = self.fontscale
            },

            ui.R{ align = 'cm', minw = self.thumbW, ui.O(thumb) },
            self:uiModText(mod:title(), self.thumbW),
        }
    }
end

function IUISes:uiHeaderInput()
    return create_text_input({
        ref_table = self,
        ref_value = 'search',
        w = 16 * .6,
        prompt_text = 'Search (@author, #installed, $id)',
        text_scale = self.fontscale,
        extended_corpus = true
    })
end

function IUISes:uiHeader()
    return ui.R{ align = 'cm', self:uiHeaderInput()
    }
end

function IUISes:uiCycleContainer()
    return ui.R{ align = 'cm', ui.O(self.contCycle) }
end

function IUISes:uiModGrid()
    local col = {}

    for i_col=1, self.listH, 1 do
        local row = {}
        for i_row=1, self.listW, 1 do
            local i = (i_col - 1) * self.listW + i_row
            local t = ui.O(self.contMods[i])
            table.insert(row, t)
        end
        local t = ui.R(row)
        table.insert(col, t)
    end

    return ui.R{ padding = self.spacing / 2, ui.C(col) }
end

function IUISes:uiMain()
    local col = {
        self:uiHeader(),
        self:uiModGrid(),
        self:uiCycleContainer()
    }
    return ui.C(col)
end

function IUISes:uiBody()
    local uis = {
        self:uiSidebar(),
        self:uiMain(),
        ui.C{ui.O(self.contSelect)}
    }
    return ui.R(uis)
end

function IUISes:uiCycle()
    return ui.ROOT{create_option_cycle({
        options = ui.cycleOptions(self.maxPage),
        current_option = self.listPage,
        ref_table = self,
        ref_value = 'listPage',
        _ses = self,
        opt_callback = funcs.cyclePage,
        no_pips = true
    })}
end

function IUISes:uiBrowse()
    local uis = {
        self:uiBody(),
        ui.gap('R', self.spacing),
        ui.R{self.tasks.status:render()}
    }
    return ui.C{
        minw = self.w,
        minh = self.h,
        align = 'cr',
        func = funcs.update,
        ref_table = self,
        nodes = uis
    }
end

--- @param mod? imm.ModMeta
function IUISes:selectMod(mod)
    self.selectedMod = mod
    if mod then
        local modses = UIMod(self, mod)
        ui.changeRoot(self.contSelect, modses:render())
        modses:update()
    else
        ui.changeRoot(self.contSelect, ui.ROOT())
    end
    self.uibox:recalculate()
end

--- @param ifMod? imm.ModMeta
function IUISes:updateSelectedMod(ifMod)
    local mod = self.selectedMod and self.selectedMod
    if not ifMod or ifMod == mod then
        return self:selectMod(mod)
    end
end

--- @async
--- @protected
--- @param mod imm.ModMeta
--- @param n number
--- @param nocheckUpdate? boolean
function IUISes:_updateModImageCo(mod, n, nocheckUpdate)
    local root = self.contMods[n]
    if not root then return end

    local aid = self.updateId
    local err, img = mod:getImageCo()
    if not img or not nocheckUpdate and self.updateId ~= aid then return end

    local w, h = img:getDimensions()
    local aspectRatio = math.max(math.min(w / h, 16/9), 1)

    --- @type imm.LoveMoveable
    local thumb = root.UIRoot.config.ref_table.thumb
    thumb.T.w = self.thumbH * aspectRatio
    thumb.drawable = img
    root:recalculate()
end

--- @param mod imm.ModMeta
--- @param n number
--- @param nocheckUpdate? boolean
function IUISes:updateModImage(mod, n, nocheckUpdate)
    if self.noThumbnail then return end
    co.create(self._updateModImageCo, self, mod, n, nocheckUpdate)
end

--- @param mod? imm.ModMeta
--- @param n number
function IUISes:updateMod(mod, n)
    local root = self.contMods[n]
    if not root then return end

    if mod then
        ui.changeRoot(root, self:uiModEntry(mod))
        self:updateModImage(mod, n)
    else
        ui.changeRoot(root, ui.ROOT())
    end
end

function IUISes:updateMods()
    self.updateId = self.updateId + 1
    local off = (self.listPage - 1) * self.listW * self.listH
    for i=1, self.listH * self.listW, 1 do
        self:updateMod(self.filteredList[i+off], i)
    end
end

--- @class imm.Filter
--- @field author? boolean
--- @field installed? boolean
--- @field id? boolean
--- @field search? string

--- @param mod imm.ModMeta
--- @param filter imm.Filter
function IUISes:matchFilter(mod, filter)
    local id = mod:id()
    if filter.installed and not (self.ctrl.mods[id] and next(self.ctrl.mods[id].versions)) then return false end
    if not (filter.id and id or filter.author and mod:author() or mod:title()):lower():find(filter.search, 1, true) then return false end

    local hasCatFilt = false
    local hasCatMatch = false
    local catobj = {}
    for i, category in ipairs(mod:categories()) do
        catobj[category] = true
    end
    for category, filtered in pairs(self.tags) do
        hasCatFilt = hasCatFilt or filtered
        hasCatMatch = hasCatMatch or filtered and catobj[category]
        if hasCatMatch then break end
    end
    if hasCatFilt and not hasCatMatch then return false end

    return true
end

function IUISes:createFilter()
    local search = self.search:lower()
    local isAuthor, isInstalled, isId
    local hasFilter = true
    while hasFilter do
        local c = search:sub(1, 1)
        if c == '#' then isInstalled = true
        elseif c == '@' then isAuthor = true
        elseif c == '$' then isId = true
        else hasFilter = false
        end

        if hasFilter then
            search = search:sub(2)
        end
    end

    --- @type imm.Filter
    return {
        author = isAuthor,
        id = isId,
        installed = isInstalled,
        search = search
    }
end

function IUISes:updateFilter()
    self.filteredList = {}

    local ids = {}
    local addeds = {}
    local filter = self:createFilter()

    -- filter mods in list
    for k, meta in ipairs(self.repo.list) do
        local id = meta:id()
        ids[id] = true
        if not addeds[id] and self:matchFilter(meta, filter) then
            table.insert(self.filteredList, meta)
            addeds[id] = true
        end
    end
    -- include local mods
    if filter.installed then
        for mod, list in pairs(self.ctrl.mods) do
            if not (ids[mod] or list.native or addeds[mod]) then
                local meta = list:createBmiMeta(self.repo)
                if meta and self:matchFilter(meta, filter) then
                    table.insert(self.filteredList, meta)
                    addeds[mod] = true
                end
            end
        end
    end
    -- include provider-based filtering
    if not filter.author then
        for providedId, list in pairs(self.repo.listProviders) do
            if providedId:lower():find(filter.search, 1, true) then
                for i, meta in ipairs(list) do
                    local id = meta:id()
                    if not addeds[id] and self:matchFilter(meta, filter) then
                        table.insert(self.filteredList, meta)
                        addeds[id] = true
                    end
                end
            end
        end
    end

    if filter.installed then
        table.sort(self.filteredList, function (a, b)
            local la = self.ctrl.mods[a:id()]
            local va = la and la.active and 1 or 0
            local lb = self.ctrl.mods[b:id()]
            local vb = lb and lb.active and 1 or 0

            if va ~= vb then return va > vb end
            return a:title() < b:title()
        end)
    end
end

function IUISes:update()
    self:updateFilter()

    self.maxPage = math.max(math.ceil(#self.filteredList/(self.listW*self.listH)), 1)
    self.listPage = math.min(self.listPage, self.maxPage)
    ui.changeRoot(self.contCycle, self:uiCycle())

    self:updateMods()

    self.uibox:recalculate()
end

--- @protected
--- @param err? string
function IUISes:_updateList(err)
    if err then
        self.tasks.status:update(nil, string.format('Failed getting list for BMI: %s', err))
        return
    end
    pseudoshuffle(self.repo.list, math.random())
    self:update()
end

function IUISes:prepare()
    if self.prepared then
        self:update()
        self:updateSelectedMod()
        return
    end

    logger.dbg('Getting list for BMI')
    self.repo.bmi:getList(function (err) self:_updateList(err) end)

    logger.dbg('Getting list for TS')
    self.repo.ts:getList(function (err) self:_updateList(err) end)

    self.prepared = true
end

function IUISes:render()
    self:updateContainers()
    return create_UIBox_generic_options({
        padding = 0.25,
        no_back = true,
        contents = { self:uiBrowse() }
    })
end

function IUISes:showOverlay(update)
    ui.overlay(self:render())

    self.uibox = G.OVERLAY_MENU
    self.uibox.config.imm = self
    if update then self:prepare() end
    self.uibox:recalculate()
end

function IUISes:queueUpdate()
    self.queueCount = self.queueCount + 1
    G.E_MANAGER:add_event(Event{
        blockable = false,
        trigger = 'after',
        timer = 'REAL',
        delay = self.queueTimer,
        func = function () return self:queueUpdateNext() end
    })
end

function IUISes:queueUpdateNext()
    self.queueCount = self.queueCount - 1
    if self.queueCount == 0 then self:update() end
    return true
end

--- @class imm.UI.Browser.Static
--- @field funcs imm.UI.Browser.Funcs

--- @alias imm.UI.Browser.C imm.UI.Browser.Static | p.Constructor<imm.UI.Browser, nil> | fun(modctrl?: imm.ModController, modrepo?: imm.Repo): imm.UI.Browser
--- @type imm.UI.Browser.C
local UISes = constructor(IUISes)
UISes.funcs = funcs
return UISes
