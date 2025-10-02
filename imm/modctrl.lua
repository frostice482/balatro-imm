local ModCtrl = require("imm.lib.mod.ctrl")
local ModList = require("imm.lib.mod.list")
local ctrl = ModCtrl()
local conf = require("imm.config")

if G then
    ctrl.mods.Balatro = ModList('Balatro', true)
    ctrl:addEntry(ctrl.mods.Balatro:createVersion(G.VERSION, nil, true))
end
if conf.lovelyver then
    ctrl.mods.Lovely = ModList('Lovely', true)
    ctrl:addEntry(ctrl.mods.Lovely:createVersion(conf.lovelyver, nil, true))

    ctrl.mods.lovely = ModList('lovely', true)
    ctrl:addEntry(ctrl.mods.lovely:createVersion(conf.lovelyver, nil, true))
end

_G.immctrl = ctrl

return ctrl