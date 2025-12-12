local Base = require("imm.mpui.modpack.ui")
local ui = require('imm.lib.ui')
local util = require('imm.lib.util')

--- @class imm.UI.MP.Mods.Funcs
local funcs = {
	paste = 'imm_mp_mods_paste',
	remove = 'imm_mp_mods_remove'
}

--- @class imm.UI.MP.Mods.Entry
--- @field id string
--- @field entry imm.Modpack.Mod

--- @class imm.UI.MP.Mods: imm.UI.MP.Base
--- @field list imm.UI.MP.Mods.Entry[]
--- @field cycleOpts imm.UI.CycleOptions
local IUI = {
	tabId = 'mods',
	tabLabel = 'Mods',

	listId = 'modlist',
	idWidth = 3,
	versionWidth = 4,
	urlWidth = 10,
	urlColor = darken(G.C.WHITE, 0.4),
	pageSize = 5,
	titleScale = 1.25,
	urlScale = 0.8,
	searchWidth = 8,

	searchTimeout = 0.3,
	addedColor = G.C.GREEN
}

--- @protected
function IUI:initState()
	self.state.search = self.state.search or ''
	if not self.state.enableds then
		self.state.enableds = {}
		for k,v in pairs(self.mp.mods) do
			self.state.enableds[k] = true
		end
	end

	self.list = {}
	self.cycleOpts = {
		func = function (i)
			return self.list[i] and self:renderMod(self.list[i])
		end,
		id = self.listId,
		length = 0,
		pagesize = self.pageSize,
		onCycle = function (page)
			util.waitFrames(1, function ()
				return self:recalculate(true)
			end)
		end
	}
end

--- @protected
function IUI:renderInputSearch()
	return ui.textInputDelaying(self.ses:uiModifyTextInput{
		ref_table = self.state,
		ref_value = 'search',
		delay = self.searchTimeout,
		onSet = function (v) self:updateList() end,

		w = self.searchWidth,
		prompt_text = 'Search'
	})
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
function IUI:renderModTitle(entry)
	return ui.R{
		minw = self.idWidth,
		maxw = self.idWidth,
		ui.T(entry.id, {
			scale = self.ses.fontScale * self.titleScale,
			colour = not self.state.enableds[entry.id] and self.addedColor or nil
		})
	}
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
function IUI:renderModVersions(entry)
	local vers = {}
	local modlist = self:getCtrl().mods[entry.id]
	if modlist then
		for i,mod in ipairs(modlist:list()) do
			vers[i] = mod.version
		end
	end
	local i = get_index(vers, entry.entry.version)
	if not i then
		table.insert(vers, 1, entry.entry.version)
		i = 1
	end

	return create_option_cycle({
		options = vers,
		current_option = i,
		w = self.versionWidth,
		text_scale = self.ses.fontScale,
		colour = self.ses.inputColors
	})
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
function IUI:renderModURL(entry)
	return ui.R{
		align = 'c',
		minw = self.urlWidth,
		maxw = self.urlWidth,
		minh = self.ses.fontScale,

		ui.TC{
			ref_table = entry.entry,
			ref_value = 'url',
			scale = self.ses.fontScale * self.urlScale,
			colour = self.urlColor
		}
	}
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
function IUI:renderModBundle(entry)
	return create_toggle({
		ref_table = entry.entry,
		ref_value = 'bundle',
		label = 'Bundle',
		label_scale = self.ses.fontScale,
		w = self.ses.fontScale * 3,

		callback = function (value)
			self.mp:save()
		end
	})
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
--- @param label string[]
--- @param button string
--- @param minw? number
function IUI:renderButton(entry, label, button, minw)
	return UIBox_button({
		label = label,
		button = button,
		scale = self.ses.fontScale,
		minw = minw,
		minh = self.ses.fontScale * 2,
		colour = self.ses.inputColors,
		col = true,
		ref_table = {
			e = entry,
			ses = self
		}
	})
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
function IUI:renderOptions(entry)
	--- @type balatro.UIElement.Definition[]
	return {
		ui.C{ align = 'cm', self:renderModBundle(entry)},
		self:renderButton(entry, {'Paste URL'}, funcs.paste),
		self:renderButton(entry, {'X'}, funcs.remove, self.ses.fontScale * 2),
	}
end

--- @protected
--- @param entry imm.UI.MP.Mods.Entry
function IUI:renderMod(entry)
	return ui.R{
		ui.C{
			ui.R{
				ui.C{ align = 'c', self:renderModTitle(entry)},
				ui.C{ self:renderModVersions(entry) },
			},
			self:renderModURL(entry),
		},
		ui.C{
			align = 'cm',
			nodes = ui.gapList('C', 0.1, self:renderOptions(entry))
		}
	}
end

--- @protected
--- @param k string
function IUI:testMod(k)
	local list = self:getCtrl().mods[k]
	local latest = list and list:latest()
	return
		self.state.search == ""
		or k:lower():find(self.state.search:lower(),1, true)
		or latest and latest.name:lower():find(self.state.search:lower(),1, true)
end

--- @protected
function IUI:getList()
	--- @type imm.UI.MP.Mods.Entry[]
	local list = {}
	--- @type imm.UI.MP.Mods.Entry[]
	local prioritized = {}
	for k,v in pairs(self.mp.mods) do
		if self:testMod(k) then
			table.insert(self.state.enableds[k] and list or prioritized, { id = k, entry = v })
		end
	end
	table.sort(list, function (a, b) return a.id < b.id end)
	table.sort(prioritized, function (a, b) return a.id < b.id end)
	util.insertBatch(prioritized, list)
	return prioritized
end

function IUI:updateList()
	self.list = self:getList()
	return self:updateCycle()
end

function IUI:updateCycle()
	self.cycleOpts.length = #self.list
	return ui.cycleUpdate(self.cycleOpts)
end

--- @protected
function IUI:renderListContainer()
	local e = ui.container(self.listId, true)
	e.config.padding = 0.1
	return e
end

--- @protected
function IUI:renderCycle()
	self:updateList()
	return ui.cycle(self.cycleOpts)
end

--- @protected
function IUI:renderCols()
	--- @type balatro.UIElement.Definition[]
	return {
		ui.R{align = 'cm', paddding = 0.1, self:renderInputSearch()},
		self:renderListContainer(),
		self:renderCycle()
	}
end

function IUI:render()
	if not self.renderOnce then
		self.mp:initVersions()
		self.renderOnce = true
	end
	ui.cycleReset(self.cycleOpts)
	return ui.ROOT(self:renderCols())
end

--- @alias imm.UI.MP.Mods.C imm.UI.MP.Mods.S | imm.UI.MP.Base.C.X<imm.UI.MP.Mods>
--- @type imm.UI.MP.Mods.C
local UI = Base:extendTo(IUI)

--- @class imm.UI.MP.Mods.S
local UIS = UI

UIS.funcs = funcs

G.FUNCS[funcs.paste] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MP.Mods, imm.UI.MP.Mods.Entry
	local ses, e = t.ses, t.e

	local url = love.system.getClipboardText()
	if url == "" then return end

	e.entry.url = url
	ses.mp:save()
end

G.FUNCS[funcs.remove] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MP.Mods, imm.UI.MP.Mods.Entry
	local ses, e = t.ses, t.e

	local i = get_index(ses.list, e)
	if not i then return end

	table.remove(ses.list, i)
	ses:updateCycle()
	ses.mp.mods[e.id] = nil
	ses.mp:save()
end

return UI
