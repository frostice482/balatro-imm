local constructor = require("imm.lib.constructor")
local V = require("imm.lib.version")
local util = require('imm.lib.util')
local logger = require('imm.logger')

local function errNative(mod)
    return false, string.format('Mod %s is native and therefore cannot be edited', mod)
end

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
--- @field conflicts? imm.Dependency.List
--- @field provides? table<string, string>
--- @field pathDepth? number

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
    self.versionParsed = V(ver)
    self.path = opts.path or ('tmp-'..math.random())
    self.format = opts.format or 'thunderstore'
    self.info = opts.info or {}
    self.deps = opts.deps or {}
    self.conflicts = opts.conflicts or {}
    self.provides = opts.provides or {}
    self.pathDepth = opts.pathDepth or 0
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
        version = self.version,
        provides = self.provides,
        repo = self.info.repo
    }
end

function IMod:uninstall()
    if self.list.native then return errNative() end

    if self.list.active == self then self.list:disable() end
    local ok = util.rmdir(self.path, true)
    if not ok then return false, 'Failed deleting moddir' end

    logger.fmt('log', 'Deleted %s %s (%s)', self.mod, self.version, self.path)
    self.list.versions[self.version] = nil
    return true
end

function IMod:enable()
    if self.list.native then return self:errNative() end
    if self.list.active then self.list:disable() end

    local ok,err = NFS.remove(self.path .. '/.lovelyignore')
    if not ok then return ok, err end

    logger.fmt('log', 'Enabled %s %s', self.mod, self.version)
    self.list.active = self
    return true
end

--- @alias imm.Mod.C p.Constructor<imm.Mod, nil> | fun(entry: imm.ModList, ver: string, opts?: imm.ModOpts): imm.Mod
--- @type imm.Mod.C
local Mod = constructor(IMod)
return Mod