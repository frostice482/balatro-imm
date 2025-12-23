local constructor = require("imm.lib.constructor")
local LoveMoveable = require("imm.lib.love_moveable")
local UIMod = require("imm.ui.mod")
local ui = require("imm.lib.ui")
local co = require("imm.lib.co")
local imm= require("imm")
local util = require("imm.lib.util")

--- @class imm.UI.Browser.Funcs
local funcs = {
    refresh     = 'imm_b_refresh',
    setCategory = 'imm_b_setcat',
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
---
--- @field sidebarBase balatro.UIElement.Config
local IUISes = {
    search = '',
    searchTimeout = 0.3,

    maxPage = 1,
    listPage = 1,
    listW = 3,
    listH = 3,
    fontscale = 0.4,
    spacing = 0.1,
    updateId = 0,
    thumbW = 16 * .2,
    thumbH = 9 * .2,
    textInputWidth = 16 * .6,
    w = 0,
    h = 0,

    sideWidth = 3,

    prepared = false,
    hasChanges = false,

    noThumbnail = false,
    filterInstalled = false,

    colorCategorySelected = G.C.GREEN,
    colorCategoryUnselected = G.C.BLUE,
    colorHeader = G.C.RED,
    colorButtons = G.C.ORANGE,
    colorMod = G.C.BOOSTER
}

--- @alias imm.UI.Browser.C imm.UI.Browser.Static | p.Constructor<imm.UI.Browser, nil> | fun(modctrl?: imm.ModController, modrepo?: imm.Repo): imm.UI.Browser
--- @type imm.UI.Browser.C
local UISes = constructor(IUISes)

--- @class imm.UI.Browser.Static
local BrowserStatic = UISes

BrowserStatic.funcs = funcs

BrowserStatic.categories = {
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

-- NOTE: this section can be moved to tasks but kinda irrelevant idk

BrowserStatic.flavors = {
    'Crash logs are important when Balatro crashes. Be sure to include them when repoting a crash.',
}

--- @type (fun(browser: imm.UI.Browser): string?)[]
BrowserStatic.specialFlavors = {
    function (browser)
        if (#G.P_CENTER_POOLS.Back <= 25 and #G.P_CENTER_POOLS.Stake <= 20) or browser.ctrl.mods.galdur then return end
        return 'If you are having trouble with selecting a deck, try Galdur.'
    end,
    function (browser)
        if not (browser.ctrl.mods.Talisman and browser.ctrl.mods.Talisman.active) then return end
        return 'Some mods are not compatible with Talisman.'
    end
    --[[
    function (browser)
        if browser.ctrl.mods.aikoyorisshenanigans then return end
        return 'play my mod - aikoyori'
    end,
    ]]
}

BrowserStatic.safetyWarning = 'Safety warning: Not all mods are safe to download. Install only the mods you trust.'

--- @param contents balatro.UIElement.Definition[]
function IUISes:subcontainer(contents)
    return create_UIBox_generic_options({
        contents = contents,
        back_func = UISes.funcs.back,
        ref_table = self
    })
end

--- @protected
--- @param tasks? imm.Tasks
function IUISes:init(tasks)
    self.tasks = tasks or require('imm.tasks')
    self.tasks.ses = self
    self.repo = self.tasks.repo
    self.ctrl = self.tasks.ctrl

    self.tags = {}
    self.filteredList = {}
    self.categories = copy_table(BrowserStatic.categories)
    self.sidebarBase = { padding = 0.15, r = true, hover = true, shadow = true, colour = self.colorButtons }

    self:generateFlavor()
end

-- NOTE: this function can be moved to tasks but kinda irrelevant idk

function IUISes:selectFlavor()
    local specials = {}
    for i, fn in ipairs(BrowserStatic.specialFlavors) do
        local text = fn(self)
        if text then table.insert(specials, text) end
    end

    local flavors = BrowserStatic.flavors
    local flavorsLen = #flavors
    local r = math.random(1, flavorsLen + #specials)
    if r <= flavorsLen then return flavors[r] end
    return specials[r - flavorsLen]
end

function IUISes:generateFlavor()
    local f, w
    if not imm.config.disableFlavor then f = self:selectFlavor() end
    if not imm.config.disableSafetyWarning then w = BrowserStatic.safetyWarning end
    if f or w then
        self.tasks.status:update(f, w, true)
    end
end

--- @protected
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
function IUISes:renderText(text, scale, col)
    return ui.T(text, { scale = (scale or 1) * self.fontscale, colour = col })
end

--- @param text string
--- @param scale? number
--- @param col? ColorHex
function IUISes:renderTextRow(text, scale, col)
    return ui.TRS(text, (scale or 1) * self.fontscale, col)
end

--- @protected
--- @param mode 'R' | 'C'
--- @param list balatro.UIElement.Definition[]
function IUISes:uiGap(mode, list)
    return ui.gapList(mode, self.spacing, list)
end

--- @param title string
--- @param maxw? number
function IUISes:renderModText(title, maxw)
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

--- @protected
--- @param label string
--- @param category? string
function IUISes:renderCategory(label, category)
    category = category or label
    return ui.R{
        align = 'm',
        colour = self.tags[category] and self.colorCategorySelected or self.colorCategoryUnselected,
        minw = 2,
        padding = 0.1,
        shadow = true,
        hover = true,
        res = self.fontscale,
        r = true,
        button = funcs.setCategory,
        ref_table = { ses = self, cat = category },
        self:renderText(label)
    }
end

--- @protected
function IUISes:renderOptExit()
    return ui.C({
        tooltip = { text = {'Exit'} },
        button = 'exit_overlay_menu',

        self:renderText('X')
    }, self.sidebarBase)
end

--- @protected
function IUISes:renderOptRefresh()
    return ui.C({
        tooltip = { text = {'Refresh'} },
        button = funcs.refresh,
        ref_table = self,

        self:renderText('R')
    }, self.sidebarBase)
end

--- @protected
function IUISes:renderOptMore()
    return ui.C({
        tooltip = { text = {'More Options'} },
        button = funcs.options,
        ref_table = self,

        self:renderText('O')
    }, self.sidebarBase)
end

--- @protected
function IUISes:renderOptions()
    --- @type balatro.UIElement.Definition[]
    return {
        self:renderOptExit(),
        self:renderOptRefresh(),
        self:renderOptMore(),
    }
end

--- @protected
function IUISes:renderOptionsContainer()
    return ui.R{
        align = 'm',
        nodes = self:uiGap('C', self:renderOptions())
    }
end

--- @protected
function IUISes:renderSidebar()
    local categories = {}
    table.insert(categories, self:renderOptionsContainer())
    for i,entry in ipairs(self.categories) do table.insert(categories, self:renderCategory(entry[1], entry[2])) end
    return ui.C(self:uiGap('R', categories))
end

--- @protected
--- @param mod imm.ModMeta
function IUISes:renderModEntry(mod)
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
            colour = self.colorMod,
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
            self:renderModText(mod:title(), self.thumbW),
        }
    }
end

--- @protected
function IUISes:renderInput()
    return ui.textInputDelaying({
        ref_table = self,
        ref_value = 'search',
        delay = self.searchTimeout,
        onSet = function (v) self:update() end,

        w = self.textInputWidth,
        prompt_text = 'Search (@author)',
        text_scale = self.fontscale,
        extended_corpus = true,
        colour = self.colorHeader,
        hooked_colour = darken(self.colorHeader, 0.2)
    })
end

--- @protected
function IUISes:renderToggleFilterInstalled()
    return create_toggle({
		ref_table = self,
		ref_value = 'filterInstalled',
		label = 'Installed',
		label_scale = self.fontscale,
		w = 0,
		callback = function (value)
			self:update()
		end
    })
end

--- @protected
function IUISes:renderHeader()
    return ui.R{
        align = 'cm',
        self:renderInput()
    }
end

--- @protected
function IUISes:renderCycleContainer()
    return ui.R{
        align = 'cm',
        ui.C{
            minw = self.sideWidth,
            align = 'cl',
            self:renderToggleFilterInstalled()
        },
        ui.O(self.contCycle),
        ui.C{
            minw = self.sideWidth,
            align = 'cr',
        }
    }
end

--- @protected
function IUISes:renderModGrid()
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

--- @protected
function IUISes:renderMain()
    --- @type balatro.UIElement.Definition[]
    return {
        self:renderHeader(),
        self:renderModGrid(),
        self:renderCycleContainer()
    }
end

--- @protected
function IUISes:renderBody()
    --- @type balatro.UIElement.Definition[]
    return {
        self:renderSidebar(),
        ui.C(self:renderMain()),
        ui.C{ui.O(self.contSelect)}
    }
end

--- @protected
function IUISes:renderCycle()
    return create_option_cycle({
        options = ui.cycleOptions(self.maxPage),
        current_option = self.listPage,
        ref_table = self,
        ref_value = 'listPage',
        _ses = self,
        opt_callback = funcs.cyclePage,
        no_pips = true,
        colour = self.colorHeader
    })
end

--- @protected
function IUISes:renderBrowseColumns()
    --- @type balatro.UIElement.Definition[]
    return {
        ui.R(self:renderBody()),
        ui.R{self.tasks.status:render()}
    }
end

--- @protected
function IUISes:renderBrowse()
    return ui.C{
        minw = self.w,
        minh = self.h,
        align = 'cr',
        nodes = self:uiGap('R', self:renderBrowseColumns())
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

--- @param ifMod? string
function IUISes:updateSelectedMod(ifMod)
    local mod = self.selectedMod and self.selectedMod
    if not ifMod or mod and mod:id() == ifMod then
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

--- @protected
--- @param mod imm.ModMeta
--- @param n number
--- @param nocheckUpdate? boolean
function IUISes:updateModImage(mod, n, nocheckUpdate)
    if self.noThumbnail then return end
    co.create(self._updateModImageCo, self, mod, n, nocheckUpdate)
end

--- @protected
--- @param mod? imm.ModMeta
--- @param n number
function IUISes:updateMod(mod, n)
    local root = self.contMods[n]
    if not root then return end

    if mod then
        ui.changeRoot(root, self:renderModEntry(mod))
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
    self.uibox:recalculate()
end

--- @class imm.Filter
--- @field author? boolean
--- @field id? boolean
--- @field search? string

--- @protected
--- @param mod imm.ModMeta
--- @param filter imm.Filter
function IUISes:matchFilter(mod, filter)
    local id = mod:id()
    if self.filterInstalled and not (self.ctrl.mods[id] and next(self.ctrl.mods[id].versions)) then return false end
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

--- @protected
function IUISes:createFilter()
    local search = self.search:lower()
    local isAuthor, isId
    local hasFilter = true
    while hasFilter do
        local c = search:sub(1, 1)
        if c == '@' then isAuthor = true
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
    if self.filterInstalled then
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

    if self.filterInstalled then
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
    ui.changeRoot(self.contCycle, ui.ROOT{self:renderCycle()})

    self:updateMods()

    self.uibox:recalculate()
end

--- @protected
--- @param prov string
--- @param err? string
function IUISes:_updateList(prov, err)
    if err then
        self.tasks.status:update(nil, string.format('Failed getting list for %s: %s', prov, err))
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

    self:initRepo()
    self.prepared = true
end

function IUISes:initRepo()
    self.repo:getLists(function (provider, err)
        self:_updateList(provider.name, err)
    end)
end

function IUISes:render()
    self:updateContainers()
    return create_UIBox_generic_options({
        padding = 0.25,
        no_back = true,
        contents = { self:renderBrowse() }
    })
end

function IUISes:showOverlay(update)
    G.SETTINGS.paused = true
    ui.overlay(self:render())

    self.uibox = G.OVERLAY_MENU
    self.uibox.config.imm = self
    if update then self:prepare() end
    self.uibox:recalculate()
end

return UISes
