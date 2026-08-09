local imm = require('imm')
local util = require("imm.lib.util")

local updateConfig = false

if imm.config.nextEnable then
    local ctrl = require('imm.ctrl')
    local logger = require('imm.logger')

    for i,entry in util.splitentries(imm.config.nextEnable, '%s*==%s*') do
        local mod, ver = entry:match('^([^=]+)=(.*)')
        if mod and ver then
            local ok, err = ctrl:enable(mod, ver)
            if ok then logger.log('Postenabled:', mod, ver)
            else logger.err('Postenable failed:', err or '?') end
        else
            logger.fmt('invalid nextEnable entry "%s"', entry)
        end
    end

    imm.config.nextEnable = nil
    updateConfig = true
end

if updateConfig then
    imm.saveconfig()
end
