local imm = require('imm')
local util = require("imm.lib.util")

local updateConfig = false

if imm.config.nextEnable then
    local ctrl = require('imm.ctrl')
    local logger = require('imm.logger')

    local mods = util.strsplit(imm.config.nextEnable, '%s*==%s*')
    for i,entry in ipairs(mods) do
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

if not imm.config.init then
    local ctrl = require('imm.ctrl')
    local hasOtherMod = false
    for i, list in ipairs(ctrl:list()) do
        if not list:isExcluded() then
            hasOtherMod = true
            break
        end
    end
    if not hasOtherMod then
        require("imm.welcome")
    else
        imm.config.init = '1'
        updateConfig = true
    end
end

if updateConfig then
    _imm.saveconfig()
end
