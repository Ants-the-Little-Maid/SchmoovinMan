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
-- Clear the roadside first, so no randomly spawned jogger is passed during the check.
for _, record in ipairs(r.joggers) do
	r:FreeRecord(record)
end
r.joggers, r.passes, r.joggerNext = {}, {}, 1e9
local function JoggerOf(race)
	for _, list in ipairs(ns.Assets.joggers) do
		if list.race == race then
			return list
		end
	end
	error("no " .. race .. " jogger list")
end
local tauren = r:NewRecord(JoggerOf("tauren"), "jogger")
tauren.race, tauren.side, tauren.x, tauren.y = "tauren", 1, 5, 12
table.insert(r.joggers, tauren)
said = {}
Frames(3)
assert(said[1] and compliments[said[1]], "runner didn't compliment the tauren: " .. tostring(said[1]))
assert(said[2] and replies[said[2]], "tauren didn't reply: " .. tostring(said[2]))
print("tauren exchange: " .. said[1] .. " / " .. said[2])
local orc = r:NewRecord(JoggerOf("orc"), "jogger")
orc.race, orc.side, orc.x, orc.y = "orc", -1, -5, 4
table.insert(r.joggers, orc)
C:HideBubbles()
C.nextQuip = 0
said = {}
Frames(3)
assert(said[1] and not taurenLines[said[1]], "orc jogger used a tauren line: " .. tostring(said[1]))
-- A famous face gets their own line, then answers with their own reply.
local famousList
for _, list in ipairs(ns.Assets.joggers) do
	if list.name == "Thrall" then
		famousList = list
	end
end
assert(famousList, "no Thrall jogger list")
local famousLines, famousReplies = {}, {}
for _, line in ipairs(famousList.lines) do famousLines[line] = true end
for _, line in ipairs(famousList.replies) do famousReplies[line] = true end
for _, record in ipairs(r.joggers) do
	r:FreeRecord(record)
end
r.joggers, r.passes = {}, {}
r.joggerNext = 1e9
local thrall = r:NewRecord(famousList, "jogger")
thrall.race, thrall.name, thrall.lines, thrall.replies = famousList.race, famousList.name, famousList.lines, famousList.replies
thrall.side, thrall.x, thrall.y = 1, 5, 12
table.insert(r.joggers, thrall)
C:HideBubbles()
C.nextQuip = 0
said = {}
Frames(3)
assert(said[1] and famousLines[said[1]], "runner didn't use Thrall's lines: " .. tostring(said[1]))
assert(said[2] and famousReplies[said[2]], "Thrall didn't reply: " .. tostring(said[2]))
print("famous exchange: " .. said[1] .. " / " .. said[2])
-- Running into an Alliance jogger knocks them over, with a line and points.
local knockLines = {}
for _, line in ipairs(ns.Assets.quips.knock) do knockLines[line] = true end
C:HideBubbles()
said = {}
local knocksBefore = C.world.knocks
C.world:AddEntity("alliance", C.world.runner.lane, C.world.time + 0.6, 0)
Frames(2)
assert(C.world.knocks == knocksBefore + 1, "Alliance jogger wasn't knocked")
assert(said[1] and knockLines[said[1]], "no knock line: " .. tostring(said[1]))
print("knock: " .. said[1])
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

-- Minimap right-click menu, through a stub of the game's MenuUtil.
local function Description()
	local d = { items = {} }
	local function add(kind, text, a, b)
		local item = { kind = kind, text = text, a = a, b = b, sub = Description() }
		table.insert(d.items, item)
		return item.sub
	end
	function d:CreateTitle(text) return add("title", text) end
	function d:CreateButton(text, callback) return add("button", text, callback) end
	function d:CreateRadio(text, isSelected, setSelected) return add("radio", text, isSelected, setSelected) end
	function d:CreateCheckbox(text, isSelected, setSelected) return add("checkbox", text, isSelected, setSelected) end
	function d:CreateDivider() return add("divider") end
	return d
