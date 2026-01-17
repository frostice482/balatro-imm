local constructor = require("imm.lib.constructor")
local TM = require("imm.lib.texture_moveable")
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
--- @field contImage imm.TextureMoveable
local IUIModSes = {
    thumbScale = 1.25,
    cyclePageSize = 5,
    nonCycleMaxSize = 7,
    idListCnt = 'imm-other-cycle'
}

--- @protected
--- @param ses imm.UI.Browser
--- @param mod imm.ModMeta
function IUIModSes:init(ses, mod)
    self.ses = ses
    self.mod = mod
end

--- @protected
--- @param version string
--- @param opts imm.UI.Version.Opts
function IUIModSes:uiVersion(version, opts)
    return UIVersion(self.ses, self.mod:id(), version, opts)
end

--- @protected
--- @param mod imm.Mod
function IUIModSes:uiVersionMod(mod)
    return UIVersion(self.ses, self.mod:id(), mod.version, {
        installed = true,
        enabled = mod:isActive(),
        locked = mod.locked,
        tooltips = {mod.path:sub(imm.modsDir:len()+2)}
    })
end

--- @protected
--- @param release imm.ModMeta.Release
function IUIModSes:uiVersionRelease(release)
    return UIVersion.fromRelease(self.ses, self.mod:id(), release)
end

--- @protected
--- @param asset ghapi.Releases.Assets
--- @param ver? string
function IUIModSes:uiVersionAsset(asset, ver)
    return UIVersion.fromGithubAsset(self.ses, self.mod:id(), asset, ver)
end

--- @protected
--- @param versions imm.UI.Version[]
function IUIModSes:renderCycleAuto(versions)
    if #versions > self.nonCycleMaxSize then
        return {
            self:renderCycle(versions),
            ui.container(self.idListCnt, true)
        }
    end

    local nodes = {}
    for i,v in ipairs(versions) do nodes[i] = v:render() end
    return {
        ui.container(self.idListCnt, true, nodes)
    }
end

--- @protected
function IUIModSes:renderTabInstalled()
    local l = self.ses.ctrl.mods[self.mod:id()]
    if not l or not next(l.versions) then return self.ses:renderText('No installed\nversions', 1.25, G.C.ORANGE) end

    --- @type imm.UI.Version[]
    local versions = {}
    for _, mod in ipairs(l:list()) do
        table.insert(versions, self:uiVersionMod(mod))
    end

    return ui.C(self:renderCycleAuto(versions))
end

--- @protected
--- @param func string
function IUIModSes:renderReleasesContainer(func)
    if not (self.mod.bmi and self.mod.bmi.repo or self.mod.ts) then return self.ses:renderText("Repo info\nunavailable", 1.25, G.C.ORANGE) end

    return ui.C{
        func = func,
        ref_table = self,
        self.ses:renderTextRow('Please wait', 1.25)
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
            if latest.bmi then
                for i, asset in ipairs(latest.bmi.assets) do
                    table.insert(list, self:uiVersionAsset(asset, latest.version))
                end
            end
            table.insert(list, self:uiVersionRelease(latest))
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

    self:uiAddCycle(elm, list)
end

--- @param elm balatro.UIElement
--- @param res imm.ModMeta.Release[]
function IUIModSes:updateOther(elm, res)
    --- @type imm.UI.Version[]
    local list = {}
    for k,release in pairs(res) do table.insert(list, self:uiVersionRelease(release)) end

    self:uiAddCycle(elm, list)
end

--- @protected
--- @param elm balatro.UIElement
--- @param list imm.UI.Version[]
function IUIModSes:uiAddCycle(elm, list)
    local uibox = elm.UIBox
    for i, node in ipairs(self:renderCycleAuto(list)) do
        uibox:add_child(node, elm)
    end
    uibox:recalculate()
    self.ses.contSelect:recalculate()
    self.ses.uibox:recalculate()
end

--- @protected
--- @param list imm.UI.Version[]
function IUIModSes:renderCycle(list)
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

--- @protected
function IUIModSes:getTabs()
    local installedMod = self.ses.ctrl.mods[self.mod:id()]
    local hasVersion = not not ( installedMod and next(installedMod.versions) )

    --- @type balatro.UI.Tab.Tab[]
    return {{
        chosen = hasVersion,
        label = 'Installed',
        tab_definition_function = function (arg)
            return ui.ROOT{self:renderTabInstalled()}
        end
    }, {
        chosen = not hasVersion,
        label = 'Releases',
        tab_definition_function = function (arg)
            return ui.ROOT{self:renderReleasesContainer(funcs.releasesInit)}
        end
    }, {
        label = 'Older',
        tab_definition_function = function (arg)
            return ui.ROOT{self:renderReleasesContainer(funcs.otherInit)}
        end
    }}
end

--- @protected
function IUIModSes:renderTabs()
    return create_tabs({
        scale = self.ses.fontscale * 1.5,
        text_scale = self.ses.fontscale,
        snap_to_nav = true,

        tabs = self:getTabs()
    })
end

--- @protected
--- @param url string
--- @param text string
function IUIModSes:renderRepoButtonUrl(url, text)
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
        self.ses:renderText(text)
    }
end

--- @protected
function IUIModSes:renderRepoButtons()
    --- @type balatro.UIElement.Definition[]
    local cols = {}
    if self.mod.bmi and self.mod.bmi.repo then
        table.insert(cols, self:renderRepoButtonUrl(self.mod.bmi.repo, 'Repo'))
    end
    if self.mod.ts and self.mod.ts.package_url then
        table.insert(cols, self:renderRepoButtonUrl(self.mod.ts.package_url, 'Package'))
    end
    if self.mod.tsLatest and self.mod.tsLatest.website_url then
        table.insert(cols, self:renderRepoButtonUrl(self.mod.tsLatest.website_url, 'Website'))
    end
    if self.mod.ts and self.mod.ts.donation_link then
        table.insert(cols, self:renderRepoButtonUrl(self.mod.ts.donation_link, 'Donate'))
    end
    return cols
end

--- @protected
function IUIModSes:renderRepoButtonContainer()
    return ui.R{ align = 'm', padding = 0.1, nodes = self:renderRepoButtons() }
end

--- @protected
--- @param text string
function IUIModSes:renderModAuthor(text)
    return ui.R{ align = 'm', self.ses:renderText('By '..text, 0.75) }
end

--- @protected
function IUIModSes:renderImageContainer()
    self.contImage = TM(nil, 0, 0, self.ses.thumbSize.w * self.thumbScale, self.ses.thumbSize.h * self.thumbScale)
    return ui.R{ align = 'm', ui.O(self.contImage) }
end

function IUIModSes:render()
    return ui.ROOT{
        self:renderImageContainer(),
        self.ses:renderModText(self.mod:title()),
        self:renderModAuthor(self.mod:author()),
        self:renderRepoButtonContainer(),
        self:renderTabs()
    }
end

--- @async
function IUIModSes:updateImageCo()
    local img, err = self.mod:getImageCo()
    if not img then return end

    local w, h = img:getDimensions()
    local aspectRatio = math.max(math.min(w / h, 16/9), 1)

    self.contImage.T.w = self.ses.thumbSize.h * self.thumbScale * aspectRatio
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
