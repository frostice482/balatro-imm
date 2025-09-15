local constructor = require("imm.lib.constructor")
local LoveMoveable = require("imm.lib.love_moveable")
local UIMod = require("imm.ui.mod")
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

--- @class imm.UI.Browser
--- @field uibox balatro.UIBox
--- @field tags table<string, boolean>
--- @field filteredList imm.ModMeta[]
--- @field selectedMod? imm.UI.Mod
--- @field taskQueues? fun()[]
--- @field ctrl imm.ModController
local IUISes = {
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
    hasChanges = false,

    idCycle = 'imm-cycle',
    idCycleCont = 'imm-cycle-cnt',
    idModSelect = 'imm-modslc',
    idModSelectCnt = 'imm-modslc-cnt',
    idMod = 'imm-mod',
    idImageContSuff = '-imgcnt'
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
    self.taskQueues = {}
end

function IUISes:nextTask()
    self.taskDone = true
    local f = table.remove(self.taskQueues, 1)
    if not f then return end
    self.taskDone = false
    f()
end

--- @param func fun()
function IUISes:queueTask(func)
    table.insert(self.taskQueues, func)
    if self.taskDone then self:nextTask() end
end

function IUISes:queueTaskCo()
    co.wrapCallbackStyle(function (res)
        if self.taskDone then
            self.taskDone = false
            res()
            return
        end
        table.insert(self.taskQueues, res)
    end)
end

--- @param n number
function IUISes:getModElmId(n)
    return 'imm-mod-'..n
end

--- @param n number
function IUISes:getModElmCntId(n)
    return 'imm-mod-container-'..n
end

--- @param text string
--- @param scale? number
--- @param col? ColorHex
function IUISes:uiText(text, scale, col)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.T,
        config = { text = text, scale = self.fontscale * (scale or 1), colour = col or G.C.UI.TEXT_LIGHT }
    }
end

--- @param id string
function IUISes:uiImage(id)
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
function IUISes:uiModText(title, maxw)
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

function IUISes:uiModSelectContainer()
    return ui.container(self.idModSelectCnt)
end

function IUISes:uiCategory(label, category)
    category = category or label
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { minh = self.fontscale * 1.6 },
        nodes = {{
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
        }}
    }
end

--- @type balatro.UIElement.Config
local someWeirdBase = { padding = 0.15, r = 0.1, hover = true, shadow = true, colour = G.C.BLUE }

function IUISes:uiSidebarHeaderExit()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = setmetatable({ tooltip = { text = {'Exit'} }, button = 'exit_overlay_menu' }, {__index = someWeirdBase}),
        nodes = {self:uiText('X')}
    }
end

function IUISes:uiSidebarHeaderRefresh()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = setmetatable({ tooltip = { text = {'Refresh'} }, button = funcs.refresh, ref_table = self }, {__index = someWeirdBase}),
        nodes = {self:uiText('R')}
    }
end

function IUISes:uiSidebarHeaderOptions()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = setmetatable({ tooltip = { text = {'More Options'} }, button = funcs.options, ref_table = self }, {__index = someWeirdBase}),
        nodes = {self:uiText('O')}
    }
end

function IUISes:uiSidebarHeader()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.1, align = 'm' },
        nodes = {
            self:uiSidebarHeaderExit(),
            ui.gap('C', self.fontscale / 8),
            self:uiSidebarHeaderRefresh(),
            ui.gap('C', self.fontscale / 8),
            self:uiSidebarHeaderOptions(),
        }
    }
end

function IUISes:uiSidebar()
    local categories = {}

    table.insert(categories, self:uiSidebarHeader())

    for i,entry in ipairs(self.categories) do
        table.insert(categories, self:uiCategory(entry[1], entry[2]))
    end

    --- @type balatro.UIElement.Definition
    return { n = G.UIT.C, nodes = categories }
end

--- @param mod imm.ModMeta
--- @param n number
function IUISes:uiModEntry(mod, n)
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
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'cm', padding = 0.1 },
        nodes = {
            self:uiHeaderInput()
        }
    }
end

function IUISes:uiMain()
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

function IUISes:uiBody()
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

function IUISes:uiCycle()
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

function IUISes:uiCycleContainer()
    local w = ui.container(self.idCycleCont, true)
    w.config = {
        align = 'cm',
        padding = 0.1
    }
    return w
end

function IUISes:uiErrorContainer()
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

function IUISes:uiTaskContainer()
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

function IUISes:uiBrowse()
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

--- @param mod? imm.ModMeta
function IUISes:selectMod(mod)
    if self.selectedMod then self.uibox:remove_group(nil, self.idModSelect) end
    local cnt = self.uibox:get_UIE_by_ID(self.idModSelectCnt)
    if not mod or not cnt then return end

    local modses = UIMod(self, mod)
    self.selectedMod = modses
    self.uibox:add_child(modses:render(), cnt)
    modses:update()
end

--- @param ifMod? imm.ModMeta
function IUISes:updateSelectedMod(ifMod)
    local mod = self.selectedMod and self.selectedMod.mod
    if not ifMod or ifMod == mod then
        return self:selectMod(mod)
    end
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

