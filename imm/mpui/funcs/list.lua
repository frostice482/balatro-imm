local MP = require("imm.mp.mp")
local UI = require("imm.mpui.list")
local UIModpack = require("imm.mpui.modpack")
local UICT = require('imm.mpui.confirm')
local ui = require("imm.lib.ui")

G.FUNCS[UI.funcs.active] = function ()
end

G.FUNCS[UI.funcs.optuibox] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table

	t.ses:unsetActiveOptions()

	t.ses.optionsUibox = UIBox{
		definition = t.ses:renderMPActionsContainer(t),
		config = {
			major = e,
			align = 'cr',
			instance_type = 'POPUP',
			offset = { x = 0.2, y = 0 }
		}
	}
end

G.FUNCS[UI.funcs.optsync] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table

	if not t.ses.uibox or t.ses.uibox.REMOVED then
		t.ses:unsetActiveOptions()
	end
end

--- @param e _imm.UI.MPList.MPInfo
--- @param off number
local function swapwith(e, off)
	local ses = e.ses
	local l = ses.list
	local i = get_index(e.ses.list, e.mp)
	if not i then return end

	off = i + off
	local other = l[off]
	if not other then return end

	other.order, e.mp.order = e.mp.order, other.order

	other:save()
	e.mp:save()

	ses.gpPageCycle = ses.gpPageCycle + 1
	ses.cycleOpts.currentPage = math.ceil(off / ses.pageSize)
	ses:updateList()
end

G.FUNCS[UI.funcs.moveup] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table
	return swapwith(t, -1)
end

G.FUNCS[UI.funcs.movedown] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table
	return swapwith(t, 1)
end

G.FUNCS[UI.funcs.settings] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table
	UIModpack(t.ses, t.mp):showOverlay()
end

G.FUNCS[UI.funcs.activate] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table
	local ll = MP.applyDiff(t.mp:diff(), t.mp.ctrl:createLoadList(), t.merge)
	UICT({ list = ll, mpses = t.ses, mp = t.mp, ctrl = t.mp.ctrl }):showOverlay()
end

G.FUNCS[UI.funcs.delete] = function (e)
	--- @type _imm.UI.MPList.MPInfo
	local t = e.config.ref_table

	ui.overlay(
		ui.confirm(
			ui.TRS(string.format("Really delete modpack %s?", t.mp.name), 0.6, nil, { align = 'cm' }),
			UI.funcs.deleteConfirm,
			e.config.ref_table
		)
	)
end

G.FUNCS[UI.funcs.deleteConfirm] = function (e)
	local t = e.config.ref_table
	if t.confirm then t.ses.modpacks:remove(t.mp.id) end
	t.ses:showOverlay()
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