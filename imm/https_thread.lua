--- @type love.Channel
local i = ...
local hok, https
require('love.event')

local function process(req)
    if not https then
        hok, https = pcall(require, 'https')
        if not hok then
            return { -1, "Failed to initialize https: " .. https }
        end
    end

    local res = { pcall(https.request, req.url, req.options) }
    return res[1] and {unpack(res, 2, 4)} or {-1, res[2]}
end

while true do
    local msg = i:demand()
    local res = process(msg.req)
    love.event.push('imm_taskres', msg.gid, msg.id, res) --- @diagnostic disable-line
end