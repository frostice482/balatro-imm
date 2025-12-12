local Base = require("imm.mpui.modpack.ui")
local ui = require('imm.lib.ui')
local util = require('imm.lib.util')

--- @class imm.UI.MP.AddMod.Funcs
local funcs = {
	setVersion = 'imm_mp_addmod_ver',
	add = 'imm_mp_addmod_add',
	addEnabled = 'imm_mp_addmod_addenabled',
	addCrashlist = 'imm_mp_addmod_addcrashlist',
	addArb = 'imm_mp_addmod_addarb'
}

--- @class imm.UI.MP.AddMod: imm.UI.MP.Base
--- @field list imm.ModList[]
--- @field cycleOpts imm.UI.CycleOptions
local IUI = {
	tabId = 'addmods',
	tabLabel = 'Add mods',

	inputIdWidth = 5,
	inputVersionWidth = 5,
	searchWidth = 8,

	listId = 'list',
	listHeight = 6,

	titleWidth = 3,
	versionWidth = 4,
	pageSize = 5,
	titleScale = 1.25,
	spacing = 0.1,
	searchTimeout = 0.3,
}

--- @protected
function IUI:initState()
	self.state.search = self.state.search or ''
	self.state.arbid = self.state.arbid or ''
	self.state.arbver = self.state.arbver or ''

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
function IUI:renderListContainer()
	local c = ui.container(self.listId, nil)
	c.config.minh = self.listHeight
	c.config.align = 'cm'
	return c
end

--- @protected
function IUI:renderInputSearch()
	return ui.textInputDelaying(self.ses:uiModifyTextInput{
		ref_table = self.state,
		ref_value = 'search',
		onSet = function (v) self:updateList() end,

		w = self.searchWidth,
		prompt_text = 'Search'
	})
end

--- @protected
--- @param list imm.ModList
--- @param state table
function IUI:renderModTitle(list, state)
	return ui.C{
		minw = self.titleWidth,
		maxw = self.titleWidth,
		align = 'c',
		ui.T(list.mod, { scale = self.ses.fontScale * self.titleScale })
	}
end

--- @protected
--- @param list imm.ModList
--- @param state table
function IUI:renderModVersions(list, state)
	local versions = list:list()
	local veropts = {}
	for i, mod in ipairs(versions) do veropts[i] = mod.version end
	local opt = list.active and get_index(versions, list.active) or 1

	state.versions = versions
	state.ver = versions[opt]

	return create_option_cycle({
		options = veropts,
		current_option = opt,
		w = self.versionWidth,
		text_scale = self.ses.fontScale,
		opt_callback = funcs.setVersion,
		ref_table = state,
		colour = self.ses.inputColors
	})
end

--- @protected
--- @param list imm.ModList
--- @param state table
function IUI:renderModButton(list, state)
	return UIBox_button({
		label = {'+'},
		minh = self.ses.fontScale * 2,
		minw = self.ses.fontScale * 2,
		scale = self.ses.fontScale * 1.5,
		col = true,
		button = funcs.add,
		ref_table = state,
		colour = self.ses.inputColors
	})
end

--- @protected
--- @param list imm.ModList
--- @param state table
function IUI:renderModRows(list, state)
	--- @type balatro.UIElement.Definition[]
	return {
		self:renderModTitle(list, state),
		ui.C{self:renderModVersions(list, state)},
		self:renderModButton(list, state)
	}
end

--- @protected
--- @param list imm.ModList
function IUI:renderMod(list)
	return ui.R(self:renderModRows(list, { list = list, ses = self }))
end

--- @protected
--- @param list imm.ModList
function IUI:testMod(list)
	local latest = list:latest()
	return latest
		and not self.mp.mods[list.mod]
		and not list:isExcluded()
		and (
			self.state.search == ""
			or list.mod:lower():find(self.state.search:lower(), 1, true)
			or latest.name:lower():find(self.state.search:lower(), 1, true)
		)
end

--- @protected
function IUI:getList()
	--- @type imm.ModList[]
	local list = {}
	for k,mod in pairs(self:getCtrl().mods) do
		if self:testMod(mod) then
			table.insert(list, mod)
		end
	end
	table.sort(list, function (a, b)
		if a.active then
			if not b.active then
				return true
			end
		elseif b.active then
			return false
		end
		return a.mod < b.mod
	end)
	return list
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
function IUI:renderCycle()
	self:updateList()
	return ui.cycle(self.cycleOpts)
end

---@protected
function IUI:renderTitle(text)
	return ui.R{
		padding = self.spacing,
		align = 'cm',
		ui.T(text, { scale = self.ses.fontScale * self.titleScale })
	}
end

--- @protected
function IUI:renderAddMods()
	--- @return balatro.UIElement.Definition[]
	return {
		ui.R{padding = self.spacing, self:renderListContainer()},
		ui.R{align = 'cm', self:renderCycle()}
	}
end

--- @protected
--- @param label string[]
--- @param button string
function IUI:renderQAButton(label, button, ref)
	local e = UIBox_button({
		label = label,
		button = button,
		ref_table = ref,
		scale = self.ses.fontScale * self.titleScale,
		colour = self.ses.inputColors,
	})
	e.config.padding = self.spacing
	return e
