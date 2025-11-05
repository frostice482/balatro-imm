local constructor = require("imm.lib.constructor")
local Queue = require("imm.lib.queue")
local UITaskStatusReg = require("imm.btasks.status")
local TaskDownloadCo = require("imm.btasks.download_co")
local TaskUpdateCo = require("imm.btasks.update_co")
local lovelyUrl = require('imm.lovely_downloads')
local https = require('imm.https.agent')
local imm = require("imm")

--- @class imm.Tasks
--- @field ses? imm.UI.Browser
local IBTasks = {}

--- @protected
--- @param repo? imm.Repo
--- @param modctrl? imm.ModController
function IBTasks:init(repo, modctrl)
    self.ctrl = modctrl or require('imm.ctrl')
    self.repo = repo or require('imm.repo')
    self.queues = Queue(tonumber(imm.config.concurrentTasks) or 4)
    self.status = UITaskStatusReg()
end

function IBTasks:createDownloadCoSes()
    return TaskDownloadCo(self)
end

function IBTasks:createUpdaterCoSes()
    return TaskUpdateCo(self)
end

local tmplovely = "tmp-lovely"

--- @async
--- @return string? err
function IBTasks:downloadLovelyCo()
    if not lovelyUrl then self.status:update(nil, "Cannot determine download link for Lovely") end
    local task = self.status:new()
    task:update("Downloading lovely")

    local status, data = https:requestCo(lovelyUrl, { restype = 'data' })
    if status ~= 200 then
        local err = string.format("Failed downloading lovely: HTTP %d", status)
        task:error(err)
        return err
    end

    local ok = love.filesystem.mount(data, "tmp.zip", tmplovely)
    if not ok then
        local err = string.format("Failed mounting temp folder")
        task:error(err)
        return err
    end

    local target = love.filesystem.getSourceBaseDirectory()
    for i, sub in ipairs(love.filesystem.getDirectoryItems(tmplovely)) do
        NFS.write(target..'/'..sub, love.filesystem.read(tmplovely..'/'..sub))
    end

    task:done("Installed lovely")

    local ok2 = love.filesystem.unmount(data) --- @diagnostic disable-line
    if not ok2 then
        print('Failed unmounting temp folder ' .. tmplovely)
    end
end

---@param info imm.InstallResult
function IBTasks:handleInstallResult(info)
    local strlist = {}
    for i,v in ipairs(info.installed) do table.insert(strlist, v.mod..' '..v.version) end
    local hasInstall = #strlist ~= 0

    if not hasInstall and #info.errors == 0 then table.insert(info.errors, 'Nothing is installed') end
    self.status:update(
        hasInstall and 'Installed '..table.concat(strlist, ', ') or nil,
        table.concat(info.errors, '\n')
    )

    return info
end

---@param data love.Data
function IBTasks:installModFromZip(data)
    return self:handleInstallResult(self.ctrl:installFromZip(data))
end

---@param dir string
---@param sorucenfs boolean
function IBTasks:installModFromDir(dir, sorucenfs)
    return self:handleInstallResult(self.ctrl:installFromDir(dir, sorucenfs))
end

--- @alias imm.Tasks.C p.Constructor<imm.Tasks, nil> | fun(repo?: imm.Repo, modctrl?: imm.ModController): imm.Tasks
--- @type imm.Tasks.C
local BTasks = constructor(IBTasks)
return BTasks
