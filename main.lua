--- @diagnostic disable

local function __imm_atlas(base, key, path, px, py)
    local abspath = string.format('%s/assets/%dx/%s', base, G.SETTINGS.GRAPHICS.texture_scaling, path)
    local name = 'imm_'..key

    G.ASSET_ATLAS[name] = {
        image = love.graphics.newImage(assert(NFS.newFileData(abspath)), { dpiscale = G.SETTINGS.GRAPHICS.texture_scaling }),
        name = name,
        px = px,
        py = py
    }
end

local function __imm_postload(selfdir)
    __imm_atlas(selfdir, 'icons', 'icons.png', 19, 19)
    __imm_atlas(selfdir, 'toggle', 'toggle.png', 15, 9)

    require('imm.ui')
end

local function __imm_init()
    if package.preload.nativefs then
        print("Using SMODS-provided NFS")
        NFS = require("nativefs")
    else
        NFS = require("imm-nativefs")
    end

    if package.preload.json then
        print("Using SMODS-provided JSON")
        JSON = require("json")
    else
        JSON = require("imm-json")
    end

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
        print('imm: could not determine path')
        return
    end

    NFS.mount(selfdir..'/imm', 'imm')
    package.loaded['imm.config'] = {
        path = selfdir,
        modsDir = moddir
    }

    local loveload = love.load
    function love.load() --- @diagnostic disable-line
        loveload()
        __imm_postload(selfdir)
    end
end
if not __IMM_WRAP then __imm_init() end
