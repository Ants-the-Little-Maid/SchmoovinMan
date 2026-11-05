-- Loads the whole Schmoovin Man addon against stub WoW functions and plays runs.
-- Usage: lua tests/schmoovin_smoke.lua <addon folder> <TOC .lua files, comma separated>
local root = arg[1]

local clock = 0
local calls = {}

-- Any widget: unknown methods are no-ops; a few return useful values.
local function Widget(kind)
	local w = { kind = kind, scripts = {}, shown = true, alpha = 1, w = 960, h = 566 }
	local special = {
		GetSize = function(self) return self.w, self.h end,
		GetWidth = function(self) return self.w end,
		GetHeight = function(self) return self.h end,
		GetLeft = function() return 100 end,
		GetBottom = function() return 100 end,
		GetCenter = function() return 500, 400 end,
		GetEffectiveScale = function() return 1 end,
		GetFrameLevel = function() return 1 end,
		IsShown = function(self) return self.shown end,
		Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
		Hide = function(self) local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end,
		SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
		SetScript = function(self, name, fn) self.scripts[name] = fn end,
		GetScript = function(self, name) return self.scripts[name] end,
		CreateTexture = function() return Widget("Texture") end,
		CreateFontString = function() return Widget("FontString") end,
		CreateLine = function() return Widget("Line") end,
		GetStringWidth = function() return 100 end,
		GetStringHeight = function() return 14 end,
		GetFontString = function(self) return Widget("FontString") end,
		SetTexture = function() return true end,
		CreateActor = function() return Widget("Actor") end,
		IsLoaded = function() return true end,
		IsGeoReady = function() return true end,
		SetAlpha = function(self, a) rawset(self, "lastAlpha", a) end,
		GetActiveBoundingBox = function() return -0.5, -0.5, 0, 0.5, 0.5, 2 end,
		GetMaxBoundingBox = function() return { x = -1.5, y = -0.4, z = 0 }, { x = 2.5, y = 0.6, z = 2.2 } end,
		SetModelByFileID = function() return true end,
		SetModelByCreatureDisplayID = function() return true end,
		AttachToMount = function() return true end,
		DetachFromMount = function() return true end,
		GetCameraForward = function() return 0, 0.95, -0.3 end,
		GetCameraPosition = function() return 0, -4, 4 end,
		Project3DPointTo2D = function(self, x, y, z)
			local depth = y + 4
			if depth <= 0.1 then return nil end
			return 480 + x / depth * 500, 283 + (z - 1.2) / depth * 500 - 60, depth
		end,
		RegisterEvent = function(self, e) local ev = rawget(self, "events") or {}; rawset(self, "events", ev); ev[e] = true end,
	}
	return setmetatable(w, {
		__index = function(t, k)
			if special[k] then return special[k] end
			return function() calls[k] = (calls[k] or 0) + 1 end
		end,
	})
end

local eventFrames = {}
local templatesUsed = {}
CreateFrame = function(kind, name, parent, template)
	local f = Widget(kind)
	if template then
		templatesUsed[template] = true
	end
	f.shown = kind ~= "Frame" or name ~= "SchmoovinManFrame"
	if name then _G[name] = f end
	eventFrames[#eventFrames + 1] = f
	return f
end
UIParent = Widget("Frame")
Minimap = Widget("Frame")
GameTooltip = Widget("GameTooltip")
UISpecialFrames = {}
BackdropTemplateMixin = {}
Enum = { ModelLightType = { Directional = 1 }, SendAddonMessageResult = { Success = 0 } }
SOUNDKIT = { LOOT_WINDOW_COIN_SOUND = 120 }
PlaySound = function() end
GetTime = function() return clock end
time = function() return 1793900000 + math.floor(clock) end
InCombatLockdown = function() return false end
UnitName = function() return "Moohammed" end
IsInGuild = function() return true end
GetGuildInfo = function() return "Hooves" end
GetRealmName = function() return "Realm" end
IsInInstance = function() return false end
Ambiguate = function(s) return (s:gsub("%-.*", "")) end
GetCursorPosition = function() return 0, 0 end
CreateColor = function(r, g, b, a) return { r, g, b, a } end
C_Timer = { After = function(_, fn) end }
local sent = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return 0 end, SendAddonMessage = function(p, m, c) sent[#sent + 1] = m; return 0 end }
SlashCmdList = {}
tinsert, tremove, wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
math.atan2 = math.atan2 or math.atan
print = print

local ns = {}
-- arg[2]: the TOC's file list, comma separated (fengari has no io.open).
for line in arg[2]:gmatch("[^,]+") do
	if line:match("%.lua$") then
		local chunk = assert(loadfile(root .. "/" .. line:gsub("\\", "/")))
		chunk("SchmoovinMan", ns)
	end
end

-- Fire ADDON_LOADED through the core's event frame.
for _, f in ipairs(eventFrames) do
	if rawget(f, "events") and rawget(f, "events").ADDON_LOADED then
		f.scripts.OnEvent(f, "ADDON_LOADED", "SchmoovinMan")
		f.scripts.OnEvent(f, "PLAYER_ENTERING_WORLD")
		f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "SchmoovinMan", "B|5000|900|40|2|1793800000", "GUILD", "Hornswaggle-Realm")
		f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "SchmoovinMan", "junk", "GUILD", "Bad-Realm")
	end