end

--- @protected
function IUI:renderQAs()
	--- @return balatro.UIElement.Definition
	return {
		self:renderQAButton({'Add enabled mods'}, funcs.addEnabled, self),
		self:renderQAButton({'Add from crash modlist'}, funcs.addCrashlist, self)
	}
end

--- @protected
function IUI:renderQAContainer()
	--- @return balatro.UIElement.Definition
	return ui.R{
		align = 'cm',
		ui.C{
			self:renderTitle("Quick actions:"),
			ui.R{padding = self.spacing, ui.C(self:renderQAs())}
		}
	}
end

--- @protected
function IUI:renderArbInputID()
	return create_text_input(self.ses:uiModifyTextInput{
		ref_table = self.state,
		ref_value = 'arbid',
		prompt_text = 'Mod ID',
		max_length = 5 * self.inputIdWidth,
		w = self.inputIdWidth
	})
end

--- @protected
function IUI:renderArbInputVersion()
	return create_text_input(self.ses:uiModifyTextInput{
		ref_table = self.state,
		ref_value = 'arbver',
		prompt_text = 'Mod version',
		extended_corpus = true,
		max_length = 5 * self.inputVersionWidth,
		w = self.inputVersionWidth
	})
end

--- @protected
function IUI:renderArb()
	--- @return balatro.UIElement.Definition[]
	return {
		self:renderTitle("Add arbitrary:"),
		ui.R{ padding = self.spacing, self:renderArbInputID() },
		ui.R{ padding = self.spacing, self:renderArbInputVersion() },
		self:renderQAButton({'Add'}, funcs.addArb, self)
	}
end

--- @protected
function IUI:renderArbContainer()
	return ui.R{
		align = 'cm',
		ui.C(self:renderArb())
	}
end

--- @protected
function IUI:renderTile()
	--- @return balatro.UIElement.Definition[]
	return {
		ui.C{
			padding = self.spacing,
			ui.R{align = 'cm', self:renderInputSearch()},
			ui.R(self:renderAddMods())
		},
		ui.C{
			padding = self.spacing,
			align = 'cm',
			self:renderQAContainer(),
			self:renderArbContainer(),
		}
	}
end

function IUI:render()
	ui.cycleReset(self.cycleOpts)
	return ui.ROOT(self:renderTile())
end

--- @param id string
--- @param ver string
--- @param save? boolean
function IUI:addAndRecalc(id, ver, save)
	self.mp:addMod(id, ver)
	self:updateList()
	if save then
		self.mp:save()
	end
end

--- @alias imm.UI.MP.AddMod.C imm.UI.MP.AddMod.S | imm.UI.MP.Base.C.X<imm.UI.MP.AddMod>
--- @type imm.UI.MP.AddMod.C
local UI = Base:extendTo(IUI)

--- @class imm.UI.MP.AddMod.S
local UIS = UI

UIS.funcs = funcs

G.FUNCS[funcs.setVersion] = function (e)
	e.cycle_config.ref_table.ver = e.cycle_config.ref_table.versions[e.to_key]
end

G.FUNCS[funcs.add] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MP.AddMod, imm.Mod
	local ses, ver = t.ses, t.ver

	local i = get_index(ses.list, ver.list)
	if not i then return ses:addAndRecalc(ver.mod, ver.version) end

	table.remove(ses.list, i)
	ses:updateCycle()
	ses.mp:addMod(ver.mod, ver.version)
	ses.mp:save()
end

G.FUNCS[funcs.addArb] = function (e)
	local t = e.config.ref_table
	--- @type imm.UI.MP.AddMod, imm.Mod
	local ses, ver = t.ses, t.ver
	ses:addAndRecalc(ver.mod, ver.version, true)
end

G.FUNCS[funcs.addEnabled] = function (e)
	--- @type imm.UI.MP.AddMod
	local ses = e.config.ref_table

	for k,v in pairs(ses:getCtrl().loadlist.loadedMods) do
		if not v:isHidden() then
			ses.mp:addMod(k, v.mod)
		end
	end
	ses:updateList()
	ses.mp:save()
end

G.FUNCS[funcs.addCrashlist] = function (e)
	--- @type imm.UI.MP.AddMod
	local ses = e.config.ref_table

	local lines = util.strsplit(love.system.getClipboardText(), '\r?\n')
	for i, line in ipairs(lines) do
		local id, ver = line:match("ID: ([%w_]+),[^\r\n]+Version: ([%w_.+~-]+)")
		if id and ver then
			ses.mp:addMod(id, ver)
		end
	end

	ses:updateList()
	ses.mp:save()
end

G.FUNCS[funcs.addArb] = function (e)
	--- @type imm.UI.MP.AddMod
	local ses = e.config.ref_table
	local id = ses.state.arbid
	local ver = ses.state.arbver

	if not id or id == "" or not ver or ver == "" then return end

	ses:addAndRecalc(id, ver, true)
end

return UI
