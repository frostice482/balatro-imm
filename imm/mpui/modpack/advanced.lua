local Base = require("imm.mpui.modpack.ui")
local ui = require('imm.lib.ui')
local util = require('imm.lib.util')

--- @class imm.UI.MP.Advanced.Funcs
local funcs = {
}

--- @class imm.UI.MP.Advanced: imm.UI.MP.Base
local IUI = {
	tabId = 'advanced',
	tabLabel = 'Advanced',

	padding = 0.1
}

--- @protected
--- @param ses imm.UI.MP
function IUI:init(ses)
	Base.proto.init(self, ses)

	self.colors = {
		inputs = copy_table(ses.mp.colors),
		width = 1.75,
		labelWidth = 3
	}
end

--- @protected
--- @param prop string
function IUI:renderColorInput(prop)
	return ui.textInput({
		ref_table = self.colors.inputs,
		ref_value = prop,
		w = self.colors.width,
		max_length = 6,
		extended_corpus = true,
		prompt_text = '',

		delay = 0.2,
		onSet = function (v)
			if self.mp:setColor(prop, v) then
				self.ses:refreshColor()
				self.mp:save()
			end
		end
	})
end

--- @protected
--- @param prop string
function IUI:renderColorPreview(prop)
	return ui.C{
		align = 'cm',
		ui.R{
			minw = self.ses.fontScale,
			minh = self.ses.fontScale,
			outline = 1,
			outline_colour = G.C.WHITE,
			colour = self.mp.parsedColors[prop]
		}
	}
end

--- @protected
--- @param text string
--- @param prop string
function IUI:renderColorSel(text, prop)
	local title = ui.C{
		align = 'cr',
		minw = self.colors.width,
		ui.T(text, { scale = self.ses.fontScale })
	}
	local rows = {
		title,
		self:renderColorInput(prop),
		self:renderColorPreview(prop),
	}
	return ui.R(ui.gapList('C', self.padding, rows))
end

--- @protected
function IUI:renderCols()
	--- @type balatro.UIElement.Definition[]
	return {
		ui.TRS('Colors', self.ses.fontScale * 1.5, nil, { align = 'cm', padding = self.padding }),
		self:renderColorSel('Background', 'bg'),
		self:renderColorSel('Foreground', 'fg'),
		-- self:renderColorSel('Text', 'text') no functionality
	}
end

function IUI:render()
	return ui.ROOT(ui.gapList('R', self.padding, self:renderCols()))
end

--- @alias imm.UI.MP.Advanced.C imm.UI.MP.Advanced.S | imm.UI.MP.Base.C.X<imm.UI.MP.Advanced>
--- @type imm.UI.MP.Advanced.C
local UI = Base:extendTo(IUI)

--- @class imm.UI.MP.Advanced.S
local UIS = UI

UIS.funcs = funcs

return UI
