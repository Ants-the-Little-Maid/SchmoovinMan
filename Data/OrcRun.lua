local _, ns = ...

--[[ Orc runs: now and then a chosen player's run is different. Their Tauren is
an orc, kept at the zone-1 speed, the camera pulls back so it runs near the top
of the view, and Tauren Schmoovers come up from behind, faster and faster, to
be dodged. Gameplay is in Game/World.lua (mode "orc"), drawing in
Render/Renderer.lua and the lines in Data/Assets.lua (quips).

Who gets them, about 1 run in 25, is set by character name (full name or
first name). /schmoove orc turns every run into one, on any character, until
/reload, for trying it out.

Names are kept as fingerprints (NameKey), not written out, so the source
doesn't say who it's for. A fingerprint only keeps a name out of plain sight:
someone guessing names can still check them. Pure Lua, so tests can load it.
]]
local OrcRun = {}
ns.OrcRun = OrcRun

OrcRun.CHANCE = { target = 1 / 25 }

-- NameKey fingerprints of full names.
OrcRun.targets = {
	["87d37668"] = true,
}

-- Set by /schmoove orc for this session.
OrcRun.forced = false

-- A name's fingerprint: djb2 over its bytes with A-Z lowered, as 8 hex digits.
-- Spaces and other ASCII marks are skipped, so a full name matches however
-- the game joins first name and surname. Only ASCII letters are lowered, the
-- sums stay in floats (exact well past 2^32) and the digits are printed in
-- 16-bit halves, so it comes out the same in every Lua, whatever its integer
-- size.
function OrcRun.NameKey(name)
	local hash = 5381.0
	for index = 1, #name do
		local byte = name:byte(index)
		if byte >= 65 and byte <= 90 then
			byte = byte + 32
		end
		local letter = byte >= 128 or (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57)
		if letter then
			hash = (hash * 33.0 + byte) % 4294967296.0
		end
	end
	return string.format("%04x%04x", math.floor(hash / 65536), hash % 65536)
end

local function RoleOf(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if OrcRun.targets[OrcRun.NameKey(name)] then
		return "target"
	end
	return nil
end

-- "target" or nil for a character, by full name or first name.
function OrcRun.RoleFor(fullName, firstName)
	return RoleOf(fullName) or RoleOf(firstName)
end

-- "orc" when a run should be an orc run: always when forced, otherwise by the
-- role's chance. `unit` is a random number in [0, 1).
function OrcRun.Roll(role, forced, unit)
	if forced then
		return "orc"
	end
	local chance = role and OrcRun.CHANCE[role]
	if chance and unit < chance then
		return "orc"
	end
	return nil
end
