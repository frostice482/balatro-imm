local UICT = require('imm.ui.confirm_toggle')

--- @class imm.UI.MP.CT.Funcs
local funcs = {
	confirm = 'imm_mpl_a_conf',
	cancel = 'imm_mpl_a_cancel',
	download = 'imm_mpl_a_download',
}

--- @class imm.UI.MP.Opts: imm.UI.ConfirmToggle.Opts
--- @field list imm.LoadList
--- @field mpses imm.UI.MPList
--- @field mp imm.Modpack

--- @class imm.UI.MP.CT: imm.UI.ConfirmToggle
local IUI = {
	buttonBack = funcs.cancel,
	buttonConfirm = funcs.confirm,
	buttonDownload = funcs.download
}

--- @protected
--- @param opts imm.UI.MP.Opts
function IUI:init(opts)
	UICT.proto.init(self, opts.list, opts)
	self.mpses = opts.mpses
	self.mp = opts.mp
end

--- @protected
function IUI:renderButtonCancel()
	local b = UICT.proto.renderButtonCancel(self)
	b.ref_table = self.mpses
	return b
end

--- @alias imm.UI.MP.CT.C imm.UI.MP.CT.S | p.Constructor<imm.UI.MP.CT, nil> | fun(opts: imm.UI.MP.Opts): imm.UI.MP.CT
--- @type imm.UI.MP.CT.C
local UI = UICT:extendTo(IUI)

--- @class imm.UI.MP.CT.S
local UIS = UI

UIS.funcs = funcs

return UI
