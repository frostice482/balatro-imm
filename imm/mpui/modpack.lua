local constructor = require('imm.lib.constructor')
local UIInfo = require("imm.mpui.modpack.info")
local UIExport = require("imm.mpui.modpack.export")
local UIMods = require("imm.mpui.modpack.mods")
local UIAddMod = require("imm.mpui.modpack.addmods")
local ui = require('imm.lib.ui')

--- @class imm.UI.MP.Funcs
local funcs = {
	back = 'imm_mp_back',
	init = 'imm_mp_init'
}

--- @class imm.UI.MP
--- @field currentTabComponent? imm.UI.MP.Base
local IUI = {
	currentTab = 'info',

	fontScale = 0.4,
	inputColors = G.C.BOOSTER,
	inputColorsLight = lighten(G.C.BOOSTER, 0.2),
}

--- @protected
--- @param ses imm.UI.MPList
--- @param mp imm.Modpack
function IUI:init(ses, mp)
	self.ses = ses
	self.mp = mp
	self.states = {}

	self.uiInfo = UIInfo(self)
	self.uiExport = UIExport(self)
	self.uiMods = UIMods(self)
	self.uiAddMod = UIAddMod(self)
	self.uis = {
		self.uiInfo,
		self.uiMods,
		self.uiAddMod,
		self.uiExport,
	}
end

--- @protected
--- @param def imm.UI.MP.Base
function IUI:uiTab(def)
	--- @type balatro.UI.Tab.Tab
	return {
		label = def.tabLabel,
		chosen = self.currentTab == def.tabId,
		tab_definition_function = function (arg)
			self.currentTab = def.tabId
			self.currentTabComponent = def
			return def:wrapRender()
		end,
	}
end

--- @protected
function IUI:renderTabsList()
	--- @type balatro.UI.Tab.Tab[]
	local list = {}
	for i,v in ipairs(self.uis) do
		table.insert(list, self:uiTab(v))
	end
	return list
end

--- @protected
function IUI:renderTabs()
	return create_tabs({
		tabs = self:renderTabsList()
	})
end

function IUI:render()
	return create_UIBox_generic_options({
		contents = {
			self:renderTabs(),
			ui.R{ func = funcs.init, ref_table = self }
		},
		back_func = funcs.back,
		ref_table = self
	})
end

function IUI:showOverlay()
	ui.overlay(self:render())
end

--- @param param imm.UI.TextInputDelayOpts
function IUI:uiModifyTextInput(param)
	param.extended_corpus = true
	param.colour = self.inputColors
	param.hooked_colour = self.inputColorsLight
	return param
end

--- @alias imm.UI.MP.C imm.UI.MP.S | p.Constructor<imm.UI.MP, nil> | fun(ses: imm.UI.MPList, mp: imm.Modpack): imm.UI.MP
--- @type imm.UI.MP.C
local UI = constructor(IUI)

--- @class imm.UI.MP.S
local UIS = UI

UIS.funcs = funcs

return UI
