local constructor = require("imm.lib.constructor")
local ModBrowser = require("imm.lib.browser_mod")
local LoveMoveable = require("imm.lib.love_moveable")
local Repo = require("imm.lib.mod.repo")
local ui = require("imm.lib.ui")
local util = require("imm.lib.util")
local logger = require("imm.logger")

local funcs = {
    setCategory = 'imm_ses_setcat',
    update      = 'imm_ses_update',
    cyclePage   = 'imm_ses_cycle',
    chooseMod   = 'imm_ses_choosemod',
    refresh     = 'imm_refresh'
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.setCategory] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Browser
    local ses, cat = r.ses, r.cat

    ses.tags[cat] = not ses.tags[cat]
    elm.config.colour = ses.tags[cat] and G.C.ORANGE or G.C.RED
    ses:queueUpdate()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.update] = function(elm)
    --- @type imm.Browser
    local ses = elm.config.ref_table

    if ses.prevSearch ~= ses.search then
        ses.prevSearch = ses.search
        ses:queueUpdate()
    end
end

--- @param elm balatro.UI.CycleCallbackParam
G.FUNCS[funcs.cyclePage] = function(elm)
    --- @type imm.Browser
    local ses = elm.cycle_config._ses

    ses.listPage = elm.to_key
    ses:updateMods()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.chooseMod] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Browser, bmi.Meta
    local ses, mod = r.ses, r.mod

    ses:selectMod(mod)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.refresh] = function(elm)
    util.rmdir('immcache', false)

    --- @type imm.Browser
    local ses = elm.config.ref_table
    if ses then
        ses.repo:clear()
        ses.prepared = false
        ses:showOverlay(true)
    end
end

--- @class imm.Browser
--- @field uibox balatro.UIBox
--- @field tags table<string, boolean>
--- @field filteredList bmi.Meta[]
--- @field selectedMod? imm.ModBrowser
--- @field taskQueues? fun()[]
--- @field ctrl imm.ModController
local UISes = {
    search = '',
    prevSearch = '',
    queueTimer = 0.3,
    queueCount = 0,

    listPage = 1,
    listW = 3,
    listH = 3,
    updateId = 0,
    thumbW = 16 * .2,
    thumbH = 9 * .2,
    w = 0,
    h = 0,
    fontscale = 0.4,

    prepared = false,
    errorText = '',
    taskText = '',
    noThumbnail = false,
    noAutoDownloadMissing = false,
    taskDone = true,

    idCycle = 'imm-cycle',
    idCycleCont = 'imm-cycle-cnt',
    idModSelect = 'imm-modslc',
    idModSelectCnt = 'imm-modslc-cnt',
    idMod = 'imm-mod',
    idImageContSuff = '-imgcnt',
}

--- @protected
--- @param modctrl? imm.ModController
--- @param repo? imm.Repo
function UISes:init(modctrl, repo)
    self.ctrl = modctrl or require('imm.modctrl')
    self.repo = repo or require('imm.repo')
    self.tags = {}
    self.filteredList = {}
    self.categories = {
        {'Content'},
        {'Joker'},
        {'QoL', 'Quality of Life'},
        {'Technical'},
        {'Misc', 'Miscellaneous'},
        {'Resources', 'Resource Packs'},
        {'API'}
    }
    self.taskQueues = {}
end

function UISes:nextTask()
    self.taskDone = true
    local f = table.remove(self.taskQueues, 1)
    if not f then return end
    self.taskDone = false
    f()
end

--- @param func fun()
function UISes:queueTask(func)
    table.insert(self.taskQueues, func)
    if self.taskDone then self:nextTask() end
end

function UISes:queueTaskCo()
    util.co(function (res)
        if self.taskDone then
            self.taskDone = false
            res()
            return
        end
        table.insert(self.taskQueues, res)
    end)
end

--- @param n number
function UISes:getModElmId(n)
    return 'imm-mod-'..n
end

--- @param n number
function UISes:getModElmCntId(n)
    return 'imm-mod-container-'..n
end

--- @param text string
--- @param scale? number
--- @param col? ColorHex
function UISes:uiText(text, scale, col)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.T,
        config = { text = text, scale = self.fontscale * (scale or 1), colour = col or G.C.UI.TEXT_LIGHT }
    }
end

--- @param id string
function UISes:uiImage(id)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {
            align = 'm',
            id = id,
            minw = self.thumbW,
            minh = self.thumbH,
        }
    }
end

--- @param title string
--- @param maxw? number
function UISes:uiModText(title, maxw)
    local obj = DynaText({
        string = title,
        scale = self.fontscale,
        colours = {G.C.UI.TEXT_LIGHT},
        maxw = maxw,
        bump = true,
    })
    obj:pulse()

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'cm', minh = self.fontscale * 0.8 },
        nodes = {{
            n = G.UIT.O,
            config = {
                object = obj
            }
        }}
    }
