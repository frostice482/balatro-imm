local Base = require("imm.mpui.modpack.ui")
local constructor = require('imm.lib.constructor')
local ui = require('imm.lib.ui')
local util = require('imm.lib.util')

--- @class imm.UI.MP.File.Funcs
local funcs = {
	open = 'imm_mp_files_open',
	copySettings = 'imm_mp_files_copystg',
	apply = 'imm_mp_files_apply',
}

--- @class imm.UI.MP.File: imm.UI.MP.Base
local IUI = {
	tabId = 'file',
	tabLabel = 'File',
}

--- @protected
--- @param ses imm.UI.MP
function IUI:init(ses)
	Base.proto.init(self, ses)
	self.desc = {
		'Store any files in this modpack that will override',
		'saved files when applied, for example configs.'
	}
end

--- @protected
function IUI:renderDesc()
	return ui.TRARef(self.desc, nil, { scale = self.ses.fontScale }, { align = 'cm' })
end

--- @protected
function IUI:renderButtons()
	return {
		UIBox_button({
			label = {'Open Folder'},
			button = funcs.open,
			ref_table = self,
			col = true
		}),
		UIBox_button({
			label = {'Copy configs'},
			button = funcs.copySettings,
			ref_table = self,
			col = true
		}),
		UIBox_button({
			label = {'Apply config'},
			button = funcs.apply,
			ref_table = self,
			col = true
		})
	}
end

function IUI:render()
	return ui.ROOT{
		ui.C{
			ui.R{
				align = 'cm',
				ui.C{self:renderDesc()},
			},
			ui.R{
				padding = 0.5,
				align = 'cm',
				nodes = self:renderButtons()
			}
		}
	}
end

--- @alias imm.UI.MP.File.C imm.UI.MP.File.S | imm.UI.MP.Base.C.X<imm.UI.MP.File>
--- @type imm.UI.MP.File.C
local UI = Base:extendTo(IUI)

--- @class imm.UI.MP.File.S
local UIS = UI

UIS.funcs = funcs

G.FUNCS[funcs.open] = function (e)
	--- @type imm.UI.MP.File
	local ses = e.config.ref_table
	ses.mp:mkdirFiles()
	love.system.openURL(ses.mp:fileURL('files'))
end

G.FUNCS[funcs.copySettings] = function (e)
	--- @type imm.UI.MP.File
	local ses = e.config.ref_table
	ses.mp:copySaveAllModConfigs()
end

G.FUNCS[funcs.apply] = function (e)
	--- @type imm.UI.MP.File
	local ses = e.config.ref_table
	pcall(ses.mp.applyFiles, ses.mp)
end

return UI
