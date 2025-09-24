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
function util.dirname(str)
    local prev
    while true do
        local a, b = str:find('/', (prev or 0) + 1, true)
        if not b then break end
        prev = b
    end
    return prev and str:sub(1, prev-1) or ''
end

--- @param source string
--- @param target string
--- @param sourceNfs boolean
--- @param targetNfs boolean
--- @param excludes? fun(source: string, target: string): boolean?
function util.cpdir(source, target, sourceNfs, targetNfs, excludes)
    local sourceProv = sourceNfs and NFS or love.filesystem
    local targetProv = targetNfs and NFS or love.filesystem

    if excludes and excludes(source, target) then return end

    local stat = sourceProv.getInfo(source)
    if not stat then error(string.format('stat %s returned undefined', source)) end

    if stat.type == 'file' then
        assert(targetProv.write(target,
            assert(sourceProv.read(source))
        ))
    elseif stat.type == 'directory' then
        assert(targetProv.createDirectory(target))
        local items = sourceProv.getDirectoryItems(source)
        for i, item in ipairs(items) do
            util.cpdir(source..'/'..item, target..'/'..item, sourceNfs, targetNfs, excludes)
        end
    end
end

--- @param path string
--- @param isNfs boolean
function util.rmdir(path, isNfs)
    local prov = isNfs and NFS or love.filesystem
    local items = prov.getDirectoryItems(path)

    for i, item in ipairs(items) do
        local ok = util.rmdir(path .. '/' .. item, isNfs)
        if not ok then return ok end
    end
    return prov.remove(path)
end

--- @param str string
function util.trim(str)
    return str:match("^%s*(.-)%s*$") or str
end

--- @generic T: any[]
--- @param list `T`
--- @param startPos number
--- @param endPos number
--- @return T
function util.slice(list, startPos, endPos)
    local o = {}
    for i = startPos, endPos, 1 do o[i-startPos+1] = list[i] end
    return o
end

--- @generic T: any[]
--- @param list `T`
--- @param pos number
--- @return T
function util.removeswap(list, pos)
    local v = list[pos]
    list[pos] = list[#list]
    list[#list] = nil
    return v
end

--- @generic T
--- @param list { [number]: T }
--- @param rowLen number
--- @return T[][]
function util.grid(list, rowLen)
    local r = {}
    local cur = {}
    for i,v in ipairs(list) do
        table.insert(cur, v)
        if #cur >= rowLen then
            table.insert(r, cur)
            cur = {}
        end
    end
    if #cur ~= 0 then
        table.insert(r, cur)
    end
    return r
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

function util.restart()
    local args = util.convertCommands({arg[-2], unpack(arg)})
    if jit.os == 'Windows' then args[1] = '"'..arg[-2]..'"' end

    local cmd = string.format(jit.os == 'Windows' and 'start /b "" %s' or '%s &', table.concat(args, ' '))
    os.execute(cmd)
    love.event.quit()
end

function util.saveconfig()
    local m = require('imm.config')

    local entries = {}
    for k,v in pairs(m.config) do table.insert(entries, k..' = '..v) end
    table.sort(entries, function (a, b) return a < b end)

    love.filesystem.createDirectory(util.dirname(m.configFile))
    love.filesystem.write(m.configFile, table.concat(entries, '\n'))
end

return util