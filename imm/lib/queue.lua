local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")

--- @class imm.Queue
--- @field taskQueues fun()[]
local IQueue = {}

--- @protected
--- @param max? number
function IQueue:init(max)
    self.taskQueues = {}
    self.available = max or 1
end

function IQueue:next()
    self.available = self.available + 1
    local f = table.remove(self.taskQueues, 1)
    if not f then return end
    self.available = self.available - 1
    f()
end

--- @param func fun()
function IQueue:queue(func)
    table.insert(self.taskQueues, func)
    if self.available > 0 then self:next() end
end

function IQueue:queueCo()
    co.wrapCallbackStyle(function (res) self:queue(res) end)
end

--- @alias imm.Queue.C p.Constructor<imm.Queue, nil> | fun(max?: number): imm.Queue
--- @type imm.Queue.C
local Queue = constructor(IQueue)
return Queue
