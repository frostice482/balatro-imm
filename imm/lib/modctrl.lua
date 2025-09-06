local constructor = require('imm.lib.constructor')
local getmods = require('imm.lib.getmods')
local util = require('imm.lib.util')

--- @class imm.ModController
local IModCtrl = {}

--- @protected
function IModCtrl:init()
    self.mods = getmods()
end

--- @param mod string
function IModCtrl:disableMod(mod)
    local modinfo = self.mods[mod]
    if not modinfo then return false, string.format('Mod not found %s', mod) end
    if not modinfo.active then return true end

    local enableInfo = modinfo.versions[modinfo.active]
    if enableInfo then
        local ok, err = NFS.write(enableInfo.path .. '/.lovelyignore', '')
        if not ok then return false, err end
    end
    modinfo.active = nil

    return true
end

--- @param mod string
--- @param version string
function IModCtrl:enableMod(mod, version)
    local modinfo = self.mods[mod]
    if not modinfo then return false, string.format('Mod not found %s', mod) end

    self:disableMod(mod)

    local info = modinfo.versions[version]
    modinfo.active = version
    if not info then return false, string.format('Mod %s with version not found %s', mod, version) end

    local ok,err = NFS.remove(info.path .. '/.lovelyignore')
    if not ok then return false, err end

    return true
end

--- @param mod string
--- @param version string
function IModCtrl:deleteMod(mod, version)
    local modinfo = self.mods[mod]
    if not modinfo then return false, string.format('Mod not found %s', mod) end

    local info = modinfo.versions[version]
    if not info then return false, string.format('Mod %s with version not found %s', mod, version) end

    util.rmdir(info.path, true)

    modinfo.versions[version] = nil
    if modinfo.active == version then modinfo.active = nil end

    return true
end

--- @param mod string
--- @param ver string
--- @param info imm.ModListVersion
--- @param sourceNfs boolean
function IModCtrl:installMod(mod, ver, info, sourceNfs)
    if not self.mods[mod] then self.mods[mod] = { versions = {} } end
    local modinfo = self.mods[mod]
    if modinfo.versions[ver] then return false, 'Already installed' end

    local c = 0
    local tpath_orig = string.format('%s/%s-%s', SMODS.MODS_DIR, mod, ver)
    local tpath = tpath_orig
    if NFS.getInfo(tpath) then
        c = c + 1
        tpath = string.format('%s_%d', tpath_orig, c)
    end

    util.cpdir(info.path, tpath, sourceNfs, true)
    local ok, err = NFS.write(tpath .. '/.lovelyignore', '')
    if not ok then return false, err end

    modinfo.versions[ver] = info
    info.path = tpath

    return true
end

--- @param dir string
--- @param sourceNfs boolean
function IModCtrl:installModFromDir(dir, sourceNfs)
    local list = getmods({ base = dir, isNfs = sourceNfs })
    for mod, modvers in pairs(list) do
        for ver, info in pairs(modvers.versions) do
            assert(self:installMod(mod, ver, info, sourceNfs))
        end
    end
    return list
end

--- @param zipData love.FileData
function IModCtrl:installModFromZip(zipData)
    local tmpdir = 'mnt-' .. love.data.encode('string', 'hex', love.data.hash('md5', ''..love.timer.getTime()))
    assert(love.filesystem.mount(zipData, tmpdir), 'mount failed')
    local r = self:installModFromDir(tmpdir, false)
    assert(love.filesystem.unmount(zipData), 'unmount failed')
    return r
end

--- @alias imm.ModController.C p.Constructor<imm.ModController, nil> | fun(): imm.ModController
--- @type imm.ModController.C
local ModCtrl = constructor(IModCtrl)
return ModCtrl
