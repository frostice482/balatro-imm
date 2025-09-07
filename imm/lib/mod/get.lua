local util = require("imm.lib.util")
local ModList = require("imm.lib.mod.list")
local config = require("imm.config")

local modlist = {}

modlist.metaFields = {
    id = "string",
    name = "string",
    description = "string",
    prefix = "string",
    author = "table"
}

modlist.tsManifestFields = {
    name = "string",
    version_number = "string",
    website_url = "string",
    description = "string",
    dependencies = "table"
}

modlist.headerFields = {
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

function modlist.isSmodsMod(meta)
    if type(meta) ~= "table" then return false end
    for k, t in pairs(modlist.metaFields) do
        if type(meta[k]) ~= t then return false end
    end
    return true
end

function modlist.isTsMod(meta)
    if type(meta) ~= "table" then return false end
    for k, t in pairs(modlist.tsManifestFields) do
        if type(meta[k]) ~= t then return false end
    end
    return true
end

--- @param file string
--- @param isNfs? boolean
function modlist.processJson(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file) --- @diagnostic disable-line
    if not content then return end

    local ok, res = pcall(JSON.decode, content)
    if not ok then return end

    return res
end

--- @param content string
function modlist.parseHeader(content)
    local values = {}
    local lines = util.strsplit(content, '\r?\n', false)
    for i, line in ipairs(lines), lines, 1 do
        local s, e, attr = line:find('^--- *([%w_]+): *')
        if not s then break end
        if modlist.headerFields[attr] then
            local info = modlist.headerFields[attr]
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
function modlist.processHeader(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file, 512) --- @diagnostic disable-line
    if not content then return end
    if not util.startswith(content, "--- STEAMODDED HEADER") then return end

    return modlist.parseHeader(content)
end

--- @param id string
--- @param version string
function modlist.transformVersion(id, version)
    version = version:gsub('~', '-')
    if id == "Steamodded" then
        if util.endswith(version, "-STEAMODDED") then version = version:sub(1, -12) end
        version = version:gsub('BETA', 'beta')
    end
    return version
end

--- @param entry string
function modlist.parseTsDep(entry)
    local author, package, version = entry:match('^([^-]+)-([^-]+)-(.+)')
    if not author then return {} end
    --- @type imm.DependencySet
    return {{{ id = package, op = '==', version = version }}}
end

--- @param entryStr string
function modlist.parseSmodsDep(entryStr)
    --- @type imm.DependencySet
    local entries = {}
    local entriesStr = util.strsplit(entryStr, '|', true)
    for i, entry in ipairs(entriesStr) do
        local s, e, id = entry:find('^%s*([^%s<>=()]+)')
        if not id then break end

        --- @return imm.DependencyRule[]
        local list = {}
        local has = false
        for op, version in entry:sub(e+1):gmatch("([<>=|]+)%s*([%w_%.%-~]*)") do
            has = true
            table.insert(list, { id = id, version = version, op = op })
        end
        if not has then
            table.insert(list, { id = id, version = "0.0.0", op = ">=" })
        end
        table.insert(entries, list)
    end
    return entries
end

--- @param entry string
--- @return string? id
--- @return string? version
function modlist.parseSmodsProvides(entry)
    local s, e, id = entry:find('^%s*([^%s<>=()]+)')
    if not id then return end

    local version = entry:sub(e+1):match('%d[%w_%.%-~]*')
    return id, version
end

--- @param format bmi.Meta.Format
--- @return string id
--- @return string version
--- @return imm.DependencyList deps
--- @return imm.DependencyList conflicts
--- @return table<string, string> provides
function modlist.parseInfo(mod, format)
    --- @type imm.DependencyList, imm.DependencyList, table<string, string>
    local deps, conflicts, provides = {}, {}, {}
    local id, version

    if format == 'thunderstore' then
        id, version = mod.name, mod.version_number

        for i, set in ipairs(mod.dependencies) do
            table.insert(deps, set)
        end
    else
        id, version = mod.id, mod.version

        if mod.dependencies then
            for i, set in ipairs(mod.dependencies) do
                table.insert(deps, set)
            end
        end
        if mod.conflicts then
            for i, set in ipairs(mod.conflicts) do
                table.insert(conflicts, set)
            end
        end
        if mod.provides then
            for i, entry in ipairs(mod.provides) do
                local providedId, providedVersion = modlist.parseSmodsProvides(entry)
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
--- @param list table<string, imm.ModList>
--- @param isNfs? boolean
function modlist.processFile(base, file, list, isNfs)
    local prov = isNfs and NFS or love.filesystem
    local path = base..'/'..file
    local ifile = file:lower()
    local mod
    --- @type imm.ModMetaFormat
    local fmt

    --- get mod meta & format
    if util.endswith(ifile, ".json") then
        local parsed = modlist.processJson(path, isNfs)
        if modlist.isSmodsMod(parsed) then
            mod, fmt = parsed, 'smods'
        elseif ifile == "manifest.json" and modlist.isTsMod(parsed) then
            mod, fmt = parsed, 'thunderstore'
        end
    elseif util.endswith(ifile, ".lua") then
        local parsed = modlist.processHeader(path, isNfs)
        if parsed then
            mod, fmt = parsed, 'smods-header'
        end
    end
    if not mod then return end

    --- extract mod meta
    local id, version, deps, conflicts, provides = modlist.parseInfo(mod, fmt)
    local ignored = prov.getInfo(base..'/.lovelyignore')

    --- modify version
    if id == "Steamodded" then
        local vercode = prov.read(base..'/version.lua') or ''
        local newver = vercode:match('"(.+)"')
        if newver then version = newver end
    end
    version = modlist.transformVersion(id, version)

    --- add the mod
    if not list[id] then list[id] = ModList(id) end
    list[id]:createVersion(version, {
        format = fmt,
        info = mod,
        path = base,
        deps = deps,
        conflicts = conflicts,
        provides = provides
    }, not ignored)
end

modlist.excludedDirs = {
    lovely = true
}

--- @class imm.GetModsOptions
--- @field isNfs? boolean
--- @field list? table<string, imm.ModList>
--- @field base? string

--- @param opts? imm.GetModsOptions
function modlist.getMods(opts)
    opts = opts or {}
    local list = opts.list or {}
    local base = opts.base or config.modsDir
    local isNfs = opts.isNfs ~= false

    local prov = isNfs and NFS or love.filesystem
    for i, file in ipairs(prov.getDirectoryItems(base)) do
        local path = base..'/'..file
        local stat = prov.getInfo(path)
        if stat and stat.type ~= 'file' and not modlist.excludedDirs[file] then
            for j, subfile in ipairs(prov.getDirectoryItems(path)) do
                local subpath = path..'/'..subfile
                local substat = prov.getInfo(subpath)
                if substat and substat.type == 'file' then
                    modlist.processFile(path, subfile, list, isNfs)
                end
            end
        end
    end

    return list
end

return modlist