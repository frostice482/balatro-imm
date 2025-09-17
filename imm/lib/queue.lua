local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")

--- @alias imm.Queue.Cb fun(done: fun())

--- @class imm.Queue
--- @field taskQueues imm.Queue.Cb[]
local IQueue = {}

--- @protected
--- @param max? number
function IQueue:init(max)
    self.taskQueues = {}
    self.available = max or 1
end

--- @protected
function IQueue:next()
    --- @type imm.Queue.Cb
    local f = table.remove(self.taskQueues, 1)
    if not f then return end

    self.available = self.available - 1
    local d = false
    local function done()
        if d then return end
        d = true
        self.available = self.available + 1
        self:next()
    end
    f(done)
end

--- @param func imm.Queue.Cb
function IQueue:queue(func)
    table.insert(self.taskQueues, func)
    if self.available > 0 then self:next() end
end

--- @async
--- @return fun() done
function IQueue:queueCo()
    return co.wrapCallbackStyle(function (res) self:queue(res) end)
end

--- @alias imm.Queue.C p.Constructor<imm.Queue, nil> | fun(max?: number): imm.Queue
--- @type imm.Queue.C
local Queue = constructor(IQueue)
return Queue
