--- @diagnostic disable

local errhand_orig = love.errorhandler or love.errhand
local hasHandlerOverridden = false

local function disableAllMods(err)
    if _imm.config.handleEarlyError == 'ignore' then return end
    assert(_imm.init())

    local ctrl = require('imm.ctrl')
    local lovely = require('lovely')
    local utilt = require("imm.lib.util.table")
    local shouldDisable = _imm.config.handleEarlyError == 'disable'

    --- @type imm.ModList?
    local suspect = ctrl.mods[err:match("^%[SMODS ([^ ]+)")]
    --- @type string[]
    local disableds = {}

    local echunk = {}

    local list = suspect and suspect.active
        and { [suspect.mod] = suspect.active }
        or ctrl.loadlist.loadedMods

    if not next(list) then return end

    -- detect multiple smods installation
    if list.Steamodded and #list.Steamodded.list:list() ~= 1 then
        table.insert(echunk, 'Multiple Steamodded version detected - Remove the older ones!\n')
    end

    local mods = utilt.values(list, function (va, vb) return va.mod:lower() < vb.mod:lower() end)
    local idlen, verlen = 0, 0

    for i, mod in ipairs(mods) do
        if not mod.list:isExcluded() then
            has = true

            if mod.mod:len() > idlen then idlen = mod.mod:len() end
            if mod.version:len() > verlen then verlen = mod.version:len() end

            if shouldDisable then
                local ok, err = ctrl:disableMod(mod)
                if ok then table.insert(disableds, mod.mod..'='..mod.version)
                else print('imm: error: Failed to disable', mod.mod, err)
                end
            end
        end
    end

    if has then
        table.insert(echunk, 'Detected mods:')

        if shouldDisable then
            -- disable detected mods
            table.insert(echunk, '(these are disabled and will be reenabled on next startup)')

            table.insert(disableds, _imm.config.nextEnable)
            _imm.config.nextEnable = table.concat(disableds, '==')
            _imm.saveconfig()
        end

        local tfmt = string.format("- %%-%ds : %%-%%ds (%%s)", idlen, verlen)
        for i, mod in ipairs(mods) do
            table.insert(echunk, tfmt:format(mod.mod, mod.version, mod.path:sub(lovely.mod_dir:len()+2)))
        end

        if suspect then table.insert(echunk, 'Suspected mod: '..suspect.mod) end
    else
        -- no mods detected
        utilt.insertBatch(echunk, {
            '',
            'Your crash happened without mods - your save may be corrupted. Try:',
            '1. Move save and config files out of the save folder',
            '2. Move all mods out',
            '3. Reinstall Balatro',
            '',
            'Save folder: '..love.filesystem.getSaveDirectory(),
            'Installation: '..love.filesystem.getSource(),
            'Mods folder: '..lovely.mod_dir
        })
    end

    if not hasHandlerOverridden then
        -- version information
        utilt.insertBatch(echunk, {
            '',
            jit.os .. ' ' .. jit.arch,
            _VERSION,
            jit.version,
            'LÖVE ' .. table.concat({love.getVersion()}, '.', 1, 3),
            'Lovely ' .. lovely.version,
            'Balatro ' .. (G and G.VERSION or '?')
        })
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
        err = ok and (nerr or err) or (err..'\n\nimm failed to initialize early error handler: '..nerr)
    end
    return errhand_orig(err)
end

love.errorhandler = errHandler

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

local iok, ierr = _imm.init()
if not iok then print('imm: error: ', ierr) end

