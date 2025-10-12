--- @diagnostic disable

local errhand_orig = love.errorhandler or love.errhand
local hasHandlerOverridden = false

local function disableAllMods(err)
    assert(_imm.init())
    if _imm.config.handleEarlyError == 'ignore' then return end

    local ctrl = require('imm.ctrl')
    local lovely = require('lovely')
    local shouldDisable = _imm.config.handleEarlyError ~= 'nodisable'

    --- @type imm.ModList?
    local suspect = ctrl.mods[err:match("^%[SMODS ([^ ]+)")]
    --- @type imm.Mod[]
    local detecteds = {}
    --- @type string[]
    local disableds = {}

    local echunk = {}

    local list = suspect and suspect.active
        and { [suspect.mod] = suspect.active }
        or ctrl.loadlist.loadedMods

    if not next(list) then return end

    -- detect multiple smods installation
    local smods = list.Steamodded
    if smods and #smods.list:list() ~= 1 then
        table.insert(echunk, 'Multiple Steamodded version detected - Remove the older ones!\n')
    end

    -- disable mods
    local has = false
    for k,mod in pairs(list) do
        if not mod:isExcluded() then
            has = true
            table.insert(detecteds, string.format('- %-30s: %-20s (%s)', mod.mod, mod.version, mod.path:sub(lovely.mod_dir:len()+2)))
            if shouldDisable then
                local ok, err = ctrl:disableMod(mod)
                if ok then table.insert(disableds, mod.mod..'='..mod.version)
                else print('imm: error: Failed to disable', mod.mod, err)
                end
            end
        end
    end
    if has then
        table.insert(echunk, shouldDisable and 'imm has disabled detected mods:' or 'Detected mods:')
        table.insert(echunk, table.concat(detecteds, '\n'))

        -- make all disabled mods temporary
        if not suspect then
            table.insert(disableds, _imm.config.nextEnable)
            _imm.config.nextEnable = table.concat(disableds, '==')
            _imm.saveconfig()
            table.insert(echunk, shouldDisable and 'These mods are disabled temporarily - it will be reenabled on next startup' or nil)
        else
            table.insert(echunk, 'Suspected mod: '..suspect.mod)
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
            jit.os .. ' ' .. jit.arch,
            _VERSION,
            jit.version,
            'LÖVE ' .. table.concat({love.getVersion()}, '.', 1, 3),
            'Lovely ' .. lovely.version,
            'Balatro ' .. (G and G.VERSION or '?')
        }
        for i,v in ipairs(vers) do table.insert(echunk, v) end
    end

    err = err .. '\n' .. table.concat(echunk, '\n')

    return err
end

local attached = true

local function errHandler(err)
    err = type(err) == 'string' and err or tostring(err)
    if attached then
        attached = false
        local ok, nerr = pcall(disableAllMods, err)
        err = ok and (nerr or err) or (err..'\n\nimm failed to disable mods: '..nerr)
    end
    if __IMM_BUNDLE then
        err = err.."\nYou are loading Balatro from imm's bundled main.lua! Consider removing the main.lua from the save file"
    end
    return errhand_orig(err)
end

love.errorhandler = errHandler

--bundle inject

assert(func, err)
local ok, err = pcall(func)

if love.errorhandler ~= errHandler then
    errhand_orig = love.errorhandler or love.errhand
    love.errorhandler = errHandler
    hasHandlerOverridden = true
end

assert(ok, err)

local h = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons(...)
    if attached then
        attached = false
        print('Pre error detection detached')
    end
    return h(...)
end

_imm.init()
