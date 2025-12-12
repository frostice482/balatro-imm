local UI = require("imm.mpui.modpack")

G.FUNCS[UI.funcs.back] = function (e)
	e.config.ref_table.ses:showOverlay()
end

--- @param e balatro.UIElement
G.FUNCS[UI.funcs.init] = function (e)
	e.config.func = nil
	e.UIBox.config.imm_mp = e.config.ref_table
end
