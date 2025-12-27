local constructor = require('imm.lib.constructor')
local ModList = require('imm.mod.list')
local LoadList = require('imm.mod.loadlist')
local ProvidedList = require('imm.mod.providedlist')
local afsAgent = require('imm.afs.agent')
local getmods = require('imm.mod.get')
local util = require('imm.lib.util')
local logger = require('imm.logger')
local imm = require('imm')

--- @class imm.ModController
--- @field provideds imm.ProvidedList
local IModCtrl = {}

--- @protected
--- @param noInit? boolean
function IModCtrl:init(noInit)
    self.mods = noInit and {} or getmods.getMods({ isListing = true })
    self.provideds = ProvidedList()
    self.loadlist = LoadList(self)

    for id, list in pairs(self.mods) do
        for ver, mod in pairs(list.versions) do
            self:addEntry(mod)
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
--- @param excludesOr? imm.Dependency.Rule[][]
function IModCtrl:findModSatisfies(mod, rules, excludesOr)
    local list = self.mods[mod]
    local ruleMatch = list and list:getVersionSatisfies(rules, excludesOr)
    if ruleMatch then return ruleMatch end

    local provList = self.provideds.provideds[mod]
    local provMatch = provList and provList:getVersionSatisfies(rules, excludesOr)
    if provMatch then return provMatch end
end

--- @param modid string
--- @param version string
function IModCtrl:getMod(modid, version)
    return self.mods[modid] and self.mods[modid].versions[version]
end

function IModCtrl:getOlderMods()
    --- @type imm.Mod[]
    local list = {}
    for id, modlist in pairs(self.mods) do
        local old = false
        for i, mod in ipairs(modlist:list()) do
            if not mod:isExcluded() then
                if old and not mod:isActive() then table.insert(list, mod) end
                old = true
            end
        end
    end
    return list
end

--- @param modid string
--- @return boolean ok, string? err
function IModCtrl:disable(modid)
    local list = self.mods[modid]
    if not list then return errNotFound(modid) end
    local mod = list.active
    if not mod then return true end
    return self:disableMod(mod)
end

--- @param modid string
--- @param version string
--- @return boolean ok, string? err
function IModCtrl:enable(modid, version)
    local list = self.mods[modid]
    if not list then return errNotFound(modid) end
    local mod = list.versions[version]
    if not mod then return list:errVerNotFound(version) end
    return self:enableMod(mod)
end

--- @param mod imm.Mod
--- @return boolean ok, string? err
function IModCtrl:disableMod(mod)
    local ok, err = true, nil
    if ok then ok, err = mod.list:disable() end
    if ok then ok, err = self.loadlist:disable(mod) end
    return ok, err
end

--- @param mod imm.Mod
--- @return boolean ok, string? err
function IModCtrl:enableMod(mod)
    local ok, err = true, nil
    if ok and self.loadlist.loadedMods[mod.mod] then ok, err = self:disable(mod.mod) end
    if ok then ok, err = mod:enable() end
    if ok then ok, err = self.loadlist:enable(mod, true) end
    return ok, err
end

--- @param noCopy? boolean
function IModCtrl:createLoadList(noCopy)
    local ll = LoadList(self)
    if not noCopy then ll:simpleCopyFrom(self.loadlist) end
    return ll
end

--- @param mod imm.Mod
function IModCtrl:tryEnable(mod)
    local ll = LoadList(self)
    ll:simpleCopyFrom(self.loadlist)
    ll:tryEnable(mod)
    return ll
end

--- @param mod imm.Mod
function IModCtrl:tryDisable(mod)
    local ll = LoadList(self)
    ll:simpleCopyFrom(self.loadlist)
    ll:tryDisable(mod)
    return ll
end

--- @param info imm.Mod
function IModCtrl:addEntry(info)
    logger.fmt('debug', 'Added %s %s to registry', info.mod, info.version)
    self.provideds:add(info)
    if info:isActive() then return self.loadlist:enable(info, true) end
    return true
