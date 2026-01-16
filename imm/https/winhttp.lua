local ffi = require("ffi")
local sutil = require("imm.lib.util.str")
local emptydata = love.filesystem.newFileData("", "")

--- @class imm.winhttp.Url: ffi.cdata*
--- @field StructSize ffi.cdata*
--- @field nScheme number
--- @field nPort number
---
--- @field Scheme ffi.cdata*
--- @field SchemeLength number
--- @field HostName ffi.cdata*
--- @field HostNameLength number
--- @field UserName ffi.cdata*
--- @field UserNameLength number
--- @field Password ffi.cdata*
--- @field PasswordLength number
--- @field UrlPath ffi.cdata*
--- @field UrlPathLength number
--- @field ExtraInfo ffi.cdata*
--- @field ExtraInfoLength number

ffi.cdef((assert(love.filesystem.read("imm/https/winhttp.h"))))

local C = ffi.load("winhttp")
local K = ffi.load("kernel32.dll")

local constants = {
	ACCESS_TYPE_DEFAULT_PROXY = 0,
	INTERNET_SCHEME_HTTP = 1,
	INTERNET_SCHEME_HTTPS = 2,
	FORMAT_MESSAGE_FROM_SYSTEM = 0x1000,
	FORMAT_MESSAGE_IGNORE_INSERTS = 0x200,
	FLAG_SECURE = 0x800000,
	WINHTTP_QUERY_RAW_HEADERS_CRLF = 22,
}

local function W(str)
    local len = ffi.C.mbstowcs(nil, str, 0)
    if len == 0 then error("Conversion failed") end

    local wstr = ffi.new("wchar_t[?]", len+1)
    ffi.C.mbstowcs(wstr, str, len+1)
    return wstr, len
end

local function A(wstr)
    local len = ffi.C.wcstombs(nil, wstr, 0)
    if len == 0 then error("Conversion failed") end

    local str = ffi.new("char[?]", len+1)
    ffi.C.wcstombs(str, wstr, len+1)
    return str, len
end

local function lastErr(addCode, code)
	code = code or K.GetLastError()
	if code == 0 then return '' end

	local ptr = ffi.new('char[?]', 4096)
	local len = K.FormatMessageA(
		0x1200, -- FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS
        nil, -- no source string
        code,
        0, -- MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)
        ptr,
        4096, -- Minimum buffer size
        nil -- No extra arguments
    );
	if len == 0 then return "unknown error" end

	local str = ffi.string(ptr, len)
	if addCode then
		str = string.format('0x%x: %s', code, str)
	end
	return str
end

local o = {}

o.ses = C.WinHttpOpen(
	W"imm/winhttp (https://github.com/frostice482/balatro-imm)",
	constants.ACCESS_TYPE_DEFAULT_PROXY,
	nil,
	nil,
	0
)
if o.ses == nil then error("WinHttpOpen: " .. lastErr(true)) end

o.urllengths = {
	Scheme = 8,
	HostName = 256,
	UrlPath = 2048,
	ExtraInfo = 2048
}

o.urlSize = ffi.sizeof('URL_COMPONENTS')

function o.parseUrl(url)
	local s
	--- @type any
	s = { StructSize = o.urlSize }
	for k,len in pairs(o.urllengths) do
		s[k] = ffi.new('wchar_t[?]', len)
		s[k..'Length'] = len
	end

	--- @type imm.winhttp.Url
	local parsed = ffi.new('URL_COMPONENTS', s) --- @diagnostic disable-line
	ffi.gc(parsed, function() s = nil end)

	local lurl, lurlsz = W(url)
	if not C.WinHttpCrackUrl(lurl, lurlsz, 0, parsed) then return end

	return parsed
end

local function die(t, code)
	return error(string.format("%s error: %s", t, lastErr(true, code)))
end

