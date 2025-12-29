--- @alias imm.TextureMoveable.Mode 'fill' | 'fit'

--- @class imm.TextureMoveable: balatro.Moveable
--- @field mode imm.TextureMoveable.Mode
local ITM = Moveable:extend()
ITM.color = G.C.WHITE
ITM.mode = 'fit'

--- @param drawable? love.Texture
function ITM:init(drawable, X, Y, W, H)
    Moveable.init(self, X, Y, W, H)
    self.drawable = drawable
    table.insert(G.I.MOVEABLE, self)
end

--- @return number xOffset
--- @return number yOffset
--- @return number r (0)
--- @return number xScale
--- @return number yScale
function ITM:getDrawBox()
    local w, h = self.drawable:getDimensions()
    local xs, ys = self.T.w/w, self.T.h/h
    local xo, yo = 0, 0

    if self.mode == 'fill' then
        -- nothing
    elseif self.mode == 'fit' then
        local mar = self.T.w / self.T.h
        local iar = w / h
        if mar > iar then -- image is taller
            xo = xo + xs / 2
            xs = xs * iar / mar
            xo = xo - xs / 2
        elseif mar < iar then -- image is wider
            yo = yo + ys / 2
            ys = ys * mar / iar
            yo = yo - ys / 2
        end
    end

    return xo * w, yo * h, 0, xs, ys
end

function ITM:draw()
    if not self.drawable then return end

    prep_draw(self, 1)
    love.graphics.setColor(self.color)
    love.graphics.draw(self.drawable, self:getDrawBox())
    love.graphics.pop()

    Moveable.draw(self)
end

--- @type imm.TextureMoveable | fun(drawable?: love.Texture | love.Canvas, X, Y, W, H): imm.TextureMoveable
local TextureMoveable = ITM
return TextureMoveable