end

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
--- @return boolean ok, string? err
function IModCtrl:uninstall(mod, version)
    local list = self.mods[mod]
    if not list then return errNotFound(mod) end
    local info = list.versions[version]
    if not info then return list:errVerNotFound(version) end
    return self:deleteEntry(info)
end

--- @async
--- @param mod imm.Mod
--- @param sourceNfs boolean
--- @return boolean ok, string? err
function IModCtrl:installCo(mod, sourceNfs)
    if self.mods[mod.mod] and self.mods[mod.mod].native then return mod:errNative() end

    local id, ver = mod.mod, mod.version
    if not self.mods[id] then self.mods[id] = ModList(id) end
    local list = self.mods[id]

    -- unisntall existing version
    if list.versions[ver] then
        local ok, err = self:deleteEntry(list.versions[ver])
        if not ok then return false, err end
    end

    -- get target path
    local c = 0
    local tpath_orig = string.format('%s/%s-%s', imm.modsDir, id, ver)
    local tpath = tpath_orig
    if NFS.getInfo(tpath) then
        c = c + 1
        tpath = string.format('%s_%d', tpath_orig, c)
    end

    -- copies to target
    local ok, err = afsAgent.cpCo(mod.path, tpath, {
        srcNfs = sourceNfs,
        destNfs = true,
        fast = not not imm.config.fastCopy
    })
    if not ok then return ok, err end
    logger.fmt('debug', 'Copied %s %s to %s', id, ver, tpath)

    -- ignore
    local ok, err = NFS.write(tpath .. '/.lovelyignore', '')
    if not ok then return false, err end

    -- fix linking
    list:add(mod)
    mod.path = tpath

    self:addEntry(mod)
    logger.fmt('log', 'Installed %s %s', id, ver)
    return true
end

--- @class imm.InstallResult
--- @field mods table<string, imm.ModList>
--- @field installed imm.Mod[]
--- @field errors string[]

--- @async
--- @param dir string
--- @param sourceNfs boolean
--- @return imm.InstallResult
function IModCtrl:installFromDirCo(dir, sourceNfs)
    local modslist = getmods.getMods({ base = dir, isNfs = sourceNfs })
    --- @type imm.Mod[]
    local intalled = {}
    --- @type string[]
    local errors = {}

    for id, modvers in pairs(modslist) do
        for ver, mod in pairs(modvers.versions) do
            -- install
            local ok, err = self:installCo(mod, sourceNfs)
            if not ok then
                logger.err(err)
                table.insert(errors, string.format('%s %s: %s', mod.mod, mod.version, err))
            else
                table.insert(intalled, mod)
            end
        end
    end

    --- @type imm.InstallResult
    return {
        mods = modslist,
        installed = intalled,
        errors = errors,
    }
end

local mnttmp = 0

--- @async
--- @param zipData love.Data
--- @return imm.InstallResult
function IModCtrl:installFromZipCo(zipData)
    mnttmp = mnttmp + 1
    local tmpdir = 'tmp-'..mnttmp
    local ok = love.filesystem.mount(zipData, "tmp.zip", tmpdir)
    --- @type imm.InstallResult
    if not ok then return { errors = { 'Mount failed - is the file a zip?' }, installed = {}, mods = {} } end

    local a = self:installFromDirCo(tmpdir, false)
    love.filesystem.unmount(zipData) --- @diagnostic disable-line
    return a
end

function IModCtrl:list()
    return util.values(self.mods, function (va, vb) return va.mod < vb.mod end)
end

function IModCtrl:listAll()
    --- @type imm.Mod[]
    local mods = {}
    for i,list in ipairs(self:list()) do
        for j, mod in list:list() do
            table.insert(mods, mod)
        end
    end
    return mods
end

--- @alias imm.ModController.C p.Constructor<imm.ModController, nil> | fun(noInit?: boolean): imm.ModController
--- @type imm.ModController.C
local ModCtrl = constructor(IModCtrl)
return ModCtrl
