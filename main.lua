_imm = {
    configFile = 'config/imm.txt',
    initialized = false,
    ---@type imm.ParsedConfig
    configs = {},
}

function _imm.initmodule()
    if package.loaded['imm.config'] then return end

    --- @type imm.Config
    package.loaded['imm.config'] = {
        path = _imm.selfdir,
        modsDir = _imm.modsDir,
        configFile = _imm.configFile,
        config = _imm.configs
    }
end

function _imm.parseconfig(entry)
    if entry:sub(1, 1) == '#' then return end
    local s, e, key = entry:find('^([%w%d_-]+) *= *')
    if not key then return end
    _imm.configs[key] = entry:sub(e+1)
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

--- @return boolean ok, string? err
function _imm.init()
    if _imm.initialized then return true end

    NFS = NFS or package.preload.nativefs and require('nativefs') or require("imm-nativefs")
    JSON = JSON or package.preload.json and require('json') or require("imm-json")

    local selfdir
    local moddir = require('lovely').mod_dir
    for i, item in ipairs(NFS.getDirectoryItems(moddir)) do
        local base = moddir..'/'..item
        if not NFS.getInfo(base..'/.lovelyignore') and NFS.read(base..'/imm/sig') == 'balatro-imm' then
            selfdir = base
            break
        end
    end

    if not selfdir then
        print('imm: error: could not determine path')
        return false, 'could not determine imm path'
    end

    if not NFS.mount(selfdir..'/imm', 'imm') then return false, 'imm mount failed' end
    _imm.selfdir = selfdir
    _imm.modsDir = moddir
    _imm.initconfig()

    local loveload = love.load
    function love.load() --- @diagnostic disable-line
        loveload()

        local ok, err = pcall(require, 'imm.init')
        if not ok then print('imm: error:', err) end
    end

    _imm.initialized = true
    return true
end
if not __IMM_WRAP then _imm.init() end --- @diagnostic disable-line
