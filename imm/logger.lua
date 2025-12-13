local imm = require("imm")

local logger = {}

function logger.format(...)
    local list = {...}
    local li = 0
    for i, v in ipairs(list) do
        li = i
        list[i] = type(v) == 'string' and v or tostring(v)
    end
    return table.concat(list, ' ', 1, li)
end

function logger.output(level, ...)
    if level == "debug" and not imm.config.debug then return end
    print(string.format('imm: %s: %s', level, logger.format(...)))
end

function logger.fmt(level, format, ...)
    if level == "debug" and not imm.config.debug then return end
    print(string.format('imm: %s: %s', level, format:format(...)))
end

function logger.log(...) return logger.output('log', ...) end
function logger.warn(...) return logger.output('warn', ...) end
function logger.err(...) return logger.output('error', ...) end
function logger.dbg(...) return logger.output('debug', ...) end

return logger
