local lovely = require('lovely')

--- @class imm.Base
_imm = {
    configDir = 'config',
    configFile = 'config/imm.txt',
    initialized = false,
    config = {},
    modsDir = lovely.mod_dir,
    path = _mod_dir_immpath,
    lovelyver = lovely.version
}

function _imm.initmodule()
    package.loaded.imm = package.loaded.imm or _imm
end

function _imm.parseconfig(entry)
    if entry:sub(1, 1) == '#' then return end
    local s, e, key = entry:find('^([%w%d_-]+) *= *')
    if not key then return end
    _imm.config[key] = entry:sub(e+1)
end

function _imm.initconfig()
    _imm.initmodule()

    local configStr = love.filesystem.read(_imm.configFile)
    if not configStr then return end

    local util = require('imm.lib.util')
    for i, entry in ipairs(util.strsplit(configStr, '\r?\n')) do
        _imm.parseconfig(entry)
    end
end

function _imm.saveconfig()
    local entries = {}
    for k,v in pairs(_imm.config) do table.insert(entries, k..' = '..tostring(v)) end
    table.sort(entries, function (a, b) return a < b end)

    love.filesystem.createDirectory(_imm.configDir)
    love.filesystem.write(_imm.configFile, table.concat(entries, '\n'))
end

--- @return boolean ok, string? err
function _imm.init()
    if _imm.initialized then return true end

    NFS = NFS or package.preload.nativefs and require('nativefs') or require("imm-nativefs")
    JSON = JSON or package.preload.json and require('json') or require("imm-json")

    if not NFS.mount(_mod_dir_immpath..'/imm', 'imm') then return false, 'imm mount failed' end

    _imm.initconfig()

    local loveload = love.load
    function love.load() --- @diagnostic disable-line
        loveload()

        local ok, err = pcall(require, 'imm.init')
        if not ok then print('imm: error:', err, debug.traceback()) end
    end

    _imm.initialized = true
    return true
end
if not __IMM_WRAP then _imm.init() end
