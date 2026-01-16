--- @type love.Channel
local i = ...
require('love.event')
require('love.filesystem')

local modules = {}
table.insert(modules, 'https')
table.insert(modules, jit.os == 'Windows' and 'winhttp' or nil)
table.insert(modules, 'curl')

local ok, o
for i,v in ipairs(modules) do
    ok, o = pcall(require, 'imm.https.'..v)
    if ok then break end
    print(string.format('imm/https: failed loading module %s: %s', v, o))
end

while true do
    local msg = i:demand(30)
    if not msg then break end

    if not ok then return { -157, "", {} } end

    local pok, res = xpcall(o.process, function(err)
        local req = msg.req
        print(string.format("imm/https: error: %s %s: %s", req.options and req.options.method or 'GET', req.url, debug.traceback(err)))
        return err
    end, msg)

    if not pok then res = { -1, res } end

    love.event.push('imm_taskres', msg.gid, msg.id, res) --- @diagnostic disable-line
end

if ok then o.destroy() end