--- @diagnostic disable

local errhand_orig = love.errorhandler or love.errhand
local hasHandlerOverridden = false

local function __imm_disableAllMods(err)
    assert(_imm.init())
    local ctrl = require('imm.modctrl')
    local util = require('imm.lib.util')
    local lovely = require('lovely')

    --- @type string?
    local suspect = err:match("^%[SMODS ([^ ]+)")
    --- @type imm.Mod[]
    local detecteds = {}
    --- @type string[]
    local disableds = {}

    local echunk = {}

    local list = suspect and ctrl.loadlist.loadedMods[suspect]
        and {suspect = ctrl.loadlist.loadedMods[suspect]}
        or ctrl.loadlist.loadedMods

    if not next(list) then return end

    -- detect multiple smods installation
    local smods = list.Steamodded
    if smods and #smods.list:list() ~= 1 then
        table.insert(echunk, 'Multiple Steamodded version detected - Remove the older ones!\n')
    end

    --- @type table<imm.Mod>
    local activeListCopy = {}

    -- disable mods
    local has = false
    for k,mod in pairs(list) do
        if not hasHandlerOverridden then
            activeListCopy[mod] = true
        end

        if not mod:isExcluded() then
            has = true
            table.insert(detecteds, string.format('- %-30s: %-20s (%s)', mod.mod, mod.version, mod.path:sub(lovely.mod_dir:len()+2)))
            local ok, err = ctrl:disableMod(mod)
            if ok then table.insert(disableds, mod.mod..'='..mod.version)
            else print('imm: error: Failed to disable', mod.mod, err)
            end
        end
    end
    if has then
        table.insert(echunk, 'imm has disabled detected mods:')
        table.insert(echunk, table.concat(detecteds, '\n'))

        -- make all disabled mods temporary
        if not suspect then
            table.insert(disableds, _imm.configs.nextEnable)
            _imm.configs.nextEnable = table.concat(disableds, '==')
            util.saveconfig()
            table.insert(echunk, 'These mods are disabled temporarily - it will be reenabled on next startup')
        end
    else
        local msg = {
            '',
            'Your crash happened without mods - your save may be corrupted. Try:',
            '1. Move save and config files out of the save folder',
            '2. Move all mods out',
            '3. Reinstall Balatro',
            '',
            'Save folder: '..love.filesystem.getSaveDirectory(),
            'Installation: '..love.filesystem.getSource(),
            'Mods folder: '..lovely.mod_dir
        }
        for i,v in ipairs(msg) do table.insert(echunk, v) end
    end

    if not hasHandlerOverridden then
        local vers = {
            '',
            'Lovely ' .. lovely.version,
            jit.os .. ' ' .. jit.arch,
            _VERSION,
            jit.version,
            'LÖVE ' .. table.concat({love.getVersion()}, '.', 1, 3),
            'Balatro ' .. (G and G.VERSION or '?')
        }
        for i,v in ipairs(vers) do table.insert(echunk, v) end

        --[[
        --- @type imm.ModList[]
        local listSorted = {}
        for k,list in pairs(ctrl.mods) do
            table.insert(listSorted, list)
        end
        table.sort(listSorted, function (a, b) return a.mod < b.mod end)

        table.insert(echunk, '')
        table.insert(echunk, 'Installed mods:')
        for i, list in ipairs(listSorted) do
            for i, mod in pairs(list:list()) do
                table.insert(echunk, string.format('- %s: %s (%s)', mod.mod, mod.version, mod.path:sub(lovely.mod_dir:len()+2)))
            end
        end
        ]]
    end

    err = err .. '\n' .. table.concat(echunk, '\n')

    return err
end

local attached = true

local function handler(err)
    if attached then
        attached = false
        err = type(err) == 'string' and err or tostring(err)
        local ok, nerr = pcall(__imm_disableAllMods, err)
        err = ok and (nerr or err) or ('\n\nimm failed to disable mods: '..nerr)
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
