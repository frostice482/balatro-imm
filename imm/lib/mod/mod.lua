local constructor = require("imm.lib.constructor")
local V = require("imm.lib.version")
local util = require('imm.lib.util')
local logger = require('imm.logger')

--- @alias imm.ModMetaFormat 'thunderstore' | 'smods' | 'smods-header'

--- @class imm.Dependency.Rule
--- @field version Version
--- @field op string

--- @class imm.Dependency.Mod
--- @field mod string
--- @field rules imm.Dependency.Rule[]

--- AND - OR - AND
--- @alias imm.Dependency.List imm.Dependency.Mod[][]

--- @class imm.ModOpts
--- @field path? string
--- @field format? imm.ModMetaFormat
--- @field info? table
--- @field deps? imm.Dependency.List
--- @field conflicts? imm.Dependency.Mod[]
--- @field provides? table<string, string>
--- @field pathDepth? number
--- @field description? string

--- @class imm.Mod
local IMod = {
    name = ''
}

--- @protected
--- @param list imm.ModList
--- @param ver string
--- @param opts? imm.ModOpts
function IMod:init(list, ver, opts)
    opts = opts or {}
    self.list = list
    self.mod = list.mod
    self.version = ver
    self.versionParsed = V(ver)
    self.path = opts.path or ('tmp-'..math.random())
    self.format = opts.format or 'thunderstore'
    self.info = opts.info or {}
    self.deps = opts.deps or {}
    self.conflicts = opts.conflicts or {}
    self.provides = opts.provides or {}
    self.pathDepth = opts.pathDepth or 0
    self.description = opts.description
    self.name = opts.info and opts.info.name or list.mod
end

--- @return boolean ok, string err
function IMod:errNative()
    return false, string.format('Mod %s is native and therefore cannot be edited', self.mod)
end

--- @return boolean ok, string err
function IMod:errActiveUninstall()
    return false, string.format('Mod %s is currently active and cannot be deleted', self.mod)
end

--- @return boolean ok, string? err
function IMod:uninstall()
    if self.list.native then return self:errNative() end
    if self:isActive() then return self:errActiveUninstall() end

    local ok = util.rmdir(self.path, true)
    if not ok then return false, 'Failed deleting moddir' end

    logger.fmt('log', 'Deleted %s %s (%s)', self.mod, self.version, self.path)
    self.list.versions[self.version] = nil
    self.list.listRequiresUpdate = true
    return true
end

--- @return boolean ok, string? err
function IMod:enable()
    if self.list.native then return self:errNative() end
    if self.list.active then self.list:disable() end

    local ok,err = NFS.remove(self.path .. '/.lovelyignore')
    if not ok then return ok, err end

    logger.fmt('log', 'Enabled %s %s', self.mod, self.version)
    self.list.active = self
    return true
end

function IMod:isExcluded()
    return self.mod == 'balatro_imm' or self.list.native
end

function IMod:isActive()
    return self.list.active == self
end

--- @alias imm.Mod.C p.Constructor<imm.Mod, nil> | fun(entry: imm.ModList, ver: string, opts?: imm.ModOpts): imm.Mod
--- @type imm.Mod.C
local Mod = constructor(IMod)
return Mod