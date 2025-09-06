local util = require("imm.lib.util")

--- @alias imm.ModMetaFormat 'thunderstore' | 'smods' | 'smods-header'

--- @class imm.ModVersion.Entry
--- @field format imm.ModMetaFormat
--- @field path string
--- @field info table
--- @field mod string
--- @field version string

--- @class imm.ModList.Entry
--- @field versions table<string, imm.ModVersion.Entry>
--- @field active? imm.ModVersion.Entry

--- List of mods, mapped by mod id, then version.
--- @class imm.ModList: {[string]: imm.ModList.Entry}

local metaFields = {
    id = "string",
    name = "string",
    description = "string",
    prefix = "string",
    author = "table"
}

local tsManifestFields = {
    name = "string",
    version_number = "string",
    website_url = "string",
    description = "string",
    dependencies = "table"
}

local headerFields = {
    MOD_ID = { field = "id" },
    MOD_NAME = { field = "name" },
    MOD_DESCRIPTION = { field = "description" },
    PREFIX = { field = "prefix" },
    VERSION = { field = "version" },
    MOD_AUTHOR = { field = "author", array = true },
    DEPENDENCIES = { field = "dependencies", array = true },
    DEPENDS = { field = "dependencies", array = true },
    DEPS = { field = "dependencies", array = true },
    CONFLICTS = { field = "conflicts", array = true },
}

local function isSmodsMod(meta)
    if type(meta) ~= "table" then return false end
    for k, t in pairs(metaFields) do
        if type(meta[k]) ~= t then return false end
    end
    return true
end

local function isTsmod(meta)
    if type(meta) ~= "table" then return false end
    for k, t in pairs(tsManifestFields) do
        if type(meta[k]) ~= t then return false end
    end
    return true
end

local function processJson(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file) --- @diagnostic disable-line
    if not content then return end

    local ok, res = pcall(JSON.decode, content)
    if not ok then return end

    return res
end

local function parseHeader(content)
    local values = {}
    local lines = util.strsplit(content, '\r?\n', false)
    for i, line in ipairs(lines), lines, 1 do
        local s, e, attr = line:find('^--- *([%w_]+): *')
        if not s then break end
        if headerFields[attr] then
            local info = headerFields[attr]
            local val = line:sub(e+1)

            if info.array then
                values[info.field] = util.strsplit(util.trim(val:sub(2, -2)), '%s*,%s*')
            else
                values[info.field] = val
            end
        end
    end
    return values
end

local function processHeader(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file, 512) --- @diagnostic disable-line
    if not content then return end
    if not util.startswith(content, "--- STEAMODDED HEADER") then return end

    return parseHeader(content)
end

local function transformVersion(version)
    version = version:gsub('~', '-')
    return version
end

--- @param ctx imm.GetModsContext
--- @param base string
--- @param file string
local function processFile(ctx, base, file)
    local prov = ctx.isNfs and NFS or love.filesystem
    local path = base..'/'..file
    local ifile = file:lower()
    local mod
    --- @type imm.ModMetaFormat
    local fmt

    if util.endswith(ifile, ".json") then
        local parsed = processJson(path, ctx.isNfs)
        if isSmodsMod(parsed) then
            mod = parsed
            fmt = 'smods'
        elseif ifile == "manifest.json" and isTsmod(parsed) then
            mod = parsed
            fmt = 'thunderstore'
        end
    elseif util.endswith(ifile, ".lua") then
        mod = processHeader(path, ctx.isNfs)
        if mod then fmt = 'smods-header' end
    end
    if not mod then return end

    local id, version
    local ignored = prov.getInfo(base..'/.lovelyignore')

    if fmt == 'thunderstore' then
        id, version = mod.name, mod.version_number
    else
        id, version = mod.id, mod.version
    end

    if id == "Steamodded" then
        local vercode = prov.read(base..'/version.lua') or ''
        local newver = vercode:match('"(.+)"')
        if newver and util.endswith(newver, "-STEAMODDED") then newver = newver:sub(1, -12) end
        if newver then version = newver end
        version = version:gsub('BETA', 'beta')
    end
    version = transformVersion(version)

    --- @type imm.ModVersion.Entry
    local info = { format = fmt, info = mod, path = base, mod = id, version = version }
    if not ctx.list[id] then ctx.list[id] = { versions = {} } end
    local versionList = ctx.list[id]
    versionList.versions[version] = info

    if not ignored then versionList.active = info end
end

local excludedDirs = {
    lovely = true
}

local excludedSubdirs = {
    localization = true,
    assets = true,
    lovely = true
}

--- @class imm.GetModsContext
--- @field isNfs boolean
--- @field depthLimit number
--- @field list imm.ModList

--- @class imm.GetModsContextOptions
--- @field isNfs? boolean
--- @field depthLimit? number
--- @field list? imm.ModList
--- @field base? string

--- @param ctx imm.GetModsContext
--- @param base string
--- @param depth number
local function getMods(ctx, base, depth)
    if depth > ctx.depthLimit then return end

    local prov = ctx.isNfs and NFS or love.filesystem
    for i, file in ipairs(prov.getDirectoryItems(base)) do
        local path = base..'/'..file
        local stat = prov.getInfo(path)
        if stat and stat.type == 'file' then
            processFile(ctx, base, file)
        else
            local exclusion = depth == 1 and excludedDirs or excludedSubdirs
            if not exclusion[file:lower()] then
                getMods(ctx, path, depth + 1)
            end
        end
    end
end

--- @param opts? imm.GetModsContextOptions
local function getModsHigh(opts)
    opts = opts or {}
    opts.list = opts.list or {}
    opts.isNfs = opts.isNfs ~= false
    opts.depthLimit = opts.depthLimit or 3
    getMods(opts, opts.base or SMODS.MODS_DIR, 1) --- @diagnostic disable-line

    return opts.list
end

return getModsHigh