end

--- @param text string
function UISes:uiModAuthor(text)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'm' },
        nodes = {self:uiText('By '..text, 0.75)}
    }
end

function UISes:uiModSelectContainer()
    return ui.container(self.idModSelectCnt)
end

function UISes:uiCategory(label, category)
    category = category or label
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {
            align = 'm',
            colour = self.tags[category] and G.C.ORANGE or G.C.RED,
            minw = 2,
            padding = 0.1,
            shadow = true,
            hover = true,
            res = self.fontscale,
            r = true,
            button = funcs.setCategory,
            ref_table = { ses = self, cat = category }
        },
        nodes = {self:uiText(label)}
    }
end

--- @type balatro.UIElement.Config
local someWeirdBase = { padding = 0.15, r = 0.1, hover = true, shadow = true, colour = G.C.BLUE }

function UISes:uiSidebarHeaderExit()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = setmetatable({ tooltip = { text = {'Exit'} }, button = 'exit_overlay_menu' }, {__index = someWeirdBase}),
        nodes = {self:uiText('X')}
    }
end

function UISes:uiSidebarHeaderRefresh()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = setmetatable({ tooltip = { text = {'Refresh'} }, button = funcs.refresh, ref_table = self }, {__index = someWeirdBase}),
        nodes = {self:uiText('R')}
    }
end

function UISes:uiSidebarHeader()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.1, align = 'm' },
        nodes = {
            self:uiSidebarHeaderExit(),
            ui.gap('C', self.fontscale / 5),
            self:uiSidebarHeaderRefresh(),
        }
    }
end

function UISes:uiSidebar()
    local categories = {}

    table.insert(categories, self:uiSidebarHeader())

    for i,entry in ipairs(self.categories) do
        table.insert(categories, self:uiCategory(entry[1], entry[2]))
    end

    --- @type balatro.UIElement.Definition
    return { n = G.UIT.C, nodes = categories }
end

--- @param mod bmi.Meta
--- @param n number
function UISes:uiModEntry(mod, n)
    local w, textDescs
    if mod.description then
        w, textDescs = G.LANG.font.FONT:getWrap(mod.description, G.TILESCALE * G.TILESIZE * 20 * 4)

        for i, v in ipairs(textDescs) do
            if i > 5 then textDescs[i] = nil
            else textDescs[i] = v == "" and " " or v --- why smods??
            end
        end
    end

    local id = self:getModElmId(n)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = {
            colour = G.C.RED,
            group = self.idMod,
            hover = true,
            shadow = true,
            r = true,
            button = funcs.chooseMod,
            ref_table = { ses = self, mod = mod },
            padding = 0.15,
            on_demand_tooltip = textDescs and {
                text = textDescs,
                text_scale = self.fontscale
            }
        },
        nodes = {
            self:uiImage(id .. self.idImageContSuff),
            self:uiModText(mod.title, self.thumbW),
        }
    }
end

function UISes:uiHeaderInput()
    return create_text_input({
        ref_table = self,
        ref_value = 'search',
        w = 16 * .6,
        prompt_text = 'Search (@author, #installed, $id)',
        text_scale = self.fontscale,
        extended_corpus = true
    })
end

function UISes:uiHeader()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'cm', padding = 0.1 },
        nodes = {
            self:uiHeaderInput()
        }
    }
end

function UISes:uiMain()
    local n = 0
    local col = {}

    table.insert(col, self:uiHeader())

    for i=1, self.listH, 1 do
        local row = {}
        for j=1, self.listW, 1 do
            n = n + 1
            --- @type balatro.UIElement.Definition
            local t = {
                n = G.UIT.C,
                nodes = {{
                    n = G.UIT.R, config = { id = self:getModElmCntId(n), padding = 0.1 }
                }}
            }
            table.insert(row, t)
        end
        --- @type balatro.UIElement.Definition
        local t = { n = G.UIT.R, nodes = row }
        table.insert(col, t)
    end

    table.insert(col, self:uiCycleContainer())

    --- @type balatro.UIElement.Definition
    return { n = G.UIT.C, nodes = col }
end

function UISes:uiBody()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        nodes = {
            self:uiSidebar(),
            self:uiMain(),
            self:uiModSelectContainer()
        }
    }
end

