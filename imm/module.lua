local lovely = require('lovely')

--- @class imm.Base
local imm = {
    configDir = 'config',
    configFile = 'config/imm.txt',
    initialized = false,
    config = {},
    modsDir = lovely.mod_dir,
    lovelyver = lovely.version
}

function imm.parseconfig(entry)
    if entry:sub(1, 1) == '#' then return end
    local s, e, key = entry:find('^([%w%d_-]+) *= *')
    if not key then return end
    imm.config[key] = entry:sub(e+1)
end

function imm.initconfig()
    local configStr = love.filesystem.read(imm.configFile)
    if not configStr then return end

    local util = require('imm.lib.util')
    for i, entry in ipairs(util.strsplit(configStr, '\r?\n')) do
        imm.parseconfig(entry)
    end
end

function imm.saveconfig()
    local entries = {}
    for k,v in pairs(imm.config) do table.insert(entries, k..' = '..tostring(v)) end
    table.sort(entries, function (a, b) return a < b end)

    love.filesystem.createDirectory(imm.configDir)
    love.filesystem.write(imm.configFile, table.concat(entries, '\n'))
end

--- @return boolean ok, string? err
function imm.init()
    if imm.initialized then return true end

    if not imm.path then return false, 'Cannot determine imm path' end
    imm.nfs = require("imm.nativefs")
    imm.json = JSON or package.preload.json and require('json') or require("imm.json")

    if not imm.nfs.mount(imm.path..'/imm', 'imm') then return false, 'imm mount failed' end

    imm.initconfig()

    local loveload = love.load
    function love.load() --- @diagnostic disable-line
        loveload()

        local ok, err = pcall(require, 'imm.main')
        if not ok then print('imm: error:', err, debug.traceback()) end
    end

    imm.initialized = true
    return true
end

return imm
