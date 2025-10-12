local constructor = require("imm.lib.constructor")
local Queue = require("imm.lib.queue")
local UITaskStatusReg = require("imm.btasks.status")
local TaskDownloadCo = require("imm.btasks.download_co")
local TaskUpdateCo = require("imm.btasks.update_co")
local lovelyUrl = require('imm.lovely_downloads')
local https = require('imm.https_agent')

--- @class imm.Browser.Tasks
local IBTasks = {}

--- @protected
--- @param ses imm.UI.Browser
function IBTasks:init(ses)
    self.queues = Queue(3)
    self.ses = ses
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

    local status, content = https:requestCo(lovelyUrl) --- @diagnostic disable-line
    if status ~= 200 then
        local err = string.format("Failed downloading lovely: HTTP %d", status)
        task:error(err)
        return err
    end

    local data = love.data.newByteData(content)
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

    love.filesystem.unmount(data) --- @diagnostic disable-line
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
    return self:handleInstallResult(self.ses.ctrl:installFromZip(data))
end

---@param dir string
---@param sorucenfs boolean
function IBTasks:installModFromDir(dir, sorucenfs)
    return self:handleInstallResult(self.ses.ctrl:installFromDir(dir, sorucenfs))
end

--- @alias imm.Browser.Tasks.C p.Constructor<imm.Browser.Tasks, nil> | fun(ses: imm.UI.Browser): imm.Browser.Tasks
--- @type imm.Browser.Tasks.C
local BTasks = constructor(IBTasks)
return BTasks
