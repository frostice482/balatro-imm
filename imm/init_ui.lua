require("imm.ui.browser")
require('imm.dropinstall')
require('imm.uifuncs.browser')
require('imm.uifuncs.confirm_toggle')
require('imm.uifuncs.mod')
require('imm.uifuncs.opts')
require('imm.uifuncs.version')

local imm = require("imm.config")
local function atlas(key, path, px, py)
    local abspath = string.format('%s/assets/%s', _imm.path, path)
    local name = 'imm_'..key

    G.ASSET_ATLAS[name] = {
        image = love.graphics.newImage(imm.resbundle and imm.resbundle.assets[key] or assert(NFS.newFileData(abspath)), { dpiscale = 1 }),
        name = name,
        px = px,
        py = py
    }
end

atlas('icons', 'icons.png', 19, 19)
atlas('toggle', 'toggle.png', 15, 9)
