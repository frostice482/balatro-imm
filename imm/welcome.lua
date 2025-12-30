local ui = require("imm.lib.ui")
local co = require('imm.lib.co')

local fontscale = 0.4
local fontscalesub = fontscale * 0.9

local confBut = 'imm_w_conf'

--- @param b imm.UI.Browser
local function installSmodsCo(b)
    local ok, err
    local repo = require("imm.repo")
    local status = b.tasks.status:new()

    status:update("Getting Steamodded releases")
    local err, releases = repo.bmi:getReleasesCo('https://github.com/Steamodded/smods')
    if not releases then return status:error(err or "") end

    --- @type ghapi.Releases?
    local latestRelease
    for i,v in ipairs(releases) do if not v.prerelease then latestRelease = v break end end
    if not latestRelease then return status:error("Cannot determine latest Steamodded version") end

    status:done("")
    err = b.tasks:createDownloadCoSes():download(latestRelease.zipball_url, { name = 'Steamodded '..latestRelease.tag_name })
    if err then return end

    local reg = b.ctrl.mods.Steamodded
    local latest = reg and reg:latest()
    if not latest then return b.tasks.status:update(nil, "Cannot get latest installed Steamodded version") end

    ok, err = b.ctrl:enableMod(latest)
    if not ok then return b.tasks.status:update(nil, err) end
    b.hasChanges = true
end

--- @param b imm.UI.Browser
local function installLovelyCo(b)
    b.tasks:downloadLovelyCo()
end

--- @param b imm.UI.Browser
local function handleAfter(b)
    co.create(installSmodsCo, b)
end

G.FUNCS[confBut] = function (elm)
    _imm.config.init = '1'
    _imm.saveconfig()

    local b = G.FUNCS.imm_browse()
    if not elm.config.ref_table.confirm then return end

    co.create(function ()
        co.waitFrames(2)
        handleAfter(b)
    end)
end

local function uiWelcome()
    --- @type balatro.UIElement.Definition[]
    local l = {
        ui.TRS("Welcome to Modded Balatro!", fontscale * 1.25),
        ui.TRS("Do you want to install recommended mods below?", fontscale)
    }
    if true then
        table.insert(l, ui.TRS('- Steamoddded', fontscalesub, G.C.GREEN))
    end
    return ui.gapList('R', 0.1, l)
end

local function uiWelcomeWrap()
    return ui.confirm(ui.R(uiWelcome()), confBut)
end

local G2 = G
local init = false
local _main_menu = G2.main_menu
function G2:main_menu(...)
    if not init then
        init = true
        ui.overlay(uiWelcomeWrap())
    end
    return _main_menu(self, ...)
end