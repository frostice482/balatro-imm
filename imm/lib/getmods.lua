local util = require("imm.lib.util")

--- @alias imm.ModMetaFormat 'thunderstore' | 'smods' | 'smods-header'

--- @class imm.DependencyRule
--- @field id string
--- @field version string
--- @field op string

--- @class imm.ModVersion.Entry
--- @field format imm.ModMetaFormat
--- @field path string
--- @field info table
--- @field version string
--- @field deps imm.DependencyRule[][]
--- @field conflicts imm.DependencyRule[][]

--- @class imm.ModList.Entry
--- @field versions table<string, imm.ModVersion.Entry>
--- @field active? imm.ModVersion.Entry
--- @field native? boolean

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

--- @param file string
--- @param isNfs? boolean
local function processJson(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file) --- @diagnostic disable-line
    if not content then return end

    local ok, res = pcall(JSON.decode, content)
    if not ok then return end

    return res
end

--- @param content string
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

--- @param file string
--- @param isNfs? boolean
local function processHeader(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file, 512) --- @diagnostic disable-line
    if not content then return end
    if not util.startswith(content, "--- STEAMODDED HEADER") then return end

    return parseHeader(content)
end

--- @param id string
--- @param version string
local function transformVersion(id, version)
    version = version:gsub('~', '-')
    if id == "Steamodded" then
        if util.endswith(version, "-STEAMODDED") then version = version:sub(1, -12) end
        version = version:gsub('BETA', 'beta')
    end
    return version
end

--- @param entry string
--- @return imm.DependencyRule[][]
local function parseTsDep(entry)
    local author, package, version = entry:match('^([^-]+)-([^-]+)-(.+)')
    if not author then return {} end
    --- @type imm.DependencyRule[][]
    return {{{ id = package, op = '==', version = version }}}
end

--- @param entryStr string
--- @return imm.DependencyRule[][]
local function parseSmodsDep(entryStr)
    local entries = {}
    local entriesStr = util.strsplit(entryStr, '|', true)
    for i, entry in ipairs(entriesStr) do
        local s, e, id = entry:find('^%s*([^%s<>=()]+)')
        if not id then break end

        local list = {}
        for op, version in entry:sub(e+1):gmatch("([<>=]+)%s*([%w_%.%-~]+)") do
            table.insert(list, { id = id, version = version, op = op })
        end
        table.insert(entries, list)
    end
    return entries
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
    local deps, conflicts = {}, {}
    local ignored = prov.getInfo(base..'/.lovelyignore')

    if fmt == 'thunderstore' then
        id, version = mod.name, mod.version_number

        for i, entry in ipairs(mod.dependencies) do
            for j, list in ipairs(parseTsDep(entry)) do
                table.insert(deps, list)
            end
        end
    else
        id, version = mod.id, mod.version

        if mod.dependencies then
            for i, entry in ipairs(mod.dependencies) do
                for j, list in ipairs(parseSmodsDep(entry)) do
                    table.insert(deps, list)
                end
            end
        end
        if mod.conflicts then
            for i, entry in ipairs(mod.conflicts) do
                for j, list in ipairs(parseSmodsDep(entry)) do
                    table.insert(conflicts, list)
                end
            end
        end
    end

    if id == "Steamodded" then
        local vercode = prov.read(base..'/version.lua') or ''
        local newver = vercode:match('"(.+)"')
        if newver then version = newver end
    end
    version = transformVersion(id, version)

    --- @type imm.ModVersion.Entry
    local info = { format = fmt, info = mod, path = base, version = version, deps = deps, conflicts = conflicts }
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