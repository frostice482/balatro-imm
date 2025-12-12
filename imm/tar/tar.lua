local constructor = require("imm.lib.constructor")
local util = require("imm.lib.util")
local sutil = require("imm.lib.strutil")
local chars = sutil.chars

--#region

--- @class Tar.Pax.Header: { [string]: any }
--- @field comment? string
--- @field mtime? number
--- @field atime? number
--- @field charset? string
--- @field hdrcharset? string
--- @field gid? number
--- @field gname? string
--- @field uid? number
--- @field uname? string
--- @field linkpath? string
--- @field path? string
--- @field size? number

--- @class Tar.HeaderParsed
--- @field pathname string
--- @field mode number
--- @field uid number
--- @field gid number
--- @field size number
--- @field mtime number
--- @field checksum number
--- @field type Tar.Header.FlagByte
--- @field linkname string
--- @field ustar string
--- @field uname string
--- @field gname string
--- @field devmajor string
--- @field devminor string
--- @field prefix string
--- @field comment? string
--- @field pax? Tar.Pax.Header
--- @field sizeBlocked? number
--- @field contentStart? number

--- @class Tar.HeaderMini
--- @field mode? number
--- @field uid? number
--- @field gid? number
--- @field mtime? number
--- @field uname? string
--- @field gname? string
--- @field devmajor? string
--- @field devminor? string
--- @field comment? string

--- @alias Tar.Header.Opts Tar.HeaderMini | Tar.HeaderParsed

local optsFields = {"mode", "uid", "gid", "mtime", "uname", "gname", "devmajor", "devminor", "comment"}

--[[
--- @alias Tar.Header.FlagByte
--- | 0  Normal file
--- | 48 `0` Normal file
--- | 49 `1` Hard link
--- | 50 `2` Symlink
--- | 51 `3` Character special
--- | 52 `4` Block special
--- | 53 `5` Directory
--- | 54 `6` FIFO
--- | 55 `7` Contiguous
--- | 103 `g` Global extended header with meta data
--- | 120 `x` Extended header with metadata for the next file in the archive
--- | 68 `D` GNU - Dumpdir
--- | 75 `K` GNU - Long linkname for next line
--- | 76 `L` GNU - Long name for next line
--- | 77 `M` GNU - Continuation of a file that began on another volume
--- | 78 `N` GNU - Storing filename that doesn't fit in header
--- | 79 `S` GNU - Sparse file
--- | 86 `V` GNU - Tape/volume header
--- | 88 `X` Solaris - Extended header
]]

--- @alias Tar.Header.FlagByte
--- | 0  Normal file
--- | 48 `0` Normal file
--- | 49 `1` Hard link
--- | 50 `2` Symlink
--- | 53 `5` Directory
--- | 103 `g` Global extended header with meta data
--- | 120 `x` Extended header with metadata for the next file in the archive
--- | 75 `K` GNU - Long linkname for next line
--- | 76 `L` GNU - Long name for next line

--- @alias Tar.EachFn fun(entry: Tar.EntryType, fname: string, dir: Tar.Dir): boolean?

--- @alias Tar.Entry.C p.Constructor<Tar.Entry, nil> | fun(root: Tar.Root, header?: Tar.Header.Opts): Tar.Entry
--- @alias Tar.Symlink.C p.Constructor<Tar.Symlink.C, Tar.Entry.C> | fun(root: Tar.Root, link: string, header?: Tar.Header.Opts): Tar.Symlink
--- @alias Tar.File.C p.Constructor<Tar.File.C, Tar.Entry.C> | fun(root: Tar.Root, header?: Tar.Header.Opts): Tar.File
--- @alias Tar.Dir.C p.Constructor<Tar.Dir, Tar.Entry.C> | fun(root: Tar.Root, header?: Tar.Header.Opts): Tar.Dir
--- @alias Tar.Root.C Tar.Static | p.Constructor<Tar.Root, Tar.Entry.C> | fun(): Tar.Root

local Entry
local Link
local File
local Dir

--- @class Tar.Static: p.Constructor
local TarS = {}

