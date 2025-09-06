local constructor = require("imm.lib.constructor")
local ui = require("imm.lib.ui")
local util = require("imm.lib.util")
local repo = require("imm.repo")
local modctrl = require("imm.modctrl")

local function transformTagVersion(tag)
    if tag:sub(1, 1) == "v" then tag = tag:sub(2) end
    return tag
end

local funcs = {
    v_deleteConfirm = 'imm_mses_version_delete_confirm',
    v_delete        = 'imm_mses_version_delete',
    v_download      = 'imm_mses_version_download',
    v_toggle        = 'imm_mses_version_toggle',
    releasesInit    = 'imm_mses_releases_init',
    otherInit       = 'imm_mses_other_init',
    otherCycle      = 'imm_mses_other_cycle',
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.releasesInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local ses = modses.ses
    local mod = modses.mod
    local uibox = elm.UIBox
    elm.config.func = nil

    modses.releasesBusy = true
    repo.getReleases(mod.repo, function (err, res)
        modses.releasesBusy = false
        util.remove_childrens(elm)

        if not res then
            ses.errorText = err
            return
        else
            local pre
            local latest

            for i,v in ipairs(res) do
                if v.prerelease then pre = pre or v
                else latest = latest or v
                end
                if latest then break end
            end

            if latest then
                uibox:add_child(modses:uiVersionEntry({
                    version = transformTagVersion(latest.tag_name),
                    downloadUrl = latest.zipball_url
                }), elm)
            end
            if pre then
                uibox:add_child(modses:uiVersionEntry({
                    version = transformTagVersion(pre.tag_name),
                    sub = 'Prerelease',
                    downloadUrl = pre.zipball_url
                }), elm)
            end
        end

        uibox:add_child(modses:uiVersionEntry({
            version = 'Source',
            sub = 'May be unstable!',
            downloadUrl = mod.downloadURL
        }), elm)

        uibox:recalculate()
        ses.uibox:recalculate()
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.otherInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local ses = modses.ses
    local mod = modses.mod
    local uibox = elm.UIBox
    elm.config.func = nil

    modses.releasesBusy = true
    repo.getReleases(mod.repo, function (err, res)
        modses.releasesBusy = false
        util.remove_childrens(elm)

        if not res then
            ses.errorText = err
            return
        end

        local opts = {}
        local n = math.max(math.ceil(#res / modses.otherCyclePageSize), 1)
        for i=1, n, 1 do table.insert(opts, string.format('%d/%d', i, n)) end

        local cycle = create_option_cycle({
            options = opts,
            current_option = 1,
            opt_callback = funcs.otherCycle,
            _list = res,
            _uibox = uibox,
            _ses = modses,
        })

        local vlist = {}
        for i=1, modses.otherCyclePageSize, 1 do
            local release = res[i]
            if not release then break end

            local t = modses:uiVersionEntry({
                version = transformTagVersion(release.tag_name),
                downloadUrl = release.zipball_url
            })
            table.insert(vlist, t)
        end

        --- @type balatro.UIElement.Definition
        local list = ui.container(modses.idOtherCycle, true, vlist)

        uibox:add_child(cycle, elm)
        uibox:add_child(list, elm)
        uibox:recalculate()
        ses.uibox:recalculate()
    end)
end

--- @param ev balatro.UI.CycleCallbackParam
G.FUNCS[funcs.otherCycle] = function(ev)
    local r = ev.cycle_config
    --- @type ghapi.Releases[], balatro.UIBox, imm.ModBrowser
    local list, uibox, ses = r._list, r._uibox, r._ses

    local listcnt = uibox:get_UIE_by_ID(ses.idOtherCycle)
    if not listcnt then return end

    util.remove_childrens(listcnt)
    local off = (ev.to_key - 1) * ses.otherCyclePageSize
    for i=1, ses.otherCyclePageSize, 1 do
        local release = list[i+off]
        if not release then break end

        local t = ses:uiVersionEntry({
            version = transformTagVersion(release.tag_name),
            downloadUrl = release.zipball_url
        })
        uibox:add_child(t, listcnt)
    end
    uibox:recalculate()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_download] = function(elm)
    -- { ses = self, ver = opts.version, durl = opts.downloadUrl, dsize = opts.downloadSize }
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser, string, string?, number?
    local modses, ver, url, size = r.ses, r.ver, r.durl, r.dsize

    if not url then return end

    modses:queueTaskDownload(
        url,
        function (err) if not err then modses.ses:updateSelectedMod(modses.mod) end end,
        { name = modses.mod.title..' '..ver, size = size }
    )
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_delete] = function(elm)
    -- { ses = self, ver = opts.version }
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser, string
    local modses, ver = r.ses, r.ver

    G.FUNCS.overlay_menu({ definition = modses:uiDeleteVersion(ver) })
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_toggle] = function(elm)
    -- { ses = self, ver = opts.version, toggle = opts.enabled }
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser, string, boolean
    local modses, ver, enabled = r.ses, r.ver, r.toggle

    if enabled then modctrl:disableMod(modses.mod.id)
    else modctrl:enableMod(modses.mod.id, ver)
    end

    modses.ses:updateSelectedMod(modses.mod)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_deleteConfirm] = function(elm)
    -- { ses = self, ver = ver }
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser
    local modses = r.ses
    local ses = modses.ses

    if r.confirm then
        modctrl:deleteMod(modses.mod.id, r.ver)
    end

    ses:showOverlay()
    ses:update()
