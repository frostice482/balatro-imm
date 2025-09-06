local constructor = require("imm.lib.constructor")
local LoveMoveable = require("imm.lib.love_moveable")
local repo = require("imm.repo")
local modctrl = require("imm.modctrl")

local function transformTagVersion(tag)
    if tag:sub(1, 1) == "v" then tag = tag:sub(2) end
    return tag
end

local function wrappedContainer(id, row)
    --- @type balatro.UIElement.Definition
    return {
        n = row and G.UIT.R or G.UIT.C,
        nodes = {{
            n = row and G.UIT.C or G.UIT.R,
            config = { id = id }
        }}
    }
end

function G.FUNCS.immses_restart()
    SMODS.restart_game()
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_setcat(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session
    local ses, cat = r.ses, r.cat

    ses.tags[cat] = not ses.tags[cat]
    elm.config.colour = ses.tags[cat] and G.C.ORANGE or G.C.RED
    ses:queueUpdate()
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_update(elm)
    --- @type imm.Session
    local ses = elm.config.ref_table

    if ses.prevSearch ~= ses.search then
        ses.prevSearch = ses.search
        ses:queueUpdate()
    end
end

--- @param elm balatro.UI.CycleCallbackParam
function G.FUNCS.immses_cycle(elm)
    --- @type imm.Session
    local ses = elm.cycle_config._ses

    ses.listPage = elm.to_key
    ses:updateMods()
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_choosemod(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session, bmi.Meta
    local ses, mod = r.ses, r.mod

    ses:selectMod(mod)
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_vdelete(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session, bmi.Meta, string
    local ses, mod, ver = r.ses, r.mod, r.ver

    G.FUNCS.overlay_menu({ definition = ses:uiDeleteMod(mod, ver) })
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_releases_init(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session, bmi.Meta
    local ses, mod = r.ses, r.mod
    elm.config.func = nil

    repo.getReleases(mod.repo, function (err, res)
        if not res then
            ses.errorText = err
            return
        end

        local pre
        local latest

        for i,v in ipairs(res) do
            if v.prerelease then pre = pre or v
            else latest = latest or v
            end
            if latest then break end
        end

        if pre then
            elm.UIBox:add_child(ses:uiVersionEntry({
                mod = mod,
                version = transformTagVersion(pre.tag_name),
                downloadUrl = pre.zipball_url
            }), elm)
        end
        if latest then
            elm.UIBox:add_child(ses:uiVersionEntry({
                mod = mod,
                version = transformTagVersion(latest.tag_name),
                downloadUrl = latest.zipball_url
            }), elm)
        end
    end)
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_vdownload(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session, bmi.Meta, string, string?, number?
    local ses, mod, ver, url, size = r.ses, r.mod, r.ver, r.durl, r.sizeinfo

    if not url then return end

    ses:queueTaskDownload(
        url,
        function (err) if not err then ses:updateSelectedMod(mod) end end,
        { name = mod.title..' '..ver, size = size }
    )
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_vtoggle(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session, bmi.Meta, string, boolean
    local ses, mod, ver, enabled = r.ses, r.mod, r.ver, r.toggle

    if enabled then modctrl:disableMod(mod.id)
    else modctrl:enableMod(mod.id, ver)
    end

    ses:updateSelectedMod(mod)
end

--- @param elm balatro.UIElement
function G.FUNCS.immses_delconf(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Session, boolean
    local ses, del = r.ses, r.del

    if del then
        modctrl:deleteMod(r.mod.id, r.ver)
        ses:updateSelectedMod()
    end

    G.FUNCS.overlay_menu({ definition = ses:container() })
    ses.uibox = G.OVERLAY_MENU
    ses:update()
    ses:updateSelectedMod()
end

--- @class imm.Session
--- @field uibox balatro.UIBox
--- @field tags table<string, boolean>
--- @field filteredList bmi.Meta[]
--- @field list table<string, bmi.Meta>
--- @field imageCache table<string, imm.LoveMoveable>
--- @field releasesCache table<string, ghapi.Releases>
--- @field selectedMod? bmi.Meta
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
    modEntryW = 16 * .25,
    thumbW = 16 * .2,
    thumbH = 9 * .2,
    w = 0,
    h = 0,
    fontscale = 0.4,

    ready = false,
    errorText = '',
    taskText = '',
    noThumbnail = false,
    taskDone = true,
    fonttemp = love.graphics.newText(G.LANG.font.FONT),

    idCycle = 'imm-cycle',
    idCycleCont = 'imm-cycle-cnt',
    idModSelect = 'imm-modslc',
    idModSelectCnt = 'imm-modslc-cnt',
    idMod = 'imm-mod',
    idImageContSuff = '-imgcnt',
    idImageSelectCnt = 'imm-modslc-imgcnt',
    idSelectReleases = 'imm-releases'
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

--- @class imm.Uises.QueueDownloadExtraInfo
--- @field name? string
--- @field size? number

--- @param url string
--- @param cb? fun(err?: string)
--- @param extra? imm.Uises.QueueDownloadExtraInfo
function UISes:queueTaskDownload(url, cb, extra)
    extra = extra or {}
    local name = extra.name or 'something'
    local size = extra.size

    self:queueTask(function ()
        self.taskText = string.format('Downloading %s\n(%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')
        repo.blob:fetch(url, function (err, res)
            if not res then
                err = err or 'unknown error'
                self.taskText = string.format('Failed downloading %s: %s', name, err)
                if cb then cb(err) end
            else
                local data = love.filesystem.newFileData(res, 'swap')
                modctrl:installModFromZip(data)
                self.taskText = string.format('Installed %s', name)
                if cb then cb(err) end
            end
            self:nextTask()
        end)
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
        config = {
            align = 'cm',
            minw = self.modEntryW,
            minh = 0.35
        },
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

--- @class imm.Uises.VersionParam
--- @field mod bmi.Meta
--- @field version? string
--- @field sub? string
--- @field installed? boolean
--- @field enabled? boolean
--- @field color? ColorHex
--- @field downloadUrl? string
--- @field downloadSize? number

--- @param opts imm.Uises.VersionParam
function UISes:uiVersionEntry(opts)
    opts.version = opts.version or opts.mod.version
    local l = modctrl.mods[opts.mod.id]
    if l then
        if opts.installed == nil then
            opts.installed = not not l.versions[opts.version]
        end
        if opts.enabled == nil then
            opts.enabled = l.active == opts.version
        end
    end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {
            colour = opts.color or opts.enabled and G.C.GREEN or G.C.BLUE,
            minw = 5,
            padding = 0.1,
            r = true,
            shadow = true,
        },
        nodes = {{
            n = G.UIT.C,
            nodes = {{
                n = G.UIT.R,
                nodes = {{
                    n = G.UIT.T, config = { text = opts.version, colour = G.C.UI.TEXT_LIGHT, scale = self.fontscale }
                }}
            }, opts.sub and {
                n = G.UIT.R,
                nodes = {{
                    n = G.UIT.T, config = { text = opts.sub, colour = G.C.UI.TEXT_LIGHT, scale = self.fontscale * 0.5 }
                }}
            }},
        }, opts.installed and {
            n = G.UIT.O,
            config = {
                object = Sprite(0, 0, self.fontscale * 15/9, self.fontscale, G.ASSET_ATLAS.imm_toggle, opts.enabled and { x = 1, y = 0 } or { x = 0, y = 0 }),
                button = 'immses_vtoggle',
                button_dist = 0.4,
                ref_table = { ses = self, mod = opts.mod, ver = opts.version, toggle = opts.enabled }
            }
        } or { n = G.UIT.C}, {
            n = G.UIT.O,
            config = {
                object = Sprite(0, 0, self.fontscale, self.fontscale, G.ASSET_ATLAS.imm_icons, opts.installed and { x = 0, y = 0 } or { x = 1, y = 0 }),
                button = opts.installed and 'immses_vdelete' or 'immses_vdownload',
                button_dist = 0.4,
                ref_table = { ses = self, mod = opts.mod, ver = opts.version, durl = opts.downloadUrl, dsize = opts.downloadSize }
            }
        }}
    }
end

--- @param mod bmi.Meta
function UISes:uiModSelectTabInstalled(mod)
    local list = {}
    local l = modctrl.mods[mod.id]
    if l then
        --- @type [string, imm.ModListVersion][]
        local version = {}
        for ver, info in pairs(l.versions) do table.insert(version, {ver, info}) end
        table.sort(version, function (a, b) return V(a[1]) < V(b[1]) end)

        for i, entry in ipairs(version) do
            local ver, info = entry[1], entry[2]
            table.insert(list, self:uiVersionEntry({
                mod = mod,
                version = ver,
                sub = info.path:sub(SMODS.MODS_DIR:len() + 2),
                installed = true,
                enabled = ver == l.active
            }))
        end
    end
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.C, nodes = list }
end

--- @param mod bmi.Meta
function UISes:uiModSelectTabReleases(mod)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { func = 'immses_releases_init', ref_table = { ses = self, mod = mod }  }
    }
end

--- @param mod bmi.Meta
function UISes:uiModSelectTabs(mod)
    local hasVersion = not not (modctrl.mods[mod.id] and next(modctrl.mods[mod.id].versions))

    --- @type balatro.UIElement.Definition
    return create_tabs({
        scale = self.fontscale * 1.5,
        text_scale = self.fontscale,
        snap_to_nav = true,

        tabs = {{
            chosen = hasVersion,
            label = 'Installed',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, nodes = {self:uiModSelectTabInstalled(mod)} }
            end
        }, {
            chosen = not hasVersion,
            label = 'Releases',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, nodes = {self:uiModSelectTabReleases(mod)} }
            end
        }, {
            label = 'Older',
            tab_definition_function = function (arg) return { n = G.UIT.ROOT } end
        }}
    })
end

--- @param mod bmi.Meta
function UISes:uiModSelect(mod)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = {
            group = self.idModSelect
        },
        nodes = {
            self:uiImage(self.idImageSelectCnt),
            self:uiModText(mod.title),
            self:uiModAuthor(mod.author),
            self:uiModSelectTabs(mod)
        }
    }
end

function UISes:uiModSelectContainer()
    return wrappedContainer(self.idModSelectCnt)
end

--- @param mod bmi.Meta
--- @param ver string
function UISes:uiDeleteMod(mod, ver)
    return create_UIBox_generic_options({
        contents = {{
            n = G.UIT.C,
            nodes = {{
                n = G.UIT.R,
                config = { padding = 0.2 },
                nodes = {{
                    n = G.UIT.T,
                    config = {
                        text = string.format('Really delete %s %s?', mod.title, mod.version),
                        scale = self.fontscale,
                        colour = G.C.UI.TEXT_LIGHT
                    },
                }}
            }, {
                n = G.UIT.R,
                nodes = {
                    UIBox_button({
                        button = 'immses_delconf',
                        col = true,
                        padding = 0,
                        scale = self.fontscale,
                        label = {'Yes'},
                        ref_table = { ses = self, del = true, mod = mod, ver = ver }
                    }),
                    UIBox_button({
                        button = 'immses_delconf',
                        col = true,
                        padding = 0,
                        scale = self.fontscale,
                        label = {'No'},
                        colour = HEX"777777",
                        ref_table = { ses = self, del = false }
                    })
                }
            }}
        }}
    })
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
            button = 'immses_setcat',
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
            button = 'immses_choosemod',
            ref_table = { ses = self, mod = mod }
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
        opt_callback = 'immses_cycle',
    })
    obj.config.group = self.idCycle
    return obj
