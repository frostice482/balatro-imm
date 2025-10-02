local coutil = {}

--- @param init fun(res: fun(...))
function coutil.wrapCallbackStyle(init)
    local co = coroutine.running()
    if not co then error('Not in coroutine') end

    local isWaiting = false
    local earlyRet
    init(function (...)
        if not isWaiting then
            earlyRet = {...}
        else
            assert(coroutine.resume(co, ...))
        end
    end)
    if earlyRet then return unpack(earlyRet) end

    isWaiting = true
    return coroutine.yield()
end

--- @param init fun(res: fun(...))
function coutil.unwrap(init)
    local co = coroutine.running()
    if not co then error('Not in coroutine') end

    local isWaiting = false
    local earlyRet
    init(function (...)
        if not isWaiting then
            earlyRet = {...}
        else
            assert(coroutine.resume(co, ...))
        end
    end)
    if earlyRet then return unpack(earlyRet) end

    isWaiting = true
    return coroutine.yield()
end

--- @param func function
function coutil.create(func, ...)
    local obj = {...}
    local co = coroutine.create(function() return func(unpack(obj)) end)
    assert(coroutine.resume(co))
    return co
end

--- @param list fun()[]
function coutil.all(list)
    local co = coroutine.running()
    if not co then error('Not in coroutine') end

    local returns = {}
    local remainings = #list
    local isWaiting = false

    for i,func in ipairs(list) do
        coutil.create(function ()
            local ret = func()
            returns[i] = ret
            remainings = remainings - 1
            if remainings == 0 and isWaiting then assert(coroutine.resume(co, returns)) end
        end)
    end

    if remainings == 0 then return returns end

    isWaiting = true
    return coroutine.yield()
end

function coutil.waitFrames(frames)
    local co = coroutine.running()
    if not co then error('Not in coroutine') end

    local n = 0
    G.E_MANAGER:add_event(Event{
        blockable = false,
        blocking = false,
        no_delete = true,
        func = function ()
            n = n + 1
            if n < frames then return false end
            assert(coroutine.resume(co))
            return true
        end
    })

    coroutine.yield()
end

return coutil