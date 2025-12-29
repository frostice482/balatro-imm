local function atlas(key, path, px, py)
    local name = 'imm_'..key
    local img = love.graphics.newImage(string.format('imm/assets/%s', path), { dpiscale = 1 })
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
atlas('nothumb', 'nothumb.png', 32, 32)
