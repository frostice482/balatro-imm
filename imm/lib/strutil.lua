local ffi = require("ffi")

ffi.cdef[[
char* strstr(const char* str, const char* substr);
char* strchr(const char* str, int ch);
char* strrchr(const char* str, int ch);
char* memchr(const char* str, int ch, size_t count);
long strtol(const char* str, char** str_end, int base);
double strtod(const char* str, char** endptr);
int strncmp(const char* lhs, const char* rhs, size_t count);
size_t strspn(const char* str1, const char* str2);
size_t strcspn(const char* str1, const char* str2);
]]

local char_ptr = ffi.typeof("char*")
local char_arr = ffi.typeof("char[?]")
local const_char_ptr = ffi.typeof("const char*")
local sizet = ffi.typeof("size_t")

--- Creates a new `char[]` from given string
--- @param str string
local function new_strchar(str)
    return char_arr(str:len()+1, str)
end

--- Casts string to uint8_t and prevents the string from being garbage-collected
--- until returned pointer is garbage collected
--- @param str string
local function string_cast(str)
    local ptr = ffi.cast(char_ptr, str)
    ffi.gc(ptr, function () str = nil end) --- @diagnostic disable-line
    return ptr
end

--- Consumes a set of characters and returns the next index of non-matching characters
--- @param ptr ffi.cdata*
--- @param idx ffi.cdata*
--- @param expected ffi.cdata*
--- @return ffi.cdata*
local function consume(ptr, idx, expected)
    local c = ptr[idx]
    for i=0, 0x7fffffff, 1 do
        local e = expected[i]
        if e == 0 then
            break
        end
        if c == e then
            idx = idx + ffi.C.strspn(ptr+idx, expected)
            break
        end
    end
    -- magic optimization.
    -- no, i seriously dont know why this works.
    -- replacing break with return somehow makes it ultra slower
    -- (in some cases)
    return idx
end

local whitespaceChars = new_strchar(" \r\n\t\f")

--- Consumes whitespaces (CR, LF, FF, TAB)
--- @param ptr ffi.cdata*
--- @param idx ffi.cdata*
local function consumeWhitespace(ptr, idx)
    return consume(ptr, idx, whitespaceChars)
end

local byte = string.byte

--- @class p.StrUtil.Chars
local constants = {
    a = byte'a',
    b = byte'b',
    c = byte'c',
    d = byte'd',
    e = byte'e',
    f = byte'f',
    g = byte'g',
    i = byte'i',
    h = byte'h',
    j = byte'j',
    k = byte'k',
    l = byte'l',
    m = byte'm',
    n = byte'n',
    o = byte'o',
    p = byte'p',
    q = byte'q',
    r = byte'r',
    s = byte's',
    t = byte't',
    u = byte'u',
    v = byte'v',
    w = byte'w',
    x = byte'x',
    y = byte'y',
    z = byte'z',
    A = byte'A',
    B = byte'B',
    C = byte'C',
    D = byte'D',
    E = byte'E',
    F = byte'F',
    G = byte'G',
    H = byte'H',
    I = byte'I',
    J = byte'J',
    K = byte'K',
    L = byte'L',
    M = byte'M',
    N = byte'N',
    O = byte'O',
    P = byte'P',
    Q = byte'Q',
    R = byte'R',
    S = byte'S',
    T = byte'T',
    U = byte'U',
    V = byte'V',
    W = byte'W',
    X = byte'X',
    Y = byte'Y',
    Z = byte'Z',
    d0 = byte'0',
    d1 = byte'1',
    d2 = byte'2',
    d3 = byte'3',
    d4 = byte'4',
    d5 = byte'5',
    d6 = byte'6',
    d7 = byte'7',
    d8 = byte'8',
    d9 = byte'9',
    tilde = byte'~',
    backtick = byte'`',
    exclMark = byte'!',
    at = byte'@',
    hash = byte'#',
    dollar = byte'$',
    percent = byte'%',
    caret = byte'^',
    ampersand = byte'&',
    asterisk = byte'*',
    openRBr = byte'(',
    closeRBr = byte')',
    minus = byte'-',
    underscore = byte'_',
    equals = byte'=',
    plus = byte'+',
    openSqBr = byte'[',
    closeSqBr = byte']',
    openCBr = byte'{',
    closeCBr = byte'}',
    backslash = byte'\\',
    vertBar = byte'|',
    semicolon = byte';',
    colon = byte':',
    quotMark = byte'"',
    tickMark = byte'\'',
    dot = byte'.',
    comma = byte',',
    lessThan = byte'<',
    greaterThan = byte'>',
    slash = byte'/',
    questionMark = byte'?',
    newline = byte'\n',
    cr = byte'\r',
    tab = byte'\t',
    ff = byte'\f',
    vtab = byte'\v',
    backspace = byte'\b',
    null = 0
}

return {
    consume = consume,
    consumeWhitespace = consumeWhitespace,
    newCharArray = new_strchar,
    castString = string_cast,

    charptr = char_ptr,
    chararr = char_arr,
    constcharptr = const_char_ptr,
    size_t = sizet,
    size_t_0 = sizet(0),
    NULL = ffi.cast('void*', 0),

    json_arrtype = {},
    ffi = ffi,

    chars = constants
}