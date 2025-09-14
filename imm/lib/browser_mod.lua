local constructor = require("imm.lib.constructor")
local ui = require("imm.lib.ui")
local funcs = require("imm.browser_mod_funcs")
local browser_funcs = require("imm.browser_funcs")
local modsDir = require('imm.config').modsDir

local betaColor = G.C.ORANGE
local thunderstoreColor = mix_colours(copy_table(G.C.BLUE), {1, 1, 1, 1}, 0.6)

--- @class imm.ModBrowser
--- @field ses imm.Browser
--- @field mod imm.ModMeta
local UIModSes = {
    cyclePageSize = 7,
    idListCnt = 'imm-other-cycle',
    idImageSelectCnt = 'imm-slc-imgcnt',

    actFontScaleTitle = 0.3,
    actFontScale = 0.3,
    actFontScaleSub = 0.3 * 0.75
}

--- @protected
--- @param ses imm.Browser
--- @param mod imm.ModMeta
function UIModSes:init(ses, mod)
    self.ses = ses
    self.mod = mod

    --- @type ColorHex
    self.actWhoColor = G.C.WHITE
    --- @type ColorHex
    self.actVersionColor = G.C.BLUE
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
    local downText = opts.downloadUrl
    if downText and opts.downloadSize then downText = string.format('%s (%.1fMB)', downText, opts.downloadSize / 1048576) end

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
                    ref_table = opts.installed and {
                        ses = self,
                        ver = opts.version,
                        toggle = opts.enabled
                    } or nil,
                    tooltip = opts.downloadUrl and {
                        text = {{ ref_table = { downText }, ref_value = 1 }},
                        text_scale = self.ses.fontscale * 0.6
                    },
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
    if opts.enabled or not (opts.installed or opts.downloadUrl) then return end
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
    local l = self.ses.ctrl.mods[self.mod:id()]
    if l then
        if opts.installed == nil then opts.installed = not not l.versions[opts.version] end
        if opts.enabled == nil then opts.enabled = (l.active and l.active.version) == opts.version end
    end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { minh = self.ses.fontscale * 1.8 },
        nodes = {{
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
        }}
    }
end

--- @param ver imm.ModMeta.Release
function UIModSes:createVersionOpts(ver)
    local l = self.ses.ctrl.mods[self.mod:id()]
    local installed, enabled
    if l then
        installed = not not l.versions[ver.version]
        enabled = (l.active and l.active.version) == ver.version
    end
    --- @type imm.ModSession.VersionParam
    return {
        version = ver.version,
        color = ver.isPre and betaColor or ver.ts and thunderstoreColor or nil,
        downloadSize = ver.size,
        downloadUrl = ver.url,
        enabled = enabled,
        installed = installed
    }
end

function UIModSes:uiTabInstalled()
    local l = self.ses.ctrl.mods[self.mod:id()]
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
                    sub = info.path:sub(modsDir:len() + 2),
                    installed = true
                })
            end),
            ui.container(self.idListCnt, true)
        }
    }
end

--- @param func string
function UIModSes:uiReleasesContainer(func)
    if not (self.mod.bmi and self.mod.bmi.repo or self.mod.ts) then return self.ses:uiText("Repo info\nunavailable", 1.25, G.C.ORANGE) end

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
--- @param res imm.ModMeta.Release[]
function UIModSes:updateReleases(elm, res)
    --- @type imm.ModSession.VersionParam[]
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
            --if latest then break end
        end

        if latest then
            table.insert(list, self:createVersionOpts(latest))
        end
        if pre and not (pre.versionParsed and latest.versionParsed and pre.versionParsed < latest.versionParsed) then
            table.insert(list, self:createVersionOpts(pre))
        end
    end

    if self.mod.bmi and self.mod.bmi.repo then
        table.insert(list, {
            version = 'Source',
            sub = self.mod.bmi.version..' - Potentially unstable!',
            downloadUrl = self.mod.bmi.download_url,
            color = betaColor
        })
    end

    self:uiAdd(elm, #list, function (i)
        local info = list[i]
        return info and self:uiVersion(info)
    end)
end

--- @param elm balatro.UIElement
--- @param res imm.ModMeta.Release[]
function UIModSes:updateOther(elm, res)
    self:uiAdd(elm, #res, function (i)
        local info = res[i]
        return info and self:uiVersion(self:createVersionOpts(info))
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
    local hasVersion = not not ( self.ses.ctrl.mods[mod:id()] and next(self.ses.ctrl.mods[mod:id()].versions) )

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

--- @param url string
--- @param text string
function UIModSes:uiRepoButtonUrl(url, text)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = {
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
            }
        },
        nodes = {self.ses:uiText(text)}
    }
