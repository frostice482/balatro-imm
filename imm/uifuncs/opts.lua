local a = require("imm.lib.assert")
local util = require("imm.lib.util")
local modsDir = require('imm.config').modsDir
local UIBrowser = require("imm.ui.browser")
local UIOpts = require("imm.ui.options")
local ui = require("imm.lib.ui")
local funcs = UIOpts.funcs

--- @param elm balatro.UIElement
G.FUNCS[funcs.disableAll] = function(elm)
    --- @type imm.UI.Browser
    local ses = elm.config.ref_table
    UIBrowser:assertInstance(ses, 'ref_table')

    local suc = {}
    local fail = {}

    for k, mod in pairs(ses.ctrl.loadlist.loadedMods) do
        if not mod.list.native and mod.mod ~= 'balatro_imm' then
            local ok, err = ses.ctrl:disableMod(mod)
            if ok then table.insert(suc, mod.mod..' '..mod.version)
            else table.insert(fail, err)
            end
        end
    end

    --ses.taskText = #suc ~= 0 and 'Disabled '..table.concat(suc, ', ') or 'Nothing is disabled'
    ses.taskText = ''
    ses.errorText = table.concat(fail, '\n')
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
    love.system.openURL('file:///'..modsDir:gsub('\\', '/'))
end
