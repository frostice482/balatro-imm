local constructor = require('imm.lib.constructor')
local ModList = require('imm.lib.mod.list')
local getmods = require('imm.lib.mod.get')
local util = require('imm.lib.util')
local repo = require('imm.lib.repo')
local logger = require('imm.logger')

--- @class imm.ModController
--- The provided id \
--- The version provided \
--- the mod that provides it \
--- @field provideds table<string, table<string, table<imm.Mod, imm.Mod>>>
local IModCtrl = {}

--- @protected
--- @param noInit? boolean
function IModCtrl:init(noInit)
    self.mods = noInit and {} or getmods.getMods()
    self.provideds = {}

    for id, list in pairs(self.mods) do
        for ver, mod in pairs(list.versions) do
            self:add(mod)
        end
    end
end

local function errNotFound(mod)
    return false, string.format('Mod %s not found', mod)
end

--- @param mod string
function IModCtrl:disable(mod)
    local list = self.mods[mod]
    if not list then return errNotFound(mod) end
    return list:disable()
end

--- @param mod string
--- @param version string
function IModCtrl:enable(mod, version)
    local list = self.mods[mod]
    if not list then return errNotFound(mod) end
    return list:enable(version)
end

--- @protected
--- @param info imm.Mod
--- @param id string
--- @param ver string
function IModCtrl:addProvider(info, id, ver)
    if not self.provideds[id] then self.provideds[id] = {} end
    local verList = self.provideds[id]
    if not verList[ver] then verList[ver] = {} end

    verList[ver][info] = info
end

--- @protected
--- @param info imm.Mod
--- @param id string
--- @param ver string
function IModCtrl:deleteProvider(info, id, ver)
    if not self.provideds[id] then return end
    local verList = self.provideds[id]
    if not verList[ver] then return end

    verList[ver][info] = nil
    if not next(verList[ver]) then verList[ver] = nil end
end

--- @protected
--- @param info imm.Mod
function IModCtrl:add(info)
    if info.provides then
        for id, ver in pairs(info.provides) do
            self:addProvider(info.provides, id, ver)
        end
    end
    return true
end

--- @protected
--- @param info imm.Mod
function IModCtrl:deleteEntry(info, noUninstall)
    if not noUninstall then
        local ok, err = info:uninstall()
        if not ok then return ok, err end
    end
    if info.provides then
        for id, ver in pairs(info.provides) do
            self:deleteProvider(info.provides, id, ver)
        end
    end
    return true
end

--- @param mod string
--- @param version string
function IModCtrl:uninstall(mod, version)
    local list = self.mods[mod]
    if not list then return errNotFound(mod) end
    local info = list.versions[version]
    if not info then return list:errVerNotFound(version) end
    return self:deleteEntry(info)
end

--- @param info imm.Mod
--- @param sourceNfs boolean
--- @param excludedDirs? table<string, boolean>
function IModCtrl:install(info, sourceNfs, excludedDirs)
    local mod, ver = info.mod, info.version
    if not self.mods[mod] then self.mods[mod] = ModList(mod) end
    local list = self.mods[mod]

    -- unisntall existing version
    if list.versions[ver] then
        local ok, err = self:deleteEntry(list.versions[ver])
        if not ok then return ok, err end
    end

    -- get target path
    local c = 0
    local tpath_orig = string.format('%s/%s-%s', repo.modsDir, mod, ver)
    local tpath = tpath_orig
    if NFS.getInfo(tpath) then
        c = c + 1
        tpath = string.format('%s_%d', tpath_orig, c)
    end

    -- copies to target
    local ok, err = pcall(util.cpdir, info.path, tpath, sourceNfs, true, excludedDirs and function (source) return excludedDirs[source] end)
    if not ok then return ok, err end
    logger.fmt('log', 'Copied %s %s to %s', mod, ver, tpath)

    -- ignore
    local ok, err = NFS.write(tpath .. '/.lovelyignore', '')
    if not ok then return ok, err end

    -- fix linking
    list.versions[ver] = info
    info.list = list
    info.path = tpath

    self:add(info)
    logger.fmt('log', 'Installed %s %s', mod, ver)
    return true
end

--- @param dir string
--- @param sourceNfs boolean
function IModCtrl:installFromDir(dir, sourceNfs)
    local modslist = getmods.getMods({ base = dir, isNfs = sourceNfs })
    --- @type imm.Mod[]
    local intalled = {}
    --- @type string[]
    local errors = {}

    --- @type imm.Mod[]
    local rawlist = {}
    local paths = {}
    local excludedPaths = {}

    for mod, modvers in pairs(modslist) do
        for ver, info in pairs(modvers.versions) do
            table.insert(rawlist, info)
            paths[info.path] = info
        end
    end
    table.sort(rawlist, function (a, b) return a.pathDepth > b.pathDepth end)

    for i, info in ipairs(rawlist) do
        local curPath = info.path

        -- install
        local ok, err = self:install(info, sourceNfs, excludedPaths)
        if not ok then
            logger.err(err)
            table.insert(errors, string.format('%s %s: %s', info.mod, info.version, err))
        else
            table.insert(intalled, info)
        end

        -- determine if nested install
        -- if nested exclude the path
        for i=info.pathDepth, 2, -1 do
            local par = curPath
            curPath = util.dirname(curPath)
            local parmod = paths[curPath]
            if parmod then
                logger.fmt('log', '%s %s is a nested install from %s %s %s', info.mod, info.version, parmod.mod, parmod.version, curPath)
                excludedPaths[par] = true
                break
            end
        end
    end

    return modslist, intalled, errors
end

local mnttmp = 0

--- @param zipData love.FileData
function IModCtrl:installFromZip(zipData)
    mnttmp = mnttmp + 1
    local tmpdir = 'tmp-'..mnttmp
    local ok = love.filesystem.mount(zipData, tmpdir)
    if not ok then return {}, {}, { 'Mount failed - is the file a zip?' } end

    local a, b, c = self:installFromDir(tmpdir, false)
    love.filesystem.unmount(zipData) --- @diagnostic disable-line

    return a, b, c
end

--- @alias imm.ModController.C p.Constructor<imm.ModController, nil> | fun(noInit?: boolean): imm.ModController
--- @type imm.ModController.C
local ModCtrl = constructor(IModCtrl)
return ModCtrl
