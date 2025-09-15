--- @param browser imm.UI.Browser
--- @param file love.DroppedFile
local function dropinstall(browser, file)
    local fd = love.filesystem.newFileData(file:read('data'), '')
    file:close()

    local ml = browser:installModFromZip(fd)
    local _, list = next(ml)
    if not list then return end

    local meta
    for i,v in ipairs(browser.repo.list) do
        if v:id() == list.mod then
            meta = v
            break
        end
    end
    meta = meta or list:createBmiMeta(browser.repo)
    if meta then browser:selectMod(meta) end
end

local o2 = love.filedropped
function love.filedropped(file) --- @diagnostic disable-line
    if G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm then
        return dropinstall(G.OVERLAY_MENU.config.imm, file)
    end
    if o2 then o2(file) end
end
