local a = require("imm.lib.assert")
local util = require("imm.lib.util")
local config = require('imm.config')
local UIBrowser = require("imm.ui.browser")
local UICT = require("imm.ui.confirm_toggle")
local UIOpts = require("imm.ui.options")
local lovelyUrl = require('imm.lovely_downloads')
local ui = require("imm.lib.ui")
local co = require("imm.lib.co")
local funcs = UIOpts.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.disableAll] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    local suc = {}
    local fail = {}

    for k, mod in pairs(ses.ctrl.loadlist.loadedMods) do
        if not mod:isExcluded() then
            local ok, err = ses.ctrl:disableMod(mod)
            if ok then
                table.insert(suc, mod.mod..' '..mod.version)
                ses.hasChanges = true
            else
                table.insert(fail, err)
            end
        end
    end

    --ses.taskText = #suc ~= 0 and 'Disabled '..table.concat(suc, ', ') or 'Nothing is disabled'
    ses.tasks.status:update(nil, table.concat(fail, '\n'))
    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.clearCache] = function(elm)
    --- @type table
    local r = elm.config.ref_table
    a.type(r, 'ref_table', 'table')

    --- @type imm.UI.Browser, string
    local ses, mode = r.ses, r.mode
    UIBrowser:assertInstance(ses, 'r.ses')
    a.enum(mode, 'mode', { 't', 'd', 'r', 'l' })

    local repo = ses.repo
    local ts, bmi = repo.ts, repo.bmi

    if mode == 't' then
        util.rmdir(util.dirname(ts.thumbApi.cacheFile), false)
        util.rmdir(util.dirname(bmi.thumbApi.cacheFile), false)
        ts.imageCache = {}
        bmi.imageCache = {}
    elseif mode == 'd' then
        util.rmdir(util.dirname(repo.api.blob.cacheFile), false)
    elseif mode == 'r' then
        repo:clearReleases()
    elseif mode == 'l' then
        repo:clearList()
        ses.prepared = false
    end

    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.clearCacheOpts] = function(elm)
    --- @type imm.UI.Options
    local ses = elm.config.ref_table
    UIOpts:assertInstance(ses, 'ref_table')

    ui.overlay(ses:renderClearCacheOpts())
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.modsOpts] = function(elm)
    --- @type imm.UI.Options
    local ses = elm.config.ref_table
    UIOpts:assertInstance(ses, 'ref_table')

    ui.overlay(ses:renderModsOpts())
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.checkRateLimit] = function(elm)
    --- @type imm.UI.Options
    local ses = elm.config.ref_table
    UIOpts:assertInstance(ses, 'ref_table')

    ui.overlay(ses:renderCheckRateLimitExec())
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.restart] = function(elm)
    util.restart()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.openModFolder] = function(elm)
    love.system.openURL('file:///'..config.modsDir:gsub('\\', '/'))
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.updateAll] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    co.create(function ()
        ses.tasks:createUpdaterCoSes():updateAll()
    end)
    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.deleteOld] = function(elm)
    --- @type imm.UI.Options
    local r = elm.config.ref_table
    UIOpts:assertInstance(r, 'ref_table')

    local list = r.ses.ctrl:getOlderMods()
    if #list == 0 then return r.ses:showOverlay(true) end

    ui.overlay(r:uiRenderRemoveMods(list))
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.deleteConf] = function(elm)
    local r = elm.config.ref_table or {}

    --- @type imm.UI.Browser, imm.Mod[]
    local ses, list = r.ses, r.list
    UIBrowser:assertInstance(ses, 'r.ses')

    if r.confirm then
        for i,mod in ipairs(list) do
            ses.ctrl:deleteEntry(mod)
        end
    end

    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.enableAll] = function(elm)
    --- @type imm.UI.Browser
    local r = elm.config.ref_table
    UIBrowser:assertInstance(r, 'ref_table')

    local vlist = r.ctrl:createLoadList()

    for i, list in ipairs(r.ctrl:list()) do
        local m = list:latest()
        if m and not m:isActive() and not m:isExcluded() then
            local mlist = r.ctrl:createLoadList(true)
            mlist:simpleCopyFrom(vlist)

            mlist:tryEnable(m)

            local ok = not next(mlist.missingDeps)
            if ok then
                for k,v in pairs(mlist.actions) do
                    ok = ok and v.action == 'enable'
                    if not ok then break end
                end
            end
            if ok then
                vlist:tryEnable(m)
            end
        end
    end

    if next(vlist.actions) then
        ui.overlay(UICT(r, vlist):render())
    else
        r:showOverlay(true)
    end
end

local modlistfmt = "%-30s %-20s %-8s %s"
local modlisthead = '# '..modlistfmt:format("id", "version", "status", "path")

--- @param mod imm.Mod
local function fmtmod(mod)
    return '- '..modlistfmt:format(mod.mod, mod.version, mod.isLoaded and 'loaded' or '-', mod.path:sub(config:len()+2))
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.copyModlist] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    local entries = { modlisthead }
    local disabledEntries = {}

    for i, list in ipairs(ses.ctrl:list()) do
        if not list:isExcluded() then
            local l = disabledEntries
            if list.active then
                l = entries
                table.insert(entries, fmtmod(list.active))
            end
            for j, mod in ipairs(list:list()) do
                if mod ~= list.active then
                    table.insert(l, fmtmod(mod))
                end
            end
        end
    end

    for i,v in ipairs(disabledEntries) do
        table.insert(entries, v)
    end

    love.system.setClipboardText(table.concat(entries, '\n'))

    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.updateLovely] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    co.create(function ()
        ses.tasks:downloadLovelyCo()
    end)
    ses:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.updateLovelyInit] = function(elm)
    local texts = {
        config.lovelyver and 'Current: '..config.lovelyver or 'Undetected'
    }
    if not lovelyUrl then
        table.insert(texts, string.format('Unknown hardware (%s %s)', jit.os, jit.arch))
        elm.disable_button = true
    end
    elm.config.tooltip = { text = texts }
end