end

function UIModSes:uiRepoButton()
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

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { padding = 0.1, align = 'm' },
        nodes = cols
    }
end

local actionsRank = {
    disable = 3,
    switch = 2,
    enable = 1,
}

--- @param act imm.LoadList.ModAction
function UIModSes:uiAct(act)
    local name = act.mod.name
    local version = act.mod.version
    local entryScale = self.actFontScale
    local entryScaleSub = self.actFontScaleSub

    --- @type balatro.UIElement.Definition?
    local byElm = act.cause and { n = G.UIT.T, config = { text = string.format(' (%s)', act.cause.mod), scale = entryScaleSub, colour = self.actWhoColor } }
    --- @type balatro.UIElement.Definition
    local verElm = { n = G.UIT.T, config = { text = ' '..version, scale = entryScaleSub, colour = self.actVersionColor } }
    --- @type balatro.UIElement.Definition[]
    local t

    if act.impossible then
        t = {{ n = G.UIT.T, config = { text = '! '..name, scale = entryScale, colour = G.C.RED } }}
    elseif act.action == 'enable' then
        t = {{ n = G.UIT.T, config = { text = '+ '..name, scale = entryScale, colour = G.C.GREEN } }}
    elseif act.action == 'disable' then
        t = {{ n = G.UIT.T, config = { text = '- '..name, scale = entryScale, colour = G.C.ORANGE } }}
    elseif act.action == 'switch' then
        local from = (self.ses.ctrl.loadlist.loadedMods[act.mod.mod] or {}).version or '?'
        t = {
            { n = G.UIT.T, config = { text = '/ '..name, scale = entryScale, colour = G.C.YELLOW } },
            { n = G.UIT.T, config = { text = from, scale = entryScaleSub, colour = self.actVersionColor } },
            { n = G.UIT.T, config = { text = ' ->', scale = entryScaleSub, colour = G.C.UI.TEXT_LIGHT } },
        }
    end

    table.insert(t, verElm)
    table.insert(t, byElm)

    --- @type balatro.UIElement.Definition
    return { n = G.UIT.R, nodes = t }
end

--- @param nodes balatro.UIElement.Definition[]
--- @param list imm.LoadList
--- @param mod imm.Mod
--- @return boolean hasImpossible, boolean hasChange
function UIModSes:uiConfirmModifyPartActions(nodes, list, mod)
    local hasImpossible, hasChange = false, false
    local ll = self.ses.ctrl.loadlist

    --- @type imm.LoadList.ModAction[]
    local impossibles = {}
    --- @type imm.LoadList.ModAction[]
    local actions = {}
    for k, act in pairs(list.actions) do
        if act.impossible or act.mod ~= mod then
            if act.action == 'enable' and self.ses.ctrl.loadlist.loadedMods[act.mod.mod] then act.action = 'switch' end
            table.insert(act.impossible and impossibles or actions, act)
        end
    end
    table.sort(impossibles, function (a, b)
        return a.mod.name < b.mod.name
    end)
    table.sort(actions, function (a, b)
        if a.action ~= b.action then return actionsRank[a.action] > actionsRank[b.action] end
        return a.mod.name < b.mod.name
    end)

    for i,act in ipairs(impossibles) do
        if not hasImpossible then
            table.insert(nodes, ui.simpleTextRow('These mods are in impossible condition to load:', self.actFontScaleTitle))
            hasImpossible = true
        end
        table.insert(nodes, self:uiAct(act))
    end

    for i,act in ipairs(actions) do
        if not hasChange then
            table.insert(nodes, ui.simpleTextRow('These mods will also take effect:', self.actFontScaleTitle))
            hasChange = true
        end
        table.insert(nodes, self:uiAct(act))
    end

    return hasImpossible, hasChange
end

