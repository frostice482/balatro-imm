local https = require("https")
local emptydata = love.filesystem.newFileData("", "")

local o = {}

function o.process(msg)
	--- @type imm.HttpsAgent.Req
	local req = msg.req
	local code, body, headers = https.request(req.url, req.options)

	if req.options and req.options.restype == 'data' then
		body = body and body:len() > 0 and love.data.newByteData(body) or emptydata --- @diagnostic disable-line
	end
	return {code, body, headers}
end

function o.destroy()
end

return o