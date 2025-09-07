local constructor = require("imm.lib.constructor")

local gid = 0
--- @type table<number, imm.Tasks>
local registry = {}
setmetatable(registry, { __mode = 'v' })

--- @class imm.Tasks<Req, Res>: {
---     runTask: fun(self: self, req: Req, res: fun(res: Res) ): number;
--- }
--- @field threadcode love.FileData
--- @field threads love.Thread[]
--- @field pendings table<number, fun(res: any)>
local ITasks = {
    allocated = 0,
    pendingCount = 0,
    nextId = 1
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

function ITasks:spawn()
    self.allocated = self.allocated + 1
    local thr = love.thread.newThread(self.threadcode)
    thr:start(self.input, self:handleSpawnAdditionalParams(thr))
    table.insert(self.threads, thr)
    return thr
end

--- @param id string
--- @param res any
function ITasks:handleRes(id, res)
    local cb = self.pendings[id]
    if not cb then return end
    self.pendingCount = self.pendingCount - 1
    self.pendings[id] = nil
    cb(res)
end

local _ITasks = ITasks

--- @param req any
--- @param cb fun(res: any)
--- @diagnostic disable-next-line
function _ITasks:runTask(req, cb)
    self.pendingCount = self.pendingCount + 1
    self.nextId = self.nextId + 1
    self.input:push({ gid = self.gid, id = self.nextId, req = req })
    self.pendings[self.nextId] = cb

    if self.pendingCount > self.allocated and self.allocated < self.maxConcurrency then
        self:spawn()
    end

    return self.nextId
end

--- @diagnostic disable-next-line
function love.handlers.imm_taskres(gid, id, res)
    local taskReg = registry[gid]
    if not taskReg then return end
    taskReg:handleRes(id, res)
end

--- @alias imm.Tasks.C p.Constructor<imm.Tasks<any, any>, nil> | fun(threadcode: love.FileData, max?: number): imm.Tasks<any, any>
--- @type imm.Tasks.C
local Tasks = constructor(ITasks)
return Tasks