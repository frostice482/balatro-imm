local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")

--- @class imm.Queue
--- @field taskQueues fun()[]
local IQueue = {}

--- @protected
function IQueue:init()
    self.taskQueues = {}
    self.taskDone = true
end

function IQueue:next()
    self.taskDone = true
    local f = table.remove(self.taskQueues, 1)
    if not f then return end
    self.taskDone = false
    f()
end

--- @param func fun()
function IQueue:queue(func)
    table.insert(self.taskQueues, func)
    if self.taskDone then self:next() end
end

function IQueue:queueCo()
    co.wrapCallbackStyle(function (res)
        if self.taskDone then
            self.taskDone = false
            res()
            return
        end
        table.insert(self.taskQueues, res)
    end)
end

--- @alias imm.Queue.C p.Constructor<imm.Queue> | fun(): imm.Queue
--- @type imm.Queue.C
local Queue = constructor(IQueue)
return Queue
