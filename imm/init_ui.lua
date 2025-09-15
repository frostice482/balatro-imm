require("imm.ui.browser")
require('imm.dropinstall')
require('imm.uifuncs.browser')
require('imm.uifuncs.confirm_toggle')
require('imm.uifuncs.mod')
require('imm.uifuncs.opts')
require('imm.uifuncs.version')

local function atlas(key, path, px, py)
    local abspath = string.format('%s/assets/%dx/%s', _imm.selfdir, G.SETTINGS.GRAPHICS.texture_scaling, path)
    local name = 'imm_'..key

    G.ASSET_ATLAS[name] = {
        image = love.graphics.newImage(assert(NFS.newFileData(abspath)), { dpiscale = G.SETTINGS.GRAPHICS.texture_scaling }),
        name = name,
        px = px,
        py = py
    }
end

atlas('icons', 'icons.png', 19, 19)
atlas('toggle', 'toggle.png', 15, 9)
