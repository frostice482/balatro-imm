--- @class imm.Util.Fs
local util = {}

--- @param source string
--- @param target string
--- @param sourceNfs? boolean
--- @param targetNfs? boolean
--- @param excludes? fun(source: string, target: string): boolean?
function util.cpdir(source, target, sourceNfs, targetNfs, excludes)
    local sourceProv = sourceNfs and NFS or love.filesystem
    local targetProv = targetNfs and NFS or love.filesystem

    if excludes and excludes(source, target) then return end

    local stat = sourceProv.getInfo(source)
    if not stat then error(string.format('stat %s returned undefined', source)) end

    if stat.type == 'file' then
        assert(targetProv.write(target,
            assert(sourceProv.newFileData(source))
        ))
    elseif stat.type == 'directory' then
        assert(targetProv.createDirectory(target))
        local items = sourceProv.getDirectoryItems(source)
        for i, item in ipairs(items) do
            util.cpdir(source..'/'..item, target..'/'..item, sourceNfs, targetNfs, excludes)
        end
    end
end

--- @param path string
--- @param isNfs boolean
function util.rmdir(path, isNfs)
    local prov = isNfs and NFS or love.filesystem
    local info = prov.getInfo(path)

    if info and info.type == 'directory' then
        local items = prov.getDirectoryItems(path)
        for i, item in ipairs(items) do
            local ok, x = util.rmdir(path .. '/' .. item, isNfs)
            if not ok then return ok, x end
        end
    end
    return prov.remove(path), path
end

return util