--- @class p.Tar.HeaderEnum
TarS.headerTypes = {
    normalFile = chars.d0,
    hardlink = chars.d1,
    symlink = chars.d2,
    characterSpecial = chars.d3,
    blockSpecial = chars.d4,
    directory = chars.d5,
    dido = chars.d6,
    contiguous = chars.d7,
    paxGlobalHeader = chars.g,
    paxFileHeader = chars.x,
    gnu_dumpdir = chars.D,
    gnu_longname = chars.K,
    gnu_longlink = chars.L,
    gnu_multivolContinuation = chars.M,
    gnu_nameUnfit = chars.N,
    gnu_sparse = chars.S,
    gnu_header = chars.V,
    solaris_extHeader = chars.X
}

--#endregion

--#region entry

--- @class Tar.Entry
--- @field type string
--- @field header Tar.Header.Opts
--- @field root Tar.Root
--- @field parent? Tar.Dir
local IEntry = {
    type = "other",
    headerChar = TarS.headerTypes.blockSpecial
}


--- @type Tar.HeaderParsed
TarS.defaultHeader = {
    pathname = '',
    mode = 448, -- 700
    uid = 1000,
    gid = 1000,
    size = 0,
    mtime = os.time(),
    checksum = 0,
    type = 0,
    linkname = '',
    ustar = 'ustar\00000',
    uname = '?',
    gname = '?',
    devmajor = '',
    devminor = '',
    prefix = '',
    pax = {}
}

--- @param k string
--- @param v any
function TarS.estimatePaxLengthEntry(k, v)
	if type(v) ~= 'string' then v = tostring(v) end
	local l = k:len() + v:len() + 3
	l = l + math.ceil(math.log10(l))
	local m = math.floor(math.log10(l))
	if l >= 10 ^ m and l <= 10 ^ m + m then l = l + 1 end
    return l
end

function TarS.estimatePaxLengthEntries(l)
    local s = 0
    for k,v in pairs(l) do
        s = s + TarS.estimatePaxLengthEntry(k, v)
    end
    return s
end

--- @protected
--- @param root Tar.Root
--- @param header? Tar.Header.Opts
function IEntry:init(root, header)
    header = header or {}
    self.root = root
    self.header = setmetatable({}, { __index = TarS.defaultHeader })
    for i,field in ipairs(optsFields) do self.header[field] = header[field] end
end

local l = {}
--- @param root? Tar.Entry
function IEntry:getPath(root)
    local i = 1

    --- @type Tar.Entry?
    local cur = self
    while cur and cur.parent and cur ~= root do
        i = i - 1
        l[i] = cur.parent.itemNames[cur]
        cur = cur.parent
    end
    return table.concat(l, "/", i, 0)
end

--- @param root? Tar.Entry
function IEntry:getPathLength(root)
    local n = -1

    --- @type Tar.Entry?
    local cur = self
    while cur and cur.parent and cur ~= root do
        n = n + cur.parent.itemNames[cur]:len() + 1
        cur = cur.parent
    end
    return n
end

function IEntry:getName()
    if not self.parent then return end

    local n = self.parent.itemNames[self]
    if not n then return end
    local v = self.parent.items[n]
    if v ~= self then return end

    return n
end

function IEntry:isRootReachable()
    local cur = self
    while cur do
        if cur == self.root then return true end
        if not cur:getName() then return false end
        cur = cur.parent
    end
    return false
end

--- @param path string
--- @param entry Tar.Entry
--- @return Tar.Entry entry
function IEntry:_parentAddItem(path, entry)
    if not self.parent then error("missing parent") end
    self.parent:addItem(path, entry)
    return entry
end

--- @param path string
--- @return Tar.Symlink link
function IEntry:symlinkTo(path)
    local e self:_parentAddItem(path, Link(self.root, self:getPath(), self.header))
    return e
end

function IEntry:estimateExtraBlocks()
    local plen = self:getPathLength()
    return plen < 100 and 0 or 1 + math.ceil((plen+16)/512)
end

function IEntry:estimateBlocks()
    local b = 1 + math.ceil(self.header.size/512) + self:estimateExtraBlocks()
    local s = TarS.estimatePaxLengthEntries(self.header.pax)
    if s > 0 then b = b + 1 + math.ceil(s/512) end
    return b
end

--- @param type string
function IEntry:assertType(type)
    if self.type ~= type then
        return error(string.format("%s: not a %s, got %s", self:getPath(), type, self.type))
    end
end

--- @type Tar.Entry.C
Entry = constructor(IEntry)

--#endregion
--#region symlink

