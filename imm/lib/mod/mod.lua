local constructor = require("imm.lib.constructor")
local util = require('imm.lib.util')

local function errNative(mod)
    return false, string.format('Mod %s is native and therefore cannot be edited', mod)
end

--- @alias imm.ModMetaFormat 'thunderstore' | 'smods' | 'smods-header'

--- @class imm.ModVersion
--- @field mod string
--- @field version string

--- @class imm.DependencyRule
--- @field id string
--- @field version string
--- @field op string

--- @class imm.ModOpts
--- @field path? string
--- @field format? imm.ModMetaFormat
--- @field info? table
--- @field deps? imm.DependencyRule[][]
--- @field conflicts? imm.DependencyRule[][]

--- @class imm.Mod
local IMod = {}

--- @protected
--- @param list imm.ModList
--- @param ver string
--- @param opts? imm.ModOpts
function IMod:init(list, ver, opts)
    opts = opts or {}
    self.list = list
    self.mod = list.mod
    self.version = ver
    self.path = opts.path or ('tmp-'..math.random())
    self.format = opts.format or 'thunderstore'
    self.info = opts.info or {}
    self.deps = opts.deps or {}
    self.conflicts = opts.conflicts or {}
end

--- @protected
function IMod:errNative()
    return false, string.format('Mod %s is native and therefore cannot be edited', self.mod)
end

function IMod:createBmiMeta()
    local author = self.info.author
    local authorStr = type(author) == 'table' and table.concat(author, ', ') or author or '-'
    --- @type bmi.Meta
    return {
        id = self.mod,
        title = self.info.name or self.mod,
        author = authorStr,
        categories = {},
        metafmt = 'smods',
        deps = self.info.dependencies,
        conflicts = self.info.conflicts
    }
end

function IMod:uninstall()
    if self.list.native then return errNative() end

    if self.list.active == self then self.list:disable() end
    local ok = util.rmdir(self.path, true)
    if not ok then return false, 'Failed deleting moddir' end

    sendInfoMessage(string.format('Deleted %s %s (%s)', self.mod, self.version, self.path), 'imm')
    self.list.versions[self.version] = nil
    return true
end

function IMod:enable()
    if self.list.native then return self:errNative() end

    local ok,err = NFS.remove(self.path .. '/.lovelyignore')
    if not ok then return ok, err end

    sendInfoMessage(string.format('Enabled %s %s', self.mod, self.version), 'imm')
    self.list.active = self
    return true
end

--- @alias imm.Mod.C p.Constructor<imm.Mod, nil> | fun(entry: imm.ModList, ver: string, opts?: imm.ModOpts): imm.Mod
--- @type imm.Mod.C
local Mod = constructor(IMod)
return Mod