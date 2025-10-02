--- @meta https

--- @class luahttps
local luahttps = {}

--- @class luahttps.Options
--- @field data? string
--- @field method? string
--- @field headers? table<string, string|nil>

--- @param url string
--- @param options? luahttps.Options
--- @return number? code
--- @return string? body
--- @return table<string, string>? headers
function luahttps.request(url, options) end

return luahttps