--- @class Tar.Symlink: Tar.Entry
--- @field type "symlink"
--- @field link string
local ILink = {
    type = "symlink",
    headerChar = TarS.headerTypes.symlink
}

--- @protected
--- @param root Tar.Root
--- @param link string
--- @param header? Tar.Header.Opts
function ILink:init(root, link, header)
    IEntry.init(self, root, header)
    self.link = link
end

function ILink:resolve()
    return self.root:get(self.link)
end

function ILink:estimateExtraBlocks()
    local len = self.link:len()
    local w = len < 100 and 0 or 1 + math.ceil((len+16)/512)
    return IEntry.estimateExtraBlocks(self) + w
end

--- @type Tar.Symlink.C
Link = Entry:extendTo(ILink)

--#endregion
--#region file

--- @class Tar.FileContent
--- @field str? ffi.cdata*
--- @field len number

--- @class Tar.File: Tar.Entry
--- @field type "file"
--- @field link Tar.FileContent
local IFile = {
    type = "file",
    headerChar = TarS.headerTypes.normalFile
}

--- @protected
--- @param root Tar.Root
--- @param header? Tar.Header.Opts
function IFile:init(root, header)
    IEntry.init(self, root, header)
    self.link = {
        off = 0,
        len = 0
    }
end

--- @param ptr ffi.cdata*
--- @param len number
function IFile:setContentFFI(ptr, len)
    self.link.str = ptr
    self.link.len = len
    self.header.size = len
    return self
end

--- @param str string | love.Data
--- @param len? number
--- @param off? number
function IFile:setContentString(str, len, off)
    off = off or 0
    local ptr
    if type(str) == "string" then
        ptr, len = str, len or str:len()
    else
        ptr, len = str:getFFIPointer(), len or str:getSize()
    end
    ptr = sutil.const_char_ptr(ptr) + off
    sutil.ffi.gc(ptr, function () str = nil end) --- @diagnostic disable-line
    return self:setContentFFI(ptr, len)
end

function IFile:getContentString()
    if not self.link.str then return end
    return sutil.ffi.string(self.link.str, self.link.len)
end

local empty = love.filesystem.newFileData("", "")

function IFile:getContentData()
    if not self.link.str then return end
    if self.link.len == 0 then return empty end

    local d = love.data.newByteData(self.link.len)
    local ptr = d:getFFIPointer()
    sutil.ffi.copy(ptr, self.link.str, self.link.len)
    return d
end

--- @param path string
--- @return Tar.File? link
function IFile:hardLinkTo(path)
    local f = File(self.root)
    self:_parentAddItem(path, f)
    f.header = self.header
    f.link = self.link
    return f
end

--- @type Tar.File.C
File = Entry:extendTo(IFile)

--#endregion
--#region dir

--- @class Tar.Dir: Tar.Entry
--- @field type "dir"
--- @field items table<string, Tar.EntryType>
--- @field itemNames table<Tar.EntryType, string>
local IDir = {
    type = "dir",
    headerChar = TarS.headerTypes.directory
}

--- @protected
--- @param root Tar.Root
--- @param header? Tar.Header.Opts
function IDir:init(root, header)
    IEntry.init(self, root, header)
    self.items = {}
    self.itemNames = {}
end

--- @protected
--- @param name string
--- @param item Tar.Entry
--- @return boolean success
--- @return string? error
function IDir:_addItem(name, item)
    if name == "" or name == "." or name == ".." then
        return false, string.format("illegal item name %s", name)
    end
    if self.items[name] then
        return false, string.format("%s/%s already exists", self:getPath(), name)
    end
    if item.parent then
        return false, string.format("item is linked on %s", item:getPath())
    end
    if item.root ~= self.root then
        return false, string.format("root not equal (current: %p, item: %p)", self.root, item.root)
    end

    self.items[name] = item
    self.itemNames[item] = name
    item.parent = self
    return true
end

