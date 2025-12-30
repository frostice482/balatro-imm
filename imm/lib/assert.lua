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
    if not expected then return t end

    if type(expected) == "string" then
        if expected == t then
            return t
        end
    else
        if #expected == 0 then return t end
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

--- @param var any
--- @param obj any
--- @param name? string
--- @param vname? string
--- @param elevel? number
function a.instance(var, obj, name, vname, elevel)
    local mt = getmetatable(var)
    while mt do
        if mt == obj then return mt end
        mt = getmetatable(mt)
    end
    error(string.format("%s is expected to be an instance of %s", vname or "self", obj.classname or name or '?'), elevel or base_elevel)
end

--- @param var string
--- @param varname string
--- @param enums string[] | number[]
--- @param elevel? number
--- @vararg string
function a.enum(var, varname, enums, elevel)
    local t = type(var)
    if t ~= "string" and t ~= 'number' then
        error(string.format("Expected type string for %s, got %s", varname, t), elevel or base_elevel)
    end

    for i, v in ipairs(enums) do
        if var == v then
            return v
        end
    end

    error(string.format("Expected enum %s for %s, got %s", table.concat(enums, ' | '), varname, var), elevel or base_elevel)
end

--- @alias p.Assert.Schema.Func<T> fun(obj: T, varname: string, level: number): string?

--- @class p.Assert.Schema
--- @field type? type | type[]
--- @field props? table<any, p.Assert.Schema> For tables
--- @field restProps? false | p.Assert.Schema For tables
--- @field isArray? boolean For tables
--- @field instance? any For tables
--- @field instancename? string For tables
--- @field pattern? string For strings
--- @field enum? string[] | number[] For strings
--- @field on? p.Assert.Schema.Func<any>

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
        if schema.pattern then
            if not string.find(var, schema.pattern) then
                error(string.format('Variable %s with value %s does not satisfy pattern %s', varname, var, schema.pattern))
            end
        end
    elseif t == 'number' then
        if schema.enum then
            a.enum(var, varname, schema.enum, elevel)
        end
    elseif t == 'table' then
        if schema.instance then
            a.instance(var, schema.instance, schema.instancename, varname, elevel)
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
    if schema.on then
        local err = schema.on(var, varname, elevel+1)
        if err then error(string.format('%s: %s', varname, err), elevel - 1) end
    end
end

--- @class p.Assert.MethodSchemaArg: p.Assert.Schema
--- @field name? string

--- @class p.Assert.MethodSchema
--- @field [number] p.Assert.MethodSchemaArg
--- @field level? number
--- @field noSelf? boolean
--- @field maxArg? number

--- @class p.Assert.ObjectSchema
--- @field props table<string, p.Assert.MethodSchema>
--- @field classname? string

--- @param obj table
--- @param objschema p.Assert.ObjectSchema
--- @param args any[]
--- @param schema p.Assert.MethodSchema
function a.classObjectMethod(obj, objschema, args, schema)
    local elevel = schema.level or base_elevel
    elevel = elevel + 1

    local argc = 0
    for k,v in pairs(args) do argc = math.max(argc, k) end

    if argc > schema.maxArg then
        error(string.format('Too many arguments passed (%d/%d)', argc, schema.maxArg), elevel)
    end

    local pos = 1
    if not schema.noSelf then
        a.instance(args[pos], obj, objschema.classname, nil, elevel+1)
        pos = pos + 1
    end

    for i, argschema in ipairs(schema) do
        a.schema(args[pos], argschema.name, argschema, elevel+1)
        pos = pos + 1
    end
end

--- @param obj any
--- @param objschema p.Assert.ObjectSchema
function a.classObjectHook(obj, objschema)
    for k, schema in pairs(objschema.props) do
        schema.maxArg = schema.maxArg or #schema
        if not schema.noSelf then
            schema.maxArg = schema.maxArg + 1
        end
        for i,argschema in ipairs(schema) do
            argschema.name = string.format('#%d: %s', i, argschema.name or 'arg')
        end

        local hook = obj[k]
        obj[k] = function (...)
            a.classObjectMethod(obj, objschema, {...}, schema)
            return hook(...)
        end
    end
end

return a