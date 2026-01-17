local imm = require("imm")

imm.initconfig()
if imm.config.handleEarlyError == 'ignore' then
    if not imm.initstatus.f then return error(imm.initstatus.ferr, 0) end
    return imm.initstatus.f()
end

local errhand_orig = love.errorhandler or love.errhand --- @diagnostic disable-line: undefined-field
local overridden = false
local attached = true

local function initx(err)
    return require("imm.init.early_error_handler")(err, overridden)
end

local function errHandler(err)
    err = type(err) == 'string' and err or tostring(err)
    if attached then
        attached = false
        local ok, nerr = pcall(initx, err)
        nerr = nerr or err
        err = ok and nerr or (err..'\n\nimm failed to initialize early error handler: '..nerr)
    end
    return errhand_orig(err)
end

love.errorhandler = errHandler

if not imm.initstatus.f then return error(imm.initstatus.ferr, 0) end
local ok, err = pcall(imm.initstatus.f)

if love.errorhandler ~= errHandler then
    errhand_orig = love.errorhandler or love.errhand --- @diagnostic disable-line: undefined-field
    love.errorhandler = errHandler
    overridden = true
end

if not ok then return error(err, 0) end

local h = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons(...)
    if attached then
        attached = false
        print('Pre error detection detached')
    end
    return h(...)
end
