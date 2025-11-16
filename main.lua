--- @class imm.Base
_imm = {
    configFile = 'config/imm.txt',
    initialized = false,
    config = {},
}

--bundle inject

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

    love.filesystem.createDirectory(_imm.dirname(_imm.configFile))
    love.filesystem.write(_imm.configFile, table.concat(entries, '\n'))
end

--- @return string dirname, string filename
function _imm.dirname(str)
    local prev
    while true do
        local a, b = str:find('[/\\]', (prev or 0) + 1)
        if not b then break end
        prev = b
    end
    if not prev then return '', str end
    return str:sub(1, prev-1), str:sub(prev+1)
end

--- @return string filename, string extname
function _imm.filename(str)
    local prev
    while true do
        local a, b = str:find('.', (prev or 0) + 1, true)
        if not b then break end
        prev = b
    end
    if not prev then return str, '' end
    return str:sub(1, prev-1), str:sub(prev)
end

function _imm.determineConfpath()
    if jit.os == 'Linux' then
        return os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME')..'/.config'
    elseif jit.os == 'OSX' then
        return os.getenv('HOME')..'/Library/Application Support'
    elseif jit.os == 'Windows' then
        return os.getenv('appdata')
    end
end

function _imm.determineModpath()
    local confpath = _imm.determineConfpath()
    if not confpath then return end

    local exe = arg[-2] -- is this consistent??
    local dirname, filename = _imm.dirname(exe)
    if jit.os == 'OSX' then
        dirname, filename = _imm.dirname(_imm.dirname(_imm.dirname(dirname)))
    end
    local base, ext = _imm.filename(filename)
    base = base:gsub("%.", "_")

    return table.concat({ confpath, base, 'Mods' }, '/')
end

function _imm.applyNonLovelyHook()
    local a = create_UIBox_generic_options
    local G2 = _G
    function G2.create_UIBox_generic_options(opts) --- @diagnostic disable-line
        local n = a(opts)
        if opts then
            if opts.ref_table then
                n.nodes[1].nodes[1].nodes[2].config.ref_table = opts.ref_table
            end
        end
        return n
    end
end

--- @return boolean ok, string? err
function _imm.init()
    if _imm.initialized then return true end

    NFS = NFS or package.preload.nativefs and require('nativefs') or require("imm-nativefs")
    JSON = JSON or package.preload.json and require('json') or require("imm-json")

    local selfdir
    local moddir
    if _imm.resbundle then
        _imm.applyNonLovelyHook()
        local lok, lovely = pcall(require, 'lovely')
        if lok then
            moddir = lovely.mod_dir
            _imm.lovelyver = lovely.version
        end
        if not moddir then moddir = os.getenv("LOVELY_MOD_DIR") end
        if not moddir then moddir = _imm.determineModpath() end
        if not moddir then error("Cannot determine mod path (unsupported os?)") end
        selfdir = {}
    else
        local lovely = require('lovely')
        moddir = lovely.mod_dir
        _imm.lovelyver = lovely.version
        selfdir = _mod_dir_immpath
        if not NFS.mount(_mod_dir_immpath..'/imm', 'imm') then return false, 'imm mount failed' end
    end

    _imm.path = selfdir
    _imm.modsDir = moddir
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
