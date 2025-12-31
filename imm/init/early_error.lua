--- @diagnostic disable

local errhand_orig = love.errorhandler or love.errhand
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
        nerr = nerr or ''
        err = ok and nerr or (err..'\n\nimm failed to initialize early error handler: '..nerr)
    end
    return errhand_orig(err)
end

love.errorhandler = errHandler

assert(func, err)
local ok, err = pcall(func)

if love.errorhandler ~= errHandler then
    errhand_orig = love.errorhandler or love.errhand
    love.errorhandler = errHandler
    overridden = true
end

assert(ok, err)

local h = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons(...)
    if attached then
        attached = false
        print('Pre error detection detached')
    end
    return h(...)
end

local iok, ierr = imm.init()
if not iok then print('imm: error: ', ierr) end

