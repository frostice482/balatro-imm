local constructor = require("imm.lib.constructor")
local Repo = require("imm.lib.mod.repo")
local ui = require("imm.lib.ui")

local funcs = {
    v_deleteConfirm = 'imm_mses_version_delete_confirm',
    v_delete        = 'imm_mses_version_delete',
    v_download      = 'imm_mses_version_download',
    v_toggle        = 'imm_mses_version_toggle',
    openUrl         = 'imm_mses_openurl',
    releasesInit    = 'imm_mses_releases_init',
    otherInit       = 'imm_mses_other_init'
}


--- @param elm balatro.UIElement
G.FUNCS[funcs.openUrl] = function (elm)
    local r = elm.config.ref_table or {}
    love.system.openURL(r.url)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.releasesInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local ses = modses.ses
    local mod = modses.mod
    elm.config.func = nil

    ses.repo:getModReleases(mod, function (err, res)
        ui.removeChildrens(elm)
        modses:updateReleases(elm, err, res)
    end)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.otherInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local ses = modses.ses
    local mod = modses.mod
    elm.config.func = nil

    ses.repo:getModReleases(mod, function (err, res)
        ui.removeChildrens(elm)
        modses:updateOther(elm, err ,res)
    end)
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
    local ses = modses.ses
    local mod = modses.mod

    local ok, err
    if enabled then ok, err = ses.modctrl:disable(mod.id)
    else ok, err = ses.modctrl:enable(mod.id, ver)
    end

    ses.errorText = err or ''
    ses:updateSelectedMod(mod)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.v_deleteConfirm] = function(elm)
    -- { ses = self, ver = ver }
    local r = elm.config.ref_table or {}
    --- @type imm.ModBrowser
    local modses = r.ses
    local ses = modses.ses

    if r.confirm then
        local ok, err = ses.modctrl:uninstall(modses.mod.id, r.ver)
        ses.errorText = err or ''
    end

    ses:showOverlay(true)
end

--- @class imm.ModBrowser
--- @field ses imm.Browser
--- @field mod bmi.Meta
local UIModSes = {
    cyclePageSize = 8,
    idListCnt = 'imm-other-cycle',
    idImageSelectCnt = 'imm-slc-imgcnt'
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
        ses.repo.api.blob:fetch(url, function (err, res)
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
function UIModSes:uiVersionTitle(opts)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { minw = self.ses.fontscale * 10 },
        nodes = {{
            n = G.UIT.R,
            nodes = {{
                n = G.UIT.T,
                config = {
                    text = opts.version,
                    colour = G.C.UI.TEXT_LIGHT,
                    scale = self.ses.fontscale,

                    button = opts.installed and funcs.v_toggle or nil,
                    ref_table = opts.installed and { ses = self, ver = opts.version, toggle = opts.enabled} or nil,
                    tooltip = opts.downloadUrl and { text = {{ ref_table = {opts.downloadUrl}, ref_value = 1 }}, text_scale = self.ses.fontscale * 0.6 },
                }
            }}
        }, opts.sub and {
            n = G.UIT.R,
            nodes = {self.ses:uiText(opts.sub, 0.5)}
        }},
    }
end

--- @param opts imm.ModSession.VersionParam
function UIModSes:uiVersionSwitchBtn(opts)
    --- @type balatro.UIElement.Definition
    if not opts.installed then return { n = G.UIT.C } end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.O,
        config = {
            object = Sprite(0, 0, self.ses.fontscale * 15/9, self.ses.fontscale, G.ASSET_ATLAS.imm_toggle, opts.enabled and { x = 1, y = 0 } or { x = 0, y = 0 }),
            button = funcs.v_toggle,
            button_dist = 0.4,
            ref_table = { ses = self, ver = opts.version, toggle = opts.enabled }
        }
    }
end

--- @param opts imm.ModSession.VersionParam
function UIModSes:uiVersionActionBtn(opts)
    if not (opts.installed or opts.downloadUrl) then return end
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.O,
        config = {
            object = Sprite(0, 0, self.ses.fontscale, self.ses.fontscale, G.ASSET_ATLAS.imm_icons, opts.installed and { x = 0, y = 0 } or { x = 1, y = 0 }),
            button = opts.installed and funcs.v_delete or funcs.v_download,
            button_dist = 0.4,
            ref_table = { ses = self, ver = opts.version, durl = opts.downloadUrl, dsize = opts.downloadSize }
        }
    }
end

--- @param opts imm.ModSession.VersionParam
function UIModSes:uiVersionActions(opts)
    local list = {}
    local switch = self:uiVersionSwitchBtn(opts)
    if switch then table.insert(list, switch) end
    local action = self:uiVersionActionBtn(opts)
    if action then table.insert(list, action) end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { minw = self.ses.fontscale * (15/9 + 1 + 1/5), align = 'cr' },
        nodes = {{
            n = G.UIT.R,
            config = { align = 'c' },
            nodes = ui.gapList('C', self.ses.fontscale / 5, list)
        }}
    }
end

--- @param opts imm.ModSession.VersionParam
function UIModSes:uiVersion(opts)
    local l = self.ses.modctrl.mods[self.mod.id]
    if l then
        if opts.installed == nil then
            opts.installed = not not l.versions[opts.version]
        end
        if opts.enabled == nil then
            opts.enabled = (l.active and l.active.version) == opts.version
        end
    end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {
            colour = opts.color or opts.enabled and G.C.GREEN or G.C.BLUE,
            padding = 0.1,
            r = true,
            shadow = true,
        },
        nodes = {
            self:uiVersionTitle(opts),
            self:uiVersionActions(opts)
        }
    }
