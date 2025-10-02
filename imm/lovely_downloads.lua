local base = 'https://github.com/ethangreen-dev/lovely-injector/releases/latest/download/'

local macos_arm = 'lovely-aarch64-apple-darwin.tar.gz'
local macos_intel = 'lovely-x86_64-apple-darwin.tar.gz'
local windows = 'lovely-x86_64-pc-windows-msvc.zip'
local linux = 'lovely-x86_64-unknown-linux-gnu.tar.gz'
local url

local is_arm = jit.arch:find('arm')
local is_intel = jit.arch:find('x')

if jit.os == 'OSX' and false then -- targz unimplemented
    if is_arm then
        url = macos_arm
    elseif is_intel then
        url = macos_intel
    end
elseif jit.os == 'Linux' and false then -- targz unimplemented, custom installation
    if is_intel then
        url = linux
    end
elseif jit.os == 'Windows' then
    if is_intel then
        url = windows
    end
end
if url then
    url = base..url
end

return url or false