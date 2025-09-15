local constructor = require("imm.lib.constructor")
local UIBrowser = require("imm.ui.browser")
local httpsAgent = require('imm.https_agent')
local ui = require('imm.lib.ui')

--- @class imm.UI.Options.Funcs
local funcs = {
    restart        = 'imm_o_restart',
    openModFolder  = 'imm_o_open',
    clearCache     = 'imm_o_clearcache',
    checkRateLimit = 'imm_o_checkghratelimit',
    disableAll     = 'imm_o_disableall'
}

--- @class imm.UI.Options
local IUIOpts = {}

--- @param ses imm.UI.Browser
function IUIOpts:init(ses)
    self.ses = ses
end

--- @param commonOpts balatro.UI.ButtonParam
--- @return balatro.UIElement.Definition[]
function IUIOpts:A(commonOpts)
    return {
        UIBox_button(setmetatable({ button = funcs.disableAll       , label = {'Disable all mods'}, ref_table = self.ses }, {__index = commonOpts})),
        UIBox_button(setmetatable({ button = funcs.restart          , label = {'Restart'} }, {__index = commonOpts})),
        UIBox_button(setmetatable({ button = funcs.openModFolder    , label = {'Open mods folder'} }, {__index = commonOpts})),
        UIBox_button(setmetatable({ button = funcs.checkRateLimit   , label = {'Check ratelimit'}, ref_table = self }, {__index = commonOpts})),
    }
end

--- @param commonOpts balatro.UI.ButtonParam
--- @return balatro.UIElement.Definition[]
function IUIOpts:B(commonOpts)
    return {
        UIBox_button(setmetatable({ button = funcs.clearCache, ref_table = {ses = self.ses, mode = 't'}, label = {'Clear thumbnails cache'} }, {__index = commonOpts})),
        UIBox_button(setmetatable({ button = funcs.clearCache, ref_table = {ses = self.ses, mode = 'd'}, label = {'Clear downloads'} }, {__index = commonOpts})),
        UIBox_button(setmetatable({ button = funcs.clearCache, ref_table = {ses = self.ses, mode = 'r'}, label = {'Clear releases cache'} }, {__index = commonOpts})),
        UIBox_button(setmetatable({ button = funcs.clearCache, ref_table = {ses = self.ses, mode = 'l'}, label = {'Clear list cache'} }, {__index = commonOpts})),
    }
end

--- @param commonOpts balatro.UI.ButtonParam
--- @return balatro.UIElement.Definition[][]
function IUIOpts:grid(commonOpts)
    return {
        self:A(commonOpts),
        self:B(commonOpts)
    }
end

function IUIOpts:render()
    local spacing = 0.2
    local commonOpts = { ref_table = self, minw = 4 }
    return create_UIBox_generic_options({
        contents = {{
            n = G.UIT.R,
            nodes = ui.gapGrid(spacing, spacing, self:grid(commonOpts), false)
        }},
        back_func = UIBrowser.funcs.back,
        ref_table = self.ses
    })
end

function IUIOpts:renderCheckRateLimitExec()
    local textscale = 0.4
    local conf = { t = 'Checking...', ref_value = 't', scale = textscale }
    conf.ref_table = conf
    local subconf = { t = '', ref_value = 't', scale = textscale * 0.75 }
    subconf.ref_table = subconf

    local t = os.time()
    httpsAgent:request('https://api.github.com/rate_limit', nil, function (code, body, headers)
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

    return create_UIBox_generic_options({
        contents = {{
            n = G.UIT.R,
            config = { align = 'cm' },
            nodes = {
                { n = G.UIT.T, config = { text = 'Github API Ratelimit: ', scale = textscale } },
                { n = G.UIT.T, config = conf },
            }
        }, {
            n = G.UIT.R,
            config = { align = 'cm' },
            nodes = {
                { n = G.UIT.T, config = subconf },
            }
        }},
        back_func = UIBrowser.funcs.back,
        ref_table = self.ses
    })
end

--- @class imm.UI.Options.Static
--- @field funcs imm.UI.Options.Funcs

--- @alias imm.UI.Options.C imm.UI.Options.Static | p.Constructor<imm.UI.Options, nil> | fun(ses: imm.UI.Browser): imm.UI.Options
--- @type imm.UI.Options.C
local UISes = constructor(IUIOpts)
UISes.funcs = funcs
return UISes
