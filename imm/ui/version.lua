local constructor = require('imm.lib.constructor')
local ui = require("imm.lib.ui")

--- @class imm.UI.Version.Funcs
local funcs = {
    deleteConfirm  = 'imm_v_delete_confirm',
    delete         = 'imm_v_delete',
    download       = 'imm_v_download',
    toggle         = 'imm_v_toggle',
}

local betaColor = G.C.ORANGE
local thunderstoreColor = mix_colours(copy_table(G.C.BLUE), {1, 1, 1, 1}, 0.6)

--- @class imm.UI.Version.Opts
--- @field sub? string
--- @field installed? boolean
--- @field enabled? boolean
--- @field color? ColorHex
--- @field downloadUrl? string
--- @field downloadSize? number

--- @class imm.UI.Version
local IUIVer = {}

--- @protected
--- @param ses imm.UI.Browser
--- @param mod string
--- @param ver string
--- @param opts? imm.UI.Version.Opts
function IUIVer:init(ses, mod, ver, opts)
    self.ses = ses
    self.mod = mod
    self.ver = ver
    self.opts = opts or {}
end

function IUIVer:partTitle()
    local opts = self.opts
    local downText = opts.downloadUrl
    if downText and opts.downloadSize then downText = string.format('%s (%.1fMB)', downText, opts.downloadSize / 1048576) end

    return ui.C{
        minw = self.ses.fontscale * 10,
        ui.R{
            ui.T(self.ver, {
                colour = G.C.UI.TEXT_LIGHT,
                scale = self.ses.fontscale,

                button = opts.installed and funcs.toggle or nil,
                ref_table = opts.installed and {
                    ses = self,
                    toggle = opts.enabled
                } or nil,
                tooltip = opts.downloadUrl and {
                    text = {{ ref_table = { downText }, ref_value = 1 }},
                    text_scale = self.ses.fontscale * 0.6
                },
            })
        },
        opts.sub and self.ses:uiTextRow(opts.sub, 0.5)
    }
end

function IUIVer:partSwitchButton()
    local opts = self.opts
    if not opts.installed then return end

    local spr = Sprite(0, 0, self.ses.fontscale * 15/9, self.ses.fontscale, G.ASSET_ATLAS.imm_toggle, opts.enabled and { x = 1, y = 0 } or { x = 0, y = 0 })
    return ui.O(spr, {
        button = funcs.toggle,
        button_dist = 0.4,
        ref_table = { ses = self, toggle = opts.enabled }
    })
end

function IUIVer:partActionsButton()
    local opts = self.opts
    if opts.enabled or not (opts.installed or opts.downloadUrl) then return end

    local spr = Sprite(0, 0, self.ses.fontscale, self.ses.fontscale, G.ASSET_ATLAS.imm_icons, opts.installed and { x = 0, y = 0 } or { x = 1, y = 0 })
    return ui.O(spr, {
        button = opts.installed and funcs.delete or funcs.download,
        button_dist = 0.4,
        ref_table = self
    })
end

function IUIVer:partActions()
    local list = {}
    local switch = self:partSwitchButton()
    if switch then table.insert(list, switch) end
    local action = self:partActionsButton()
    if action then table.insert(list, action) end

    return ui.C{
        minw = self.ses.fontscale * (15/9 + 1 + 1/5),
        align = 'cr',
        ui.R{
            align = 'c',
            nodes = ui.gapList('C', self.ses.fontscale / 5, list)
        }
    }
end

function IUIVer:render()
    local opts = self.opts
    local l = self.ses.ctrl.mods[self.mod]
    if l then
        if opts.installed == nil then opts.installed = not not l.versions[self.ver] end
        if opts.enabled == nil then opts.enabled = (l.active and l.active.version) == self.ver end
    end

    local uis = {
        self:partTitle(),
        self:partActions()
    }

    return ui.R{
        minh = self.ses.fontscale * 1.8,
        ui.R{
            colour = opts.color or opts.enabled and G.C.GREEN or G.C.BLUE,
            padding = 0.1,
            r = true,
            shadow = true,
            nodes = uis
        }
    }
end

--- @class imm.UI.Version.Static
--- @field funcs imm.UI.Version.Funcs
--- @field fromRelease fun(ses: imm.UI.Browser, mod: string, release: imm.ModMeta.Release): imm.UI.Version

--- @alias imm.UI.Version.C imm.UI.Version.Static | p.Constructor<imm.UI.Version, nil> | fun(ses: imm.UI.Browser, mod: string, ver: string, opts?: imm.UI.Version.Opts): imm.UI.Version
--- @type imm.UI.Version.C
local UIVer = constructor(IUIVer)

UIVer.funcs = funcs

function UIVer.fromRelease(ses, mod, release)
    local l = ses.ctrl.mods[mod]
    local ver = release.version

    local installed, enabled
    if l then
        installed = not not l.versions[ver]
        enabled = (l.active and l.active.version) == ver
    end

    return UIVer(ses, mod, ver, {
        color = release.isPre and betaColor or release.ts and thunderstoreColor or nil,
        downloadSize = release.size,
        downloadUrl = release.url,
        enabled = enabled,
        installed = installed
    })
end

return UIVer