--- @protected
--- @param paths string[]
--- @param mkdir? boolean
--- @param mkdirhead? Tar.Header.Opts
--- @return Tar.EntryType?
--- @return string? err
function IDir:_resolve(paths, mkdir, mkdirhead)
    --- @type any, any?
    local cur, next = self, nil

    for i,path in ipairs(paths) do
        if not cur then return nil, string.format("%s/%s: not exist (resolving %s)", self:getPath(), table.concat(paths, '/', 1, i-1), table.concat(paths, '/')) end
        if Link:is(cur) then cur = cur:resolve() end
        if not Dir:is(cur) then return nil, string.format("%s/%s: not a dir, got %s", self:getPath(), table.concat(paths, '/', 1, i), cur.type) end

        if path == "" then
            next = i == 1 and next.root or next
        elseif path == "." then
            next = next
        elseif path == ".." then
            next = cur.parent
        else
            next = cur.items[path]
        end

        if not next and mkdir  then
            next = Dir(self.root, mkdirhead)
            local ok, e = cur:_addItem(path, next)
            if not ok then return end
        end

        cur = next
    end

    if not cur then return nil, string.format("%s/%s: not exist", self:getPath(), table.concat(paths, '/')) end

    return cur
end

--- @param path string
--- @return Tar.Dir? dir
--- @return string filenameOrError
function IDir:resolveDir(path)
    local paths, len = util.strsplit(path,  "/", true)
    local item = paths[len]
    paths[len] = nil

    if item == "" or item == "." or item == ".." then
        error(string.format("illegal item name %s", item))
    end

    local dir = self:_resolve(paths, true)
    if not dir then return nil, string.format('%s/%s/%s -> %s: doesn\'t exist', self:getPath(), table.concat(paths, '/'), item) end
    if not Dir:is(dir) then return nil, string.format('%s/%s/%s -> %s: not a dir, got %s', self:getPath(), table.concat(paths, '/'), item, dir.type)  end

    return dir, item --- @diagnostic disable-line
end

--- @param path string
--- @param entry Tar.Entry
--- @return Tar.File? entry
--- @return string? err
--- @return Tar.Dir? dir
function IDir:addItem(path, entry)
    local dir, fname_e = self:resolveDir(path)
    if not dir then return nil, fname_e end
    local ok, e = dir:_addItem(fname_e, entry)
    if e then return nil, e end
    return entry, nil, dir --- @diagnostic disable-line
end

--- @param target string
--- @param linkName string
--- @param header? Tar.Header.Opts
--- @return Tar.File? entry
--- @return string? err
--- @return Tar.Dir? dir
function IDir:symlink(target, linkName, header)
    return self:addItem(linkName, Link(self.root, target, header))
end

--- @param path string
--- @param header? Tar.Header.Opts
--- @return Tar.EntryType? entry
function IDir:openDir(path, header)
    return self:_resolve(util.strsplit(path, "/", true), true, header)
end

--- @param path string
--- @param header? Tar.Header.Opts
--- @return Tar.File? entry
--- @return string? err
--- @return Tar.Dir? dir
function IDir:openFile(path, header)
    local dir, fname_e = self:resolveDir(path)
    if not dir then return nil, fname_e end

    local item = dir.items[fname_e]
    if not item then
        item = File(self.root, header)
        dir:_addItem(fname_e, item)
    else
        if not File:is(item) then return nil, string.format('%s/%s: not a file, got %s', self:getPath(), path, item.type) end
    end

    return item, nil, dir --- @diagnostic disable-line
end

--- @param path string
--- @return boolean success
--- @return string? err
function IDir:rm(path)
    local dir, fname_e = self:resolveDir(path)
    if not dir then return false, fname_e end

    local c = dir.items[fname_e]
    if not c then return false, string.format('%s/%s: doesn\'t exist', self:getPath(), path) end

    dir.items[fname_e] = nil
    dir.itemNames[c] = nil
    c.parent = nil
    return true
end

--- @param path string
function IDir:get(path)
    return self:_resolve(util.strsplit(path, "/", true), false)
end

--- Loops over all entries. Function shuold return false to stop loop
--- @param cb Tar.EachFn
function IDir:each(cb)
    for k,entry in pairs(self.items) do
        local ret = cb(entry, k, self)
        if ret == false then return false end
        if Dir:is(entry) then
            ret = entry:each(cb)
            if ret == false then return false end
        end
    end
    return true
end

--- Loops over all entries. Function shuold return false to stop loop
--- @param cb Tar.EachFn
function IDir:eachSort(cb)
    local l = util.entries(self.items, function (ka, va, kb, vb) return va:getName() < vb:getName() end)

    for i, item in ipairs(l) do
        local k, entry = item[1], item[2]
        local ret = cb(entry, k, self)
        if ret == false then return false end
        if Dir:is(entry) then
            ret = entry:eachSort(cb)
            if ret == false then return false end
        end
    end