--- @param nodes balatro.UIElement.Definition[]
--- @param list imm.LoadList
--- @param mod imm.Mod
--- @return boolean hasMissing
function UIModSes:uiConfirmModifyPartMissing(nodes, list, mod)
    local hasMissing = false

    -- 1 month from now i will probably forget how this code does

    --- @type [string, string[]][]
    local missings = {}
    for k, missing in pairs(list.missingDeps) do
        --- @type string[]
        local modsRulesStr = {}
        for other, rules in pairs(missing) do
            --- @type string[]
            local rulesStr = {}
            for i, rule in ipairs(rules) do
                table.insert(rulesStr, rule.op..' '..rule.version.raw)
            end
            table.insert(modsRulesStr, string.format('%s (%s)', other.name, table.concat(rulesStr, ' ')))
        end
        table.sort(modsRulesStr, function (a, b) return a < b end)
        table.insert(missings, { k, modsRulesStr })
    end
    table.sort(missings, function (a, b) return a[1] < b[1] end)

    for i, entry in ipairs(missings) do
        if not hasMissing then
            table.insert(nodes, ui.simpleTextRow('These mods have missing dependencies:', self.actFontScaleTitle))
            hasMissing = true
        end

        local base = ui.simpleTextRow(string.format('? %s', entry[1]), self.actFontScale, G.C.YELLOW)
        table.insert(nodes, base)
        for i, entry in pairs(entry[2]) do
            table.insert(nodes, ui.simpleTextRow('    '..entry, self.actFontScaleSub))
        end
    end

    return hasMissing
end

--- @param list imm.LoadList
--- @param mod imm.Mod
--- @param isDisable boolean
function UIModSes:uiConfirmModify(list, mod, isDisable)
    local tgltext = isDisable and 'Disable' or 'Enable'

    --- @type balatro.UIElement.Definition[]
    local nodes = {}
    table.insert(nodes, ui.simpleTextRow(string.format('%s %s %s, but..', tgltext, mod.name, mod.version), self.actFontScaleTitle * 1.25))

    local hasMissing = self:uiConfirmModifyPartMissing(nodes, list, mod)
    local hasImpossible, hasChange = self:uiConfirmModifyPartActions(nodes, list, mod)
    local hasErr = hasMissing or hasImpossible

    local data = { list = list, ses = self.ses, mod = mod }
    local bconf = { __index = { scale = self.ses.fontscale, ref_table = data, minh = 0.6, minw = 5 } }

    if hasMissing then
        table.insert(nodes, UIBox_button(setmetatable({ button = funcs.vt_download, label = {'Download missings'}, colour = G.C.BLUE }, bconf)))
    end
    local labelModifyAll = 'Confirm'
    local labelOne = string.format('%s JUST %s', tgltext, mod.name)
    if hasErr then
        labelModifyAll = labelModifyAll..' anyway'
        labelOne = labelOne..' anyway'
    end

    table.insert(nodes, UIBox_button(setmetatable({ button = funcs.vt_confirm, label = {labelModifyAll}, colour = hasErr and G.C.ORANGE or G.C.BLUE }, bconf)))
    table.insert(nodes, UIBox_button(setmetatable({ button = funcs.vt_confirmOne, label = {labelOne}, colour = G.C.ORANGE }, bconf)))
    table.insert(nodes, UIBox_button(setmetatable({ button = browser_funcs.back, label = {'Cancel'}, colour = G.C.GREY, ref_table = self.ses }, bconf)))

    return create_UIBox_generic_options({
        contents = nodes,
        no_back = true
    })
end

--- @param text string
function UIModSes:uiModAuthor(text)
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'm' },
        nodes = {self.ses:uiText('By '..text, 0.75)}
    }
end

function UIModSes:uiMoreInfo()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = { align = 'm' },
        nodes = {self.ses:uiText(self.mod:id(), 0.5)}
    }
end

function UIModSes:container()
    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.C,
        config = { group = self.ses.idModSelect },
        nodes = {
            self.ses:uiImage(self.idImageSelectCnt),
            self.ses:uiModText(self.mod:title()),
            self:uiModAuthor(self.mod:author()),
            --self:uiMoreInfo(),
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
    local mod = self.ses.ctrl:getMod(self.mod:id(), ver)
    local stat = mod and NFS.getInfo(mod.path)

    local cols = {}

    local main = ui.simpleTextRow(string.format('Really delete %s %s?', self.mod:title(), ver), self.ses.fontscale)
    main.config = {align = 'cm'}
    table.insert(cols, main)

    if stat and stat.type == 'symlink' then
        local sub = ui.simpleTextRow('This mod is symlinked', self.ses.fontscale, G.C.ORANGE)
        sub.config = {align = 'cm'}
        table.insert(cols, sub)
    end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {align = 'cm'},
        nodes = {{
            n = G.UIT.C,
            config = {align = 'cm'},
            nodes = cols
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

--- @class imm.ModBrowser.Static
--- @field funcs imm.ModBrowser.Funcs

--- @alias imm.ModBrowser.C imm.ModBrowser.Static | p.Constructor<imm.ModBrowser, nil> | fun(ses: imm.Browser, mod: imm.ModMeta): imm.ModBrowser
--- @type imm.ModBrowser.C
local UIModSes = constructor(UIModSes)
UIModSes.funcs = funcs
return UIModSes
