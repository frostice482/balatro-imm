local MP = require("imm.mp.mp")
local UI = require("imm.mpui.list")
local UIModpack = require("imm.mpui.modpack")
local UICT = require('imm.mpui.confirm')
local ui = require("imm.lib.ui")

G.FUNCS[UI.funcs.active] = function ()
end

G.FUNCS[UI.funcs.settings] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MPList, imm.Modpack
	local ses, mp = t.ses, t.mp

	UIModpack(ses, mp):showOverlay()
end

G.FUNCS[UI.funcs.activate] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MPList, imm.Modpack
	local ses, mp = t.ses, t.mp

	local ll = MP.applyDiff(mp:diff(), mp.ctrl:createLoadList(), t.merge)
	UICT({ list = ll, mpses = ses, mp = mp, ctrl = mp.ctrl }):showOverlay()
end

G.FUNCS[UI.funcs.delete] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MPList, imm.Modpack
	local ses, mp = t.ses, t.mp

	ui.overlay(
		ui.confirm(
			ui.R{
				align = "cm",
				ui.T(string.format("Really delete modpack %s?", mp.name), { scale = 0.6 })
			},
			UI.funcs.deleteConfirm,
			e.config.ref_table
		)
	)
end

G.FUNCS[UI.funcs.deleteConfirm] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MPList, imm.Modpack
	local ses, mp, confirm = t.ses, t.mp, t.confirm

	if confirm then ses.modpacks:remove(mp.id) end
	ses:showOverlay()
end

G.FUNCS[UI.funcs.addnew] = function (e)
	--- @type imm.UI.MPList
	local t = e.config.ref_table

	local n = t.modpacks:new()
	t.prioritizeId[n.id] = true

	t:updateList()
end

--- @param e balatro.UIElement
G.FUNCS[UI.funcs.init] = function (e)
	--- @type imm.UI.MPList
	local t = e.config.ref_table
	t.uibox = e.UIBox
	e.UIBox.config.imm_mplist = t
end