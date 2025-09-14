local util = require("imm.lib.util")
local modsDir = require('imm.config').modsDir

--- @class imm.Browser.Funcs
local funcs = {
    setCategory    = 'imm_s_setcat',
    update         = 'imm_s_update',
    cyclePage      = 'imm_s_cycle',
    chooseMod      = 'imm_s_choosemod',
    refresh        = 'imm_s_refresh',
    restart        = 'imm_s_restart',
    restartConf    = 'imm_s_restart_conf',
    openModFolder  = 'imm_s_open',
    clearCache     = 'imm_s_clearcache',
    checkRateLimit = 'imm_s_checkghratelimit',
    options        = 'imm_options',
    back           = 'imm_back',
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.clearCache] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Browser, string
    local ses, mode = r.ses, r.mode
    local repo = ses.repo
    local ts, bmi = repo.ts, repo.bmi

    if mode == 't' then
        util.rmdir(util.dirname(ts.thumbApi.cacheFile), false)
        util.rmdir(util.dirname(bmi.thumbApi.cacheFile), false)
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
G.FUNCS[funcs.back] = function(elm)
    elm.config.ref_table:showOverlay(true)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.restart] = function(elm)
    util.restart()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.options] = function(elm)
    --- @type imm.Browser
    local ses = elm.config.ref_table
    G.FUNCS.overlay_menu({ definition = ses:uiOptions() })
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.checkRateLimit] = function(elm)
    --- @type imm.Browser
    local ses = elm.config.ref_table
    G.FUNCS.overlay_menu({ definition = ses:uiOptionsCheckRateLimitExec() })
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.restartConf] = function(elm)
    if not elm.config.ref_table.confirm then return G.FUNCS.exit_overlay_menu() end
    util.restart()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.openModFolder] = function(elm)
    love.system.openURL('file:///'..modsDir:gsub('\\', '/'))
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.setCategory] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Browser
    local ses, cat = r.ses, r.cat

    ses.tags[cat] = not ses.tags[cat]
    elm.config.colour = ses.tags[cat] and G.C.ORANGE or G.C.RED
    ses:queueUpdate()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.update] = function(elm)
    --- @type imm.Browser
    local ses = elm.config.ref_table

    if ses.prevSearch ~= ses.search then
        ses.prevSearch = ses.search
        ses:queueUpdate()
    end
end

--- @param elm balatro.UI.CycleCallbackParam
G.FUNCS[funcs.cyclePage] = function(elm)
    --- @type imm.Browser
    local ses = elm.cycle_config._ses

    ses.listPage = elm.to_key
    ses:updateMods()
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.chooseMod] = function(elm)
    local r = elm.config.ref_table or {}
    --- @type imm.Browser, imm.ModMeta
    local ses, mod = r.ses, r.mod

    ses:selectMod(mod)
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.refresh] = function(elm)
    util.rmdir('immcache', false)
    --- @type imm.Browser
    local ses = elm.config.ref_table
    ses.repo:clear()
    ses.prepared = false
    ses:showOverlay(true)
end

return funcs