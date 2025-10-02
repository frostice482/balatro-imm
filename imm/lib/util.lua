local fs_util = require("imm.lib.util.fs")
local str_util = require("imm.lib.util.str")
local tbl_util = require("imm.lib.util.table")

--- @class imm.util: imm.Util.Fs, imm.Util.Table, imm.Util.Str
local util = {}

tbl_util.assign(util, fs_util)
tbl_util.assign(util, str_util)
tbl_util.assign(util, tbl_util)

function util.restart()
    local args = util.convertCommands({arg[-2], unpack(arg)})
    if jit.os == 'Windows' then args[1] = '"'..arg[-2]..'"' end

    local cmd = string.format(jit.os == 'Windows' and 'start /b "" %s' or '%s &', table.concat(args, ' '))
    os.execute(cmd)
    love.event.quit()
end

return util