local constructor = require('imm.lib.constructor')
local ui = require("imm.lib.ui")
local util = require("imm.lib.util")

--- @class imm.UI.Version.Funcs
local funcs = {
    deleteConfirm  = 'imm_v_delete_confirm',
    delete         = 'imm_v_delete',
    download       = 'imm_v_download',
    toggle         = 'imm_v_toggle',
    lock           = 'imm_v_lock',
}
local sprites = {
    switchOn = { x = 1, y = 0 },
    switchOff = { x = 0, y = 0 },
    iconDelete = { x = 0, y = 0 },
    iconDownload = { x = 1, y = 0 },
    iconUnLocked = { x = 0, y = 1 },
    iconLocked = { x = 1, y = 1 },
}

local thunderstoreColor = mix_colours(copy_table(G.C.BLUE), {1, 1, 1, 1}, 0.6)

--- @class imm.UI.Version.Opts
--- @field sub? string
--- @field installed? boolean
--- @field enabled? boolean
--- @field locked? boolean
--- @field color? ColorHex
--- @field tooltips? string[]
---
--- @field downloadUrl? string
--- @field downloadSize? number
--- @field releaseDate? string | number
--- @field downloadCount? number
--- @field hideInfo? boolean
--- @field noSync? boolean

--- @class imm.UI.Version
--- @field tooltips string[]
local IUIVer = {}

--- @protected
--- @param ses imm.UI.Browser
--- @param mod string
--- @param ver string
--- @param opts? imm.UI.Version.Opts
function IUIVer:init(ses, mod, ver, opts)
    opts = opts or {}
    self.ses = ses
    self.mod = mod
    self.ver = ver
    self.opts = opts
    self.sub = opts.sub or ''
    self.tooltips = self.opts.tooltips or {}
    if not opts.hideInfo then
        self:initInfo()
    end
    self:syncInfo()
end

function IUIVer:getMod()
    return self.ses.ctrl:getMod(self.mod, self.ver)
end

--- @protected
function IUIVer:initInfo()
    local opts = self.opts
    local extra = {}

    local rd = opts.releaseDate
    if type(rd) == "string" then rd = util.isotime(rd) end
    if rd then
        table.insert(extra, os.date("%x", rd))
    end

    if opts.downloadCount then
        table.insert(extra, string.format("%s downloads", opts.downloadCount))
    end

    if #extra ~= 0 then
        table.insert(self.tooltips, table.concat(extra, ' - '))
    end

    if opts.downloadUrl then
        local t = opts.downloadUrl
        if opts.downloadSize then t = string.format('%s (%.1fMB)', t, opts.downloadSize / 1048576) end
        table.insert(self.tooltips, 1, t)
    end
end

function IUIVer:partTitleConfig()
    local opts = self.opts
    --- @type balatro.UIElement.Config
    return {
        colour = G.C.UI.TEXT_LIGHT,
        scale = self.ses.fontscale,

        button = opts.installed and not opts.locked and funcs.toggle or nil,
        ref_table = opts.installed and not opts.locked and {
            ses = self,
            toggle = opts.enabled
        } or nil,
        tooltip = #self.tooltips ~= 0 and {
            text = self.tooltips,
            text_scale = self.ses.fontscale * 0.6
        } or nil,
    }
end

function IUIVer:partTitle()
    return ui.C{
        minw = self.ses.fontscale * 10,
        maxw = self.ses.fontscale * 10,
        ui.R{ ui.T(self.ver, self:partTitleConfig()) },
        self.sub and self.sub ~= '' and self.ses:uiTextRow(self.sub, 0.5) or nil
    }
end

function IUIVer:atlas(pos, atlas, wm, hm)
    return Sprite(0, 0, self.ses.fontscale * (wm or 1), self.ses.fontscale * (hm or 1), G.ASSET_ATLAS[atlas or 'imm_icons'], pos)
end

function IUIVer:partSwitchButton()
    local opts = self.opts
    if opts.locked or not opts.installed then return nil end

    local spr = self:atlas(opts.enabled and sprites.switchOn or sprites.switchOff, 'imm_toggle', 15/9, 1)
    return ui.O(spr, {
        button = funcs.toggle,
        button_dist = 0.4,
        ref_table = { ses = self, toggle = opts.enabled }
    })
end

function IUIVer:partActionsButton()
    local opts = self.opts
    if opts.locked or opts.enabled or not (opts.installed or opts.downloadUrl) then return nil end

    local spr = self:atlas(opts.installed and sprites.iconDelete or sprites.iconDownload)
    return ui.O(spr, {
        button = opts.installed and funcs.delete or funcs.download,
        button_dist = 0.4,
        ref_table = self
    })
end

function IUIVer:partLockButton()
    local opts = self.opts
    if not opts.installed then return nil end

    local spr = self:atlas(opts.locked and sprites.iconLocked or sprites.iconUnLocked)
    return ui.O(spr, {
        button = funcs.lock,
        button_dist = 0.4,
        ref_table = { ver = self, locked = opts.locked }
    })
end

function IUIVer:partActions()
    local list = {}
    table.insert(list, self:partSwitchButton())
    table.insert(list, self:partActionsButton())
    table.insert(list, self:partLockButton())

    return ui.C{
        minw = self.ses.fontscale * (15/9 + 1 + 1 + 2/5),
        align = 'cr',
        ui.R{
            align = 'c',
            nodes = ui.gapList('C', self.ses.fontscale / 5, list)
        }
    }
end

function IUIVer:syncInfo()
    local opts = self.opts
    if opts.noSync then return end
    local mod = self:getMod()
    if not mod then return end

    if opts.installed == nil then opts.installed = true end
    if opts.enabled == nil then opts.enabled = mod:isActive() end
    if opts.locked == nil then opts.locked = mod.isLocked end
end

function IUIVer:renderParts()
    return {
        self:partTitle(),
        self:partActions()
    }
end

function IUIVer:render()
    return ui.R{
        ui.R{
            colour = self.opts.color or self.opts.enabled and G.C.GREEN or G.C.BLUE,
            padding = 0.1,
            r = true,
            shadow = true,
            nodes = self:renderParts()
        },
        ui.gap('R', 0.1)
    }
end

--- @class imm.UI.Version.Static

--- @alias imm.UI.Version.C imm.UI.Version.Static | p.Constructor<imm.UI.Version, nil> | fun(ses: imm.UI.Browser, mod: string, ver: string, opts?: imm.UI.Version.Opts): imm.UI.Version
--- @type imm.UI.Version.C
local UIVer = constructor(IUIVer)

--- @class imm.UI.Version.Static
local UIVS = UIVer

UIVS.funcs = funcs

--- @param ses imm.UI.Browser
--- @param mod string
--- @param release imm.ModMeta.Release
function UIVS.fromRelease(ses, mod, release)
    return UIVer(ses, mod, release.version, {
        color = release.ts and thunderstoreColor or nil,
        downloadUrl = release.url,
        releaseDate = release.time,
        downloadCount = release.count
    })
end

--- @param ses imm.UI.Browser
--- @param mod string
--- @param asset ghapi.Releases.Assets
--- @param ver? string
function UIVS.fromGithubAsset(ses, mod, asset, ver)
    return UIVer(ses, mod, asset.name, {
        downloadSize = asset.size,
        downloadUrl = asset.browser_download_url,
        releaseDate = asset.updated_at,
        downloadCount = asset.download_count,
        enabled = false,
        installed = false
    })
end

return UIVer

