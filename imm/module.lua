local lovely = require('lovely')

--- @class imm.InitStatus
--- @field f? fun()
--- @field ferr? string
local initstatus = {
    imm =  false,
    config = false,
    f = nil,
    ferr = nil,
    wrap = false
}

--- @class imm.Base
--- @field configFile string
--- @field path string
local imm = {
    initstatus = initstatus,
    configDir = 'config',
    configFile = 'config/imm.txt',
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

function imm.initmodule()
    imm.nfs = require("imm.include.nativefs")
    imm.json = JSON or package.preload.json and require('json') or require("imm.include.json")
end

function imm.initconfig()
    local configStr = love.filesystem.read(imm.configFile)
    if not configStr then return end

    local sutil = require('imm.lib.util.str')
    for i, entry in sutil.splitentries(configStr, '\r?\n') do
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
    if imm.initstatus.imm then return true end

    if not imm.path then return false, 'Cannot determine imm path' end
    local ok, err = pcall(require("imm.minimount"), "imm", "imm", imm.path, "imm", "imm")
    if not ok then return false, err end

    imm.initstatus.imm = true

    imm.initmodule()
    imm.initconfig()

    local loveload = love.load
    function love.load() --- @diagnostic disable-line
        loveload()

        local ok, err = pcall(require, 'imm.main')
        if not ok then print('imm: error:', err, debug.traceback()) end
    end

    return true
end

return imm
