local ffi = require("ffi")
local emptydata = love.filesystem.newFileData("", "")

if jit.os == "Windows" then
	--Windows!
	ffi.cdef[[
		enum {
			INVALID_SOCKET = ~0,
			SOCKET_BAD = ~0
		};
	]]
else
	--Not Windows!
	ffi.cdef[[
		typedef int socket_t;
		enum {
			SOCKET_BAD = -1
		};
	]]
end

ffi.cdef[[
struct IMM_cbinfo {
	int gid;
	int id;
};
]]

--- @type string[]
local chunks = {}
local totalsize = 0

ffi.cdef((assert(love.filesystem.read("imm/https/curl.h"))))

local progcbok, progcbfn = pcall(ffi.cast, "curl_progress_callback", function (clientp, dltotal, dlnow, ultotal, ulnow)
	local info = ffi.cast("struct IMM_cbinfo*", clientp)
	love.event.push("imm_https_progress", { info.gid, info.id, dltotal, dlnow, ultotal, ulnow }) --- @diagnostic disable-line
	return 0
end)

local cbok, cbfn = pcall(ffi.cast, "curl_write_callback", function(ptr, size, nmemb, userdata)
	local chunksize = size * nmemb
	totalsize = totalsize + tonumber(chunksize)
	table.insert(chunks, ffi.string(ptr, chunksize))
	return chunksize
end)

local temp, temph
if not cbok then
	ffi.cdef[[
		typedef struct FILE FILE;
		size_t fwrite(const void* buffer, size_t size, size_t count, FILE* stream);
		size_t fread(void* buffer, size_t size, size_t count, FILE* stream);
	]]
	local x = os.tmpname()
	print('imm/curl: Using temporary file', x)
	temp = assert(io.open(x, "w+"), 'Cannot open temporary file ' .. x)
	temph = ffi.cast("FILE*", temp)
end

local cok, curl, hok
local tries = {
	"curl",
	"XCurl",
	"curl.so.4",
}

local function cinit()
	if curl then return end
	for i,module in ipairs(tries) do
		cok, curl = pcall(ffi.load, module)
		if cok then
			hok = pcall(function() return curl.curl_easy_nextheader end)
			return
		end
		print(string.format("imm/curl failed to load %s: %s", module, curl))
	end
	curl = nil
	return false
end

local function csetopt(ez, opt, val, whatever)
	local r = curl.curl_easy_setopt(ez, curl['CURLOPT_'..opt], val)
	if not whatever and r ~= curl.CURLE_OK then
		error(string.format("failed setting curleasy opt for %s %s", opt, val))
	end
end

local function cassert(func, ez, ...)
	local err = func(ez, ...)
	if err ~= curl.CURLE_OK then
		error(string.format("curleasy error (%s): %s", tonumber(err), ffi.string(curl.curl_easy_strerror(err))))
	end
end

local function processLow(msg)
	chunks = {}
	totalsize = 0

	if not cbok then
		assert(temp:seek("set", 0))
	end

	--- @type imm.HttpsAgent.Req
	local req = msg.req
	local opts = req.options or {}

	local ez = curl.curl_easy_init()
	ffi.gc(ez, curl.curl_easy_cleanup)

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

	local outgoingHeader
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

	local progressdata = ffi.new("struct IMM_cbinfo", msg.gid, msg.id)
	if req.progress and progcbok then
		csetopt(ez, 'NOPROGRESS', 0, true)
		csetopt(ez, 'PROGRESSFUNCTION', progcbfn, true)
		csetopt(ez, 'PROGRESSDATA', progressdata, true)
	end

	if cbok then
		csetopt(ez, 'WRITEFUNCTION', cbfn)
	else
		csetopt(ez, 'WRITEDATA', temph)
		csetopt(ez, 'WRITEFUNCTION', ffi.C.fwrite)
	end

	cassert(curl.curl_easy_perform, ez)

	local statusptr = ffi.new("long[1]")
	cassert(curl.curl_easy_getinfo, ez, curl.CURLINFO_RESPONSE_CODE, statusptr)
	local status = tonumber(statusptr[0])

	local headers
	if hok then
		headers = {}
		local incomingHeader
		while true do
			local h = curl.curl_easy_nextheader(ez, 1, 0, incomingHeader)
			if h == nil then break end
			headers[ffi.string(h.name)] = ffi.string(h.value)
			incomingHeader = h
		end
	end

	curl.curl_easy_cleanup(ffi.gc(ez, nil))
	if outgoingHeader then
		curl.curl_slist_free_all(ffi.gc(outgoingHeader, nil))
	end

	local body
	if cbok then
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
	else
		temp:flush()
		local totalsize = assert(temp:seek())
		assert(temp:seek("set", 0))
		if opts.restype == 'data' then
			if totalsize > 0 then
				body = love.data.newByteData(totalsize)
				local buf = ffi.cast('char*', body:getFFIPointer())
				local read = ffi.C.fread(buf, 1, totalsize, temp)
				if read ~= totalsize then
					return error(string.format("inequal read: %s != %s", tonumber(read), totalsize))
				end
			else
				body = emptydata
			end
		else
			body = temp:read(totalsize)
		end
	end

	return { status, body, headers }
end

local o = {}

function o.process(msg)
	if cinit() == false then return { -155, "Failed initializing curl", {} } end

	local ok, data = xpcall(processLow, function (err)
		print(string.format('imm/curl: error: %s %s: %s', msg.req.method or 'GET', msg.req.url, err))
		return err
	end, msg)
	if ok then return data end
	return { -1, data }
end

function o.destroy()
	if cbok then cbfn:free() end
	if progcbok then progcbfn:free() end
	if temp then temp:close() end
end

return o