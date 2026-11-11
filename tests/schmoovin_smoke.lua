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
		-- Try-on results: Success (0), unless a test sets TryOnResult(link).
		TryOn = function(self, link)
			calls.TryOn = (calls.TryOn or 0) + 1
			return TryOnResult and TryOnResult(link) or 0
		end,
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
-- The title bar's Pause button pauses and resumes, and says which.
local pauseButton = C.frame.pauseButton
rawset(pauseButton, "SetEnabled", function(self, on) rawset(self, "enabled", on) end)
rawset(pauseButton.text, "SetText", function(self, text) rawset(self, "value", text) end)
pauseButton.scripts.OnClick(pauseButton)
Frames(0.05)
assert(C.state == "paused" and pauseButton.text.value == "Resume" and pauseButton.enabled, "Pause button didn't pause")
pauseButton.scripts.OnClick(pauseButton)
Frames(0.05)
assert(C.state == "running" and pauseButton.text.value == "Pause", "Pause button didn't resume")
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
-- And the road, with nothing new for a while, so no Alliance jogger is
-- knocked over (with its own line) in the middle of an exchange.
C.world.entities = {}
C.world.cursor = C.world.time + 15
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
-- Where the camera is (distance ahead of the runner, height), from the
-- scene's look-at point, distance and tilt.
local function CameraOf(scene)
	return scene.targetY - scene.distance * math.cos(scene.pitch), scene.targetZ + scene.distance * math.sin(scene.pitch)
end
-- How far down the view (0 top, 1 bottom) a point shows. In the real client
-- the view spans tan(fov / 2) / 2.086 either side of its centre (measured
-- from a 0.10.0 screenshot).
local function FromTopOf(scene, y, z)
	local cy, cz = CameraOf(scene)
	local angle = math.atan2(z - cz, y - cy) + scene.pitch
	return 0.5 - 0.5 * math.tan(angle) / (math.tan(scene.fov / 2) / 2.086)
