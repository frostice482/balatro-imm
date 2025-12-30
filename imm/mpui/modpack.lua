local constructor = require('imm.lib.constructor')
local UIInfo = require("imm.mpui.modpack.info")
local UIExport = require("imm.mpui.modpack.export")
local UIMods = require("imm.mpui.modpack.mods")
local UIAddMod = require("imm.mpui.modpack.addmods")
local UIFile = require("imm.mpui.modpack.file")
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
}

--- @protected
--- @param ses imm.UI.MPList
--- @param mp imm.Modpack
function IUI:init(ses, mp)
	self.ses = ses
	self.mp = mp
	self.states = {}

	self.colors = {
		normal = G.C.BOOSTER,
		header = G.C.BOOSTER,
		footer = G.C.RED,
	}

	self.uiObjects = {
		Info = UIInfo(self),
		Export = UIExport(self),
		Mods = UIMods(self),
		AddMod = UIAddMod(self),
		File = UIFile(self),
	}
	self.uis = {
		self.uiObjects.Info,
		self.uiObjects.Mods,
		self.uiObjects.AddMod,
		self.uiObjects.File,
		self.uiObjects.Export,
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

--- @param param imm.UI.TextInputOpts
function IUI:uiTextInput(param)
	param.extended_corpus = true
	param.colour = param.colour or self.colors.header
	return ui.textInput(param)
end

function IUI:uiCycleOpts()
	--- @type balatro.UI.OptionCycleParam
	return {
		no_pips = true,
		colour = self.colors.footer
	}
end

--- @class _imm.UI.Mp.ButtonParam: balatro.UI.ButtonParam
--- @field hs? number

--- @param param _imm.UI.Mp.ButtonParam
function IUI:uiButton(param)
	param.scale = param.scale or self.fontScale
	param.minh = param.minh or self.fontScale * (param.hs or 2)
	param.colour = param.colour or self.colors.normal
	return UIBox_button(param)
end

--- @alias imm.UI.MP.C imm.UI.MP.S | p.Constructor<imm.UI.MP, nil> | fun(ses: imm.UI.MPList, mp: imm.Modpack): imm.UI.MP
--- @type imm.UI.MP.C
local UI = constructor(IUI)

--- @class imm.UI.MP.S
local UIS = UI

UIS.funcs = funcs

return UI
