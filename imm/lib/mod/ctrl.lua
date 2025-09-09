local constructor = require('imm.lib.constructor')
local ModList = require('imm.lib.mod.list')
local ProvidedList = require('imm.lib.mod.providedlist')
local getmods = require('imm.lib.mod.get')
local util = require('imm.lib.util')
local logger = require('imm.logger')

--- @class imm.ModController
--- @field provideds imm.ProvidedList
local IModCtrl = {}

--- @protected
--- @param noInit? boolean
function IModCtrl:init(noInit)
    self.mods = noInit and {} or getmods.getMods()
    self.provideds = ProvidedList()

    for id, list in pairs(self.mods) do
        for ver, mod in pairs(list.versions) do
            self:add(mod)
        end
    end
end

local function errNotFound(mod)
    return false, string.format('Mod %s not found', mod)
end

--- @param rule1 imm.Dependency.List
function IModCtrl:getMissingDeps(rule1)
    --- @type table<string, imm.Dependency.Rule[][]>
    local list = {}
    for i, rule2 in ipairs(rule1) do
        local satisfied = false
        for i, rule3 in ipairs(rule2) do
            local mod = self:findModSatisfies(rule3.mod, rule3.rules)
            if mod then -- already installed
                satisfied = true
                break
            end
        end
        if not satisfied then
            for i, rule3 in ipairs(rule2) do
                local x = rule3.mod
                if not list[x] then list[x] = {} end
                table.insert(list[x], rule3.rules)
            end
        end
    end
    return list
end

--- @param mod string
--- @param rules imm.Dependency.Rule[]
function IModCtrl:findModSatisfies(mod, rules)
    local list = self.mods[mod]
    local ruleMatch = list and list:getVersionSatisfies(rules)
    if ruleMatch then return ruleMatch end

    local provList = self.provideds.provideds[mod]
    local provMatch = provList and provList:getVersionSatisfies(rules)
    if provMatch then return provMatch end
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
function IModCtrl:add(info)
    self.provideds:add(info)
    return true
end

--- @protected
--- @param info imm.Mod
function IModCtrl:deleteEntry(info, noUninstall)
    if not noUninstall then
        local ok, err = info:uninstall()
        if not ok then return ok, err end
    end
    self.provideds:remove(info)
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
    local tpath_orig = string.format('%s/%s-%s', require('imm.config').modsDir, mod, ver)
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
