local ffi = require("ffi")
local a = require("imm.lib.assert")
local Tar = require("imm.tar.tar")

ffi.cdef[[
int snprintf(char *s, size_t n, const char *format, ...);
]]

--- @param target ffi.cdata*
--- @param datastack any[]
local function assignHeader(target, datastack)
	local off = 0
	for i,field in ipairs(Tar.fields) do
		local v
		for j, data in ipairs(datastack) do
			v = data[field.field]
			if v then break end
		end
		if field.type == 3 then
			a.type(v, "byte:"..field.field, "number")
			target[off] = v
		elseif field.type == 2 then
			a.type(v, "octal:"..field.field, "number")
			ffi.copy(target+off, string.format("%o", v):sub(1, field.size-1))
		else
			a.type(v, "string:"..field.field, "string")
			ffi.copy(target+off, v, math.min(v:len()+1, field.size-1))
		end
		off = off + field.size
	end

	-- checksum
	ffi.copy(target+148, string.format("%o", Tar.sumHeader(target)))
end

local typeswap = {
	{ size = 0, type = 0 },
	Tar.defaultHeader
}

--- @param data ffi.cdata*
--- @param lim ffi.cdata*
--- @param size number
--- @param type number
local function assignHeaderType(data, lim, size, type)
	if data + 512 > lim then error('out of bound') end
	typeswap[1].size = size
	typeswap[1].type = type
	assignHeader(data, typeswap)
	data = data + 512
	return data
end

--- @param data ffi.cdata*
--- @param lim ffi.cdata*
--- @param path string
--- @return ffi.cdata*
local function assignLongname(data, lim, path)
	local len = path:len()
	if len < 100 then return data end

	data = assignHeaderType(data, lim, len, Tar.headerTypes.gnu_longname)

	if data + len > lim then error('out of bound') end
	ffi.copy(data, path)
	data = data + math.ceil(len/512) * 512

	return data
end

--- @param data ffi.cdata*
--- @param lim ffi.cdata*
--- @param entry Tar.EntryType
--- @return ffi.cdata*
local function assignLonglink(data, lim, entry)
	if entry.type ~= 'symlink' then return data end
	local len = entry.link:len()
	if len < 100 then return data end

	data = assignHeaderType(data, lim, len, Tar.headerTypes.gnu_longlink)

	if data + len > lim then error('out of bound') end
	ffi.copy(data, entry.link) --- @diagnostic disable-line
	data = data + math.ceil(len/512) * 512

	return data
end

local headersswap = {}

--- @param data ffi.cdata*
--- @param lim ffi.cdata*
--- @param entry Tar.EntryType
--- @return ffi.cdata*
local function assignPax(data, lim, entry)
	local i = 0
	local len = 0
	for k,v in pairs(entry.header.pax) do
		local elen = Tar.estimatePaxLengthEntry(k, v)
		len = len + elen
		i = i + 1
		headersswap[i] = string.format("%d %s=%s\n", elen, k, tostring(v))
	end
	if len == 0 then return data end

	data = assignHeaderType(data, lim, len, Tar.headerTypes.paxFileHeader)

	if data + len > lim then error('out of bound') end
	ffi.copy(data, table.concat(headersswap, '', 1, i))
	data = data + math.ceil(len/512) * 512

	return data
end

local cswap = {
	{ pathname = '' },
	{}
}

--- @param data ffi.cdata*
--- @param entry Tar.EntryType
--- @param lim ffi.cdata*
--- @return ffi.cdata*
local function assign(data, entry, lim)
	if entry.root == entry then
		for k,v in pairs(entry.items) do
			data = assign(data, v, lim)
		end
		return data
	end

	local p = entry:getPath()
	data = assignLongname(data, lim, p)
	data = assignLonglink(data, lim, entry)
	data = assignPax(data, lim, entry)

	cswap[1].pathname = p
	cswap[1].type = entry.headerChar
	cswap[2] = entry.header
	assignHeader(data, cswap) data = data + 512

	if entry.type == 'file' then
		if data + entry.link.len > lim then error('out of bound') end
		ffi.copy(data, entry.link.str, entry.link.len)
		data = data + math.ceil(entry.link.len/512) * 512
	elseif entry.type == 'dir' then
		for k,v in pairs(entry.items) do
			data = assign(data, v, lim)
		end
	end

	return data
end

local x = {}

--- @param entry Tar.EntryType
function x.createTar(entry)
	local sz = entry:estimateBlocks()*512
	local data = love.data.newByteData(sz)
	local ptr = ffi.cast("char*", data:getFFIPointer())
	local ndata = assign(ptr, entry, ptr + sz)
	return data
end

return x