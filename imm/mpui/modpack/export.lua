local Base = require("imm.mpui.modpack.ui")
local tarc = require('imm.tar.c')
local ui = require('imm.lib.ui')

--- @class imm.UI.MP.Export.Funcs
local funcs = {
	export = 'imm_mp_export'
}

--- @class imm.UI.MP.Export: imm.UI.MP.Base
local IUI = {
	tabId = 'export',
	tabLabel = 'Export',
}

--- @protected
--- @param ses imm.UI.MP
function IUI:init(ses)
	Base.proto.init(self, ses)
	self.warnings = {
		"- For downloadable mods, don't modify the content directly.",
		"  If you need to, use patching instead",
		"- For modpack-exclusive mods, if you are updating them,",
		"  make sure to also change their version.",
	}
end

--- @protected
function IUI:renderButton()
	return UIBox_button({
		label = {'Export'},
		button = funcs.export,
		ref_table = self
	})
end

--- @protected
function IUI:renderWarnings()
	local r = {}
	for i,v in ipairs(self.warnings) do
		table.insert(r, ui.TRS(v, self.ses.fontScale * 0.9))
	end
	return r
end

function IUI:render()
	return ui.ROOT{
		ui.R{
			minh = 2,
			minw = 5,
			align = 'cm',
			self:renderButton()
		},
		ui.R{
			align = "cm",
			padding = 0.1,
			ui.T("Warning!", { scale = self.ses.fontScale, colour = G.C.YELLOW })
		},
		ui.R{
			ui.C(self:renderWarnings())
		}
	}
end

--- @alias imm.UI.MP.Export.C imm.UI.MP.Export.S | imm.UI.MP.Base.C.X<imm.UI.MP.Export>
--- @type imm.UI.MP.Export.C
local UI = Base:extendTo(IUI)

--- @class imm.UI.MP.Export.S
local UIS = UI

UIS.funcs = funcs

G.FUNCS[funcs.export] = function (e)
	--- @type imm.UI.MP.Export
	local ses = e.config.ref_table
	ses.mp:exportToFile()
	love.system.openURL(ses.mp:fileURL())
end

return UI
