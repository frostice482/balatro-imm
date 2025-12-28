local imm = require('imm')

local function atlas(key, path, px, py)
    local abspath = string.format('%s/assets/%s', _imm.path, path)
    local name = 'imm_'..key
    local source = assert(imm.nfs.newFileData(abspath))
    local img = love.graphics.newImage(source, { dpiscale = 1 })
    img:setFilter("nearest", "nearest")
    G.ASSET_ATLAS[name] = {
        image = img,
        name = name,
        px = px,
        py = py
    }
end

atlas('icons', 'icons.png', 19, 19)
atlas('toggle', 'toggle.png', 15, 9)
