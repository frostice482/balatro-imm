local Tasks = require("imm.lib.threadworker")
local imm = require("imm")
local threadcode = assert(love.filesystem.newFileData('imm/afs/thread.lua'))

--- @class _imm.AfsWorker.SharedThread
--- @field input love.Channel
--- @field header love.FileData
--- @field nfscode love.FileData

--- @class _imm.AfsWorker.SharedData: ffi.cdata*
--- @field id number;
--- @field gid number;
--- @field remaining number;
--- @field abort boolean;

--- @class _imm.AfsAgent.CpOpts
--- @field srcNfs? boolean
--- @field destNfs? boolean
--- @field fast? boolean

--- @class imm.AfsAgent
local agent = {
    --- @type imm.ThreadWorker<any, any>
    task = Tasks(threadcode, tonumber(imm.config) or 3) --- @diagnostic disable-line
}
agent.task.autoRecountThreads = true

--- @protected
function agent.spawn()
    agent.task:recountThreads()
    for i=agent.task.allocated, 2, 1 do
        agent.task:spawn(true)
    end
end

--- @protected
--- @type _imm.AfsWorker.SharedThread
agent.shareinput = {
    input = love.thread.newChannel(),
    header = assert(love.filesystem.newFileData('imm/afs/afs.h')),
    nfscode = assert(love.filesystem.newFileData('imm/include/nativefs.lua')),
}

function agent.task:handleSpawnAdditionalParams(thread)
    return agent.shareinput
end

local tmp = 0

--- @param src string
--- @param dest string
--- @param opts? _imm.AfsAgent.CpOpts
--- @param cb fun(ok: boolean, err?: string)
function agent.cp(src, dest, cb, opts)
    agent.spawn()
    opts = opts or {}

    local org
    if opts.srcNfs then
        local tmpmnt = '__afs_tmp' .. tmp
        tmp = tmp + 1
        if not NFS.mount(src, tmpmnt) then
            return cb(false, string.format('Failed mounting %s to %s', src, tmpmnt))
        end
        org = src
        src = tmpmnt
        local f = cb
        function cb(...)
            assert(NFS.unmount(org))
            return f(...)
        end
    end

    return agent.task:runTask({
        command = 'cp',
        org = org,
        src = src,
        dest = dest,
        opts = opts
    }, cb)
end

return agent
