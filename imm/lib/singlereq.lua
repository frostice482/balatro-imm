local constructor = require('imm.lib.constructor')
local util = require('imm.lib.util')
local co = require('imm.lib.co')

--- @class imm.SingleReq
--- @field protected set function[][]
local ISR = {}

--- @protected
function ISR:init()
	self.set = {}
end

function ISR:has(key)
	return self.set[key]
end

--- @async
function ISR:invoke(key, func, ...)
	if self.set[key] then
		return co.wrapCallbackStyle(function (res)
			return table.insert(self.set[key], res)
		end)
	end

	self.set[key] = {}
	local retc, retv = util.lenr(func(...))
	for i,v in ipairs(self.set[key]) do
		v(unpack(retv, 1, retc))
	end
	self.set[key] = nil

	return unpack(retv, 1, retc)
end

--- @alias imm.SingleReq.C p.Constructor<imm.SingleReq, nil> | fun(): imm.SingleReq
--- @type imm.SingleReq.C
local SR = constructor(ISR)

return SR
