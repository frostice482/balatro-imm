local v = require('imm.lib.version')

for line in io.lines() do
    if line == "" then break end
    local ver = v(line)
    print(ver.major, ver.minor, ver.patch, ver.rev)
end