end

function UISes:uiCycleContainer()
    local w = wrappedContainer(self.idCycleCont, true)
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
            id = 'imm-main',
            minw = self.w,
            minh = self.h,
            align = 'cr',
            func = 'immses_update',
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

    self.selectedMod = mod
    local cnt = self.uibox:get_UIE_by_ID(self.idModSelectCnt)
    if mod and cnt then self.uibox:add_child(self:uiModSelect(mod), cnt) end
end

--- @param ifMod? bmi.Meta
function UISes:updateSelectedMod(ifMod)
    if not ifMod or ifMod == self.selectedMod then
        return self:selectMod(self.selectedMod)
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
--- @param cb fun(err?: string, data?: imm.LoveMoveable)
function UISes:getImage(key, cb)
    if self.noThumbnail then return cb(nil, nil) end
    if self.imageCache[key] then return cb(nil, self.imageCache[key]) end
    repo.thumbnails:fetch(key, function (err, res, headers)
        if not res then return cb(err, res) end

        local ok, img = pcall(love.graphics.newImage, love.filesystem.newFileData(res, key))
        if ok then
            local inst = LoveMoveable(img, 0, 0, self.thumbW, self.thumbH)
            self.imageCache[key] = inst
            cb(nil, inst)
        end
    end)
end

--- @param id string
--- @param img balatro.Moveable
function UISes:uiUpdateImage(id, img)
    local imgcnt = self.uibox:get_UIE_by_ID(id)
    imgcnt.config.colour = G.C.WHITE
    if not imgcnt then return end

    self.uibox:add_child({
        n = G.UIT.O,
        config = { object = img }
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
end

function UISes:prepare()
    repo.list:fetch(nil, function (err, res, headers)
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

--- @alias imm.Session.C p.Constructor<imm.Session, nil> | fun(): imm.Session
--- @type imm.Session.C
local uisesc = constructor(UISes)
return uisesc