end

--- @class imm.ModBrowser
--- @field ses imm.Browser
--- @field mod bmi.Meta
local UIModSes = {
    otherCyclePageSize = 8,
    idOtherCycle = 'imm-other-cycle',
    idImageSelectCnt = 'imm-slc-imgcnt',
    releasesBusy = false
}

--- @protected
--- @param ses imm.Browser
--- @param mod bmi.Meta
function UIModSes:init(ses, mod)
    self.ses = ses
    self.mod = mod
end

--- @class imm.ModSession.QueueDownloadExtraInfo
--- @field name? string
--- @field size? number

--- @param url string
--- @param cb? fun(err?: string)
--- @param extra? imm.ModSession.QueueDownloadExtraInfo
function UIModSes:queueTaskDownload(url, cb, extra)
    extra = extra or {}
    local name = extra.name or 'something'
    local size = extra.size
    local ses = self.ses

    self.ses:queueTask(function ()
        ses.taskText = string.format('Downloading %s\n(%s%s)', name, url, size and string.format(', %.1fMB', size / 1048576) or '')
        repo.blob:fetch(url, function (err, res)
            if not res then
                err = err or 'unknown error'
                ses.taskText = string.format('Failed downloading %s: %s', name, err)
                if cb then cb(err) end
            else
                ses:installModFromZip(love.filesystem.newFileData(res, 'swap'))
                if cb then cb(err) end
            end
            self.ses:nextTask()
        end)
    end)
end

--- @class imm.ModSession.VersionParam
--- @field version string
--- @field sub? string
--- @field installed? boolean
--- @field enabled? boolean
--- @field color? ColorHex
--- @field downloadUrl? string
--- @field downloadSize? number

--- @param opts imm.ModSession.VersionParam
function UIModSes:uiVersionEntry(opts)
    local l = modctrl.mods[self.mod.id]
    if l then
        if opts.installed == nil then
            opts.installed = not not l.versions[opts.version]
        end
        if opts.enabled == nil then
            opts.enabled = (l.active and l.active.version) == opts.version
        end
    end

    --- @type balatro.UIElement.Definition
    local title = {
        n = G.UIT.C,
        config = { minw = self.ses.fontscale * 8 },
        nodes = {{
            n = G.UIT.R,
            nodes = {{
                n = G.UIT.T, config = { text = opts.version, colour = G.C.UI.TEXT_LIGHT, scale = self.ses.fontscale }
            }}
        }, opts.sub and {
            n = G.UIT.R,
            nodes = {{
                n = G.UIT.T, config = { text = opts.sub, colour = G.C.UI.TEXT_LIGHT, scale = self.ses.fontscale * 0.5 }
            }}
        }},
    }

    --- @type balatro.UIElement.Definition
    local btnSwitch
    if opts.installed then btnSwitch = {
        n = G.UIT.O,
        config = {
            object = Sprite(0, 0, self.ses.fontscale * 15/9, self.ses.fontscale, G.ASSET_ATLAS.imm_toggle, opts.enabled and { x = 1, y = 0 } or { x = 0, y = 0 }),
            button = funcs.v_toggle,
            button_dist = 0.4,
            ref_table = { ses = self, ver = opts.version, toggle = opts.enabled }
        }
    } else btnSwitch = {
        n = G.UIT.C
    } end

    --- @type balatro.UIElement.Definition
    local btnAction
    if opts.installed or opts.downloadUrl then btnAction = {
        n = G.UIT.O,
        config = {
            object = Sprite(0, 0, self.ses.fontscale, self.ses.fontscale, G.ASSET_ATLAS.imm_icons, opts.installed and { x = 0, y = 0 } or { x = 1, y = 0 }),
            button = opts.installed and funcs.v_delete or funcs.v_download,
            button_dist = 0.4,
            ref_table = { ses = self, ver = opts.version, durl = opts.downloadUrl, dsize = opts.downloadSize }
        }
    } end

    --- @type balatro.UIElement.Definition
    local actions = {
        n = G.UIT.C,
        config = { minw = self.ses.fontscale * (15/9 + 1 + 1/5), align = 'cr' },
        nodes = {{
            n = G.UIT.R,
            config = { align = 'c' },
            nodes = {
                btnSwitch,
                { n = G.UIT.C, config = { minw = self.ses.fontscale / 5 } },
                btnAction
            }
        }}
    }

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {
            colour = opts.color or opts.enabled and G.C.GREEN or G.C.BLUE,
            padding = 0.1,
            r = true,
            shadow = true,
        },
        nodes = {title, actions}
    }