end
local function Find(d, text)
	for _, item in ipairs(d.items) do
		if item.text == text then return item end
		local found = Find(item.sub, text)
		if found then return found end
	end
end
local menuRoot
MenuUtil = { CreateContextMenu = function(owner, generator) menuRoot = Description(); generator(owner, menuRoot) end }
local mini = _G.SchmoovinManMinimapButton
C.frame:Hide()
C.state = "closed"
mini.scripts.OnClick(mini, "RightButton")
assert(menuRoot and Find(menuRoot, "Start a run"), "right-click menu missing Start a run")
Find(menuRoot, "Start a run").a()
assert(C.frame.shown and C.state == "running", "quick start didn't open straight into a run")
local zone15 = Find(menuRoot, "15 s (Frantic)")
local liveZone = C.world.tuning.zoneLength
zone15.b()
assert(ns.Tuning.zoneLength == 15 and zone15.a(), "menu zone length didn't apply")
assert(C.world.tuning.zoneLength == liveZone, "menu zone length reached the live run")
Find(menuRoot, "Large").b()
assert(ns.db.settings.windowSize == "large", "menu window size didn't apply")
local duck = Find(menuRoot, "Ducking")
local before = duck.a()
duck.b()
assert(duck.a() ~= before, "menu ducking checkbox didn't toggle")
local sound = Find(menuRoot, "Sound")
local soundBefore = sound.a()
sound.b()
assert(sound.a() ~= soundBefore, "menu sound checkbox didn't toggle")
-- Quick start with a paused run brings it back instead of starting over.
C:Pause("")
local pausedWorld = C.world
C.frame:Hide()
C:QuickStart()
assert(C.world == pausedWorld and C.state == "paused", "quick start threw away a paused run")
-- Without a menu system, right-click still quick-starts.
MenuUtil = nil
C:QuitRun()
mini.scripts.OnClick(mini, "RightButton")
assert(C.state == "running", "right-click fallback didn't start a run")

-- The runner is sized from its active box (2 yards tall in the stub), not the
-- larger max box, and stays inside the sane character scale range.
local runnerScale = C.renderer:Fit(C.renderer.runner)
assert(runnerScale and math.abs(runnerScale - ns.Assets.runnerHeight / 2) < 1e-6, "runner not sized from its active box: " .. tostring(runnerScale))
-- Riding the wind rider leaves the runner's actor scaled by the mount, so
-- landing gives the runner a fresh actor and keeps the old one out of the pool.
do
	local R = C.renderer
	local before = R.runner.actor
	C.world.safeLeft = 1e9
	C.world:ApplyPowerup("windRider")
	Frames(1)
	assert(R.mount and R.mountAttached, "wind rider didn't attach the runner")
	assert(R.runner.actor == before, "runner actor changed before landing")
	local mountActor = R.mount.actor
	-- Let the flight run out and the runner come down.
	Frames(ns.Tuning.durations.windRider + 2)
	assert(not C.world.runner.flying and not R.mount, "wind rider still there after landing")
	assert(R.runner.actor ~= before, "runner kept the actor it rode with")
	assert(R.runner.actor ~= mountActor, "runner was given the actor that was the mount")
	for _, actor in ipairs(R.scene.freeActors) do
		assert(actor ~= before, "the ridden runner actor went back to the pool")
	end
	-- Quitting mid-flight does the same.
	local again = R.runner.actor
	C.world:ApplyPowerup("windRider")
	Frames(1)
	assert(R.mountAttached, "wind rider didn't attach the second time")
	R:Reset()
	assert(not R.mount and R.runner.actor ~= again, "reset mid-flight kept the ridden runner actor")
	C.world.safeLeft = 0
