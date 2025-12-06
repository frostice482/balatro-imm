local ModList = require("imm.mod.list")
local V = require("imm.lib.version")
local util = require("imm.lib.util")
local logger = require("imm.logger")
local imm = require('imm')

local get = {}

get.metaFields = {
    id = "string",
    name = "string",
    description = "string",
    prefix = "string",
    author = "table",
    version = "string"
}

get.tsManifestFields = {
    name = "string",
    version_number = "string",
    website_url = "string",
    description = "string",
    dependencies = "table"
}

get.headerFields = {
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

function get.isSmodsMod(meta)
    if type(meta) ~= "table" then return false end
    for k, t in pairs(get.metaFields) do
        if type(meta[k]) ~= t then return false end
    end
    return true
end

function get.isTsMod(meta)
    if type(meta) ~= "table" then return false end
    for k, t in pairs(get.tsManifestFields) do
        if type(meta[k]) ~= t then return false end
    end
    return true
end

--- @param file string
--- @param isNfs? boolean
function get.processJson(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file) --- @diagnostic disable-line
    if not content then return end

    local ok, res = pcall(JSON.decode, content)
    if not ok then return end

    return res
end

--- @param content string
function get.parseHeader(content)
    local values = {
        version = "0"
    }
    local lines = util.strsplit(content, '\r?\n', false)
    for i, line in ipairs(lines), lines, 1 do
        local s, e, attr = line:find('^--- *([%w_]+): *')
        if not s then
            if line ~= "" then break end
        elseif get.headerFields[attr] then
            local info = get.headerFields[attr]
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
function get.processHeader(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file, 512) --- @diagnostic disable-line
    if not content then return end
    if not util.startswith(content, "--- STEAMODDED HEADER") then return end

    return get.parseHeader(content)
end

--- @param id string
--- @param version string
function get.transformVersion(id, version)
    version = version:gsub('~', '-')
    if id == "Steamodded" then
        if util.endswith(version, "-STEAMODDED") then version = version:sub(1, -12) end
        version = version:gsub('BETA', 'beta')
    end
    return version
end

--- @param entry string
function get.parseTsDep(entry)
    local author, package, version = entry:match('^([^-]+)-([^-]+)-(.+)')
    if not author then return {} end
    --- @type imm.Dependency.Mod[]
    return {{ mod = package, rules = {{ op = '>=', version = V(version) }}}}
end

local modPattern = '^%s*([^%s<>=()!]+)'
local versionPattern = '[%w_~*.%-+]*'
local versionDepPattern = string.format('([<>=!]+)%%s*(%s)', versionPattern)
local versionProvidePattern = '%d'..versionPattern

--- @param entry string
function get.parseSmodsDepMod(entry)
    local s, e, id = entry:find(modPattern)
    if not id then return end

    --- @type imm.Dependency.Mod
    local modRules = { mod = id, rules = {} }
    for op, version in entry:sub(e+1):gmatch(versionDepPattern) do
        table.insert(modRules.rules, { version = V(get.transformVersion(id, version)), op = op })
    end
    return modRules
end

--- @param entryStr string
function get.parseSmodsDep(entryStr)
    --- @type imm.Dependency.Mod[]
    local entries = {}
    local entriesStr = util.strsplit(entryStr, '|', true)
    for i, entry in ipairs(entriesStr) do
        local d = get.parseSmodsDepMod(entry)
        if d then table.insert(entries, d) end
    end
    return entries
end

--- @param entry string
--- @return string? id
--- @return string? version
function get.parseSmodsProvides(entry)
    local s, e, id = entry:find(modPattern)
    if not id then return end

    local version = entry:sub(e+1):match(versionProvidePattern)
    return id, version
end

--- @param format bmi.Meta.Format
--- @return string id
--- @return string version
--- @return imm.Dependency.List deps
--- @return imm.Dependency.Mod[] conflicts
--- @return table<string, string> provides
function get.parseInfo(mod, format)
    --- @type imm.Dependency.List, imm.Dependency.Mod[], table<string, string>
    local deps, conflicts, provides = {}, {}, {}
    local id, version

    if format == 'thunderstore' then
        id, version = mod.name, mod.version_number

        for i, set in ipairs(mod.dependencies) do
            table.insert(deps, get.parseTsDep(set))
        end
    else
        id, version = mod.id, mod.version

        if mod.dependencies then
            for i, set in ipairs(mod.dependencies) do
                table.insert(deps, get.parseSmodsDep(set))
            end
        end
        if mod.conflicts then
            for i, set in ipairs(mod.conflicts) do
                table.insert(conflicts, get.parseSmodsDepMod(set))
            end
        end
        if mod.provides then
            for i, entry in ipairs(mod.provides) do
                local providedId, providedVersion = get.parseSmodsProvides(entry)
                if providedId then
                    provides[providedId] = providedVersion or version
                end
            end
        end
    end

    return id, version, deps, conflicts, provides
end

--- @param base string
--- @param file string
--- @param ctx _imm.GetModsContext
--- @param depth number
function get.processFile(ctx, base, depth, file)
    local prov = ctx.isNfs and NFS or love.filesystem
    local path = base..'/'..file
    local ifile = file:lower()
    local mod
    --- @type imm.ModMetaFormat
    local fmt

    --- get mod meta & format
    if util.endswith(ifile, ".json") then
        local parsed = get.processJson(path, ctx.isNfs)
        if get.isSmodsMod(parsed) then
            mod, fmt = parsed, 'smods'
        elseif ifile == "manifest.json" and get.isTsMod(parsed) then
            mod, fmt = parsed, 'thunderstore'
        end
    elseif util.endswith(ifile, ".lua") then
        local parsed = get.processHeader(path, ctx.isNfs)
        if parsed then
            mod, fmt = parsed, 'smods-header'
        end
    end
    if not mod then return end

    --- extract mod meta
    local id, version, deps, conflicts, provides = get.parseInfo(mod, fmt)
    local ignored = prov.getInfo(base..'/.lovelyignore')

    --- modify version
    if id == "Steamodded" then
        local vercode = prov.read(base..'/version.lua') or ''
        local newver = vercode:match('"(.+)"')
        if newver then version = newver end
    end
    version = get.transformVersion(id, version)

    --- add the mod
    if not ctx.list[id] then ctx.list[id] = ModList(id) end
    ctx.list[id]:createVersion(version, {
        format = fmt,
        info = mod,
        path = base,
        deps = deps,
        conflicts = conflicts,
        provides = provides,
        pathDepth = depth,
        description = mod.description,
        loaded = not ignored
    })
end

get.excludedDirs = {
    lovely = true
}

get.excludedDirs = {
    lovely = true
}

get.excludedSubdirs = {
    localization = true,
    assets = true,
    lovely = true
}

--- @class _imm.GetModsContext
--- @field isNfs boolean
--- @field depthLimit number
--- @field list table<string, imm.ModList>

--- @class imm.GetModsContextOptions
--- @field isNfs? boolean
--- @field depthLimit? number
--- @field list? table<string, imm.ModList>
--- @field base? string

--- @param ctx _imm.GetModsContext
--- @param base string
--- @param depth number
function get.getModsLow(ctx, base, depth)
    if depth > ctx.depthLimit then return end

    local prov = ctx.isNfs and NFS or love.filesystem
    for i, file in ipairs(prov.getDirectoryItems(base)) do
        local path = base..'/'..file
        local stat = prov.getInfo(path)
        if stat and stat.type == 'file' then
            local ok, err = pcall(get.processFile, ctx, base, depth, file)
            if not ok then logger.fmt('error', 'Error processing %s: %s', path, err) end
        else
            local exclusion = depth == 1 and get.excludedDirs or get.excludedSubdirs
            if not exclusion[file:lower()] then
                get.getModsLow(ctx, path, depth + 1)
            end
        end
    end
end

--- @param opts? imm.GetModsContextOptions
function get.getMods(opts)
    opts = opts or {}
    opts.list = opts.list or {}
    opts.isNfs = opts.isNfs ~= false
    opts.depthLimit = opts.depthLimit or 3
    get.getModsLow(opts, opts.base or imm.modsDir, 1) --- @diagnostic disable-line

    return opts.list
end

return get