end
assert(ns.db, "saved variables not set up")

SlashCmdList.SCHMOOVINMAN("")
local C = ns.Controller
assert(C.frame.shown, "window did not open")
assert(C.state == "start", "expected start screen, got " .. tostring(C.state))

local function Frames(seconds)
	for _ = 1, seconds * 60 do
		clock = clock + 1 / 60
		C.frame.scripts.OnUpdate(C.frame, 1 / 60)
	end
end

Frames(1)
C.keys.scripts.OnKeyDown(C.keys, "ENTER")
assert(C.state == "running", "Enter didn't start a run")
-- Exercise keys, power-ups, zone change and a crash.
for _, key in ipairs({ "A", "D", "D", "W", "S", "SPACE", "LEFT" }) do
	C.keys.scripts.OnKeyDown(C.keys, key)
	C.keys.scripts.OnKeyUp(C.keys, key)
	Frames(0.3)
end
for _, role in ipairs({ "windRider", "magnet", "goldRush", "stampede", "shield" }) do
	C.world:ApplyPowerup(role)
	Frames(0.5)
end
C.keys.scripts.OnKeyDown(C.keys, "P")
assert(C.state == "paused", "P didn't pause")
C.keys.scripts.OnKeyUp(C.keys, "P")
C.keys.scripts.OnKeyDown(C.keys, "P")
assert(C.state == "running", "P didn't resume")
C.keys.scripts.OnKeyUp(C.keys, "P")
local said = {}
local realSay = ns.Bubble.Say
ns.Bubble.Say = function(self, text, untilTime, anchor)
	said[#said + 1] = text
	return realSay(self, text, untilTime, anchor)
end
C.world.safeLeft = 1e9
Frames(50)
assert(#said > 0, "no speech bubble after 50 seconds of joggers")
-- Tauren lines only ever come with Tauren joggers: force one past and check
-- the runner compliments them, then they reply.
local taurenLines, compliments, replies = {}, {}, {}
for _, line in ipairs(ns.Assets.quips.toTauren) do taurenLines[line] = true; compliments[line] = true end
for _, line in ipairs(ns.Assets.quips.taurenReply) do taurenLines[line] = true; replies[line] = true end
C:HideBubbles()
C.nextQuip = 0
local r = C.renderer
local tauren = r:NewRecord(ns.Assets.joggers[5], "jogger")
tauren.race, tauren.side, tauren.x, tauren.y = "tauren", 1, 5, 12
table.insert(r.joggers, tauren)
said = {}
Frames(3)
assert(said[1] and compliments[said[1]], "runner didn't compliment the tauren: " .. tostring(said[1]))
assert(said[2] and replies[said[2]], "tauren didn't reply: " .. tostring(said[2]))
print("tauren exchange: " .. said[1] .. " / " .. said[2])
local orc = r:NewRecord(ns.Assets.joggers[1], "jogger")
orc.race, orc.side, orc.x, orc.y = "orc", -1, -5, 4
table.insert(r.joggers, orc)
C:HideBubbles()
C.nextQuip = 0
said = {}
Frames(3)
assert(said[1] and not taurenLines[said[1]], "orc jogger used a tauren line: " .. tostring(said[1]))
-- High bars get posts.
local high = C.world:AddEntity("high", 2, C.world.time + 3, 0)
Frames(0.2)
assert(r.records[high.id] and r.records[high.id].posts and #r.records[high.id].posts == 2, "high bar has no posts")
-- Two high bars side by side are one barrier: inner posts hidden, outer shown.
local at = C.world.time + 3.5
local left = C.world:AddEntity("high", 1, at, 0)
local right = C.world:AddEntity("high", 2, at, 0)
Frames(0.2)
assert(left.joinRight and not left.joinLeft and right.joinLeft and not right.joinRight, "side-by-side bars not grouped")
local lp, rp = r.records[left.id].posts, r.records[right.id].posts
assert(lp[2].actor.alpha ~= nil, "post alpha not tracked")
print(("grouped bar posts: left outer %s, left inner %s, right inner %s, right outer %s"):format(
	tostring(lp[1].actor.lastAlpha), tostring(lp[2].actor.lastAlpha), tostring(rp[1].actor.lastAlpha), tostring(rp[2].actor.lastAlpha)))
assert(lp[2].actor.lastAlpha == 0 and rp[1].actor.lastAlpha == 0, "inner posts of a grouped bar are showing")
assert(lp[1].actor.lastAlpha > 0 and rp[2].actor.lastAlpha > 0, "outer posts of a grouped bar are hidden")
assert(C.world.zoneIndex >= 2, "zone didn't change")
C.world.safeLeft = 0
C.world.shield = false
C.world.powerups = {}
C.world:AddEntity("block", C.world.runner.lane, C.world.time + 0.3, 0)
Frames(3)
assert(C.state == "over", "crash didn't end the run, state " .. tostring(C.state))
assert(#ns.db.scores == 1, "score not saved")
C.screens:ShowBoard("guild")
C.screens:ShowBoard("mine")
C.keys.scripts.OnKeyDown(C.keys, "R")
assert(C.state == "running", "R didn't restart")
-- Close mid-run pauses.
C.frame:Hide()
assert(C.state == "paused", "closing didn't pause")
C.frame:Show()
for _, key in ipairs({ "small", "large", "huge", "medium", "bogus" }) do C:SetWindowSize(key); Frames(0.2) end
C:ShowStart(); C.screens.zoneButton.scripts.OnClick(C.screens.zoneButton); assert(ns.Tuning.zoneLength == 35, "zone button did not cycle"); SlashCmdList.SCHMOOVINMAN("zones 15"); assert(ns.Tuning.zoneLength == 15 and ns.db.settings.zoneLength == 15); SlashCmdList.SCHMOOVINMAN("zones 99"); assert(ns.Tuning.zoneLength == 25)
SlashCmdList.SCHMOOVINMAN("sound")
SlashCmdList.SCHMOOVINMAN("duck")
SlashCmdList.SCHMOOVINMAN("nonsense")

-- The runner is sized from its active box (2 yards tall in the stub), not the
-- larger max box, and stays inside the sane character scale range.
local runnerScale = C.renderer:Fit(C.renderer.runner)
assert(runnerScale and math.abs(runnerScale - ns.Assets.runnerHeight / 2) < 1e-6, "runner not sized from its active box: " .. tostring(runnerScale))
-- A model whose geometry hasn't streamed in yet is not measured.
local waiting = C.renderer:NewRecord({ { fileID = 123456789 } }, "jogger")
rawset(waiting.actor, "IsGeoReady", function() return false end)
C.renderer:CheckLoaded(waiting)
assert(not waiting.ready and not C.renderer.bounds["f123456789"], "measured a model before its geometry was ready")
rawset(waiting.actor, "IsGeoReady", function() return true end)
C.renderer:CheckLoaded(waiting)
assert(waiting.ready, "model not measured once its geometry was ready")
C.renderer:FreeRecord(waiting)

-- Settings changed mid-run wait for the next run.
C:StartRun()
local runDuck, runZone = C.world.tuning.duckEnabled, C.world.tuning.zoneLength
SlashCmdList.SCHMOOVINMAN("duck")
SlashCmdList.SCHMOOVINMAN("zones 45")
assert(C.world.tuning.duckEnabled == runDuck and C.world.tuning.zoneLength == runZone, "mid-run setting change reached the live run")
C:StartRun()
assert(C.world.tuning.duckEnabled == ns.Tuning.duckEnabled and C.world.tuning.zoneLength == 45, "next run didn't pick up the new settings")

-- An alt doesn't post the account's best under its own name.
local realName = UnitName
UnitName = function() return "Altchar" end
assert(ns.GuildBoard.MyBest() == nil, "alt claims the main's best")
local altBoard = ns.GuildBoard.List()
for _, entry in ipairs(altBoard) do
	assert(entry.name ~= "Altchar", "alt listed on the guild board with the main's score")
end
UnitName = realName
assert(ns.GuildBoard.MyBest() ~= nil, "main lost its own best")
print("templates used: " .. table.concat((function() local t = {} for k in pairs(templatesUsed) do t[#t + 1] = k end table.sort(t) return t end)(), ", "))
print(("smoke ok: %d scores, guild board %d, %d messages sent, best %s"):format(#ns.db.scores, #ns.GuildBoard.List(), #sent, tostring(ns.db.scores[1].score)))
