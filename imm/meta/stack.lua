local constructor = require("imm.lib.constructor")

--- @class imm.ModMetaStack
--- @field id? string
--- @field title? string
--- @field author? string
--- @field description? string
--- @field categories? string[]
--- @field badgeColor? string
--- @field badgeTextColor? string
local IMStack = {
    type = 'generic',
    rank = 0
}

--- @return love.Image? data, string? err
function IMStack:getImage()
end

--- @async
--- @return imm.ModMeta.Release[]?, string? err
function IMStack:getReleasesCo()
	return {}
end

function IMStack:clearReleases()
end

function IMStack:hasReleaseInfo()
    return false
end

--- @alias imm.ModMetaStack.C imm.ModMetaStack.Static | p.Constructor<imm.ModMetaStack, nil> | fun(): imm.ModMetaStack
--- @type imm.ModMetaStack.C
local MStack = constructor(IMStack)

--- @class imm.ModMetaStack.Static
local S = MStack

function S.transformVersion(tag)
    if tag:sub(1, 1) == "v" or tag:sub(1, 1) == "V" then tag = tag:sub(2) end
    return tag
end

return MStack