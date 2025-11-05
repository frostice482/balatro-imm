--- @type love.Channel, love.FileData
local i, curlh, forcecurl = ...
require('love.event')
require('love.filesystem')
local emptydata = love.filesystem.newFileData("", "")

local hok, https
if not forcecurl then hok, https = pcall(require, 'https') end

local process
if hok then
    function process(req)
        local res = { pcall(https.request, req.url, req.options) }
        if not res[1] then
            print('imm/https: request failed:', res[2])
            return { -1, res[2] }
        end

        if req.options and req.options.restype == 'data' then
            local str = res[3]
            res[3] = str and str:len() > 0 and love.data.newByteData(str) or emptydata
        end
        return {unpack(res, 2, 4)}
    end
else
    local ffi = require("ffi")
    local cok, curl
    ffi.cdef(curlh:getString())

    if jit.os == "Windows" then
        --Windows!
        ffi.cdef([[
            enum {
                INVALID_SOCKET = ~0,
                SOCKET_BAD = ~0
            };
        ]])
    else
        --Not Windows!
        ffi.cdef([[
            typedef int socket_t;
            enum {
                SOCKET_BAD = -1
            };
        ]])
    end

    local function cinit()
        if curl then return end
        cok, curl = pcall(ffi.load, "curl")
        if cok then return end
        curl = nil
        return false
    end

    local function csetopt(ez, opt, val)
        local r = curl.curl_easy_setopt(ez, curl['CURLOPT_'..opt], val)
        if r ~= curl.CURLE_OK then
            error(string.format("failed setting curleasy opt for %s %s", opt, val))
        end
    end

    local function cassert(func, ez, ...)
        local err = func(ez, ...)
		if err ~= curl.CURLE_OK then
            error(string.format("curleasy error (%s): %s", tonumber(err), ffi.string(curl.curl_easy_strerror(err))))
		end
    end

    local CURLH_HEADER = 1

    local function processLow(req)
        local ez = curl.curl_easy_init()
        local outgoingHeader
        ffi.gc(ez, curl.curl_easy_cleanup)

        local opts = req.options or {}
        csetopt(ez, 'URL', req.url)

        if opts.method then
            if opts.method == "HEAD" then
                csetopt(ez, 'NOBODY', 1)
            elseif opts.method == "POST" then
                csetopt(ez, 'POST', 1)
            else
                csetopt(ez, 'CUSTOMREQUEST', opts.method)
            end
        end

        if opts.data then
            csetopt(ez, 'POSTFIELDS', opts.data)
            csetopt(ez, 'POSTFIELDSIZE_LARGE', opts.data:len())
        end

        if opts.headers then
            for k,v in pairs(opts.headers) do
                local entry = string.format("%s: %s", k, v)
                local nl = curl.curl_slist_append(outgoingHeader, entry)
                if not nl then error("failed appending header " .. entry) end

                if outgoingHeader then ffi.gc(outgoingHeader, nil) end
                outgoingHeader = nl
                ffi.gc(nl, curl.curl_slist_free_all)
            end
			csetopt(ez, 'HTTPHEADER', outgoingHeader)
        end

        --- @type string[]
        local chunks = {}
        local totalsize = 0
		local cb = ffi.cast("curl_write_callback", function(ptr, size, nmemb, userdata)
			local chunksize = size * nmemb
            totalsize = totalsize + tonumber(chunksize)
			table.insert(chunks, ffi.string(ptr, chunksize))
			return chunksize
		end)
        csetopt(ez, 'WRITEFUNCTION', cb)

		cassert(curl.curl_easy_perform, ez)

        local statusptr = ffi.new("long[1]")
		cassert(curl.curl_easy_getinfo, ez, curl.CURLINFO_RESPONSE_CODE, statusptr)
        local status = tonumber(statusptr[0])

        local headers = {}
		local incomingHeader
		while true do
			local h = curl.curl_easy_nextheader(ez, CURLH_HEADER, 0, incomingHeader)
			if h == nil then break end
			headers[ffi.string(h.name)] = ffi.string(h.value)
			incomingHeader = h
		end

        curl.curl_easy_cleanup(ffi.gc(ez, nil))
        if outgoingHeader then
            curl.curl_slist_free_all(ffi.gc(outgoingHeader, nil))
        end

        local body
        if opts.restype == 'data' then
            if totalsize > 0 then
                body = love.data.newByteData(totalsize)
                local off = ffi.cast('char*', body:getFFIPointer())
                for i, chunk in ipairs(chunks) do
                    local len = chunk:len()
                    ffi.copy(off, chunk, len)
                    off = off + len
                end
            else
                body = emptydata
            end
        else
            body = table.concat(chunks)
        end

        return { status, body, headers }
    end

    function process(req)
        if cinit() == false then return { -155, "Failed initializing curl", {} } end
        local ok, data = xpcall(processLow, function (err)
            print('imm/curl: error:', err)
            print(debug.traceback())
            return err
        end, req)
        if ok then return data end
        return { -1, data }
    end
end

while true do
    local msg = i:demand(30)
    if not msg then break end
    local res = process(msg.req)
    love.event.push('imm_taskres', msg.gid, msg.id, res) --- @diagnostic disable-line
end
