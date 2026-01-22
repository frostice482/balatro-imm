--[[
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

if __MINIMOUNT then return __MINIMOUNT end

local ffi = require("ffi")
ffi.cdef[[
typedef struct FILE FILE;
void* malloc(size_t sz);
size_t fread(void* restrict buffer, size_t size, size_t count, FILE* restrict stream);
typedef void (*PHYSFS_FreeCallback)(void *ptr);
int PHYSFS_mount(const char* dir, const char* mountPoint, int appendToPath);
int PHYSFS_mountMemory(
	const void *buf,
	unsigned long long len,
	PHYSFS_FreeCallback del,
	const char *newDir,
	const char *mountPoint,
	int appendToPath
);
int PHYSFS_setRoot(const char* archive, const char* subdir);
]]
local physfs = pcall(function() return ffi.C.PHYSFS_mount end) and ffi.C or ffi.load("love")

--- @param name string
--- @param id string
--- @param dir string
--- @param mountpoint string
--- @param sub? string
--- @param appendToPath? boolean
function __MINIMOUNT(name, id, dir, mountpoint, sub, appendToPath)
	local file = io.open(dir, "r")
	if file and file:read(0) and sub then
		local fsname = string.format('virt/mod/%s', id)
		local temp = ffi.new('int[1]')
		ffi.gc(temp, function() file:close() end)

		local size = file:seek("end", 0)
		file:seek("set", 0)

		local buf = ffi.C.malloc(size)
		if buf == nil then
			error(string.format("%s: allocation failed with size %d", name, size))
		end

		local readcount = ffi.C.fread(buf, 1, size, file)
		if readcount ~= size then
			error(string.format("%s: read mismatch (expected %d, got %d)", name, size, tonumber(readcount) or 0))
		end

		file:close()
		ffi.gc(temp, nil)

		if physfs.PHYSFS_mountMemory(buf, size, nil, fsname, mountpoint, appendToPath and 1 or 0) == 0 then
			error(string.format("%s: failed zip mounting to %s from %s (size: %d, fs: %s)", name, mountpoint, dir, size, fsname))
		end
		if not love.filesystem.getInfo(mountpoint..'/'..sub) then
			local items = love.filesystem.getDirectoryItems(mountpoint)
			if #items ~= 1 then error(string.format("%s: root ambiguity on nested zip with multiple folders", name)) end

			sub = items[1]..'/'..sub
			if not love.filesystem.getInfo(mountpoint..'/'..sub) then error(string.format("%s: missing root on nested folder %s", name, items[1])) end
		end
		if physfs.PHYSFS_setRoot(fsname, sub) == 0 then
			error(string.format("%s: failed zip setting root to %s from %s (size: %d, fs: %s)", name, sub, dir, size, fsname))
		end
		return
	end
	if file then file:close() end

	if sub then dir = dir..'/'..sub end

	if physfs.PHYSFS_mount(dir, mountpoint, appendToPath and 1 or 0) == 0 then
		error(string.format("%s: failed mounting to %s from %s", name, mountpoint, dir))
	end
end

return __MINIMOUNT