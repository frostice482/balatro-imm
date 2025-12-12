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
    hide           = 'imm_v_hide',
    init           = 'imm_v_init',
}
local sprites = {
    switchOn = { x = 1, y = 0 },
    switchOff = { x = 0, y = 0 },
    delete = { x = 0, y = 0 },
    download = { x = 1, y = 0 },
    unlocked = { x = 0, y = 1 },
    locked = { x = 1, y = 1 },
}

local thunderstoreColor = mix_colours(copy_table(G.C.BLUE), {1, 1, 1, 1}, 0.6)

--- @class imm.UI.Version.Opts
--- @field sub? string
--- @field color? ColorHex
--- @field tooltips? string[]
---
--- @field installed? boolean
--- @field enabled? boolean
--- @field locked? boolean
--- @field hidden? boolean
---
--- @field downloadUrl? string
--- @field downloadSize? number
--- @field releaseDate? string | number
--- @field downloadCount? number
--- @field hideInfo? boolean
--- @field noSync? boolean

--- @class imm.UI.Version
--- @field tooltips string[]
--- @field uie? balatro.UIElement
local IUIVer = {
    titleWidth = 9
}

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

--- @protected
function IUIVer:getTitleConfig()
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

--- @protected
function IUIVer:renderTitle()
    return ui.C{
        minw = self.ses.fontscale * self.titleWidth,
        maxw = self.ses.fontscale * self.titleWidth,
        ui.R{ ui.T(self.ver, self:getTitleConfig()) },
        self.sub and self.sub ~= '' and self.ses:renderTextRow(self.sub, 0.5) or nil
    }
end

--- @class _imm.UI.Version.AtlasButton
--- @field pos Position
--- @field btn string
--- @field ref? any
--- @field atlas? string
--- @field wm? number
--- @field hm? number
--- @field tooltipText? string[]

--- @protected
--- @param opts _imm.UI.Version.AtlasButton
function IUIVer:atlasBtn(opts)
    local spr = Sprite(0, 0, self.ses.fontscale * (opts.wm or 1), self.ses.fontscale * (opts.hm or 1), G.ASSET_ATLAS[opts.atlas or 'imm_icons'], opts.pos)
    return ui.C{
        tooltip = opts.tooltipText and { text = opts.tooltipText, text_scale = self.ses.fontscale * 0.8 } or nil,
        button = opts.btn,
        button_dist = 0.4,
        ref_table = opts.ref or self,

        ui.O(spr)
    }
end

--- @protected
function IUIVer:renderButtonSwitch()
    local opts = self.opts
    if opts.locked or not opts.installed then return nil end

    return self:atlasBtn({
        pos = opts.enabled and sprites.switchOn or sprites.switchOff,
        btn = funcs.toggle,
        ref = { ses = self, toggle = opts.enabled },
        atlas = 'imm_toggle', wm = 15/9, hm = 1,
        tooltipText = opts.enabled and {'Enabled'} or {'Disabled'}
    })
end

--- @protected
function IUIVer:renderButtonAction()
    local opts = self.opts
    if opts.locked or opts.enabled or not (opts.installed or opts.downloadUrl) then return nil end

    return self:atlasBtn(opts.installed and {
        pos = sprites.delete,
        btn = funcs.delete,
        tooltipText = {'Delete'}
    } or {
        pos = sprites.download,
        btn = funcs.download,
        tooltipText = {'Download'}
    })
end

--- @protected
function IUIVer:renderButtonLock()
    local opts = self.opts
    if not opts.installed then return nil end

    return self:atlasBtn({
        pos = opts.locked and sprites.locked or sprites.unlocked,
        btn = funcs.lock,
        ref = { ver = self, locked = opts.locked },
        tooltipText = opts.locked and {'Locked'} or {'Unlocked'}
    })
end

--- @protected
function IUIVer:renderActions()
    local list = {}
    table.insert(list, self:renderButtonSwitch())
    table.insert(list, self:renderButtonAction())
    table.insert(list, self:renderButtonLock())
    return list
end

--- @protected
function IUIVer:getActionsWidth()
    return 15/9 + 1 + 1 + 1 + 3/5
end

--- @protected
function IUIVer:renderActionsContainer()
    return ui.C{
        minw = self.ses.fontscale * self:getActionsWidth(),
        align = 'cr',
        ui.R{
            align = 'c',
            nodes = ui.gapList('C', self.ses.fontscale / 5, self:renderActions())
        }
    }
end

function IUIVer:syncInfo()
    local opts = self.opts
    if opts.noSync then return end
    local mod = self:getMod()
    if not mod then return end

    opts.installed = true
    opts.enabled = mod:isActive()
    opts.locked = mod.locked
    opts.hidden = mod.hidden
end

--- @protected
function IUIVer:renderParts()
    return {
        self:renderTitle(),
        self:renderActionsContainer()
    }
end

--- @protected
function IUIVer:renderLow()
    return ui.ROOT{
        func = funcs.init,
        ref_table = self,

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

function IUIVer:rerender()
    if not self.uie then return end
    self:syncInfo()
    ui.changeRoot(self.uie.UIBox, self:renderLow())
end

function IUIVer:render()
    return ui.R{ui.O(UIBox{definition = self:renderLow(), config = {}})}
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

