local constructor = require('imm.lib.constructor')
local ui = require('imm.lib.ui')

local initfunc = 'imm_mp_base_init'

--- @class imm.UI.MP.Base
--- @field uibox? balatro.UIBox
local IUI = {
	tabId = '',
	tabLabel = '',
}

--- @protected
--- @param ses imm.UI.MP
function IUI:init(ses)
	self.ses = ses
	self.mp = ses.mp
end

--- @protected
function IUI:initRender()
end

function IUI:render()
	return ui.ROOT()
end

function IUI:getCtrl()
	return self.ses.ses.tasks.ctrl
end

function IUI:getRepo()
	return self.ses.ses.tasks.repo
end

function IUI:wrapRender()
	self.uibox = nil
	local r = self:render()
	r.config._ifunc = r.config.func --- @diagnostic disable-line
	r.config._iref = self --- @diagnostic disable-line
	r.config.func = initfunc
	return r
end

function IUI:rerender()
	local uibox = self.uibox
	if not uibox then return end
	ui.changeRoot(uibox, self:render())
	self:recalculate()
end

function IUI:recalculate(recalcself)
	if not self.uibox then return end
	if recalcself then self:recalculate() end

	local p = self.uibox.parent
	while p and p.UIBox do
		p.UIBox:recalculate()
		p = p.UIBox
	end
end

G.FUNCS[initfunc] = function (e)
	e.config.func = e.config._ifunc
	e.config._iref.uibox = e.UIBox
	e.config._iref:initRender()
	e.config._iref = nil
end

--- @alias imm.UI.MP.Base.C.X<T> p.Constructor<T, imm.UI.MP.Base.C> | fun(ses: imm.UI.MP): T
--- @alias imm.UI.MP.Base.C p.Constructor<imm.UI.MP.Base, nil> | fun(ses: imm.UI.MP): imm.UI.MP.Base
--- @type imm.UI.MP.Base.C
local UI = constructor(IUI)
return UI

