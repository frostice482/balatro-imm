local UI = require("imm.mpui.confirm")
local co = require("imm.lib.co")

G.FUNCS[UI.funcs.confirm] = function (e)
    --- @type imm.UI.MP.CT
    local r = e.config.ref_table

    if r.allowFileOverride then
        pcall(r.mp.applyFiles, r.mp)
    end

    for id, act in pairs(r.list.actions) do
        if not act.impossible then
            local mod = act.mod
            if act.action == 'enable' or act.action == 'switch' then
                assert(r.ctrl:enableMod(mod))
            elseif act.action == 'disable' then
                assert(r.ctrl:disableMod(mod))
            end
        end
    end

    r.mpses.hasChanges = true
	r.mpses:showOverlay()
end

G.FUNCS[UI.funcs.back] = function (e)
	e.config.ref_table:showOverlay()
end

G.FUNCS[UI.funcs.download] = function (e)
    --- @type imm.UI.MP.CT
	local r = e.config.ref_table
    local ses = r.mpses
    local down = ses.tasks:createDownloadCoSes()
    down.allowNoReleaseUseCommit = false
    down.installMissings = false

    for id in pairs(r.list.missingDeps) do
        local entry = r.mp.mods[id]
        if entry and entry.url then
            co.create(function ()
                down:download(entry.url, { name = string.format('%s %s', id, entry.version) })
            end)
        end
    end

    ses:showOverlay()
end

G.FUNCS[UI.funcs.viewFiles] = function (e)
    --- @type imm.UI.MP.CT
	local r = e.config.ref_table
    love.system.openURL(r.mp:fileURL('files'))
end
