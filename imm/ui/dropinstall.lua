local co = require "imm.lib.co"

--- @param browser imm.UI.Browser
--- @param info imm.InstallResult
local function handleresult(browser, info)
    local _, list = next(info.mods)
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

--- @param browser imm.UI.Browser
--- @param file love.DroppedFile
local function dropinstall(browser, file)
    local fd = file:read('data')
    file:close()
    local info = browser.tasks:createDownloadCoSes():installModFromZip(fd) --- @diagnostic disable-line
    handleresult(browser, info)
end

local mnttmp = 0

--- @param browser imm.UI.Browser
--- @param dir string
local function dirinstall(browser, dir)
    mnttmp = mnttmp + 1
    local tmpdir = 'imm-tmpd-'..mnttmp
    local ok = love.filesystem.mount(dir, tmpdir)
    if not ok then
        browser.tasks.status:update(nil, "Failed mounting temp folder")
        return
    end

    local info = browser.tasks:createDownloadCoSes():installModFromDir(tmpdir, false)

    ok = love.filesystem.unmount(dir)
    if not ok then
        print('Failed unmounting temp folder ' .. tmpdir)
    end
    handleresult(browser, info)
end

local filehook = love.filedropped
function love.filedropped(file) --- @diagnostic disable-line
    if G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm then
        return co.create(dropinstall, G.OVERLAY_MENU.config.imm, file)
    end
    if filehook then return filehook(file) end
end

local dirhook = love.directorydropped
function love.directorydropped(file) --- @diagnostic disable-line
    if G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm then
        return co.create(dirinstall, G.OVERLAY_MENU.config.imm, file)
    end
    if dirhook then return dirhook(file) end
end
