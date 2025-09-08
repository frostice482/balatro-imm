--[[
Taken from: https://github.com/Steamodded/smods/blob/main/src/utils.lua#L609, modified

]]

local constructor = require("imm.lib.constructor")

--- @class Version: metatable
local IV = {}

local WILDCARD = -2

--- @protected
--- @param str string
function IV:init(str)
    local major, minor, patch, rev = str:match('^(%d+)%.?([%d%*]*)%.?([%d%*]*)([%w_~*.%-]*)$')
    if not major or rev and not patch then error('Illegal version '..str) end

    self.major = tonumber(major)
    self.minor = minor == '*' and WILDCARD or tonumber(minor) or 0
    self.patch = patch == '*' and WILDCARD or tonumber(patch) or 0
    self.rev = rev or ''
    self.beta = rev and rev:sub(1,1) == '~' and -1 or 0
end

--- @protected
--- @param a Version
--- @param b Version
function IV.__eq(a, b)
    local minorWildcard = a.minor == WILDCARD or b.minor == WILDCARD
    local patchWildcard = a.patch == WILDCARD or b.patch == WILDCARD
    local betaWildcard = a.rev == '~' or b.rev == '~'

    return a.major == b.major
        and (minorWildcard or a.minor == b.minor)
        and (minorWildcard or patchWildcard or a.patch == b.patch)
        and (minorWildcard or patchWildcard or betaWildcard or a.rev == b.rev)
        and (betaWildcard or a.beta == b.beta)
end

--- @protected
--- @param a Version
--- @param b Version
function IV.__le(a, b)
    local b = {
        major = b.major + (b.minor == WILDCARD and 1 or 0),
        minor = b.minor == WILDCARD and 0 or (b.minor + (b.patch == WILDCARD and 1 or 0)),
        patch = b.patch == WILDCARD and 0 or b.patch,
        beta = b.beta,
        rev = b.rev,
    }
    if a.major ~= b.major then return a.major < b.major end
    if a.minor ~= b.minor then return a.minor < b.minor end
    if a.patch ~= b.patch then return a.patch < b.patch end
    if a.beta ~= b.beta then return a.beta < b.beta end
    return a.rev <= b.rev
end

--- @protected
--- @param a Version
--- @param b Version
function IV.__lt(a, b)
    return a <= b and not (a == b)
end

--- @param rules imm.Dependency.Rule[]
function IV:satisfies(rules)
    for i, rule in ipairs(rules) do
        if not (
            rule.op == "<<" and self < rule.version
        or  rule.op == "<=" and self <= rule.version
        or  rule.op == ">>" and self > rule.version
        or  rule.op == ">=" and self >= rule.version
        or  rule.op == "==" and self == rule.version
        ) then return false end
    end
    return true
end

--- @alias imm.Version.C p.Constructor<Version, nil> | fun(ver: string): Version
--- @type imm.Version.C
local V = constructor(IV)
return V