end
-- A model whose geometry hasn't streamed in yet is not measured.
local waiting = C.renderer:NewRecord({ { fileID = 123456789 } }, "jogger")
rawset(waiting.actor, "IsGeoReady", function() return false end)
C.renderer:CheckLoaded(waiting)
assert(not waiting.ready and not C.renderer.bounds["f123456789"], "measured a model before its geometry was ready")
-- In Forever the signal can stay false forever for props: after a short wait
-- the model must be measured and shown anyway, never dropped as failed.
clock = clock + 1.5
C.renderer:CheckLoaded(waiting)
assert(waiting.ready and not waiting.failed, "model stuck invisible while its geometry signal stayed false")
C.renderer:FreeRecord(waiting)
-- Copies of one model failing together are reported once.
C.renderer:TakeFailures()
local copies = {}
for index = 1, 3 do
	copies[index] = C.renderer:NewRecord({ { fileID = 987654321 } }, "low")
	rawset(copies[index].actor, "IsLoaded", function() return false end)
end
clock = clock + 11
for _, copy in ipairs(copies) do
	C.renderer:CheckLoaded(copy)
end
local failed = C.renderer:TakeFailures()
assert(#failed == 1 and failed[1] == "f987654321", "failure reported more than once: " .. table.concat(failed, ", "))
for _, copy in ipairs(copies) do
	C.renderer:FreeRecord(copy)
end

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

-- Forever surnames: UnitName returns the surname second. Runs saved under the
-- first name move to the full name, the character's own guild messages are
-- ignored, and it isn't ranked against itself.
local board = ns.GuildBoard.List()
local mine = ns.GuildBoard.MyBest()
assert(mine.character == "Moohammed", "expected a first-name run to migrate")
UnitName = function() return "Moohammed", "Schmoove" end
assert(ns.PlayerName() == "Moohammed Schmoove", "full name not built: " .. tostring(ns.PlayerName()))
ns.GuildBoard.AdoptFullName()
assert(mine.character == "Moohammed Schmoove", "run not moved to the full name")
assert(ns.GuildBoard.MyBest() == mine, "full-name character lost its best")
for _, f in ipairs(eventFrames) do
	if rawget(f, "events") and rawget(f, "events").CHAT_MSG_ADDON then
		f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "SchmoovinMan", "B|" .. (mine.score + 1) .. "|900|40|2|1793800000", "GUILD", "Moohammed Schmoove-Realm")
	end
end
local names, selfRows = {}, 0
for _, entry in ipairs(ns.GuildBoard.List()) do
	names[entry.name] = true
	if entry.name == "Moohammed Schmoove" then
		selfRows = selfRows + 1
		assert(entry.score == mine.score, "own echoed message replaced the board entry")
	end
end
assert(not names.Moohammed, "first-name entry still on the guild board")
assert(selfRows == 1, "expected one row for the character, got " .. selfRows)
local others = 0
for _, entry in ipairs(ns.GuildBoard.List()) do
	if entry.name ~= "Moohammed Schmoove" and entry.score > mine.score then
		others = others + 1
	end
end
assert(ns.GuildBoard.RankFor(mine.score) == others + 1, "ranked against itself")
UnitName = realName
-- The guild badge only shows for this character's new best, not every run.
C.screens.guildText.SetText = function(self, text) self.value = text end
C:StartRun()
C.world.score = 99999999
C:EndRun()
assert(C.screens.guildBadge.shown, "guild badge missing for a new best")
assert(C.screens.guildText.value == "#1 in guild", "new best not ranked #1: " .. tostring(C.screens.guildText.value))
C:StartRun()
C.world.score = 1
C:EndRun()
assert(not C.screens.guildBadge.shown, "guild badge shown for a run that isn't this character's best")
print("templates used: " .. table.concat((function() local t = {} for k in pairs(templatesUsed) do t[#t + 1] = k end table.sort(t) return t end)(), ", "))
print(("smoke ok: %d scores, guild board %d, %d messages sent, best %s"):format(#ns.db.scores, #ns.GuildBoard.List(), #sent, tostring(ns.db.scores[1].score)))
