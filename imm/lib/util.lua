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

function util.random()
    return (math.random()..""):sub(3, 12)
end

--- @param func fun(): ...
function util.sleeperTimeout(func)
    local c = 0
    local function f()
        c = c - 1
        if c == 0 then func() end
        return true
    end

    --- @param delay number
    return function (delay)
        c = c + 1
        util.delay(delay, f)
    end
end

--- @param frames number
--- @param func fun(): ...
function util.waitFrames(frames, func)
    local n = 0
    G.E_MANAGER:add_event(Event{
        blockable = false,
        blocking = false,
        no_delete = true,
        func = function ()
            n = n + 1
            if n < frames then return false end
            func()
            return true
        end
    })
end

--- @param time number
--- @param func fun(): ...
function util.delay(time, func)
    G.E_MANAGER:add_event(Event{
        blockable = false,
        blocking = false,
        trigger = 'after',
        timer = 'REAL',
        delay = time,
        func = function ()
            func()
            return true
        end
    })
end

return util