function UISes:uiCycle()
    local n = math.max(math.ceil(#self.filteredList/(self.listW*self.listH)), 1)
    local opts = ui.cycleOptions(n)
    self.listPage = math.min(self.listPage, n)

    local obj = create_option_cycle({
        options = opts,
        current_option = self.listPage,
        ref_table = self,
        ref_value = 'listPage',
        _ses = self,
        opt_callback = funcs.cyclePage,
        no_pips = true
    })
    obj.config.group = self.idCycle
    return obj
end

function UISes:uiCycleContainer()
    local w = ui.container(self.idCycleCont, true)
    w.config = {
        align = 'cm',
        padding = 0.1
    }
    return w
end

function UISes:uiErrorContainer()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        nodes = {{
            n = G.UIT.T,
            config = {
                ref_table = self,
                ref_value = 'errorText',
                scale = self.fontscale * 0.8,
                colour = G.C.ORANGE
            }
        }}
    }
end

function UISes:uiTaskContainer()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        nodes = {{
            n = G.UIT.T,
            config = {
                ref_table = self,
                ref_value = 'taskText',
                scale = self.fontscale * 0.8,
                colour = G.C.UI.TEXT_LIGHT
            }
        }}
    }
end

function UISes:uiBrowse()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = {
            minw = self.w,
            minh = self.h,
            align = 'cr',
            func = funcs.update,
            ref_table = self
        },
        nodes = {
            self:uiBody(),
            self:uiTaskContainer(),
            self:uiErrorContainer(),
        }
    }
end

--- @param mod? bmi.Meta
function UISes:selectMod(mod)
    if self.selectedMod then self.uibox:remove_group(nil, self.idModSelect) end
    local cnt = self.uibox:get_UIE_by_ID(self.idModSelectCnt)
    if not mod or not cnt then return end

    local modses = ModBrowser(self, mod)
    self.selectedMod = modses
    self.uibox:add_child(modses:container(), cnt)
    modses:update()
end

--- @param ifMod? bmi.Meta
function UISes:updateSelectedMod(ifMod)
    local mod = self.selectedMod and self.selectedMod.mod
    if not ifMod or ifMod == mod then
        return self:selectMod(mod)
    end
end

function UISes:queueUpdate()
    self.queueCount = self.queueCount + 1
    G.E_MANAGER:add_event(Event{
        blockable = false,
        trigger = 'after',
        timer = 'REAL',
        delay = self.queueTimer,
        func = function () return self:queueUpdateNext() end
    })
end

function UISes:queueUpdateNext()
    self.queueCount = self.queueCount - 1
    if self.queueCount == 0 then self:update() end
    return true
end

--- @param containerId string
--- @param img love.Image
function UISes:uiUpdateImage(containerId, img)
    local imgcnt = self.uibox:get_UIE_by_ID(containerId)
    if not imgcnt then return end

    self.uibox:add_child({
        n = G.UIT.O,
        config = { object = LoveMoveable(img, 0, 0, self.thumbW, self.thumbH) }
    }, imgcnt)
end

--- @protected
--- @param mod bmi.Meta
--- @param containerId string
--- @param nocheckUpdate? boolean
function UISes:_updateModImage(mod, containerId, nocheckUpdate)
    if not mod.pathname then return end
    local aid = self.updateId
    local err, data = self.repo:getImageCo(mod.pathname)

    if not data or not nocheckUpdate and self.updateId ~= aid then
        if err then print(string.format("Error loading thumbnail %s: %s", mod.pathname, err)) end
        return
    end

    self:uiUpdateImage(containerId, data)
end

--- @param mod bmi.Meta
--- @param containerId string
--- @param nocheckUpdate? boolean
function UISes:updateModImage(mod, containerId, nocheckUpdate)
    util.createCo(self._updateModImage, self, mod, containerId, nocheckUpdate)
end

--- @param mod? bmi.Meta
--- @param n number
function UISes:updateMod(mod, n)
    local cont = self.uibox:get_UIE_by_ID(self:getModElmCntId(n))
    if not cont or not mod then return end

    self.uibox:add_child(self:uiModEntry(mod, n), cont)
    self:updateModImage(mod, self:getModElmId(n)..self.idImageContSuff)
end

function UISes:updateMods()
    self.updateId = self.updateId + 1
    self.uibox:remove_group(nil, self.idMod)
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

--- @param mod bmi.Meta
--- @param filter imm.Filter
function UISes:matchFilter(mod, filter)
    if filter.installed and not (self.ctrl.mods[mod.id] and next(self.ctrl.mods[mod.id].versions)) then return false end
    if not (filter.id and mod.id or filter.author and mod.author or mod.title):lower():find(filter.search, 1, true) then return false end

    local hasCatFilt = false
    local hasCatMatch = false
    local catobj = {}
    for i, category in ipairs(mod.categories) do
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

function UISes:createFilter()
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

