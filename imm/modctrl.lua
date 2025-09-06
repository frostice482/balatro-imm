local ctrl = require("imm.lib.modctrl")()
local balaver = G.VERSION
local lovelyver = SMODS.Mods.Lovely.version

local baseinfo = { format = 'smods', path = 'temp-'..math.random(), info = {}, deps = {}, conflicts = {} }

ctrl.mods.Balatro = {
    mod = 'Balatro',
    versions = { [balaver] = setmetatable({ version = balaver }, { __index = baseinfo }) },
    native = true
}

ctrl.mods.Lovely = {
    mod = 'Lovely',
    versions = { [lovelyver] = setmetatable({ version = lovelyver }, { __index = baseinfo }) },
    native = true
}
ctrl.mods.lovely = ctrl.mods.Lovely

return ctrl