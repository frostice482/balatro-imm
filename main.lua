NFS.mount(SMODS.current_mod.path..'/imm', 'imm')

SMODS.Atlas({ key = 'icons', path = 'icons.png', px = 19, py = 19 })
SMODS.Atlas({ key = 'toggle', path = 'toggle.png', px = 15, py = 9 })

require('imm.ui')
require('imm.dropinstall')

_G.imm = require("imm.modctrl")