local constructor = require("imm.lib.constructor")
local LoveMoveable = require("imm.lib.love_moveable")
local ModBrowser = require("imm.modbrowser")
local repo = require("imm.repo")
local ui = require("imm.lib.ui")

local funcs = {
    setCategory = 'imm_ses_setcat',
    update      = 'imm_ses_update',
    cyclePage   = 'imm_ses_cycle',
    chooseMod   = 'imm_ses_choosemod',
    restartGame = 'imm_ses_restart'
}

G.FUNCS[funcs.restartGame] = function()
    SMODS.restart_game()
end

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

--- @class imm.Browser
--- @field uibox balatro.UIBox
--- @field tags table<string, boolean>
--- @field filteredList bmi.Meta[]
--- @field list table<string, bmi.Meta>
--- @field imageCache table<string, love.Image>
--- @field releasesCache table<string, ghapi.Releases>
--- @field selectedMod? imm.ModBrowser
--- @field taskQueues? fun()[]
local UISes = {
    search = '',
    prevSearch = '',
    queueTimer = 0.5,
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

    ready = false,
    errorText = '',
    taskText = '',
    noThumbnail = true,
    taskDone = true,
    fonttemp = love.graphics.newText(G.LANG.font.FONT),

    idCycle = 'imm-cycle',
    idCycleCont = 'imm-cycle-cnt',
    idModSelect = 'imm-modslc',
    idModSelectCnt = 'imm-modslc-cnt',
    idMod = 'imm-mod',
    idImageContSuff = '-imgcnt',
}

function UISes:init()
    self.tags = {}
    self.filteredList = {}
    self.list = {}
    self.categories = {
        {'Content'},
        {'Joker'},
        {'QoL', 'Quality of Life'},
        {'Technical'},
        {'Misc', 'Miscellaneous'},
        {'Resources', 'Resource Packs'},
        {'API'}
    }
    self.imageCache = {}
    self.releasesCache = {}
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

--- @param n number
function UISes:getModElmId(n)
    return 'imm-mod-'..n
end

--- @param n number
function UISes:getModElmCntId(n)
    return 'imm-mod-container-'..n
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
        config = { align = 'cm' },
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
        nodes = {{
            n = G.UIT.T,
            config = {
                text = 'By ' .. text,
                scale = self.fontscale * 0.75,
                colour = G.C.UI.TEXT_LIGHT,
            }
        }}
    }
end

function UISes:uiModSelectContainer()
    return ui.container(self.idModSelectCnt)
end

function UISes:uiHeaderInput()
    return create_text_input({
        ref_table = self,
        ref_value = 'search',
        w = 16 * .6,
        prompt_text = 'Mod name',
        text_scale = self.fontscale
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
        nodes = {{
            n = G.UIT.T,
            config = { text = label, scale = self.fontscale, colour = G.C.UI.TEXT_LIGHT }
        }}
    }
end

function UISes:uiSidebarExitButton()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.1, align = 'm' },
        nodes = {{
            n = G.UIT.C, config = { padding = 0.15, r = 0.1, hover = true, shadow = true, colour = G.C.PURPLE, button = 'exit_overlay_menu' },
            nodes = {{
                n = G.UIT.T, config = { text = "X", scale = self.fontscale, colour = G.C.UI.TEXT_LIGHT }
            }}
        }}
    }
end

function UISes:uiSidebar()
    local categories = {}

    table.insert(categories, self:uiSidebarExitButton())

    for i,entry in ipairs(self.categories) do
        table.insert(categories, self:uiCategory(entry[1], entry[2]))
    end

    --- @type balatro.UIElement.Definition
    return { n = G.UIT.C, nodes = categories }
end

--- @param mod bmi.Meta
--- @param n number
function UISes:uiModEntry(mod, n)
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
        },
        nodes = {
            self:uiImage(id .. self.idImageContSuff),
            self:uiModText(mod.title, self.thumbW),
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
    local opts = {}
    local n = math.max(math.ceil(#self.filteredList/(self.listW*self.listH)), 1)
    for i=1, n, 1 do
        table.insert(opts, string.format('%d/%d', i, n))
    end
    self.listPage = math.min(self.listPage, n)

    local obj = create_option_cycle({
        options = opts,
        current_option = self.listPage,
        ref_table = self,
        ref_value = 'listPage',
        _ses = self,
        opt_callback = funcs.cyclePage,
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
                scale = self.fontscale,
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
                scale = self.fontscale,
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

    self.selectedMod = ModBrowser(self, mod)
    self.uibox:add_child(self.selectedMod:container(), cnt)
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

--- @param mod bmi.Meta
function UISes:matchFilter(mod)
    if self.search and not mod.title:lower():find(self.search:lower()) then return false end

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

--- @param key string
--- @param cb fun(err?: string, data?: love.Image)
function UISes:getImage(key, cb)
    if self.noThumbnail then return cb(nil, nil) end
    if self.imageCache[key] then return cb(nil, self.imageCache[key]) end
    repo.thumbnails:fetch(key, function (err, res)
        if not res then return cb(err, res) end

        local ok, img = pcall(love.graphics.newImage, love.filesystem.newFileData(res, key))
        if ok then
            self.imageCache[key] = img
            cb(nil, img)
        end
    end)
end

--- @param id string
--- @param img love.Image
function UISes:uiUpdateImage(id, img)
    local imgcnt = self.uibox:get_UIE_by_ID(id)
    if not imgcnt then return end

    self.uibox:add_child({
        n = G.UIT.O,
        config = { object = LoveMoveable(img, 0, 0, self.thumbW, self.thumbH) }
    }, imgcnt)
end

--- @param mod bmi.Meta
--- @param id string
function UISes:updateModImage(mod, id)
    local aid = self.updateId
    self:getImage(mod.pathname, function (err, data)
        if not data or self.updateId ~= aid then
            if err then print(string.format("Error loading thumbnail %s: %s", mod.pathname, err)) end
            return
        end
        self:uiUpdateImage(id, data)
    end)
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
    self.uibox:remove_group(nil, self.idMod)
    local off = (self.listPage - 1) * self.listW * self.listH
    for i=1, self.listH * self.listW, 1 do
        self:updateMod(self.filteredList[i+off], i)
    end
end

function UISes:update()
    self.updateId = self.updateId + 1

    self.filteredList = {}
    for k, meta in pairs(self.list) do
        if self:matchFilter(meta) then
            table.insert(self.filteredList, meta)
        end
    end

    self.uibox:remove_group(nil, self.idCycle)

    local cyclecont = self.uibox:get_UIE_by_ID(self.idCycleCont)
    if cyclecont then self.uibox:add_child(self:uiCycle(), cyclecont) end

    self:updateMods()
    self:updateSelectedMod()
end

function UISes:prepare()
    repo.list:fetch(nil, function (err, res)
        if not res then
            self.errorText = err
            return
        end
        self.list = res
        self.ready = true
        self:update()
    end)
end

function UISes:container()
    return create_UIBox_generic_options({
        no_back = true,
        contents = { self:uiBrowse() }
    })
end

--- @alias imm.Browser.C p.Constructor<imm.Browser, nil> | fun(): imm.Browser
--- @type imm.Browser.C
local uisesc = constructor(UISes)
return uisesc
