local Base = require("imm.mpui.modpack.ui")
local ui = require('imm.lib.ui')

--- @class imm.UI.MP.Export.Funcs
local funcs = {
	export = 'imm_mp_export'
}

--- @class imm.UI.MP.Export: imm.UI.MP.Base
local IUI = {
	tabId = 'export',
	tabLabel = 'Export',

	buttonPadding = 0.8
}

--- @protected
--- @param ses imm.UI.MP
function IUI:init(ses)
	Base.proto.init(self, ses)
	self.warnings = {
		"- For downloadable mods, don't modify the content directly. If you need to, use patching instead",
		"- For modpack-exclusive mods, if you are updating them, make sure to also change their version.",
		"- Bundled mods does not follow .gitignore. Make a .immbfiles file in the mod folder to list files to include, in form of lua patterns.",
	}
end

--- @protected
function IUI:renderButton()
	return self.ses:uiButton{
		label = {'Export'},
		button = funcs.export,
		ref_table = self
	}
end

--- @protected
function IUI:renderMissings()
	local ctrl = self:getCtrl()
	local r = {}
	for k,e in pairs(self.mp.mods) do
		if not ctrl:getMod(k, e.version) and e.bundle then
			table.insert(r, ui.TRS(string.format('Missing: %s %s', k, e.version), self.ses.fontScale * 0.9))
		end
	end
	return r
end

--- @protected
function IUI:renderWarnings()
	return ui.TRARef(self.warnings, nil, {
		scale = self.ses.fontScale * 0.9
	})
end

function IUI:render()
	return ui.ROOT{
		ui.R{
			padding = self.buttonPadding,
			align = 'cm',
			ui.C{
				ui.R{align = 'cm', self:renderButton()},
				ui.R{ui.C(self:renderMissings())}
			}
		},
		ui.TRS("Warning!", self.ses.fontScale, G.C.YELLOW, {
			padding = 0.1,
			align = 'cm',
		}),
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