function o.process(msg)
	--- @type imm.HttpsAgent.Req
	local req = msg.req
	local opts = req.options or {}
	assert(req.url, "Missing URL")

	local hConn, hReq

	-- step: url

	local url = o.parseUrl(req.url)
	if not url then return die"URL"end

	-- step: connect

	hConn = C.WinHttpConnect(
		o.ses,
		url.HostName,
		url.nScheme == constants.INTERNET_SCHEME_HTTP and 80
			or url.nScheme == constants.INTERNET_SCHEME_HTTPS and 443
			or 0,
		0
	)
	if hConn == nil then return die"connect"end
	ffi.gc(hConn, function ()
		C.WinHttpCloseHandle(hConn)
	end)

	-- step: request

	local path = url.UrlPath
	if url.ExtraInfo ~= nil and url.ExtraInfoLength > 0 then
		path = ffi.new('wchar_t[?]', url.UrlPathLength + url.ExtraInfoLength + 1)
		ffi.copy(path, url.UrlPath, url.UrlPathLength)
		ffi.copy(path+url.UrlPathLength, url.ExtraInfo, url.ExtraInfoLength)
	end

	hReq = C.WinHttpOpenRequest(
		hConn,
		W(opts.method or 'GET'),
		path,
		nil, -- http/1.1
		nil,
		nil,
		url.nScheme == constants.INTERNET_SCHEME_HTTPS and constants.FLAG_SECURE or 0
	)
	if hReq == nil then return die"openrequest" end
	ffi.gc(hReq, function ()
		hConn = nil
		C.WinHttpCloseHandle(hReq)
	end)

	-- step: send

	do

	local headers, hlen = nil, 0
	if opts.headers then
		local hc = {}
		for k,v in pairs(opts.headers) do
			table.insert(hc, string.format('%s: %s\r\n', k, v))
		end
		headers, hlen = W(table.concat(hc))
	end

	local data = opts.data
	local dlen = data and data:len() or 0

	if not C.WinHttpSendRequest(hReq, headers, hlen, data, dlen, dlen, nil) then die"sendrequest" end

	end

	-- step: recv

	if not C.WinHttpReceiveResponse(hReq, nil) then die"receiveresponse" end

	-- step: get headers

	local headersParsed = {}
	local p, statusCode, statusText = nil, 0, 'no response'

	do

	local sizep = ffi.new('unsigned long[1]')
	C.WinHttpQueryHeaders(
		hReq,
		constants.WINHTTP_QUERY_RAW_HEADERS_CRLF,
		nil,
		nil,
		sizep,
		nil
	)

	local headers = ffi.new('wchar_t[?]', sizep[0] / ffi.sizeof('wchar_t'))
	if not C.WinHttpQueryHeaders(
		hReq,
		constants.WINHTTP_QUERY_RAW_HEADERS_CRLF,
		nil,
		headers,
		sizep,
		nil
	)
	then die"queryheaders" end

	local headersStr = ffi.string(A(headers))
	local prevh
	for i, entry in sutil.splitentries(headersStr, "\r?\n") do
		if i == 1 then
			p, statusCode, statusText = entry:match("^([^ ]+)%s+(%d+)%s+(.*)$")
		else
			if entry:sub(1, 1):find("%s") and prevh then
				headersParsed[prevh] = headersParsed[prevh] .. entry:sub(2)
			else
				local k, v = unpack(sutil.strsplit(entry, ": ", true, 2), 1, 2)
				headersParsed[k] = v
				prevh = k
			end
		end
	end

	end

	-- body

	local chunks = {}
	local totalsize = 0
	local _a
	_a = ffi.new('unsigned long[1]')

	do

	local allocsz = 131072
	local alloc = ffi.new('char[?]', allocsz)
	local sizep = ffi.new('unsigned long[1]')

	repeat
		if not C.WinHttpQueryDataAvailable(hReq, sizep) then
			die"querydataavailable"
		end

		local size = sizep[0]
		local buf = size <= allocsz and alloc or ffi.new('char[?]', size)
		if not C.WinHttpReadData(hReq, buf, size, _a) then
			die(string.format("readdata(%s)", tonumber(size)))
		end

		table.insert(chunks, ffi.string(buf, size)) --- @diagnostic disable-line
		totalsize = totalsize + tonumber(size)
	until sizep[0] <= 0

	end

	-- cleanup

	if not C.WinHttpCloseHandle(ffi.gc(hReq, nil)) then die"close(req)" end
	if not C.WinHttpCloseHandle(ffi.gc(hConn, nil)) then die"close(conn)" end

	-- output

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

	return { tonumber(statusCode) or -158, body, headersParsed }
end

function o.destroy()
	collectgarbage("collect")
	C.WinHttpCloseHandle(o.ses)
end

return o