end
-- A boss fight, made due now in Westfall: banner, boss bar, the boss drawn,
-- throws with landing marks, spears thrown at it, then the driven-off banner
-- and the boss running off without coming back.
do
	local world = C.world
	local hud = C.hud
	local labels = {}
	rawset(hud.bannerLabel, "SetText", function(self, text) labels[#labels + 1] = text end)
	rawset(hud.bossCount, "SetText", function(self, text) rawset(self, "value", text) end)
	rawset(hud.zoneNext, "SetText", function(self, text) rawset(self, "value", text) end)
	local sceneFrame = r.scene.frame
	rawset(sceneFrame, "SetFogNear", function(self, value) rawset(self, "fogNear", value) end)
	rawset(sceneFrame, "SetFogFar", function(self, value) rawset(self, "fogFar", value) end)
	-- The run so far may have met its first boss already: see it off first.
	local earlier = world.boss
	if world:InFight() then
		world:EndBoss("survived")
		Frames(3)
		assert(not r.bossRecord, "earlier boss still drawn after leaving")
	end
	world.zoneOrder[world.zoneIndex] = "westfall"
	world.zoneKey = "westfall"
	world.bossZone = world.zoneIndex
	world.paused = world.paused - (world:BossStart() - world.time)
	world.safeLeft = 1e9
	Frames(0.2)
	assert(world.boss ~= earlier and world.boss.state == "fight" and world.boss.name == "Edwin VanCleef", "boss didn't turn up")
	assert(labels[#labels] == "BOSS", "no boss banner: " .. tostring(labels[#labels]))
	assert(hud.boss.shown, "boss bar not shown")
	-- The boss bar shares the top slot with banners: faded while the boss's
	-- banner shows, then fully there.
	assert(hud.boss.lastAlpha < 0.5, "boss bar not giving way to the banner: " .. tostring(hud.boss.lastAlpha))
	assert(hud.zoneNext.value:find("paused"), "zone line doesn't say it's paused: " .. tostring(hud.zoneNext.value))
	assert(hud.bossCount.value == "0 of " .. world.boss.needed .. " spears", "boss bar count: " .. tostring(hud.bossCount.value))
	assert(r.bossRecord and r.bossRecord.ready, "boss not drawn")
	-- Throws arc in with a mark where they land.
	local marks = 0
	for _ = 1, 300 do
		world.safeLeft = 1e9
		Frames(1 / 60)
		marks = math.max(marks, r.markers.count)
	end
	assert(marks > 0, "no landing marks for thrown hazards")
	-- The camera has moved to the fight view.
	local scene, fight = r.scene, ns.Renderer.FIGHT_CAMERA
	assert(math.abs(scene.pitch - fight.pitch) < 1e-9 and math.abs(scene.fov - fight.fov) < 1e-9, "camera didn't move to the fight view")
	local function Camera()
		return CameraOf(scene)
	end
	-- The fog has drawn back, keeping its depth, so the boss isn't lost in it.
	local fog = r.zone.fog
	local depth = fog.far - fog.near
	local fogNear, fogFar = rawget(sceneFrame, "fogNear") or fog.near, rawget(sceneFrame, "fogFar") or fog.far
	local cameraY, cameraZ = Camera()
	local into = (math.sqrt((ns.Tuning.boss.distance - cameraY) ^ 2 + cameraZ ^ 2) - fogNear) / depth
	assert(fogNear > fog.near and math.abs(fogFar - fogNear - depth) < 1e-6, "fog didn't draw back for the boss")
	assert(into <= 0.15 + 1e-6, ("boss still deep in the fog: %.2f of the way in"):format(into))
	-- The framing: the tallest boss's head under the boss bar (the top 9% of
	-- the view) and the runner's feet still in view.
	local function FromTop(y, z)
		return FromTopOf(scene, y, z)
	end
	local tallest = 0
	for _, zone in ipairs(ns.Zones) do
		tallest = math.max(tallest, zone.boss and zone.boss.height or 0)
	end
	local head, feet = FromTop(ns.Tuning.boss.distance, tallest), FromTop(0, 0)
	assert(head > 0.11, ("a %.1f-yard boss's head is behind the boss bar: %.2f from the top"):format(tallest, head))
	assert(feet < 0.98, ("runner's feet out of view in a fight: %.2f from the top"):format(feet))
	print(("fight view: tallest boss's head %.2f from the top, runner's feet %.2f"):format(head, feet))
	assert(hud.boss.lastAlpha == 1, "boss bar not showing after the banner: " .. tostring(hud.boss.lastAlpha))
	print(("boss: %s, %d spears needed, up to %d landing marks"):format(world.boss.name, world.boss.needed, marks))
	-- A spear grabbed is thrown at the boss.
	world:AddEntity("spear", world.runner.lane, world.time + 0.3, 0.9)
	local shot = false
	for _ = 1, 60 do
		world.safeLeft = 1e9
		Frames(1 / 60)
		shot = shot or #r.shots > 0
	end
	assert(world.boss.hits == 1 and shot, "spear wasn't thrown at the boss")
	assert(hud.bossCount.value == "1 of " .. world.boss.needed .. " spears", "boss bar didn't count the hit: " .. tostring(hud.bossCount.value))
	world.boss.hits = world.boss.needed - 1
	world:AddEntity("spear", world.runner.lane, world.time + 0.3, 0.9)
	Frames(1)
	assert(world.boss.state == "driven", "boss wasn't driven off")
	assert(labels[#labels] == "DRIVEN OFF", "no driven-off banner: " .. tostring(labels[#labels]))
	assert(not hud.boss.shown, "boss bar still shown")
	Frames(3)
	assert(not r.bossRecord, "boss still drawn after running off")
	Frames(1.5)
	local chase = ns.Renderer.CAMERA
	assert(math.abs(scene.pitch - chase.pitch) < 1e-9 and math.abs(scene.fov - chase.fov) < 1e-9, "camera didn't go back after the boss left")
	fogNear, fogFar = rawget(sceneFrame, "fogNear"), rawget(sceneFrame, "fogFar")
	assert(math.abs(fogNear - r.zone.fog.near) < 1e-6 and math.abs(fogFar - r.zone.fog.far) < 1e-6,
		"fog didn't settle back after the boss left: " .. fogNear)
	rawset(sceneFrame, "SetFogNear", nil)
	rawset(sceneFrame, "SetFogFar", nil)
	world.safeLeft = 1e9
	rawset(hud.bannerLabel, "SetText", nil)
	rawset(hud.bossCount, "SetText", nil)
	assert(hud.zoneNext.value:find("next in"), "zone line still paused after the boss left: " .. tostring(hud.zoneNext.value))
	rawset(hud.zoneNext, "SetText", nil)
end
-- A boss whose model never loads still leaves, and the camera goes back.
do
	local world = C.world
	world.bossZone = world.zoneIndex
	world.paused = world.paused - (world:BossStart() - world.time)
	world.safeLeft = 1e9
	Frames(0.2)
	assert(world:InFight() and r.bossRecord, "second boss didn't turn up")
	r.bossRecord.ready, r.bossRecord.failed = false, true
	world:EndBoss("survived")
	world.safeLeft = 1e9
	Frames(2.6)
	assert(not r.bossRecord, "a boss that never loaded is still held after leaving")
	Frames(1.5)
	assert(math.abs(r.scene.pitch - ns.Renderer.CAMERA.pitch) < 1e-9, "camera stuck in the fight view after an unloaded boss")
	world.safeLeft = 1e9
end
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
Frames(0.6)
-- Crashed, and still on screen for a moment: the run is over, so neither
-- the button nor P pauses it.
assert(C.world.over and C.state == "running", "not in the moment after the crash: " .. tostring(C.state))
assert(pauseButton.enabled == false, "Pause button not greyed out after the crash")
pauseButton.scripts.OnClick(pauseButton)
assert(C.state == "running", "the Pause button paused a crashed run")
C.keys.scripts.OnKeyDown(C.keys, "P")
C.keys.scripts.OnKeyUp(C.keys, "P")
assert(C.state == "running", "P paused a crashed run")
Frames(2.4)
assert(C.state == "over", "crash didn't end the run, state " .. tostring(C.state))
Frames(0.05)
assert(pauseButton.enabled == false, "Pause button not greyed out on the game-over screen")
-- Roadside scenery stands clear of the road, whatever its size: no corner of
-- its turned box within 1.5 yards of the edge (3.9 yards out).
local sceneryChecked = 0
for _, record in ipairs(C.renderer.scenery) do
	if record.ready then
		sceneryChecked = sceneryChecked + 1
		local box, scale = r.bounds[record.key], r:Fit(record)
		local c, s = math.cos(record.yaw), math.sin(record.yaw)
		local reach = 0
		for _, mx in ipairs({ box[1], box[4] }) do
			for _, my in ipairs({ box[2], box[5] }) do
				reach = math.max(reach, math.abs(mx * c - my * s) * scale)
			end
		end
		assert(record.offRoad and math.abs(record.x) - reach >= 3.9 + 1.5 - 1e-6,
			("scenery reaches the road: x %.2f, reach %.2f"):format(record.x, reach))
	end
end
assert(sceneryChecked > 0, "no scenery to check")
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
C:ShowStart(); C.screens.zoneButton.scripts.OnClick(C.screens.zoneButton); assert(ns.Tuning.zoneLength == 35, "zone button did not cycle"); SlashCmdList.SCHMOOVINMAN("zones 15"); assert(ns.Tuning.zoneLength == 15 and ns.db.settings.zoneLength == 15); SlashCmdList.SCHMOOVINMAN("zones 99"); SlashCmdList.SCHMOOVINMAN("zones"); assert(ns.Tuning.zoneLength == 15, "a wrong or missing zone length changed the setting"); SlashCmdList.SCHMOOVINMAN("speed 14"); SlashCmdList.SCHMOOVINMAN("speed 10"); assert(ns.Tuning.baseSpeed == 14, "a wrong starting speed changed the setting"); SlashCmdList.SCHMOOVINMAN("speed 11"); SlashCmdList.SCHMOOVINMAN("zones 25"); assert(ns.Tuning.zoneLength == 25 and ns.Tuning.baseSpeed == 11)
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
-- Starting speed, Options, model picks and the resume countdown ------------------
do
	-- /schmoove speed: the next run starts at that speed and scores with its
	-- multiplier; the start screen says so.
	C:ShowStart()
	SlashCmdList.SCHMOOVINMAN("speed 8")
	assert(ns.Tuning.baseSpeed == 8 and ns.Tuning.scoreMultiplier == 0.75 and ns.db.settings.startSpeed == 8, "/schmoove speed 8 didn't set a slow start")
	rawset(C.screens.speedButton.text, "SetText", function(self, text) rawset(self, "value", text) end)
	C.screens:UpdateZoneButton()
	assert(C.screens.speedButton.text.value == "Start: 8 yd/s (Slow, score x0.75)", "start screen speed: " .. tostring(C.screens.speedButton.text.value))
	C:StartRun()
	local world = C.world
	world.safeLeft = 1e9
	Frames(2)
	assert(math.abs(world.speed - (8 + ns.Tuning.rampPerSecond * world.time)) < 0.05, "slow run doesn't start at 8: " .. world.speed)
	local raw = world.tokenPoints + world.timePoints + world.movePoints + world.bossPoints
	assert(world.score == math.floor(raw * 0.75), "slow run's score isn't x0.75")
	C.screens.speedButton.scripts.OnClick(C.screens.speedButton)
	assert(ns.Tuning.baseSpeed == 11 and world.tuning.baseSpeed == 8, "speed button didn't cycle, or reached the live run")
	SlashCmdList.SCHMOOVINMAN("speed 99")
	assert(ns.Tuning.baseSpeed == 11 and ns.Tuning.scoreMultiplier == 1, "an unknown speed didn't fall back to Normal")

	-- Resume countdown: nothing moves for 3 seconds, keys wait, then it goes on.
	C:Pause("")
	C:Resume()
	local frozenAt = world.time
	local hud = C.hud
	rawset(hud.countdown, "SetText", function(self, text) rawset(self, "value", text) end)
	Frames(0.5)
	assert(world.time == frozenAt and hud.countdown.shown and hud.countdown.value == "3", "countdown not counting from 3: " .. tostring(hud.countdown.value))
	local lane = world.runner.lane
	C.keys.scripts.OnKeyDown(C.keys, lane == 1 and "D" or "A")
	C.keys.scripts.OnKeyUp(C.keys, lane == 1 and "D" or "A")
	assert(world.runner.lane == lane, "a lane key worked during the countdown")
	Frames(2)
	assert(world.time == frozenAt and hud.countdown.value == "1", "countdown didn't reach 1 with the run still held")
	Frames(0.6)
	assert(world.time > frozenAt and not hud.countdown.shown, "run didn't go on after the countdown")
	-- Pausing during the countdown stops it; with it off, Resume goes straight on.
	C:Pause("")
	C:Resume()
	Frames(0.2)
	C.keys.scripts.OnKeyDown(C.keys, "P")
	C.keys.scripts.OnKeyUp(C.keys, "P")
	assert(C.state == "paused" and not hud.countdown.shown and not C.countdownUntil, "P during the countdown didn't pause")
	ns.SetCountdown(false)
	C:Resume()
	local before = world.time
	Frames(0.2)
	assert(world.time > before, "with the countdown off, Resume didn't go straight on")
	ns.SetCountdown(true)

	-- Options: opening it mid-run pauses; each game row changes its setting.
	local options = C.options
	world.safeLeft = 1e9
	C:OpenOptions()
	assert(options:IsShown() and C.state == "paused", "Options didn't open, or the run didn't pause")
	local labels = {}
	for index, row in ipairs(options.gameRows) do
		rawset(row.button.text, "SetText", function(self, text) rawset(self, "value", text) end)
		labels[index] = row.label
	end
	local function Row(label)
		for _, row in ipairs(options.gameRows) do
			if row.label == label then
				return row
			end
		end
		error("no Options row " .. label)
	end
	local function Click(label)
		local button = Row(label).button
		button.scripts.OnClick(button)
		return button.text.value
	end
	local sound = ns.db.settings.sound
	assert(Click("Sound") == (sound and "Off" or "On") and ns.db.settings.sound ~= sound, "Options sound row")
	Click("Sound")
	local duck = ns.db.settings.duck
	Click("Ducking")
	assert(ns.db.settings.duck ~= duck, "Options ducking row")
	Click("Ducking")
	assert(Click("Resume countdown") == "Off" and ns.db.settings.countdown == false, "Options countdown row")
	Click("Resume countdown")
	local zoneLength = ns.Tuning.zoneLength
	Click("Zone length")
	assert(ns.Tuning.zoneLength ~= zoneLength and world.tuning.zoneLength == zoneLength, "Options zone length row")
	ns.SetZoneLength(zoneLength)
	assert(Click("Starting speed") == "14 yd/s (Fast, score x1.25)" and ns.Tuning.baseSpeed == 14, "Options starting speed row")
	ns.SetStartSpeed(11)
	local size = ns.db.settings.windowSize
	Click("Window size")
	assert(ns.db.settings.windowSize ~= size, "Options window size row")
	C:SetWindowSize(size)
	print("options rows: " .. table.concat(labels, ", "))

	-- Model picks: the next choice for Mulgore's low hazard is saved, drawn
	-- first from now on, and offered alongside the extras; going round comes
	-- back to the usual model and clears the pick.
	options.zoneIndex = 1
	options:Refresh()
	local mulgore = ns.Zones[1]
	assert(mulgore.key == "mulgore", "first zone isn't Mulgore")
	local choices = ns.Models.Choices(mulgore, "low")
	local lowRow
	for index, row in ipairs(options.modelRows) do
		if row.role == "low" then
			lowRow = index
		end
	end
	options:Cycle(lowRow, 1)
	local pickedKey = ns.Models.Key(choices[2])
	assert(ns.db.models.mulgore and ns.db.models.mulgore.low == pickedKey, "pick not saved")
	local list = C.renderer:ListFor({ role = "low" }, mulgore)
	assert(ns.Models.Key(list[1]) == pickedKey and #list == #ns.Models.List(mulgore, "low"), "picked model isn't drawn first")
	local extras = 0
	for _, candidate in ipairs(ns.Models.Choices(mulgore, "gem")) do
		assert(candidate.name, "a gem choice has no name")
		for _, extra in ipairs(ns.ExtraModels.gem) do
			if extra == candidate then
				extras = extras + 1
			end
		end
	end
	assert(extras == #ns.ExtraModels.gem, "gem extras not offered")
	for _ = 2, #choices do
		options:Cycle(lowRow, 1)
	end
	assert(ns.db.models.mulgore == nil, "going round to the usual model didn't clear the pick")
	-- Every zone's every role has a few named choices.
	for _, zone in ipairs(ns.Zones) do
		for _, item in ipairs(ns.Models.ROLES) do
			local offered = ns.Models.Choices(zone, item.role)
			assert(#offered >= 2, ("%s %s has %d choices"):format(zone.key, item.role, #offered))
			for _, candidate in ipairs(offered) do
				assert(candidate.name, ("%s %s: a choice with no name"):format(zone.key, item.role))
			end
		end
	end
	-- The preview shows the selected row's model once it loads.
	options:Cycle(lowRow, 1)
	options.frame.scripts.OnUpdate(options.frame, 0.1)
	assert(options.previewCandidate == choices[2] and options.previewFit, "preview didn't show the picked model")
	options.modelRows[1].scripts.OnClick(options.modelRows[1])
	assert(ns.Models.Picked("mulgore", "low"), "pick lost on selecting its row")
	options:Cycle(lowRow, -1)
	assert(ns.Models.Picked("mulgore", "low") == nil, "stepping back didn't return to the usual model")

	-- Esc closes Options, back on the pause screen.
	C.keys.scripts.OnKeyDown(C.keys, "ESCAPE")
	C.keys.scripts.OnKeyUp(C.keys, "ESCAPE")
	assert(not options:IsShown() and C.state == "paused" and C.screens.paused.shown, "Esc didn't close Options back to the pause screen")
	-- The title bar's Resume stays clickable over Options: resuming closes it,
	-- so the keys reach the run again.
	C:OpenOptions()
	C.frame.pauseButton.scripts.OnClick(C.frame.pauseButton)
	assert(not options:IsShown() and C.state == "running", "Resume left the run going on under Options")
	-- From the start screen and the slash command too.
	C:QuitRun()
	C.screens.optionsButton.scripts.OnClick(C.screens.optionsButton)
	assert(options:IsShown() and C.state == "start", "start screen's Options button")
	-- So does starting a run (the minimap's Start a run, /schmoove start).
	C:QuickStart()
	assert(not options:IsShown() and C.state == "running", "a run started under Options")
	C:QuitRun()
	SlashCmdList.SCHMOOVINMAN("options")
	assert(options:IsShown(), "/schmoove options")
	options:Hide()
	rawset(C.screens.speedButton.text, "SetText", nil)
	rawset(hud.countdown, "SetText", nil)
	for _, row in ipairs(options.gameRows) do
		rawset(row.button.text, "SetText", nil)
	end
end
-- Orc runs ----------------------------------------------------------------------
do
	local R = C.renderer
	local world
	-- Nobody on the lists and nothing forced: runs are as usual.
	C.orcRole = nil
	C:StartRun()
	Frames(0.1)
	assert(C.world.mode == nil and R.runner.list == ns.Assets.runner, "an orc run without the name or the command")

	-- /schmoove orc: every run is an orc run.
	SlashCmdList.SCHMOOVINMAN("orc")
	assert(ns.OrcRun.forced, "/schmoove orc didn't force orc runs")
	local labels = {}
	rawset(C.hud.bannerLabel, "SetText", function(self, text) labels[#labels + 1] = text end)
	rawset(C.hud.speed, "SetText", function(self, text) rawset(self, "value", text) end)
	C:StartRun()
	world = C.world
	world.safeLeft = 1e9
	Frames(0.1)
	assert(world.mode == "orc", "a forced run isn't an orc run")
	assert(labels[#labels] == "ORC RUN", "no orc-run banner: " .. tostring(labels[#labels]))
	assert(R.runner.list == ns.Assets.orcRunner, "the runner isn't an orc")
	assert(C.hud.speed.value == string.format("%.1f yd/s", world.taurenSpeed), "HUD speed isn't the Tauren's: " .. tostring(C.hud.speed.value))
	assert(R.ground.near < -20, "road not drawn far enough back: " .. tostring(R.ground.near))

	-- The pulled-back camera: the orc a fifth of the way down the view, and a
	-- Tauren where they appear, 20 yards back, already in view.
	local scene, orcCamera = R.scene, ns.Renderer.ORC_CAMERA
	assert(math.abs(scene.pitch - orcCamera.pitch) < 1e-9 and math.abs(scene.fov - orcCamera.fov) < 1e-9
		and math.abs(scene.distance - orcCamera.distance) < 1e-9, "camera isn't the orc-run camera")
	local head, feet = FromTopOf(scene, 0, ns.Assets.runnerHeight), FromTopOf(scene, 0, 0)
	local spawn = ns.Tuning.orcRun.spawnBehind
	local backHead, backFeet = FromTopOf(scene, -spawn, ns.Assets.runnerHeight), FromTopOf(scene, -spawn, 0)
	print(("orc view: orc's head %.2f from the top, feet %.2f; a Tauren %d yards back from %.2f to %.2f"):format(head, feet, spawn, backHead, backFeet))
	assert(head > 0.1 and head < 0.3, ("orc's head not near the top of the view: %.2f"):format(head))
	-- It comes in at the bottom edge: mostly in view, feet just below it.
	assert(backHead < 0.8 and backFeet < 1.1, ("a Tauren where they appear is out of view: %.2f to %.2f"):format(backHead, backFeet))

	-- Tauren come up from behind and are drawn; no joggers beside the road.
	local drawn = 0
	for _ = 1, 300 do
		world.safeLeft = 1e9
		Frames(1 / 60)
		for _, entity in ipairs(world.entities) do
			local record = R.records[entity.id]
			if entity.role == "tauren" and record and record.ready and (record.actor.lastAlpha or 0) > 0 then
				drawn = drawn + 1
			end
		end
	end
	assert(drawn > 0, "no Tauren drawn in an orc run")
	assert(#R.joggers == 0, "roadside joggers in an orc run")

	-- A Tauren passing on the left yells "On your left!", the next one on the
	-- left "On your left... Again", and the orc answers with a complaint.
	local quips = ns.Assets.quips
	local taurenLines, orcLines, generalLines = {}, {}, {}
	for _, line in ipairs(quips.taurenToOrc) do taurenLines[line] = true end
	taurenLines[quips.passLeft], taurenLines[quips.passRight] = true, true
	taurenLines[quips.passLeftAgain], taurenLines[quips.passRightAgain] = true, true
	for _, line in ipairs(quips.orcRun) do orcLines[line] = true end
	for _, line in ipairs(quips.general) do generalLines[line] = true end
	local sideChance = quips.sideChance
	local function Pass(lane, sides)
		quips.sideChance = sides and 1 or 0
		C:HideBubbles()
		C.nextComplaint = 0
		world.cursor, world.coinNext = 1e9, 1e9
		world.entities = {}
		said = {}
		world:AddEntity("tauren", lane, world.time + 1.2, 0)
		for _ = 1, 150 do
			world.safeLeft = 1e9
			Frames(1 / 60)
		end
		return said
	end
	world.runner.lane = 2
	C.lastPassSide = nil
	local first = Pass(1, true)
	assert(first[1] == quips.passLeft, "a Tauren passing on the left didn't say so: " .. tostring(first[1]))
	assert(first[2] and orcLines[first[2]], "the orc didn't complain: " .. tostring(first[2]))
	local second = Pass(1, true)
	assert(second[1] == quips.passLeftAgain, "a second pass on the left didn't say Again: " .. tostring(second[1]))
	local third = Pass(3, false)
	assert(third[1] and taurenLines[third[1]] and not generalLines[third[1]], "a Tauren used a line it shouldn't: " .. tostring(third[1]))
	-- One in your own lane passes on neither side, so it never says which.
	local sideLines = { [quips.passLeft] = true, [quips.passRight] = true, [quips.passLeftAgain] = true, [quips.passRightAgain] = true }
	local own = Pass(2, true)
	assert(own[1] and taurenLines[own[1]] and not sideLines[own[1]], "a Tauren in your lane gave a side: " .. tostring(own[1]))
	print(("orc run: %s / %s / %s / %s"):format(first[1], first[2], second[1], third[1]))
	quips.sideChance = sideChance

	-- Trampled: the run ends, says why, with a candle on the saved run.
	rawset(C.screens.crashText, "SetText", function(self, text) rawset(self, "value", text) end)
	world.entities = {}
	world.safeLeft = 0
	world:AddEntity("tauren", world.runner.lane, world.time + 0.8, 0)
	Frames(3)
	assert(C.state == "over" and world.crashRole == "tauren", "a Tauren in your lane didn't end the run")
	assert(C.screens.crashText.value:find("Trampled by a Schmoover"), "crash text: " .. tostring(C.screens.crashText.value))
	assert(C.screens.lastEntry.orc == true, "orc run not marked on its saved score")
	-- An orc player sees their own character (hair, colour, face) instead,
	-- undressed and put in the orc warlock's starting clothes.
	UnitRace = function() return "Orc", "Orc", 2 end
	local tries, undresses, copies = calls.TryOn or 0, calls.Undress or 0, calls.SetModelByUnit or 0
	C:StartRun()
	Frames(0.2)
	assert(R.runner.list == ns.Assets.orcPlayerRunner and R.runner.candidate.unit == "player", "an orc player's orc run doesn't use their own character")
	assert(R.runner.dressed and R.runner.ready, "own character not dressed and shown")
	assert((calls.SetModelByUnit or 0) > copies and (calls.Undress or 0) > undresses
		and (calls.TryOn or 0) - tries >= #ns.Assets.orcPlayerDress, "own character not copied, undressed and put in the robes")
	-- An item that won't go on falls back to the next; one still loading is
	-- tried again until it arrives, and the character waits hidden till then.
	local tried, pendingLeft = {}, 3
	TryOnResult = function(link)
		tried[#tried + 1] = link
		if link == "item:6129" then
			return 2 -- not wearable
		elseif link == "item:1396" and pendingLeft > 0 then
			pendingLeft = pendingLeft - 1
			return 3 -- data pending
		end
		return 0
	end
	R:FreeRecord(R.runner)
	R.runner = nil
	C:StartRun()
	Frames(0.05)
	assert(not R.runner.dressed and not R.runner.ready, "own character shown before its outfit had loaded")
	Frames(1.5)
	assert(R.runner.dressed and R.runner.ready, "own character not dressed once its items loaded")
	local seen = {}
	for _, link in ipairs(tried) do
		seen[link] = (seen[link] or 0) + 1
	end
	assert(seen["item:52543"] and not seen["item:57"], "the robe didn't fall back to the next one")
	assert((seen["item:1396"] or 0) == 4 and not seen["item:52679"], "the loading pants weren't waited for: " .. tostring(seen["item:1396"]))
	TryOnResult = nil
	UnitRace = nil

	SlashCmdList.SCHMOOVINMAN("orc")
	assert(not ns.OrcRun.forced, "/schmoove orc didn't turn forcing off")

	-- The next run is back to normal: the Tauren runner, chase camera and road.
	rawset(C.hud.bannerLabel, "SetText", nil)
	rawset(C.hud.speed, "SetText", nil)
	C:StartRun()
	Frames(0.1)
	assert(C.world.mode == nil and R.runner.list == ns.Assets.runner, "runner still an orc after an orc run")
	local chase = ns.Renderer.CAMERA
	assert(math.abs(scene.pitch - chase.pitch) < 1e-9 and math.abs(scene.fov - chase.fov) < 1e-9, "camera stayed pulled back after an orc run")
	assert(R.ground.near == -6, "road still drawn far back after an orc run")
	rawset(C.screens.crashText, "SetText", nil)
end
-- Hazard markers: off by default, a mark per hazard when on.
do
	local C = ns.Controller
	local world = C.world
	assert(ns.db.settings.markers == false, "hazard markers on by default")
	world.entities = {}
	world:AddEntity("block", 1, world.time + 2, 0)
	world:AddEntity("low", 3, world.time + 2, 0)
	Frames(0.05)
	assert(C.renderer.markers.count == 0, "hazard marks drawn with the setting off")
	SlashCmdList.SCHMOOVINMAN("markers")
	Frames(0.05)
	local markers = C.renderer.markers
	assert(ns.db.settings.markers == true and markers.count == 2, "no mark per hazard: " .. tostring(markers.count))
	assert(markers[1].r ~= markers[2].r, "jump and avoid marks share a colour")
	SlashCmdList.SCHMOOVINMAN("markers")
	Frames(0.05)
	assert(C.renderer.markers.count == 0, "hazard marks still drawn after turning them off")
end
-- Things drawn by hand: a pit and its ramp, a steam vent, a wisp, and an
-- escort with a gift in the air.
do
	local C = ns.Controller
	local world = C.world
	local r = C.renderer
	world.entities = {}
	world.cursor = 1e9
	world.safeLeft = 1e9
	local at = world.time + 2
	local ramp = world:AddEntity("ramp", 1, at, 0)
	ramp.leave = at + 1.5
	world:AddEntity("pitedge", 3, at, 0)
	local pit = world:AddEntity("pit", 2, at + 0.05, 0)
	pit.leave = at + 1.5
	Frames(0.05)
	local quads = 0
	for index = 1, r.markers.count do
		quads = quads + (r.markers[index].quad and 1 or 0)
	end
	-- A ramp alone is two sides, a top, a lip and six arrow arms.
	assert(quads >= 12, "pit and ramp not drawn in perspective: " .. quads)
	assert(next(r.records) == nil, "a pit or ramp was given a model")

	world.entities = {}
	local vent = world:AddEntity("vent", 2, world.time + 2, 0)
	vent.zoneKey = "ironforge"
	world:AddEntity("wisp", 1, world.time + 2, 0.9)
	Frames(0.05)
	local fading, glowing = 0, 0
	for index = 1, r.markers.count do
		fading = fading + (r.markers[index].fade and 1 or 0)
		glowing = glowing + (r.markers[index].glow and 1 or 0)
	end
	assert(fading == 4 and glowing == 2, ("steam and wisp not drawn: %d puffs, %d lights"):format(fading, glowing))
	assert(next(r.records) == nil, "a steam vent or wisp was given a model")

	world.entities = {}
	world.zoneOrder[world.zoneIndex] = "orgrimmar"
	world.zoneKey = "orgrimmar"
	local gift = world:AddEntity("goldRush", 2, world.time + 1.2, 0.9)
	gift.thrown, gift.gift, gift.phase, gift.throwMax = true, true, "waiting", ns.Tuning.escort.distance - 2
	local flew = false
	for _ = 1, 30 do
		world.safeLeft = 1e9
		Frames(1 / 60)
		flew = flew or (gift.phase == "flying" and r.markers.count > 0 and r.markers[1].g > r.markers[1].r)
	end
	assert(r.escort and r.escort.name == "Thrall" and r.escortY, "no escort in Orgrimmar")
	assert(flew, "a gift in the air has no green landing mark")
	world.zoneOrder[world.zoneIndex] = "mulgore"
	world.zoneKey = "mulgore"
	Frames(2)
	assert(r.escort == nil, "the escort stayed on after its zone")
end
print("templates used: " .. table.concat((function() local t = {} for k in pairs(templatesUsed) do t[#t + 1] = k end table.sort(t) return t end)(), ", "))
print(("smoke ok: %d scores, guild board %d, %d messages sent, best %s"):format(#ns.db.scores, #ns.GuildBoard.List(), #sent, tostring(ns.db.scores[1].score)))
