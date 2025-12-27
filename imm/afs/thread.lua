--- @type love.Channel, _imm.AfsWorker.SharedThread
local i, sd = ...

require('love.timer')
require('love.event')
require('love.filesystem')
local ffi = require("ffi")

ffi.cdef(sd.header:getString())

local sdata_sz = assert(ffi.sizeof('struct SharedData'))
local sdata_p = ffi.typeof('struct SharedData *')
local C = pcall(function() return ffi.C.PHYSFS_openRead end) and ffi.C or ffi.load("love")
local nfs = assert(loadstring(sd.nfscode:getString(), '@imm/virt/afs/nativefs.lua'))()

local function sdata_cast(data)
	--- @type _imm.AfsWorker.SharedData
	return sdata_p(data:getFFIPointer()) --- @diagnostic disable-line
end

local bufsize = 65536
local buf = ffi.new('char[?]', bufsize)

--- @param share _imm.AfsWorker.SharedData
local function abort(share, ...)
	if share.abort then return end
	share.abort = true
	love.event.push('imm_taskres', share.gid, share.id, { ... }) --- @diagnostic disable-line
end

--- @param share _imm.AfsWorker.SharedData
local function finish(share, add)
	share.remaining = share.remaining - 1 + (add or 0)
	if share.remaining == 0 then
		abort(share, true)
	end
end

local lib = {}

--- @param src string
--- @param dest string
--- @param srcNfs? boolean
--- @param destNfs? boolean
function lib.fastcopy(src, dest, srcNfs, destNfs)
	srcNfs = false
    local rh, wh, err, r

	if srcNfs then
		rh, err = C.fopen(src, "r"), 'Cannot read ' .. src
	else
		rh, err = C.PHYSFS_openRead(src), 'Cannot read ' .. src
	end
    if rh == nil then goto cleanup end
    wh, err = io.open(destNfs and dest or love.filesystem.getSaveDirectory()..'/'..dest, "w")
    if not wh then goto cleanup end

    repeat
		if srcNfs then
			r = C.fread(buf, 1, bufsize, rh)
			if r == 0 and C.ferror(rh) ~= 0 then r = -1 end
		else
			r = C.PHYSFS_readBytes(rh, buf, bufsize)
		end
        if r == -1 then
            err = "read fail"
            goto cleanup
        end
        if C.fwrite(buf, 1, r, wh) ~= r then
            err = "inequal read to write"
            goto cleanup
        end
    until r <= 0

    ::cleanup::

    if wh ~= nil then
		wh:close()
	end
    if rh ~= nil then
		if srcNfs then
			C.fclose(rh)
		else
			C.PHYSFS_close(rh)
		end
	end
    return not err, err
end

function lib.fmtcopy(req, destFromSrc)
	local src = string.format('%s %s', req.opts.srcNfs and "nfs" or "lovefs", req.org or req.src)
	local dest = string.format('%s %s', req.opts.destNfs and "nfs" or "lovefs", req.dest)
	local m = 'to'
	if destFromSrc then src, dest, m = dest, src, 'from' end
	return string.format('%s %s %s', src, m, dest)
end

local commands = {}
--- @param share _imm.AfsWorker.SharedData
function commands.cp(req, share)
	local source = req.src
	local target = req.dest
	local sourceProv = false and req.opts.srcNfs and nfs or love.filesystem
	local targetProv = req.opts.destNfs and nfs or love.filesystem

    local stat = sourceProv.getInfo(source)
    if not stat then error(string.format('stat %s returned undefined', source), 0) end

    if stat.type == 'file' then
		if req.opts.fast then
			local ok, err = lib.fastcopy(source, target, req.opts.srcNfs, req.opts.destNfs)
			if not ok then error(string.format("Failed copying %s: %s", lib.fmtcopy(req), err), 0) end
		else
			local s, d, err
			s, err = sourceProv.newFileData(source)
			if not s then error(string.format("Failed reading %s: %s", lib.fmtcopy(req, true), err), 0) end
			d, err = targetProv.write(target, s)
			if not d then error(string.format("Failed copying %s: %s", lib.fmtcopy(req), err), 0) end
			s:release()
		end
		finish(share)
		return
    elseif stat.type == 'directory' then
        local ok, err = targetProv.createDirectory(target)

		if not ok then error(string.format("Failed creating directory %s: %s", lib.fmtcopy(req, true), err or '-'), 0) end

        local items = sourceProv.getDirectoryItems(source)
		finish(share, #items)
        for i, item in ipairs(items) do
			sd.input:push({
				command = 'cp',
				org = req.org and req.org..'/'..item,
				src = source..'/'..item,
				dest = target..'/'..item,
				opts = req.opts,
				share = req.share
			})
        end
		return
    end

	error(string.format("unknown stat type %s for %s", stat.type, lib.fmtcopy(req, true)))
end

local function handleInput(msg)
	local d = love.data.newByteData(sdata_sz)
	local sdata = sdata_cast(d)
	sdata.id = msg.id
	sdata.gid = msg.gid
	sdata.remaining = 1
	msg.req.share = d
	sd.input:push(msg.req)
end

local function handleSharedInput(msg)
	local sdata = sdata_cast(msg.share)
	if sdata.abort then return end

	local f = commands[msg.command]
	if not f then
		return abort(sdata, false, "Unknown command " .. msg.command)
	end

	local ok, o = pcall(f, msg, sdata)
	if not ok then
		return abort(sdata, false, tostring(o))
	end
end

local idlecount = 0
while true do
	local msg, msg2
	if sd.input:getCount() ~= 0 then
		msg2 = sd.input:demand()
		if msg2 then handleSharedInput(msg2) end
	end
	if i:getCount() ~= 0 then
		msg = i:demand()
		if msg then handleInput(msg) end
	end

	if msg or msg2 then
		idlecount = 0
	else
		love.timer.sleep(0.1)
		idlecount = idlecount + 1
		if idlecount > 60 then break end
	end
end

