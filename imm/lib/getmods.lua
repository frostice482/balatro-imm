local util = require("imm.lib.util")

--- @alias imm.ModInfoFormat 'thunderstore' | 'smods' | 'smods-header'

--- @class imm.ModListVersion
--- @field format imm.ModInfoFormat
--- @field path string
--- @field info table

--- @class imm.ModListEntry
--- @field versions table<string, imm.ModListVersion>
--- @field active? string

--- List of mods, mapped by mod id, then version.
--- @class imm.ModList: {[string]: imm.ModListEntry}

local metaFields = {
    id = "string",
    name = "string",
    description = "string",
    prefix = "string",
    author = "table",
    version = "string", -- optional in steamodded
}

local tsManifestFields = {
    name = "string",
    version_number = "string",
    website_url = "string",
    description = "string",
    dependencies = "table"
}

local headerFields = {
    MOD_ID = "id",
    MOD_NAME = "name",
    MOD_DESCRIPTION = "description",
    PREFIX = "prefix",
    VERSION = "version",
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

local function processHeader(file, isNfs)
    local prov = isNfs and NFS or love.filesystem
    --- @type string?
    local content = prov.read('string', file, 512) --- @diagnostic disable-line
    if not content then return end
    if not util.startswith(content, "--- STEAMODDED HEADER") then return end

    local values = {}
    local lines = util.strsplit(content, '\r?\n', false)
    for i, line in ipairs(lines), lines, 1 do
        local s, e, attr = line:find('^--- *([%w_]+): *')
        if not s then break end
        if headerFields[attr] then
            values[headerFields[attr]] = line:sub(e+1)
        end
    end

    return values
end

--- @param ctx imm.GetModsContext
--- @param base string
--- @param file string
local function processFile(ctx, base, file)
    local prov = ctx.isNfs and NFS or love.filesystem
    local path = base..'/'..file
    local ifile = file:lower()
    local mod
    --- @type imm.ModInfoFormat
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

    local id = fmt == 'thunderstore' and mod.name or mod.id
    local version = fmt == 'thunderstore' and mod.version_number or mod.version
    local ignored = prov.getInfo(base..'/.lovelyignore')

    if id == "Steamodded" then
        local vercode = prov.read(base..'/version.lua') or ''
        local newver = vercode:match('"(.+)"')
        if newver and util.endswith(newver, "-STEAMODDED") then newver = newver:sub(1, -12) end
        if newver then version = newver end
        version = version:gsub('BETA', 'beta')
    end
    version = version:gsub('~', '-')

    if not ctx.list[id] then ctx.list[id] = { versions = {} } end
    local versionList = ctx.list[id]
    versionList.versions[version] = { format = fmt, info = mod, path = base }

    if not ignored then versionList.active = version end
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