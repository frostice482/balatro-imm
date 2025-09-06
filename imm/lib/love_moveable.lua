--- @class imm.LoveMoveable: balatro.Moveable
local ILoveMoveable = Moveable:extend()

--- @param drawable love.Texture | love.Canvas
function ILoveMoveable:init(drawable, X, Y, W, H)
    Moveable.init(self, X, Y, W, H)
    self.drawable = drawable
    self.color = G.C.WHITE

    table.insert(G.I.MOVEABLE, self)
end

function ILoveMoveable:draw()
    local w, h = self.drawable:getDimensions()
    prep_draw(self, 1)
    love.graphics.setColor(self.color)
    love.graphics.draw(self.drawable, 0, 0, 0, self.T.w/w, self.T.h/h)
    love.graphics.pop()

    Moveable.draw(self)
end

--- @type imm.LoveMoveable | fun(drawable: love.Texture | love.Canvas, X, Y, W, H): imm.LoveMoveable
local LoveMoveable = ILoveMoveable
return LoveMoveable