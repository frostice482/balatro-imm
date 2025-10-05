local constructor = require("imm.lib.constructor")
local LoveMoveable = require("imm.lib.love_moveable")
local UIVersion = require('imm.ui.version')
local ui = require("imm.lib.ui")
local co = require("imm.lib.co")
local imm = require('imm')

--- @class imm.UI.Mod.Funcs
local funcs = {
    openUrl      = 'imm_m_openurl',
    releasesInit = 'imm_m_releases_init',
    otherInit    = 'imm_m_other_init'
}

local betaColor = G.C.ORANGE

--- @class imm.UI.Mod
--- @field ses imm.UI.Browser
--- @field mod imm.ModMeta
---
--- @field contImage imm.LoveMoveable
local IUIModSes = {
    thumbScale = 1.25,
    cyclePageSize = 5,
    idListCnt = 'imm-other-cycle'
}

--- @protected
--- @param ses imm.UI.Browser
--- @param mod imm.ModMeta
function IUIModSes:init(ses, mod)
    self.ses = ses
    self.mod = mod
end

--- @param version string
--- @param opts imm.UI.Version.Opts
function IUIModSes:uiVersion(version, opts)
    return UIVersion(self.ses, self.mod:id(), version, opts)
end

--- @param release imm.ModMeta.Release
function IUIModSes:uiVersionRelease(release)
    return UIVersion.fromRelease(self.ses, self.mod:id(), release)
end

--- @param asset ghapi.Releases.Assets
--- @param ver? string
function IUIModSes:uiVersionAsset(asset, ver)
    return UIVersion.fromGithubAsset(self.ses, self.mod:id(), asset, ver)
end

function IUIModSes:uiTabInstalled()
    local l = self.ses.ctrl.mods[self.mod:id()]
    if not l or not next(l.versions) then return self.ses:uiText('No installed\nversions', 1.25, G.C.ORANGE) end

    --- @type imm.UI.Version[]
    local versions = {}
    for _, entry in ipairs(l:list()) do
        local ver = self:uiVersion(entry.version, {
            sub = entry.path:sub(imm.modsDir:len()+2),
            installed = true
        })
        table.insert(versions, ver)
    end

    return ui.C{
        self:uiCycle(versions),
        ui.container(self.idListCnt, true)
    }
end

--- @param func string
function IUIModSes:uiReleasesContainer(func)
    if not (self.mod.bmi and self.mod.bmi.repo or self.mod.ts) then return self.ses:uiText("Repo info\nunavailable", 1.25, G.C.ORANGE) end

    return ui.C{
        func = func,
        ref_table = self,
        self.ses:uiTextRow('Please wait', 1.25)
    }
end

--- @param elm balatro.UIElement
--- @param res imm.ModMeta.Release[]
function IUIModSes:updateReleases(elm, res)
    --- @type imm.UI.Version[]
    local list = {}

    if res then
        --- @type imm.ModMeta.Release
        local pre
        --- @type imm.ModMeta.Release
        local latest

        for i,v in ipairs(res) do
            if v.isPre then pre = pre or v
            else latest = latest or v
            end
            if latest then break end
        end

        --- @type imm.ModMeta.Release
        latest = latest

        if latest then
            table.insert(list, self:uiVersionRelease(latest))
            if latest.bmi then
                for i, asset in ipairs(latest.bmi.assets) do
                    table.insert(list, self:uiVersionAsset(asset, latest.version))
                end
            end
        end
        if pre then
            table.insert(list, self:uiVersionRelease(pre))
        end
    end

    local bmi = self.mod.bmi
    if bmi and bmi.repo and bmi.download_url then
        local v = bmi.version
        local ui = self:uiVersion('Latest', {
            sub = v,
            downloadUrl = bmi.download_url,
            color = betaColor
        })
        table.insert(list, ui)
    end

    self:uiAdd(elm, list)
end

--- @param elm balatro.UIElement
--- @param res imm.ModMeta.Release[]
function IUIModSes:updateOther(elm, res)
    --- @type imm.UI.Version[]
    local list = {}
    for k,release in pairs(res) do table.insert(list, self:uiVersionRelease(release)) end

    self:uiAdd(elm, list)
end

--- @param elm balatro.UIElement
--- @param list imm.UI.Version[]
function IUIModSes:uiAdd(elm, list)
    local uibox = elm.UIBox
    uibox:add_child(self:uiCycle(list), elm)
    uibox:add_child(ui.container(self.idListCnt, true), elm)
    uibox:recalculate()
    self.ses.uibox:recalculate()
