local Base = require("imm.mpui.modpack.ui")
local TM = require("imm.lib.texture_moveable")
local ui = require('imm.lib.ui')
local util = require('imm.lib.util')

--- @class imm.UI.MP.Info.Funcs
local funcs = {
	pastedesc = 'imm_mp_info_pastedesc',
	openfolder = 'imm_mp_info_openfolder',
}

--- @class imm.UI.MP.Info: imm.UI.MP.Base
--- @field uibox? balatro.UIBox
local IUI = {
	tabId = 'info',
	tabLabel = 'Info',

	iconWidth = 1.6,
	iconHeight = 1.6,

	inputWidth = 8,
	updateDelay = 1,

	padding = 0.1
}

--- @protected
--- @param ses imm.UI.MP
function IUI:init(ses)
	Base.proto.init(self, ses)

	self.prev_name = ses.mp.name
	self.prev_author = ses.mp.author
end

--- @protected
function IUI:renderDesc()
	local _, descs = G.LANG.font.FONT:getWrap(self.mp.description, G.TILESCALE * G.TILESIZE * 20 * self.ses.ses.descWidth)
	local descElm = {}
	for i,v in ipairs(descs) do
		if i > self.ses.ses.descLines then break end
		descElm[i] = ui.TRS(v, self.ses.fontScale)
	end
	return ui.C{padding = self.padding, nodes = descElm}
end

--- @protected
--- @param prop string
function IUI:renderInputField(prop)
	return self.ses:uiTextInput{
		ref_table = self.mp,
		ref_value = prop,
		delay = self.updateDelay,
		onSet = function (v) self.mp:save() end,

		w = self.inputWidth,
		max_length = 5 * self.inputWidth,
	}
end

--- @protected
--- @param prop string
function IUI:renderInputContainer(prop)
	return ui.R{ padding = self.padding, self:renderInputField(prop) }
end

--- @protected
function IUI:uiIcon()
	return TM(self.mp:getIcon(), 0, 0, self.iconWidth, self.iconHeight)
end

--- @protected
function IUI:renderIcon()
	return ui.C{
		padding = 0.1,
		ui.O(self:uiIcon())
	}
end

--- @protected
function IUI:renderInputs()
	return ui.C{
		align = 'cm',
		self:renderInputContainer('name'),
		self:renderInputContainer('author')
	}
end

--- @protected
--- @param label string
--- @param button string
--- @param opts? _imm.UI.Mp.ButtonParam
function IUI:renderButton(label, button, opts)
	opts = opts or {}
	opts.label = { label }
	opts.button = button
	opts.ref_table = opts.ref_table or self
	opts.hs = opts.hs or 1.5
	opts.col = true
	return self.ses:uiButton(opts)
end

--- @protected
function IUI:renderEditOpts()
	--- @type balatro.UIElement.Definition[]
	return {
		self:renderButton('Paste Description', funcs.pastedesc),
		self:renderButton('Open Folder', funcs.openfolder),
	}
end

--- @protected
function IUI:renderHeader()
	--- @type balatro.UIElement.Definition[]
	return {
		self:renderIcon(),
		self:renderInputs(),
	}
end

--- @protected
function IUI:renderCols()
	--- @type balatro.UIElement.Definition[]
	return {
		ui.R{
			align = 'cm',
			nodes = self:renderHeader()
		},
		ui.R{
			align = 'cm',
			padding = self.padding,
			self:renderDesc()
		},
		ui.R{
			align = 'cm',
			padding = self.padding / 2,
			ui.TRS("Drag and drop an image fie to set icon.", self.ses.fontScale, {0.8, 0.8, 0.8, 1})
		},
		ui.R{
			align = 'cm',
			padding = self.padding / 2,
			nodes = ui.gapList('C', self.padding, self:renderEditOpts())
		}
	}
end

function IUI:render()
	return ui.ROOT(self:renderCols())
end

--- @alias imm.UI.MP.Info.C imm.UI.MP.Info.S | imm.UI.MP.Base.C.X<imm.UI.MP.Info>
--- @type imm.UI.MP.Info.C
local UI = Base:extendTo(IUI)

--- @class imm.UI.MP.Info.S
local UIS = UI

UIS.funcs = funcs

-- func setup

--- @param e balatro.UIElement
G.FUNCS[funcs.pastedesc] = function (e)
	--- @type imm.UI.MP.Info
	local ses = e.config.ref_table
	local t = love.system.getClipboardText()
	if not t or t == "" then return end

	ses.mp.description = t
	ses.mp:saveDescription()
	ses:rerender()
end

--- @param e balatro.UIElement
G.FUNCS[funcs.openfolder] = function (e)
	--- @type imm.UI.MP.Info
	local ses = e.config.ref_table

	love.system.openURL(ses.mp:fileURL())
end

local filedropped = love.filedropped
function love.filedropped(f) --- @diagnostic disable-line
	local o = G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm_mp
	if o then
		local iok, img = pcall(love.graphics.newImage, f)
		if iok then
			o.mp.icon = img
			if o.currentTab == 'info' then o.currentTabComponent:rerender() end
			f:seek(0)
			o.mp:saveThumb(f:read("data"))
		end
		f:seek(0)
	end
	if filedropped then return filedropped(f) end
end

return UI
