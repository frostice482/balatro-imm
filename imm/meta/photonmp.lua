local Stack = require("imm.meta.stack")

--- @class imm.ModMetaStack.PhotonMP: imm.ModMetaStack
--- @field id? string
local IBMIStack = {
    type = 'photonmp',
    rank = 3,
}

--- @protected
--- @param info photon.Modpack
function IBMIStack:init(info)
    self.info = info

    self.id = info.id
    self.title = info.name
    self.author = info.author
    self.description = info.description
    self.categories = info.tags
end

--- @alias imm.ModMetaStack.PhotonMP.C p.Constructor<imm.ModMetaStack.PhotonMP.C, imm.ModMetaStack.C> | fun(info: photon.Modpack): imm.ModMetaStack.PhotonMP
--- @type imm.ModMetaStack.PhotonMP.C
local BMIStack = Stack:extendTo(IBMIStack)

return BMIStack