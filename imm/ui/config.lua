local constructor = require("imm.lib.constructor")
local imm = require("imm")

--- @class imm.UI.Config.Funcs
local funcs = {
	save = 'save',
	setearlyerr = 'imm_c_earlyerr'
}

--- @param v balatro.UI.CycleCallbackParam
G.FUNCS[funcs.setearlyerr] = function (v)
	local t = v.cycle_config.ref_table
	t[1][t[2]] = t[3][v.to_key]
	imm.saveconfig()
end

--- @class imm.UI.Config
local IUIConf = {
    buttonWidth = 4,
    optionSpacing = 0.2
}

--- @protected
--- @param ses imm.UI.Browser
function IUIConf:init(ses)
    self.ses = ses

	self.earlyErrorOpts = { 'Disable mods', 'List mods', 'Do nothing' }
	self.earlyErrorValues = { '', 'nodisable', 'ignore' }
end

--- @param text string
--- @param prop string
function IUIConf:renderOptBoolProp(text, prop)
	return create_toggle({
		label = text,
		ref_table = imm.config, ref_value = prop,
		callback = function (v)
			imm.config[prop] = v and '' or nil
			imm.saveconfig()
		end
	})
end

function IUIConf:renderOptions()
	--- @type balatro.UIElement.Definition[]
	return {
		create_option_cycle({
			label = 'Early Error',
			options = self.earlyErrorOpts,
			current_option = get_index(self.earlyErrorValues, imm.config.handleEarlyError or ''),
			scale = 0.8,
			ref_table = { imm.config, 'handleEarlyError', self.earlyErrorValues },
			opt_callback = funcs.setearlyerr
		}),
		self:renderOptBoolProp('Debug Logging', 'debug'),
		self:renderOptBoolProp('Disable safety warning', 'disableSafetyWarning'),
		self:renderOptBoolProp('Disable flavor text', 'disableFlavor'),
		self:renderOptBoolProp('Don\'t update unreleased mode', 'noUpdateUnreleasedMods'),
		self:renderOptBoolProp('Don\'t autodownload unreleased mods', 'noAutoDownloadUnreleasedMods'),
	}
end

function IUIConf:render()
    return self.ses:subcontainer(self:renderOptions())
end

--- @class imm.UI.Config.Static
--- @field funcs imm.UI.Config.Funcs

--- @alias imm.UI.Config.C imm.UI.Config.Static | p.Constructor<imm.UI.Config, nil> | fun(ses: imm.UI.Browser): imm.UI.Config
--- @type imm.UI.Config.C
local UIConf = constructor(IUIConf)
UIConf.funcs = funcs
return UIConf
