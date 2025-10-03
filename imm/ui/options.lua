local constructor = require("imm.lib.constructor")
local UIBrowser = require("imm.ui.browser")
local httpsAgent = require('imm.https_agent')
local ui = require('imm.lib.ui')
local imm = require("imm")

--- @class imm.UI.Options.Funcs
local funcs = {
    restart        = 'imm_o_restart',
    openModFolder  = 'imm_o_open',
    clearCache     = 'imm_o_clearcache',
    clearCacheOpts = 'imm_o_clearcacheopts',
    modsOpts       = 'imm_o_modsopts',
    checkRateLimit = 'imm_o_checkghratelimit',
    disableAll     = 'imm_o_disableall',
    enableAll      = 'imm_o_enableall',
    updateAll      = 'imm_o_updateall',
    copyModlist    = 'imm_o_copymodlist',
    deleteOld      = 'imm_o_deleteold',
    deleteConf     = 'imm_o_delete_conf',
    updateLovely   = 'imm_o_updatelovely',
    updateLovelyInit = 'imm_o_updatelovelyinit',
    removeBundle    = 'imm_o_rmbundle'
}

--- @class imm.UI.Options
local IUIOpts = {
    buttonWidth = 4,
    optionSpacing = 0.2
}

--- @param ses imm.UI.Browser
function IUIOpts:init(ses)
    self.ses = ses
end

--- @return balatro.UIElement.Definition[]
function IUIOpts:gridOptions()
    return {{
        UIBox_button({ minw = self.buttonWidth, button = funcs.modsOpts      , label = {'Mods...'}, ref_table = self }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.updateLovely  , label = {imm.lovelyver and 'Update Lovely' or 'Install Lovely'}, ref_table = self.ses, func = funcs.updateLovelyInit }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.checkRateLimit, label = {'Check ratelimit'}, ref_table = self }),
    }, {
        UIBox_button({ minw = self.buttonWidth, button = funcs.restart       , label = {'Restart'} }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.clearCacheOpts, label = {'Clear cache...'}, ref_table = self }),
        __IMM_BUNDLE and UIBox_button({ minw = self.buttonWidth, button = funcs.removeBundle, label = {'Remove bundle'}, ref_table = self.ses }) or nil
    }}
end

--- @return balatro.UIElement.Definition[][]
function IUIOpts:gridMods()
    local opts = { __index = { minw = self.buttonWidth, button = funcs.clearCache } }
    return {{
        UIBox_button({ minw = self.buttonWidth, button = funcs.disableAll    , label = {'Disable all'}, ref_table = self.ses }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.updateAll     , label = {'Update all'}, ref_table = self.ses }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.openModFolder , label = {'Open mods folder'} }),
    }, {
        UIBox_button({ minw = self.buttonWidth, button = funcs.enableAll     , label = {'Safe enable all'}, ref_table = self.ses }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.deleteOld     , label = {'Delete old versions'}, ref_table = self }),
        UIBox_button({ minw = self.buttonWidth, button = funcs.copyModlist   , label = {'Copy modlist'}, ref_table = self.ses }),
    }}
end

--- @return balatro.UIElement.Definition[][]
function IUIOpts:gridClearCache()
    local opts = { __index = { minw = self.buttonWidth, button = funcs.clearCache } }
    return {{
        UIBox_button(setmetatable({ ref_table = {ses = self.ses, mode = 't'}, label = {'Clear thumbnails cache'} }, opts)),
        UIBox_button(setmetatable({ ref_table = {ses = self.ses, mode = 'r'}, label = {'Clear releases cache'} }, opts)),
    }, {
        UIBox_button(setmetatable({ ref_table = {ses = self.ses, mode = 'd'}, label = {'Clear downloads'} }, opts)),
        UIBox_button(setmetatable({ ref_table = {ses = self.ses, mode = 'l'}, label = {'Clear list cache'} }, opts)),
    }}
end

--- @param contents balatro.UIElement.Definition[]
function IUIOpts:optionsContainer(contents)
    return create_UIBox_generic_options({
        contents = contents,
        back_func = UIBrowser.funcs.back,
        ref_table = self.ses
    })
end

--- @param grid balatro.UIElement.Definition[][]
function IUIOpts:gridRow(grid)
    return {
        n = G.UIT.R,
        nodes = ui.gapGrid(self.optionSpacing, self.optionSpacing, grid, false)
    }
end

function IUIOpts:render()
    return self:optionsContainer({self:gridRow(self:gridOptions())})
end

--- @param mods? imm.Mod[]
function IUIOpts:uiRenderRemoveMods(mods)
    mods = mods or self.ses.ctrl:getOlderMods()
    local scale = self.ses.fontscale

    --- @type balatro.UIElement.Definition[]
    local uis = { ui.R{ align = 'cm', ui.TS('These mods will be DELETED:', scale) } }

    --- @type balatro.UIElement.Definition[]
    local r = {}
    local rc = 1
    for i, mod in ipairs(mods) do
        table.insert(r, ui.C{ minw = 2.5, align = 'r', ui.TRS(mod.name, scale) })
        table.insert(r, ui.C{ minw = 1, align = 'l', ui.TRS(mod.version, scale, G.C.BLUE) })

        rc = rc + 1
        if rc > 3 then
            rc = 1
            table.insert(uis, ui.R{ padding = 0.1, nodes = r })
            r = {}
        end
    end
    table.insert(uis, ui.R{ padding = 0.1, nodes = r })

    return ui.confirm(ui.R{ui.C(uis)}, funcs.deleteConf, { list = mods, ses = self.ses })
end

function IUIOpts:renderClearCacheOpts()
    return self:optionsContainer({self:gridRow(self:gridClearCache())})
end

function IUIOpts:renderModsOpts()
    return self:optionsContainer({self:gridRow(self:gridMods())})
end

function IUIOpts:renderCheckRateLimitExec()
    local textscale = 0.4
    local conf = { t = 'Checking...', ref_value = 't', scale = textscale }
    conf.ref_table = conf
    local subconf = { t = '', ref_value = 't', scale = textscale * 0.75 }
    subconf.ref_table = subconf

    local t = os.time()
    httpsAgent:request('https://api.github.com/rate_limit', {
        headers = {
            Authorization = imm.config.githubToken and 'Bearer '..imm.config.githubToken or nil
        }
    }, function (code, body, headers)
        if code ~= 200 then
            conf.t = string.format('Error %d', code)
            return
        end
        --- @type ghapi.Ratelimit
        local data = JSON.decode(body)
        local limited = data.rate.remaining == 0
        conf.t = string.format('%s (%d/%d)', limited and "Ratelimited" or "Not ratelimited", data.rate.remaining, data.rate.limit)
        conf.colour = limited and G.C.ORANGE or G.C.GREEN
        subconf.t = string.format('Resets in %d minute(s)', (data.rate.reset - t) / 60)
    end)

    return self:optionsContainer({
        ui.R{
            align = 'cm',
            ui.TS('Github API Ratelimit: ', textscale),
            ui.TC(conf)
        },
        ui.R{
            align = 'cm',
            ui.TC(subconf)
        }
    })
end

--- @class imm.UI.Options.Static
--- @field funcs imm.UI.Options.Funcs

--- @alias imm.UI.Options.C imm.UI.Options.Static | p.Constructor<imm.UI.Options, nil> | fun(ses: imm.UI.Browser): imm.UI.Options
--- @type imm.UI.Options.C
local UISes = constructor(IUIOpts)
UISes.funcs = funcs
return UISes
