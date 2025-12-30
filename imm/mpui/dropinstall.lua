local filehook = love.filedropped
function love.filedropped(file) --- @diagnostic disable-line
	local mplist = G.OVERLAY_MENU and G.OVERLAY_MENU.config.imm_mplist
    if mplist then
        local ok, res = pcall(mplist.modpacks.import, mplist.modpacks, file:read('data'), true)
		file:seek(0)
		if ok then
			mplist:updateList()
			mplist.tasks.status:update('Added ' .. res.name)
		else
			mplist.tasks.status:update(nil, res) --- @diagnostic disable-line
		end
    end
    if filehook then return filehook(file) end
end
