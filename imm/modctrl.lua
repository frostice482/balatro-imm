local ModCtrl = require("imm.lib.mod.ctrl")
local ModList = require("imm.lib.mod.list")
local ctrl = ModCtrl()
local imm = require("imm")

if G then
    ctrl.mods.Balatro = ModList('Balatro', true)
    ctrl:addEntry(ctrl.mods.Balatro:createVersion(G.VERSION, nil, true))
end
if imm.lovelyver then
    ctrl.mods.Lovely = ModList('Lovely', true)
    ctrl:addEntry(ctrl.mods.Lovely:createVersion(imm.lovelyver, nil, true))

    ctrl.mods.lovely = ModList('lovely', true)
    ctrl:addEntry(ctrl.mods.lovely:createVersion(imm.lovelyver, nil, true))
end

_G.immctrl = ctrl

return ctrl