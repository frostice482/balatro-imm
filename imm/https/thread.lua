--- @type love.Channel
local i, forcecurl = ...
require('love.event')
require('love.filesystem')

local ok, o
if not forcecurl then
    ok, o = pcall(require, 'imm.https.https')
end
if not ok then
    print('imm: https error: ', o)
    ok, o = pcall(require, 'imm.https.curl')
end
if not ok then
    print('imm: curl error: ', o)
end

while true do
    local msg = i:demand(30)
    if not msg then break end

    local res = ok and o.process(msg) or { -157, "", {} }
    love.event.push('imm_taskres', msg.gid, msg.id, res) --- @diagnostic disable-line
end

if ok then o.destroy() end