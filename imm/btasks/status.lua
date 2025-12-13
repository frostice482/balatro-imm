local constructor = require("imm.lib.constructor")
local ui = require("imm.lib.ui")
local util = require("imm.lib.util")
local logger = require("imm.logger")

local funcs = {
    statusInit = 'imm_bt_status_link',
    statusRegInit = 'imm_bt_statusreg'
}

--- @param elm balatro.UIElement
G.FUNCS[funcs.statusInit] = function (elm)
    --- @type imm.Task.UI.Status
    local r = elm.config.ref_table
    elm.config.func = nil
    r.elm = elm

    if r.isRemoved then
        ui.removeElement(elm)
        elm.UIBox:recalculate()
    end
end

--- @param elm balatro.UIElement
G.FUNCS[funcs.statusRegInit] = function (elm)
    --- @type imm.Task.UI.Status.Reg
    local r = elm.config.ref_table
    elm.config.func = nil
    r.listElm = elm
end

--- @class imm.Task.UI.Status
--- @field containerCfg balatro.UIElement.Config
--- @field labelCfg balatro.UIElement.Config
--- @field textCfg balatro.UIElement.Config
--- @field elm? balatro.UIElement
local IUITaskStatus = {
    text = '',
    isDone = false,
    isRemoved = false
}

--- @protected
function IUITaskStatus:init()
    self.labelCfg = { colour = G.C.WHITE, minw = 0.1 }
    self.textCfg = { ref_table = self, ref_value = 'text', scale = 0.3 } --- hardcoded value!

    self.doneColor = G.C.GREEN
    self.errorColor = G.C.ORANGE
end

--- @param text string
function IUITaskStatus:update(text)
    self.text = text
end

--- @param text string
function IUITaskStatus:done(text)
    self.text = text
    self.labelCfg.colour = self.doneColor
    self.isDone = true
end

--- @param text string
function IUITaskStatus:error(text)
    self.text = text
    self.labelCfg.colour = self.errorColor
    self.isDone = true
end

--- @param format string
function IUITaskStatus:updatef(format, ...)
    self.text = format:format(...)
end

--- @param format string
function IUITaskStatus:donef(format, ...)
    self:done(format:format(...))
end

--- @param format string
function IUITaskStatus:errorf(format, ...)
    self:error(format:format(...))
end

function IUITaskStatus:render()
    self.elm = nil

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {
            colour = G.C.CLEAR,
            func = funcs.statusInit,
            ref_table = self
        },
        nodes = {
            { n = G.UIT.C, config = self.labelCfg },
            --- hardcoded value!
            ui.C{ padding = 0.05, },
            ui.C{ padding = 0.05, align = 'cm', { n = G.UIT.T, config = self.textCfg } }
        }
    }
end

--- @alias imm.Task.UI.Status.C p.Constructor<imm.Task.UI.Status, nil> | fun(): imm.Task.UI.Status
--- @type imm.Task.UI.Status.C
local UITaskStatus = constructor(IUITaskStatus)

--- @class imm.Task.UI.Status.Reg
--- @field statuses imm.Task.UI.Status[]
--- @field listElm? balatro.UIElement
local ITaskStatusReg = {}

--- @protected
function ITaskStatusReg:init()
    self.statuses = {}
end

--- @param i number
function ITaskStatusReg:remove(i)
    --- @type imm.Task.UI.Status
    local e = util.removeswap(self.statuses, i)
    if not e then error(string.format('index %d not found', i)) end

    if e.elm and not e.elm.REMOVED then ui.removeElement(e.elm) end
    e.isRemoved = true
end

--- @param status imm.Task.UI.Status
function ITaskStatusReg:add(status)
    table.insert(self.statuses, status)
    if self.listElm then
        self.listElm.UIBox:add_child(status:render(), self.listElm)
    end
end

function ITaskStatusReg:removeDone()
    local i = 1
    while i <= #self.statuses do
        local entry = self.statuses[i]
        if entry.isDone then
            self:remove(i)
            i = i - 1
        end
        i = i + 1
    end
end

--- @param noRecalc? boolean
--- @param noRemoveDone? boolean
function ITaskStatusReg:new(noRecalc, noRemoveDone)
    if not noRemoveDone then self:removeDone() end
    local status = UITaskStatus()
    self:add(status)
    if not noRecalc and self.listElm then self.listElm.UIBox:recalculate() end
    return status
end

--- @param suc? string
--- @param err? string
--- @param nolog? boolean
function ITaskStatusReg:update(suc, err, nolog)
    self:removeDone()

    if suc and suc:len() ~= 0 then
        self:new(true, true):done(suc)
        if not nolog then logger.log(suc) end
    end
    if err and err:len() ~= 0 then
        self:new(true, true):error(err)
        if not nolog then logger.err(err) end
    end

    if self.listElm then self.listElm.UIBox:recalculate() end
end

function ITaskStatusReg:render()
    local list = {}
    for i,v in ipairs(self.statuses) do table.insert(list, v:render()) end

    self.listElm = nil

    return ui.C{
        func = funcs.statusRegInit,
        ref_table = self,
        nodes = list,
        insta_func = true
    }
end

--- @alias imm.Task.UI.Status.Reg.C p.Constructor<imm.Task.UI.Status.Reg, nil> | fun(): imm.Task.UI.Status.Reg
--- @type imm.Task.UI.Status.Reg.C
local UITaskStatusReg = constructor(ITaskStatusReg)
return UITaskStatusReg