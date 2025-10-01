local base_elevel = 3
local a = {}

function a.typeError(expected, varname, t)
    return string.format(
        "Expected type %s for %s, got %s",
        type(expected) == "string" and expected or table.concat(expected, ' | '),
        varname,
        t
    )
end

--- @param var any
--- @param expected type | type[]
--- @vararg type
function a.typeMatches(var, expected)
    local t = type(var)

    if type(expected) == "string" then
        if expected == t then
            return t
        end
    else
        for i, v in ipairs(expected) do
            if t == v then
                return t
            end
        end
    end
end

--- @param var any
--- @param varname string
--- @param expected type | type[]
--- @param elevel? number
--- @vararg type
function a.type(var, varname, expected, elevel)
    local t = a.typeMatches(var, expected)
    if t then return t end
    error(a.typeError(expected, varname, type(var)), elevel)
end

--- @param var table
--- @param obj table
--- @param name string
--- @param vname? string
--- @param elevel? number
function a.instance(var, obj, name, vname, elevel)
    local mt = getmetatable(var)
    while mt do
        if mt == obj then return mt end
        mt = getmetatable(mt)
    end
    error(string.format("%s is expected to be an instance of %s", vname or "self", name), elevel or base_elevel)
end

--- @param var string
--- @param varname string
--- @param enums string[]
--- @param elevel? number
--- @vararg string
function a.enum(var, varname, enums, elevel)
    if type(var) ~= "string" then
        error(string.format("Expected type string for %s, got %s", varname, type(var)), elevel or base_elevel)
    end

    for i, v in ipairs(enums) do
        if var == v then
            return v
        end
    end

    error(string.format("Expected enum %s for %s, got %s", table.concat(enums, ' | '), varname, var), elevel or base_elevel)
end

return a