--- @param containerId string
--- @param img love.Image
function IUISes:uiUpdateImage(containerId, img)
    local imgcnt = self.uibox:get_UIE_by_ID(containerId)
    if not imgcnt then return end

    local w, h = img:getDimensions()
    local aspectRatio = math.max(math.min(w / h, 16/9), 1)

    self.uibox:add_child({
        n = G.UIT.O,
        config = { object = LoveMoveable(img, 0, 0, self.thumbH * aspectRatio, self.thumbH) }
    }, imgcnt)
end

--- @protected
--- @param mod imm.ModMeta
--- @param containerId string
--- @param nocheckUpdate? boolean
function IUISes:_updateModImageCo(mod, containerId, nocheckUpdate)
    local aid = self.updateId
    local err, data = mod:getImageCo()
    if not data or not nocheckUpdate and self.updateId ~= aid then return end
    self:uiUpdateImage(containerId, data)
end

--- @param mod imm.ModMeta
--- @param containerId string
--- @param nocheckUpdate? boolean
function IUISes:updateModImage(mod, containerId, nocheckUpdate)
    co.create(self._updateModImageCo, self, mod, containerId, nocheckUpdate)
end

--- @param mod? imm.ModMeta
--- @param n number
function IUISes:updateMod(mod, n)
    local cont = self.uibox:get_UIE_by_ID(self:getModElmCntId(n))
    if not cont or not mod then return end

    self.uibox:add_child(self:uiModEntry(mod, n), cont)
    self:updateModImage(mod, self:getModElmId(n)..self.idImageContSuff)
end

function IUISes:updateMods()
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
    self.uibox:remove_group(nil, self.idCycle)

    self:updateFilter()

    local cyclecont = self.uibox:get_UIE_by_ID(self.idCycleCont)
    if cyclecont then self.uibox:add_child(self:uiCycle(), cyclecont) end

    self:updateMods()

    self.uibox:recalculate()
end

--- @protected
--- @param err? string
function IUISes:_updateList(err)
    if err then
        self.errorText = string.format('Failed getting list for BMI: %s', err)
        logger.fmt('error', self.errorText)
        return
    end
    self:update()
    pseudoshuffle(self.repo.list, math.random())
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
    return create_UIBox_generic_options({
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

--- @class imm.ModSession.QueueDownloadExtraInfo
--- @field name? string
--- @field size? number
--- @field blacklist? table<string>
--- @field cb? fun(err?: string)

--- @protected
--- @param url string
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function IUISes:_queueTaskInstallCo(url, extra)
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
function IUISes:queueTaskInstall(url, extra)
    co.create(self._queueTaskInstallCo, self, url, extra)
end

--- @protected
--- @param id string
--- @param list imm.Dependency.Rule[][]
--- @param blacklistState? table<string>
function IUISes:_installMissingModEntryCo(id, list, blacklistState)
    local mod = self.repo:getMod(id)
    if not mod then return logger.fmt('warn', 'Mod id %s does not exist in repo', id) end

    mod:getReleasesCo()
    local release, pre = mod:findModVersionToDownload(list)
    if not release then
        logger.fmt('warn', 'Failed to download missing dependencies %s', mod:title())
        return
    end

    if pre then
        logger.fmt('warn', 'A prerelease version %s %s is being downloaded', mod:title(), release.version)
    end

    self:_queueTaskInstallCo(release.url, {
        name = mod:title()..' '..release.version,
        blacklist = blacklistState
    })
end

--- @param id string
--- @param list imm.Dependency.Rule[][]
--- @param blacklistState? table<string>
function IUISes:installMissingModEntry(id, list, blacklistState)
    co.create(self._installMissingModEntryCo, self, id, list, blacklistState)
end

--- @param mod imm.Mod
--- @param blacklistState? table<string>
function IUISes:installMissingMods(mod, blacklistState)
    local missings = self.ctrl:getMissingDeps(mod.deps)
    for missingid, missingList in pairs(missings) do
        logger.fmt('log', 'Missing dependency %s by %s', missingid, mod.mod)
        self:installMissingModEntry(missingid, missingList, blacklistState)
    end
end

---@param blacklistState? table<string>
function IUISes:installModFromZip(data, blacklistState)
    local modlist, list, errlist = self.ctrl:installFromZip(data)

    local strlist = {}
    for i,v in ipairs(list) do table.insert(strlist, v.mod..' '..v.version) end

    self.errorText = table.concat(errlist, '\n')
    self.taskText = #strlist ~= 0 and 'Installed '..table.concat(strlist, ', ') or 'Nothing is installed - Check that the zip has a valid metadata file'

    if not self.noAutoDownloadMissing then
        for i, mod in ipairs(list) do
            self:installMissingMods(mod, blacklistState)
        end
    end

    return modlist, list, errlist
end

--- @class imm.UI.Browser.Static
--- @field funcs imm.UI.Browser.Funcs

--- @alias imm.UI.Browser.C imm.UI.Browser.Static | p.Constructor<imm.UI.Browser, nil> | fun(modctrl?: imm.ModController, modrepo?: imm.Repo): imm.UI.Browser
--- @type imm.UI.Browser.C
local UISes = constructor(IUISes)
UISes.funcs = funcs
return UISes
