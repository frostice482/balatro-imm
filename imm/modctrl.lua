local ModCtrl = require("imm.lib.mod.ctrl")
local ModList = require("imm.lib.mod.list")
local ctrl = ModCtrl()
local lovelyver = require("lovely").version

if G then
    ctrl.mods.Balatro = ModList('Balatro', true)
    ctrl:addEntry(ctrl.mods.Balatro:createVersion(G.VERSION, nil, true))
end

ctrl.mods.Lovely = ModList('Lovely', true)
ctrl:addEntry(ctrl.mods.Lovely:createVersion(lovelyver, nil, true))

ctrl.mods.lovely = ModList('lovely', true)
ctrl:addEntry(ctrl.mods.lovely:createVersion(lovelyver, nil, true))

_G.immctrl = ctrl

return ctrl