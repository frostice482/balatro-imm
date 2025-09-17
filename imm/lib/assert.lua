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


--- @class p.Assert.Schema
--- @field type type | type[]
--- @field props? table<any, p.Assert.Schema> For tables
--- @field restProps? p.Assert.Schema For tables
--- @field isArray? boolean For tables
--- @field instance? table For tables
--- @field instancename? string For tables
--- @field enum? string[] For strings

--- @param var any
--- @param varname string
--- @param schema p.Assert.Schema
--- @param elevel? number
function a.schema(var, varname, schema, elevel)
    elevel = elevel or base_elevel
    elevel = elevel + 1

    local t = a.type(var, varname, schema.type, elevel)
    if t == 'string' then
        if schema.enum then
            a.enum(var, varname, schema.enum, elevel)
        end
    elseif t == 'table' then
        if schema.instance then
            a.instance(var, schema.instance, varname, schema.instancename, elevel)
        end
        local already = {}
        if schema.restProps then
            for k,v in pairs(var) do
                if schema.isArray and type(k) ~= 'number' then
                    error(string.format('Variable %s is an array type and cannot contain keys other than number: %s', varname, tostring(k)), elevel - 1)
                end
                if schema.props then
                    already[k] = true
                end
                a.schema(v, varname..'.'..tostring(k), schema.props and schema.props[k] or schema.restProps, elevel) --- @diagnostic disable-line
            end
        end
        if schema.props then
            for k, subschema in pairs(schema.props) do
                if not already[k] then
                    a.schema(var[k], varname..'.'..tostring(k), subschema, elevel)
                end
            end
        end
    end
end

return a