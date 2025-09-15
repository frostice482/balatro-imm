--- @diagnostic disable

local errhand_orig = love.errorhandler or love.errhand
local hasHandlerOverridden = false

local function __imm_disableAllMods(err)
    if not _imm then error('imm not available', 0) end
    assert(_imm.init())

    local ctrl = require('imm.modctrl')

    --- @type string?
    local suspect = err:match("^%[SMODS ([^ ]+)")
    --- @type imm.Mod[]
    local detecteds = {}
    --- @type string[]
    local disableds = {}

    local list = suspect and ctrl.loadlist.loadedMods[suspect]
        and {suspect = ctrl.loadlist.loadedMods[suspect]}
        or ctrl.loadlist.loadedMods

    for k,mod in pairs(list) do
        if mod.mod ~= 'balatro_imm' and not mod.list.native then
            table.insert(detecteds, string.format('- %s: %s', mod.mod or '?', mod.version or '?'))
            ctrl:disableMod(mod)
            table.insert(disableds, mod.mod..'='..mod.version)
        end
    end

    if not suspect then
        _imm.initconfig()
        table.insert(disableds, _imm.configs.nextEnable)
        _imm.configs.nextEnable = table.concat(disableds, '==')
        require('imm.lib.util').saveconfig()
    end

    return detecteds, suspect
end

local function handler(err)
    err = tostring(err)
    if not hasHandlerOverridden then err = debug.traceback(err..'\n', 2) end

    local ok, res = pcall(__imm_disableAllMods, err)
    if not ok then
        err = err..'\n\nimm failed to disable mods: '..res
    else
        err = err..'\n\nimm has disabled detected mods: \n'..table.concat(res, '\n')
    end

    return errhand_orig(err)
end

love.errorhandler = handler

assert(func, err)
local ok, err = pcall(func, ...)

if love.errorhandler ~= handler then
    errhand_orig = love.errorhandler or love.errhand
    love.errorhandler = handler
    hasHandlerOverridden = true
end

assert(ok, err)

local main_menu_orig = Game.main_menu
function Game.main_menu(...)
    Game.main_menu = main_menu_orig
    love.errorhandler = errhand_orig
    print('Pre error detection detached')
    return main_menu_orig(...)
end

_imm.init()