function UISes:updateFilter()
    self.filteredList = {}

    local ids = {}
    local addeds = {}
    local filter = self:createFilter()

    -- filter mods in list
    for k, meta in ipairs(self.repo.list) do
        ids[meta.id] = true
        if not addeds[meta.id] and self:matchFilter(meta, filter) then
            table.insert(self.filteredList, meta)
            addeds[meta.id] = true
        end
    end
    -- include local mods
    if filter.installed then
        for mod, list in pairs(self.ctrl.mods) do
            if not ids[mod] and not list.native then
                local meta = list:createBmiMeta()
                if meta and not addeds[mod] and self:matchFilter(meta, filter) then
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
                    if not addeds[meta.id] and self:matchFilter(meta, filter) then
                        table.insert(self.filteredList, meta)
                        addeds[meta.id] = true
                    end
                end
            end
        end
    end
end

function UISes:update()
    self.uibox:remove_group(nil, self.idCycle)

    self:updateFilter()
    self:updateMods()

    local cyclecont = self.uibox:get_UIE_by_ID(self.idCycleCont)
    if cyclecont then self.uibox:add_child(self:uiCycle(), cyclecont) end

    self.uibox:recalculate()
end

function UISes:prepare()
    if self.prepared then
        self:update()
        self:updateSelectedMod()
    end

    self.prepared = true
    self.repo:getList(function (err, res)
        if not res then
            self.errorText = err
            return
        end
        self:update()
    end)
end

function UISes:container()
    return create_UIBox_generic_options({
        no_back = true,
        contents = { self:uiBrowse() }
    })
end

function UISes:showOverlay(update)
    G.FUNCS.overlay_menu({ definition = self:container() })
    self.uibox = G.OVERLAY_MENU
    self.uibox.config.imm = self
    if update then self:prepare() end
    self.uibox:recalculate()
end

--- @class imm.ModSession.QueueDownloadExtraInfo
--- @field name? string
--- @field size? number
--- @field blacklist? table<string>
--- @field cb? fun(err?: string)

--- @protected
--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function UISes:_queueTaskInstall(url, extra)
    extra = extra or {}
    local name = extra.name or 'something'
    local size = extra.size
    extra.blacklist = extra.blacklist or {}

    self:queueTaskCo()

    if extra.blacklist[url] then return end

    self.taskText = string.format('Downloading %s (%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')
    logger.log(self.taskText)

    local err, res = self.repo.api.blob:fetchCo(url)
    if not res then
        err = err or 'unknown error'
        self.taskText = string.format('Failed downloading %s: %s', name, err)
        if extra.cb then extra.cb(err) end
    else
        extra.blacklist[url] = true
        self:installModFromZip(love.filesystem.newFileData(res, 'swap'), extra.blacklist)
        if extra.cb then extra.cb(err) end
    end

    return self:nextTask()
end

--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function UISes:queueTaskInstall(url, extra)
    util.createCo(self._queueTaskInstall, self, url, extra)
end

--- @protected
--- @param id string
--- @param list imm.Dependency.Rule[][]
--- @param blacklistState? table<string>
function UISes:_installMissingModEntry(id, list, blacklistState)
    local mod = self.repo:getMod(id)
    if not mod then return logger.fmt('warn', 'Mod id %s does not exist in repo', id) end
    local title = mod.title

    local err, releases = self.repo:getModReleasesCo(mod)
    if err then logger:fmt('warn', 'Failed to obtain releases from %s: %s', mod.title, err) end

    local url, rel = self.repo:findModVersionToDownload(id, list)
    if not url then return logger.fmt('warn', 'Mod %s does not have URL downloads', title) end
    if not rel then logger.fmt('warn', 'Mod %s is downloading from source', title) end

    self:_queueTaskInstall(url, {
        name = title..' '..mod.version,
        blacklist = blacklistState
    })
end

--- @param mod imm.Mod
--- @param blacklistState? table<string>
function UISes:installMissingMods(mod, blacklistState)
    local missings = self.ctrl:getMissingDeps(mod.deps)
    for missingid, missingList in pairs(missings) do
        logger.fmt('log', 'Missing dependency %s by %s', missingid, mod.mod)
        util.createCo(self._installMissingModEntry, self, missingid, missingList, blacklistState)
    end
end

---@param blacklistState? table<string>
function UISes:installModFromZip(data, blacklistState)
    local modlist, list, errlist = self.ctrl:installFromZip(data)

    local strlist = {}
    for i,v in ipairs(list) do table.insert(strlist, table.concat({v.mod, v.version}, ' ')) end

    self.errorText = table.concat(errlist, '\n')
    self.taskText = #strlist ~= 0 and 'Installed '..table.concat(strlist, ', ') or ''

    if not self.noAutoDownloadMissing then
        for i, mod in ipairs(list) do
            self:installMissingMods(mod, blacklistState)
        end
    end

    return modlist, list, errlist
end

--- @alias imm.Browser.C p.Constructor<imm.Browser, nil> | fun(modctrl?: imm.ModController, modrepo?: imm.Repo): imm.Browser
--- @type imm.Browser.C
local UISes = constructor(UISes)
return UISes
