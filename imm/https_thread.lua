--- @type love.Channel
local i = ...
local https = require('https')
require('love.event')

while true do
    local msg = i:demand()
    local res = {pcall(https.request, msg.req.url, msg.req.options)}

    love.event.push('imm_taskres', --- @diagnostic disable-line
        msg.gid,
        msg.id,
        res[1] and {unpack(res, 2, 4)} or {-1, res[2]}
    )
end