--- @type love.Channel
local i = ...
local hok, https
require('love.event')
require('love.filesystem')

local emptydata = love.filesystem.newFileData("", "")

local function process(req)
    if not https then
        hok, https = pcall(require, 'https')
        if not hok then
            return { -1, "Failed to initialize https: " .. https }
        end
    end

    local res = { pcall(https.request, req.url, req.options) }
    if not res[1] then return { -162, res[2] } end

    if req.options and req.options.restype == 'data' then
        local str = res[3]
        res[3] = str and str:len() > 0 and love.data.newByteData(str) or emptydata
    end
    return {unpack(res, 2, 4)}
end

while true do
    local msg = i:demand(30)
    if not msg then break end
    local res = process(msg.req)
    love.event.push('imm_taskres', msg.gid, msg.id, res) --- @diagnostic disable-line
end
