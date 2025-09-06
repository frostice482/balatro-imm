local constructor = require('imm.lib.constructor')
local getmods = require('imm.lib.getmods')
local util = require('imm.lib.util')

--- @class imm.ModController
local IModCtrl = {}

--- @protected
function IModCtrl:init()
    self.mods = getmods()
end

function IModCtrl:_errNotFound(mod)
    return false, string.format('Mod %s not found', mod)
end

function IModCtrl:_errNative(mod)
    return false, string.format('Mod %s is native and therefore cannot be edited', mod)
end

function IModCtrl:_errVerNotFound(mod, version)
    return false, string.format('Mod %s with version %s not found', mod, version)
end

--- @protected
--- @param entry imm.ModList.Entry
--- @param info imm.ModVersion.Entry
function IModCtrl:_deleteEntry(entry, info)
    if entry.native then return false, self:_errNative(entry.mod) end

    if entry.active and entry.active == info then self:_disableEntry(entry) end
    local ok = util.rmdir(info.path, true)
    if not ok then return false, 'Failed deleting moddir' end
    entry.versions[info.version] = nil

    sendInfoMessage(string.format('Deleted %s %s (%s)', entry.mod, info.version, info.path), 'imm')

    return true
end

--- @protected
--- @param entry imm.ModList.Entry
function IModCtrl:_disableEntry(entry)
    if entry.native then return false, self:_errNative(entry.mod) end
    if not entry.active then return true end

    local ok, err = NFS.write(entry.active.path .. '/.lovelyignore', '')
    if not ok then return ok, err end

    sendInfoMessage(string.format('Disabled %s %s', entry.mod, entry.active.version), 'imm')

    entry.active = nil
    return true
end

--- @protected
--- @param entry imm.ModList.Entry
--- @param info imm.ModVersion.Entry
function IModCtrl:_enableEntry(entry, info)
    if entry.native then return false, self:_errNative(entry.mod) end
    if entry.active then self:_disableEntry(entry) end

    local ok,err = NFS.remove(info.path .. '/.lovelyignore')
    if not ok then return ok, err end

    sendInfoMessage(string.format('Enabled %s %s', entry.mod, info.version), 'imm')

    entry.active = info
    return true
end

--- @param mod string
function IModCtrl:disableMod(mod)
    local modinfo = self.mods[mod]
    if not modinfo then return self:_errNotFound(mod) end
    if not modinfo.active then return true end

    return self:_disableEntry(modinfo)
end

--- @param mod string
--- @param version string
function IModCtrl:enableMod(mod, version)
    local modinfo = self.mods[mod]
    if not modinfo then return self:_errNotFound(mod) end
    local info = modinfo.versions[version]
    if not info then return self:_errVerNotFound(mod, version) end

    if modinfo.active and modinfo.active.version == version then return true end

    return self:_enableEntry(modinfo, info)
end

--- @param mod string
--- @param version string
function IModCtrl:deleteMod(mod, version)
    local modinfo = self.mods[mod]
    if not modinfo then return self:_errNotFound(mod) end
    local info = modinfo.versions[version]
    if not info then return self:_errVerNotFound(mod, version) end

    return self:_deleteEntry(modinfo, info)
end

--- @param mod string
--- @param ver string
--- @param info imm.ModVersion.Entry
--- @param sourceNfs boolean
function IModCtrl:installMod(mod, ver, info, sourceNfs)
    if not self.mods[mod] then self.mods[mod] = { versions = {}, mod = mod } end
    local modinfo = self.mods[mod]

    if modinfo.versions[ver] then
        local ok, err = self:_deleteEntry(modinfo, modinfo.versions[ver])
        if not ok then return ok, err end
    end

    local c = 0
    local tpath_orig = string.format('%s/%s-%s', SMODS.MODS_DIR, mod, ver)
    local tpath = tpath_orig
    if NFS.getInfo(tpath) then
        c = c + 1
        tpath = string.format('%s_%d', tpath_orig, c)
    end

    util.cpdir(info.path, tpath, sourceNfs, true)
    local ok, err = NFS.write(tpath .. '/.lovelyignore', '')
    if not ok then return ok, err end

    modinfo.versions[ver] = info
    info.path = tpath

    sendInfoMessage(string.format('Installed %s %s (%s)', mod, ver, tpath), 'imm')

    return true
end

--- @param dir string
--- @param sourceNfs boolean
--- @return imm.ModList modList
--- @return imm.ModVersion[] flatList
--- @return string[] errors
function IModCtrl:installModFromDir(dir, sourceNfs)
    local modslist = getmods({ base = dir, isNfs = sourceNfs })
    --- @type imm.ModVersion[]
    local flatlist = {}
    --- @type string[]
    local errors = {}

    for mod, modvers in pairs(modslist) do
        for ver, info in pairs(modvers.versions) do
            local ok, err = self:installMod(mod, ver, info, sourceNfs)
            if not ok then
                sendWarnMessage(err, "imm")
                table.insert(errors, string.format('%s %s: %s', mod, ver, err))
            else
                table.insert(flatlist, { mod = mod, version = ver })
            end
        end
    end
    return modslist, flatlist, errors
end

--- @param zipData love.FileData
--- @return imm.ModList modList
--- @return imm.ModVersion[] flatList
--- @return string[] errors
function IModCtrl:installModFromZip(zipData)
    local tmpdir = 'mnt-' .. love.data.encode('string', 'hex', love.data.hash('md5', ''..love.timer.getTime()))
    assert(love.filesystem.mount(zipData, tmpdir), 'mount failed')

    local a, b, c = self:installModFromDir(tmpdir, false)

    assert(love.filesystem.unmount(zipData), 'unmount failed') --- @diagnostic disable-line

    return a, b, c
end

--- @alias imm.ModController.C p.Constructor<imm.ModController, nil> | fun(): imm.ModController
--- @type imm.ModController.C
local ModCtrl = constructor(IModCtrl)
return ModCtrl
