local util = require('imm.lib.util')

--- @param browser imm.Browser
--- @param file love.DroppedFile
local function dropinstall(browser, file)
    local fd = love.filesystem.newFileData(file:read('data'), '')
    file:close()

    local ml = browser:installModFromZip(fd)
    local _, mod = next(ml)
    local modmeta = mod and util.createMetaFromEntry(mod)
    if modmeta then browser:selectMod(modmeta) end
end

local o2 = love.filedropped
function love.filedropped(file) --- @diagnostic disable-line
    if G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm then
        return dropinstall(G.OVERLAY_MENU.config.imm, file)
    end
    if o2 then o2(file) end
end
