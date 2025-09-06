local constructor = require("imm.lib.constructor")
local ui = require("imm.lib.ui")
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
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.releasesInit] = function(elm)
    --- @type imm.ModBrowser
    local modses = elm.config.ref_table
    local ses = modses.ses
    local mod = modses.mod
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
            elm.UIBox:add_child(modses:uiVersionEntry({
                version = transformTagVersion(pre.tag_name),
                downloadUrl = pre.zipball_url
            }), elm)
        end
        if latest then
            elm.UIBox:add_child(modses:uiVersionEntry({
                version = transformTagVersion(latest.tag_name),
                downloadUrl = latest.zipball_url
            }), elm)
        end
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

    G.FUNCS.overlay_menu({ definition = ses:container() })
    ses.uibox = G.OVERLAY_MENU
    ses:update()
end

--- @class imm.ModBrowser
--- @field ses imm.Browser
--- @field mod bmi.Meta
local UIModSes = {
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

    self.ses:queueTask(function ()
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
            self.ses:nextTask()
        end)
    end)
end

--- @class imm.ModSession.VersionParam
--- @field version? string
--- @field sub? string
--- @field installed? boolean
--- @field enabled? boolean
--- @field color? ColorHex
--- @field downloadUrl? string
--- @field downloadSize? number

--- @param opts imm.ModSession.VersionParam
function UIModSes:uiVersionEntry(opts)
    opts.version = opts.version or self.mod.version
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
                    n = G.UIT.T, config = { text = opts.version, colour = G.C.UI.TEXT_LIGHT, scale = self.ses.fontscale }
                }}
            }, opts.sub and {
                n = G.UIT.R,
                nodes = {{
                    n = G.UIT.T, config = { text = opts.sub, colour = G.C.UI.TEXT_LIGHT, scale = self.ses.fontscale * 0.5 }
                }}
            }},
        }, opts.installed and {
            n = G.UIT.O,
            config = {
                object = Sprite(0, 0, self.ses.fontscale * 15/9, self.ses.fontscale, G.ASSET_ATLAS.imm_toggle, opts.enabled and { x = 1, y = 0 } or { x = 0, y = 0 }),
                button = funcs.v_toggle,
                button_dist = 0.4,
                ref_table = { ses = self, ver = opts.version, toggle = opts.enabled }
            }
        } or { n = G.UIT.C}, {
            n = G.UIT.O,
            config = {
                object = Sprite(0, 0, self.ses.fontscale, self.ses.fontscale, G.ASSET_ATLAS.imm_icons, opts.installed and { x = 0, y = 0 } or { x = 1, y = 0 }),
                button = opts.installed and funcs.v_delete or funcs.v_download,
                button_dist = 0.4,
                ref_table = { ses = self, ver = opts.version, durl = opts.downloadUrl, dsize = opts.downloadSize }
            }
        }}
    }
end

function UIModSes:uiModSelectTabInstalled()
    local list = {}
    local l = modctrl.mods[self.mod.id]
    if l then
        --- @type [string, imm.ModVersion.Entry][]
        local version = {}
        for ver, info in pairs(l.versions) do table.insert(version, {ver, info}) end
        table.sort(version, function (a, b) return V(a[1]) < V(b[1]) end)

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

function UIModSes:uiModSelectTabReleases()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { func = funcs.releasesInit, ref_table = self }
    }
end

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
                return { n = G.UIT.ROOT, nodes = {self:uiModSelectTabInstalled()} }
            end
        }, {
            chosen = not hasVersion,
            label = 'Releases',
            tab_definition_function = function (arg)
                return { n = G.UIT.ROOT, nodes = {self:uiModSelectTabReleases()} }
            end
        }, {
            label = 'Older',
            tab_definition_function = function (arg) return { n = G.UIT.ROOT } end
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
