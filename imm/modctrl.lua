local ctrl = require("imm.lib.modctrl")()
local balaver = G.VERSION
local lovelyver = SMODS.Mods.Lovely.version

local baseinfo = { format = 'smods', path = '', info = {}, deps = {}, conflicts = {} }

ctrl.mods.Balatro = {
    versions = { [balaver] = setmetatable({ version = balaver }, { __index = baseinfo }) },
    native = true
}

ctrl.mods.Lovely = {
    versions = { [lovelyver] = setmetatable({ version = lovelyver }, { __index = baseinfo }) },
    native = true
}

ctrl.mods.lovely = {
    versions = { [lovelyver] = setmetatable({ version = lovelyver }, { __index = baseinfo }) },
    native = true
}

return ctrl