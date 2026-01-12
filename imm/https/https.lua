local https = require("https")
local emptydata = love.filesystem.newFileData("", "")

local o = {}

function o.process(msg)
	--- @type imm.HttpsAgent.Req
	local req = msg.req
	local res = { pcall(https.request, req.url, req.options) }
	if not res[1] then
		print('imm/https: request failed:', res[2])
		return { -1, res[2] }
	end

	if req.options and req.options.restype == 'data' then
		local str = res[3]
		res[3] = str and str:len() > 0 and love.data.newByteData(str) or emptydata
	end
	return {unpack(res, 2, 4)}
end

function o.destroy()
end

return o