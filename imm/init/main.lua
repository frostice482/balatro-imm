--- @diagnostic disable
local imm = require("imm")
imm.path = nil

if imm.initstatus.wrap then
	require("imm.init.early_error")
else
	local ok, err = imm.init()
	if not ok then print('imm: error: ', err) end
end