end

--- @param list imm.UI.Version[]
function IUIModSes:uiCycle(list)
    return ui.cycle({
        func = function (i) return list[i] and list[i]:render() end,
        length = #list,
        id = self.idListCnt,
        pagesize = self.cyclePageSize,
        onCycle = function ()
            self.ses.contSelect:recalculate()
            self.ses.uibox:recalculate()
        end
    }, { no_pips = true })
end

function IUIModSes:uiTabs()
    local mod = self.mod
    local hasVersion = not not ( self.ses.ctrl.mods[mod:id()] and next(self.ses.ctrl.mods[mod:id()].versions) )

    return create_tabs({
        scale = self.ses.fontscale * 1.5,
        text_scale = self.ses.fontscale,
        snap_to_nav = true,

        tabs = {{
            chosen = hasVersion,
            label = 'Installed',
            tab_definition_function = function (arg)
                return ui.ROOT{self:uiTabInstalled()}
            end
        }, {
            chosen = not hasVersion,
            label = 'Releases',
            tab_definition_function = function (arg)
                return ui.ROOT{self:uiReleasesContainer(funcs.releasesInit)}
            end
        }, {
            label = 'Older',
            tab_definition_function = function (arg)
                return ui.ROOT{self:uiReleasesContainer(funcs.otherInit)}
            end
        }}
    })
end

--- @param url string
--- @param text string
function IUIModSes:uiRepoButtonUrl(url, text)
    return ui.C{
        colour = G.C.PURPLE,
        padding = 0.1,
        shadow = true,
        button = funcs.openUrl,
        ref_table = { url = url },
        r = true,
        button_dist = 0.1,
        tooltip = {
            text = { url },
            text_scale = self.ses.fontscale * 0.8
        },
        self.ses:uiText(text)
    }
end

function IUIModSes:uiRepoButton()
    local cols = {}

    if self.mod.bmi and self.mod.bmi.repo then
        table.insert(cols, self:uiRepoButtonUrl(self.mod.bmi.repo, 'Repo'))
    end
    if self.mod.ts and self.mod.ts.package_url then
        table.insert(cols, self:uiRepoButtonUrl(self.mod.ts.package_url, 'Package'))
    end
    if self.mod.tsLatest and self.mod.tsLatest.website_url then
        table.insert(cols, self:uiRepoButtonUrl(self.mod.tsLatest.website_url, 'Website'))
    end
    if self.mod.ts and self.mod.ts.donation_link then
        table.insert(cols, self:uiRepoButtonUrl(self.mod.ts.donation_link, 'Donate'))
    end

    return ui.R{ align = 'm', padding = 0.1, nodes = cols }
end

--- @param text string
function IUIModSes:uiModAuthor(text)
    return ui.R{ align = 'm', self.ses:uiText('By '..text, 0.75) }
end

function IUIModSes:uiImageContainer()
    self.contImage = LoveMoveable(nil, 0, 0, self.ses.thumbW * self.thumbScale, self.ses.thumbH * self.thumbScale)
    return ui.R{ align = 'm', ui.O(self.contImage) }
end

function IUIModSes:render()
    local uis = {
        self:uiImageContainer(),
        self.ses:uiModText(self.mod:title()),
        self:uiModAuthor(self.mod:author()),
        self:uiRepoButton(),
        self:uiTabs()
    }
    return ui.ROOT(uis)
end

--- @async
function IUIModSes:updateImageCo()
    local err, img = self.mod:getImageCo()
    if not img then return end

    local w, h = img:getDimensions()
    local aspectRatio = math.max(math.min(w / h, 16/9), 1)

    self.contImage.T.w = self.ses.thumbH * self.thumbScale * aspectRatio
    self.contImage.drawable = img
end

function IUIModSes:update()
    co.create(self.updateImageCo, self)
end

--- @class imm.UI.Mod.Static
--- @field funcs imm.UI.Mod.Funcs

--- @alias imm.UI.Mod.C imm.UI.Mod.Static | p.Constructor<imm.UI.Mod, nil> | fun(ses: imm.UI.Browser, mod: imm.ModMeta): imm.UI.Mod
--- @type imm.UI.Mod.C
local UIModSes = constructor(IUIModSes)
UIModSes.funcs = funcs
return UIModSes