end

function UIModSes:uiModSelectTabInstalled()
    local list = {}
    local l = modctrl.mods[self.mod.id]
    if l then
        --- @type [string, imm.ModVersion.Entry][]
        local version = {}
        for ver, info in pairs(l.versions) do table.insert(version, {ver, info}) end
        table.sort(version, function (a, b) return V(a[1]) > V(b[1]) end)

        for i, entry in ipairs(version) do
            local ver, info = entry[1], entry[2]
            table.insert(list, self:uiVersionEntry({
                version = ver,
                sub = info.path:sub(SMODS.MODS_DIR:len() + 2),
                installed = true,
                enabled = ver == (l.active and l.active.version)
            }))
        end
    end
    --- @type balatro.UIElement.Definition
    return { n = G.UIT.C, nodes = list }
end

--- @param func string
function UIModSes:uiModReleasesContainer(func)
    local err
    if not self.mod.repo then err = 'Repo info\nunavailable' end
    if self.releasesBusy then err = 'Bust' end

    --- @type balatro.UIElement.Definition
    if err then return { n = G.UIT.T, config = { text = err, scale = self.ses.fontscale * 1.25, colour = G.C.ORANGE } } end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { func = func, ref_table = self },
        nodes = {{
            n = G.UIT.R,
            nodes = {{
                n = G.UIT.T,
                config = { text = 'Please wait', scale = self.ses.fontscale * 1.25, colour = G.C.UI.TEXT_LIGHT }
            }}
        }}
    }
end

local transparent = { 0, 0, 0, 0 }

function UIModSes:uiModSelectTabs()
    local mod = self.mod
    local hasVersion = not not ( modctrl.mods[mod.id] and next(modctrl.mods[mod.id].versions) )

    --- @type balatro.UIElement.Definition
    return create_tabs({
        scale = self.ses.fontscale * 1.5,
        text_scale = self.ses.fontscale,
        snap_to_nav = true,

        tabs = {{
            chosen = hasVersion,
            label = 'Installed',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, config = {colour = transparent}, nodes = {self:uiModSelectTabInstalled()} }
            end
        }, {
            chosen = not hasVersion,
            label = 'Releases',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, config = {colour = transparent}, nodes = {self:uiModReleasesContainer(funcs.releasesInit)} }
            end
        }, {
            label = 'Older',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, config = {colour = transparent}, nodes = {self:uiModReleasesContainer(funcs.otherInit)} }
            end
        }}
    })
end

function UIModSes:container()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { group = self.ses.idModSelect },
        nodes = {
            self.ses:uiImage(self.idImageSelectCnt),
            self.ses:uiModText(self.mod.title),
            self.ses:uiModAuthor(self.mod.author),
            self:uiModSelectTabs()
        }
    }
end

function UIModSes:update()
    self.ses:updateModImage(self.mod, self.idImageSelectCnt)
end

--- @param ver string
function UIModSes:uiDeleteVersionMessage(ver)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.2 },
        nodes = {{
            n = G.UIT.T,
            config = {
                text = string.format('Really delete %s %s?', self.mod.title, ver),
                scale = self.ses.fontscale,
                colour = G.C.UI.TEXT_LIGHT
            },
        }}
    }
end

--- @param ver string
function UIModSes:uiDeleteVersion(ver)
    return ui.confirm(
        self:uiDeleteVersionMessage(ver),
        funcs.v_deleteConfirm,
        { ses = self, ver = ver }
    )
end

--- @alias imm.ModBrowser.C p.Constructor<imm.ModBrowser, nil> | fun(ses: imm.Browser, mod: bmi.Meta): imm.ModBrowser
--- @type imm.ModBrowser.C
local uisesc = constructor(UIModSes)
return uisesc
