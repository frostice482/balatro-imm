--- @class imm.Util.Table
local util = {}

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

function util.assign(dest, src)
    for k,v in pairs(src) do
        dest[k] = v
    end
end

return util