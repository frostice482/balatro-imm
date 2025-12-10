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

--- @generic A, B
--- @param t { [A]: B }
--- @param sort? fun(ka: A, va: B, kb: A, vb: B): boolean>
--- @return [A, B][]
function util.entries(t, sort)
    local list = {}
    for k,v in pairs(t) do table.insert(list, { k, v }) end
    if sort then table.sort(list, function (a, b) return sort(a[1], a[2], b[1], b[2]) end) end
    return list
end

local function ca(a, b) return a < b end
local function cb(a, b) return a > b end

--- @generic A
--- @param t { [A]: any }
--- @param sort? boolean | fun(ka: A, kb: A): boolean>  If true, sorts lowest to highest. If false, sorts highest to lowest.
--- @return A[]
function util.keys(t, sort)
    local list = {}
    for k,v in pairs(t) do table.insert(list, k) end
    if sort then table.sort(list, sort == true and ca or sort == false and cb or sort) end --- @diagnostic disable-line
    return list
end

--- @generic A
--- @param t { [any]: A }
--- @param sort? boolean | fun(va: A, vb: A): boolean>  If true, sorts lowest to highest. If false, sorts highest to lowest.
--- @return A[]
function util.values(t, sort)
    local list = {}
    for k,v in pairs(t) do table.insert(list, v) end
    if sort then table.sort(list, sort == true and ca or sort == false and cb or sort) end --- @diagnostic disable-line
    return list
end

function util.insertBatch(to, source)
    for i,v in ipairs(source) do table.insert(to, v) end
end

return util