end

function UIModSes:uiTabInstalled()
    local l = self.ses.modctrl.mods[self.mod.id]
    if not l or not next(l.versions) then return self.ses:uiText('No installed\nversions', 1.25, G.C.ORANGE) end

    --- @type imm.Mod[]
    local versions = {}
    for ver, info in pairs(l.versions) do table.insert(versions, info) end
    table.sort(versions, function (a, b) return a.versionParsed > b.versionParsed end)

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        nodes = {
            self:uiCycle(#versions, function (i)
                local info = versions[i]
                return info and self:uiVersion({
                    version = info.version,
                    sub = info.path:sub(require('imm.config').modsDir:len() + 2),
                    installed = true
                })
            end),
            ui.container(self.idListCnt, true)
        }
    }
end

--- @param func string
function UIModSes:uiReleasesContainer(func)
    if not self.mod.repo then return self.ses:uiText("Repo info\nunavailable", 1.25, G.C.ORANGE) end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { func = func, ref_table = self },
        nodes = {{
            n = G.UIT.R,
            nodes = {self.ses:uiText('Please wait', 1.25)}
        }}
    }
end

--- @param elm balatro.UIElement
--- @param err? string
--- @param res? ghapi.Releases[]
function UIModSes:updateReleases(elm, err, res)
    --- @type imm.ModSession.VersionParam[]
    local list = {}

    if not res then
        self.ses.errorText = err or ''
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
            table.insert(list, {
                version = Repo.transformTagVersion(latest.tag_name),
                downloadUrl = latest.zipball_url
            })
        end
        if pre then
            table.insert(list, {
                version = Repo.transformTagVersion(pre.tag_name),
                sub = 'Prerelease',
                downloadUrl = pre.zipball_url
            })
        end
    end

    table.insert(list, {
        version = 'Source',
        sub = self.mod.version..' - Potentially unstable!',
        downloadUrl = self.mod.downloadURL
    })

    self:uiAdd(elm, #list, function (i)
        local info = list[i]
        return info and self:uiVersion(info)
    end)
end

--- @param elm balatro.UIElement
--- @param err? string
--- @param res? ghapi.Releases[]
function UIModSes:updateOther(elm, err, res)
    if not res then
        self.ses.errorText = err or ''
        return
    end

    self:uiAdd(elm, #res, function (i)
        local info = res[i]
        return info and self:uiVersion({
            version = Repo.transformTagVersion(info.tag_name),
            downloadUrl = info.zipball_url
        })
    end)
end

--- @param elm balatro.UIElement
--- @param len number
--- @param func fun(i: number): balatro.UIElement.Definition?
function UIModSes:uiAdd(elm, len, func)
    local uibox = elm.UIBox
    uibox:add_child(self:uiCycle(len, func), elm)
    uibox:add_child(ui.container(self.idListCnt, true), elm)
    uibox:recalculate()
    self.ses.uibox:recalculate()
end

--- @param len number
--- @param func fun(i: number): balatro.UIElement.Definition?
function UIModSes:uiCycle(len, func)
    return ui.cycle({
        func = func,
        length = len,
        id = self.idListCnt,
        pagesize = self.cyclePageSize,
        onCycle = function () self.ses.uibox:recalculate() end
    }, { no_pips = true })
end

function UIModSes:uiTabs()
    local mod = self.mod
    local hasVersion = not not ( self.ses.modctrl.mods[mod.id] and next(self.ses.modctrl.mods[mod.id].versions) )

    --- @type balatro.UIElement.Definition
    return create_tabs({
        scale = self.ses.fontscale * 1.5,
        text_scale = self.ses.fontscale,
        snap_to_nav = true,

        tabs = {{
            chosen = hasVersion,
            label = 'Installed',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, config = {colour = G.C.CLEAR}, nodes = {self:uiTabInstalled()} }
            end
        }, {
            chosen = not hasVersion,
            label = 'Releases',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, config = {colour = G.C.CLEAR}, nodes = {self:uiReleasesContainer(funcs.releasesInit)} }
            end
        }, {
            label = 'Older',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, config = {colour = G.C.CLEAR}, nodes = {self:uiReleasesContainer(funcs.otherInit)} }
            end
        }}
    })
end

function UIModSes:uiRepoButton()
    if not self.mod.repo then
        --- @type balatro.UIElement.Definition
        return { n = G.UIT.R, config = {} }
    end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.1, align = 'm' },
        nodes = {{
            n = G.UIT.C,
            config = {
                colour = G.C.PURPLE,
                padding = 0.1,
                shadow = true,
                button = funcs.openUrl,
                ref_table = { url = self.mod.repo },
                r = true,
                button_dist = 0.1,
                tooltip = {
                    text = { self.mod.repo },
                    text_scale = self.ses.fontscale * 0.8
                }
            },
            nodes = {self.ses:uiText('Repo')}
        }}
    }
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
            self:uiRepoButton(),
            self:uiTabs()
        }
    }
end

function UIModSes:update()
    self.ses:updateModImage(self.mod, self.idImageSelectCnt, true)
end

--- @param ver string
function UIModSes:uiDeleteVersionMessage(ver)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.2 },
        nodes = {self.ses:uiText(string.format('Really delete %s %s?', self.mod.title, ver))}
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
local UIModSes = constructor(UIModSes)
return UIModSes
