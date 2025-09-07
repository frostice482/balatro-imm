local ModCtrl = require("imm.lib.mod.ctrl")
local ModList = require("imm.lib.mod.list")
local ctrl = ModCtrl()
local balaver = G.VERSION
local lovelyver = require("lovely").version

ctrl.mods.Balatro = ModList('Balatro', true)
ctrl.mods.Balatro:createVersion(balaver)

ctrl.mods.Lovely = ModList('Lovely', true)
ctrl.mods.Lovely:createVersion(lovelyver)

ctrl.mods.lovely = ModList('lovely', true)
ctrl.mods.lovely:createVersion(lovelyver)

_G.immctrl = ctrl

return ctrl