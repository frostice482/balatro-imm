--- @diagnostic disable

local errhand_orig = love.errorhandler or love.errhand
local hasHandlerOverridden = false

local function __imm_disableAllMods(err)
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

    if not next(list) then return end

    -- detect multiple smods installation
    local smods = list.Steamodded
    if smods and smods.list:list() ~= 1 then
        err = err..'\n\nMultiple Steamodded version detected - Remove the older ones!'
    end

    -- disable mods
    for k,mod in pairs(list) do
        if not mod:isExcluded() then
            table.insert(detecteds, string.format('- %s: %s', mod.mod or '?', mod.version or '?'))
            ctrl:disableMod(mod)
            table.insert(disableds, mod.mod..'='..mod.version)
        end
    end
    err = err..'\n\nimm has disabled detected mods: \n'..table.concat(detecteds, '\n')

    -- make all disabled mods temporary
    if not suspect then
        _imm.initconfig()
        table.insert(disableds, _imm.configs.nextEnable)
        _imm.configs.nextEnable = table.concat(disableds, '==')
        require('imm.lib.util').saveconfig()
        err = err..'\nThese mods are disabled temporarily - it will be reenabled on next startup'
    end

    return err
end

local attached = true

local function handler(err)
    if attached then
        attached = false
        err = type(err) == 'string' and err or tostring(err)
        local ok, nerr = pcall(__imm_disableAllMods, err)
        err = ok and (nerr or err) or ('\n\nimm failed to disable mods: '..err)
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
    if attached then
        attached = false
        print('Pre error detection detached')
    end
    return main_menu_orig(...)
end

_imm.init()
