local _, ns = ...

-- Guild board messages. Pure Lua so tests can load it.
--   Q                               ask guildmates for their best
--   B|score|tenths|tokens|zones|t   a best run (tenths of a second, unix time)
local Codec = {}
ns.Codec = Codec

Codec.PREFIX = "SchmoovinMan"

local LIMITS = {
	score = { 0, 100000000 },
	tenths = { 1, 3600000 },
	tokens = { 0, 1000000 },
	zones = { 1, 100000 },
	when = { 1000000000, 9999999999 },
}

function Codec.EncodeRequest()
	return "Q"
end

function Codec.EncodeBest(best)
	return string.format("B|%.0f|%.0f|%.0f|%.0f|%.0f", best.score, best.tenths, best.tokens, best.zones, best.when)
end

local function ReadNumber(text, limits)
	if type(text) ~= "string" or not text:match("^%d+$") or #text > 10 then
		return nil
	end
	local value = tonumber(text)
	if not value or value < limits[1] or value > limits[2] then
		return nil
	end
	return value
end

-- Returns "request", or "best" and a table, or nil for anything malformed.
function Codec.Decode(text)
	if type(text) ~= "string" or #text > 200 then
		return nil
	end
	if text == "Q" then
		return "request"
	end
	local score, tenths, tokens, zones, when = text:match("^B|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
	if not score then
		return nil
	end
	local best = {
		score = ReadNumber(score, LIMITS.score),
		tenths = ReadNumber(tenths, LIMITS.tenths),
		tokens = ReadNumber(tokens, LIMITS.tokens),
		zones = ReadNumber(zones, LIMITS.zones),
		when = ReadNumber(when, LIMITS.when),
	}
	if not (best.score and best.tenths and best.tokens and best.zones and best.when) then
		return nil
	end
	return "best", best
end
