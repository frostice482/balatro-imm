local constructor = require("imm.lib.constructor")
local co = require("imm.lib.co")
local util = require("imm.lib.util")

local gid = 0
--- @type table<number, imm.ThreadWorker>
local registry = {}
setmetatable(registry, { __mode = 'v' })

--- @class imm.ThreadWorker<Req, Res>: {
---     runTask: fun(self: self, req: Req, res: fun(res: Res) ): number;
---     runTaskCo: fun(self: self, req: Req ): Res;
--- }
--- @field pendings table<number, { req: any, res: fun(res) }>
--- @field threadcode love.FileData
--- @field threads love.Thread[]
local ITasks = {
    allocated = 0,
    pendingCount = 0,
    nextId = 1,
    autoRecountThreads = false
}

--- @protected
--- @param threadcode love.FileData
--- @param max? number
function ITasks:init(threadcode, max)
    gid = gid + 1
    self.threadcode = threadcode
    self.threads = {}
    self.pendings = {}
    self.gid = gid
    self.maxConcurrency = max or love.system.getProcessorCount()
    self.input = love.thread.newChannel()
    registry[gid] = self
end

--- @param thread love.Thread
--- @return ...
function ITasks:handleSpawnAdditionalParams(thread) end

--- @param force? boolean
function ITasks:spawn(force)
    if not (force or self.pendingCount > self.allocated and self.allocated < self.maxConcurrency) then
        return
    end

    self.allocated = self.allocated + 1
    local thr = love.thread.newThread(self.threadcode)
    thr:start(self.input, self:handleSpawnAdditionalParams(thr))
    table.insert(self.threads, thr)
    return thr
end

--- @param id number
--- @param res any
function ITasks:handleRes(id, res)
    local cb = self.pendings[id]
    if not cb then return end
    self.pendingCount = self.pendingCount - 1
    self.pendings[id] = nil
    cb.res(res)
end

function ITasks:recountThreads()
    local i = 1
    while i <= #self.threads do
        local thr = self.threads[i]
        if not thr:isRunning() then
            self.allocated = self.allocated - 1
            util.removeswap(self.threads, i)
        else
            i = i + 1
        end
    end
end

--- @type imm.ThreadWorker<any, any>
local _ITasks = ITasks

function _ITasks:runTask(req, cb)
    self.pendingCount = self.pendingCount + 1
    self.nextId = self.nextId + 1
    self.input:push({ gid = self.gid, id = self.nextId, req = req })
    self.pendings[self.nextId] = { req = req, res = cb }

    if self.autoRecountThreads then
        self:recountThreads()
    end

    self:spawn()

    return self.nextId
end

--- @async
function _ITasks:runTaskCo(req)
    return co.wrapCallbackStyle(function (res) self:runTask(req, res) end)
end

--- @diagnostic disable-next-line
function love.handlers.imm_taskres(gid, id, res)
    local taskReg = registry[gid]
    if not taskReg then return end
    taskReg:handleRes(id, res)
end

--- @alias imm.ThreadWorker.C p.Constructor<imm.ThreadWorker<any, any>, nil> | fun(threadcode: love.FileData, max?: number): imm.ThreadWorker<any, any>
--- @type imm.ThreadWorker.C
local Tasks = constructor(ITasks)
return Tasks