end

--- @param base string
--- @param noRec? boolean
--- @param filter? fun(sub: string, path: string): boolean
--- @param basesub? string
function IDir:addFrom(base, noRec, filter, basesub)
    local items = love.filesystem.getDirectoryItems(base)
    for i, sub in ipairs(items) do
        local subpath = base .. '/' .. sub
        local subsub = basesub and basesub .. '/' .. sub or sub
        local stat = love.filesystem.getInfo(subpath)

        if not filter or filter(subsub, subpath) then
            if stat.type == 'file' then
                local subitem = self:openFile(sub, { size = stat.size, mtime = stat.modtime })
                if subitem then
                    subitem:setContentString(love.filesystem.newFileData(subpath))
                end
            elseif stat.type == 'directory' and not noRec then
                local subitem, err = self:_resolve({sub}, true)
                if subitem and Dir:is(subitem) then subitem:addFrom(subpath, false, filter, subsub) end
            end
        end
    end
end

function IDir:estimateBlocks()
    local b = IEntry.estimateBlocks(self)
    for k,entry in pairs(self.items) do
        b = b + entry:estimateBlocks()
    end
    return b
end

--- @type Tar.Dir.C
Dir = Entry:extendTo(IDir)

--#endregion

--#region root

--- @class Tar.Root: Tar.Dir
--- @field _keeper? ffi.cdata*
local IRoot = {}

--- @protected
function IRoot:init()
    IDir.init(self, self)
end

function IRoot:estimateExtraBlocks()
    return 0
end

function IRoot:estimateBlocks()
    return IDir.estimateBlocks(self) - 1
end

--- @type Tar.Root.C
local Tar = Dir:extendTo(IRoot, "Tar", TarS)

TarS.Entry = Entry
TarS.File = File
TarS.Dir = Dir
TarS.Link = Link

--- @param path string
function TarS.normalizePath(path)
    local list = util.strsplit(path, '/', true)
    local out = {}
    local c = 0

    for i,v in ipairs(list) do
        if v == '' or v == "." then
        elseif v == ".." then
            if c > 0 then
                out[c] = nil
                c = c - 1
            end
        else
            out[c] = v
        end
    end

    return table.concat(out, '/')
end

--- @alias Tar.FieldType
--- | 1 Null-terminated string
--- | 2 Null-terminated Octal
--- | 3 Char

--- @class Tar.Field
--- @field field string
--- @field size number
--- @field type Tar.FieldType

--- @type Tar.Field[]
TarS.fields = {
    { field = "pathname", size = 100, type = 1 }, -- 0
    { field = "mode", size = 8, type = 2 }, -- 100
    { field = "uid", size = 8, type = 2 }, -- 108
    { field = "gid", size = 8, type = 2 }, -- 116
    { field = "size", size = 12, type = 2 }, -- 124
    { field = "mtime", size = 12, type = 2 }, -- 136
    { field = "checksum", size = 8, type = 2 }, -- 148
    { field = "type", size = 1, type = 3 }, -- 156
    { field = "linkname", size = 100, type = 1 }, -- 157
    -- this should be split to us_magic (6, 1) and us_version (2, 2),
    -- but GNU tar 1.35 still uses OLDGNU_MAGIC, defined as "ustar00\0".
    -- instead of splitting the magic and version, combine them instead
    { field = "ustar", size = 8, type = 1 }, -- 257
    { field = "uname", size = 32, type = 1 }, -- 265
    { field = "gname", size = 32, type = 1 }, -- 297
    { field = "devmajor", size = 8, type = 1 }, -- 329
    { field = "devminor", size = 8, type = 1 }, -- 337
    { field = "prefix", size = 155, type = 1 } -- 345
    -- 500
}

--- Gets header checksum. Checksum value is interpreted as whitespace
--- @param ptr ffi.cdata*
--- @return number
function TarS.sumHeader(ptr)
    local sum = 256 -- checksum value (8 bytes) is treated as whitespace (32)
    for i=0, 148-1, 1 do
        sum = sum + ptr[i]
    end
    for i=148+8, 512-1, 1 do
        sum = sum + ptr[i]
    end
    return sum
end

--#endregion

--- @alias Tar.EntryType Tar.Entry | Tar.Symlink | Tar.File | Tar.Dir

return Tar