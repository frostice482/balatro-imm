local imm = require("imm")
imm.path = nil
if not __IMM_WRAP then
    local ok, err = imm.init()
    if not ok then print('imm: error: ', err) end
end
