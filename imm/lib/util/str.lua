--- @class imm.Util.Str
local util = {}

--- Splits string with specified pattern
--- @param string string String
--- @param pattern string Split pattern
--- @param plain? boolean
--- @param max? number
--- @return string[] list
function util.strsplit(string, pattern, plain, max)
    max = max or 0x7fffffff
    max = max - 1
    local list = {}
    local off = 1
    local strlen = #string

    while off <= strlen and #list < max do
        local a, b = string:find(pattern, off, plain)
        if not a or not b then break end

        table.insert(list, string:sub(off, a-1))
        off = b+1
    end

    table.insert(list, string:sub(off))
    return list
end

--- @param arg string
function util.sanitizename(arg)
    return arg:gsub('[<>:"/\\|?*]', function(f) return string.format('_%x', f:byte(1)) end)
end

--- @param str string
--- @param check string
function util.endswith(str, check)
    return str:sub(-check:len(), -1) == check
end

--- @param str string
--- @param check string
function util.startswith(str, check)
    return str:sub(1, check:len()) == check
end

--- @param str string
--- @return string dirname
--- @return string filename
function util.dirname(str)
    local prev
    while true do
        local a, b = str:find('/', (prev or 0) + 1, true)
        if not b then break end
        prev = b
    end
    if not prev then return '', str end
    return str:sub(1, prev-1), str:sub(prev+1)
end

--- @param filename string
--- @return string basename
--- @return string extname Includes dots
function util.filename(filename)
    local prev
    while true do
        local a, b = filename:find('.', (prev or 0) + 1, true)
        if not b then break end
        prev = b
    end
    if not prev then return filename, '' end
    return filename:sub(1, prev-1), filename:sub(prev)
end

--- @param str string
function util.trim(str)
    return str:match("^%s*(.-)%s*$") or str
end

--- @param args string[]
function util.convertCommands(args, platform)
    platform = platform or jit.os
    --- @type string[]
    local converted = {}
    if platform == 'Windows' then
        for i, arg in ipairs(args) do
            converted[i] = arg:gsub('[&|^<>()% \n\t\v\f]', function (m) return '^'..m end)
        end
    else
        for i, arg in ipairs(args) do
            converted[i] = "'"..arg:gsub("'", "'\\''").."'"
        end
    end
    return converted
end

return util