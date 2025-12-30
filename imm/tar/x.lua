local sutil = require("imm.lib.strutil")
local Tar = require("imm.tar.tar")
local ffi = sutil.ffi

local paxSpecialDouble = {
    atime = true,
    mtime = true,
    gid = true,
    uid = true,
    size = true
}

local paxPropMap = {
    mtime = 1,
    atime = 1,
    uid = 1,
    gid = 1,
    uname = 1,
    gname = 1,
    size = 1,
    comment = 1,
    path = 'pathname',
    linkpath = 'linkname',
}

--- Parses header from given pointer
--- @param ptr ffi.cdata*
--- @param idx number | ffi.cdata*
local function parseHeader(ptr, idx)
    --- @type Tar.HeaderParsed
    local h = {} --- @diagnostic disable-line
    h.pax = {}

    for i,entry in ipairs(Tar.fields) do
        if entry.type == 3 then -- single char
            h[entry.field] = ptr[idx]
        elseif entry.type == 2 then -- octal
            h[entry.field] = tonumber(sutil.C.strtol(ptr+idx, sutil.NULL, 8))
        else -- string
            local after = idx+entry.size
            local b = ptr[after]
            ptr[after] = 0
            h[entry.field] = ffi.string(ptr+idx)
            ptr[after] = b
        end
        idx = idx+entry.size
    end

    idx = idx+12

    h.sizeBlocked = math.ceil(h.size/512)*512
    h.contentStart = tonumber(idx) --- @diagnostic disable-line

    return h, idx
end

--- Parses all pax extended headers from given pointer
--- @param ptr ffi.cdata*
--- @param idx number | ffi.cdata*
--- @param lim number
--- @param file? string
--- @param target? Tar.Pax.Header
local function parsePax(ptr, idx, lim, file, target)
    target = target or {}

    -- next time when working with c
    -- dont forget to add overflow & malformed checks,
    -- it'll never know what data it'll receive at anytime

    while idx < lim and ptr[idx] ~= 0 do
        local start = ptr+idx
        local elen = sutil.C.strtol(ptr+idx, sutil.endptr, 0) -- length
        local elen_nonl = elen - 1 -- length without newline
        local kw_start_ptr = sutil.endptr[0]+1

        if idx+elen > lim then
            error(string.format("pax overflow: %s - %d+%d > %d", file or "?", idx, elen, lim))
        end

        if ptr[idx+elen_nonl] ~= sutil.chars.newline then
            error("unexpected PAX newline delimiter")
        end

        local eq_ptr = sutil.C.memchr(kw_start_ptr, sutil.chars.equals, elen_nonl-(kw_start_ptr-start))
        if eq_ptr == sutil.NULL then break end

        local keyword = ffi.string(kw_start_ptr, eq_ptr - kw_start_ptr)
        local v_start = eq_ptr+1

        if paxSpecialDouble[keyword] then
            target[keyword] = sutil.C.strtod(v_start, sutil.NULL)
        else
            target[keyword] = ffi.string(v_start, elen_nonl-(v_start-start))
        end

        idx = idx + elen
    end

    return target
end

--- @param header Tar.HeaderParsed
--- @param paxHeader Tar.Pax.Header
local function applyPax(header, paxHeader)
    for k,v in pairs(paxHeader) do
        local dst = paxPropMap[k]
        if dst then header[dst == 1 and k or dst] = v end
        header.pax[k] = v
    end
end

--- Creates iterator to parse headers from given pointer
--- @param ptr ffi.cdata*
--- @param idx number | ffi.cdata*
--- @param lim number
--- @return fun(): Tar.HeaderParsed?
local function parseHeaders(ptr, idx, lim)
    return function()
        if idx >= lim or ptr[idx] == 0 then return end

        local h
        h, idx = parseHeader(ptr, idx)
        idx = idx + h.sizeBlocked
        return h
    end
end


--- Creates iterator to parse headers from given pointer,
--- while also interpreting results (g, x, K, L, etc.)
--- @param ptr ffi.cdata*
--- @param idx number | ffi.cdata*
--- @param lim number
--- @param strictChecksum? boolean
--- @return fun(): Tar.HeaderParsed?
local function parseHeadersIntr(ptr, idx, lim, strictChecksum)
    local gPax
    local nextPax
    local nextLongName
    local nextLongLink
    local h
    local itr = parseHeaders(ptr, idx, lim)

    return function()
        while true do
            h = itr()
            if not h then return end
            local t = h.type

            if h.contentStart + h.size > lim then
                error(string.format("overflow: %s - %d+%d > %d", h.pathname, h.contentStart, h.size, lim))
            end

            if strictChecksum then
                local sum = Tar.sumHeader(ptr+h.contentStart-512)
                if sum ~= h.checksum then
                    error(string.format("checksum mismatch: %s: %d != %d", h.pathname, h.checksum, sum))
                end
            end

            if t == Tar.headerTypes.gnu_longlink then
                nextLongLink = ffi.string(ptr+h.contentStart, h.size)
            elseif t == Tar.headerTypes.gnu_longname then
                nextLongName = ffi.string(ptr+h.contentStart, h.size)
            elseif t == Tar.headerTypes.paxGlobalHeader then
                gPax = parsePax(ptr, h.contentStart, h.contentStart+h.size, h.pathname)
            elseif t == Tar.headerTypes.paxFileHeader then
                nextPax = parsePax(ptr, h.contentStart, h.contentStart+h.size, h.pathname, nextPax or {})
            else
                break
            end
        end

        if nextLongLink then
            h.linkname = nextLongLink
            nextLongLink = nil
        end
        if nextLongName then
            h.pathname = nextLongName
            nextLongName = nil
        end
        if gPax then
            applyPax(h, gPax)
        end
        if nextPax then
            applyPax(h, nextPax)
            nextPax = nil
        end

        return h
    end
end

local i = {}

--- @param ptr ffi.cdata*
--- @param len number
--- @param strictChecksum? boolean
function i.parseLow(ptr, len, strictChecksum)
    if len % 512 ~= 0 then
        error("tar file length must be exactly multiple of 512 bytes")
    end

    local tar = Tar()
    --- @type table<string, Tar.FileContent>
    local hlinklist = {}

    for header in parseHeadersIntr(ptr, sutil.size_t_0, len, strictChecksum) do
        local path = header.pathname
        local t = header.type
        if t == 0 or t == Tar.headerTypes.normalFile or t == Tar.headerTypes.hardlink then
            local c = tar:openFile(path, header)
            local ln = path
            if t == Tar.headerTypes.hardlink then ln = header.linkname
            else c:setContentFFI(ptr + header.contentStart, header.size) end

            if hlinklist[ln] then c.link = hlinklist[ln]
            else hlinklist[ln] = c.link end
        elseif t == Tar.headerTypes.directory then
            tar:openDir(path, header)
        elseif t == Tar.headerTypes.symlink then
            tar:symlink(header.linkname, path, header)
        end
    end

    tar._keeper = ptr

    return tar
end

--- @param str string | love.Data
--- @param strictChecksum? boolean
function i.parse(str, strictChecksum)
    local ptr, len
    if type(str) == "string" then
        ptr, len = str, str:len()
    else
        ptr, len = str:getFFIPointer(), str:getSize()
    end
    ptr = ffi.cast("char*", ptr)
    sutil.ffi.gc(ptr, function () str = nil end) --- @diagnostic disable-line
    return i.parseLow(ptr, len, strictChecksum)
end

return i