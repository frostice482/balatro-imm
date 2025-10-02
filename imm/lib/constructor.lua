--- @class p.Constructor<Proto, Super>: {
--- proto: Proto;
--- super: Super;
--- className: string;
--- extendTo: fun(constructor: self, other: table, name?: string);
--- is: fun(constructor: self, other: any): boolean;
--- }
--- @alias p.C.Default p.Constructor<any, fun(...)>

local createConstructor

local Proto = {}


function Proto:new(...)
    local proto = self.proto
    local obj = {}
    setmetatable(obj, proto)
    local init = proto.init or proto._init
    if init then init(obj, ...) end
    return obj
end

function Proto:extendTo(proto, name)
    return createConstructor(proto, self, name)
end

function Proto:is(other)
    while type(other) == "table" do
        other = getmetatable(other)
        if other == self.proto then return true end
    end
    return false
end

--- Creates a new constructor object.
--- Set prototype should contain `init` or `_init`, which first argument takes the target object that is being initialized.
--- @generic T: table
--- @generic S: p.Constructor<any, any>
--- @param proto `T`
--- @param super? `S`
--- @param classname? string
--- @return p.Constructor<T, S> | fun(...): T
createConstructor = function(proto, super, classname)
    proto.__index = proto --- @diagnostic disable-line
    if super then setmetatable(proto, super.proto) end --- @diagnostic disable-line
    local obj = {
        proto = proto,
        super = super,
        className = classname
    }
    setmetatable(obj, {
        __call = Proto.new,
        __index = Proto
    })
    return obj
end

return createConstructor
