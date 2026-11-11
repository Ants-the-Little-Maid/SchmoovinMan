local _, ns = ...

-- Draws the world: maps entities to pooled ModelScene actors, scales each
-- model from its bounding box, falls back through candidate lists when a
-- model won't load, and runs the runner's animations and the scenery.
local Renderer = {}
Renderer.__index = Renderer
ns.Renderer = Renderer

local Assets = ns.Assets
local Scene = ns.Scene

-- Seconds to wait for a model before trying the next one. Generous, because a
-- first visit streams models in slowly; giving up early swapped in backups.
local LOAD_TIMEOUT = 10
-- Longest wait for the geometry-ready signal before measuring anyway.
local GEO_WAIT = 1
-- Longest wait for an outfit's item to load, from the first try-on, before
-- the next one is tried; and how often a waiting item is tried again.
local DRESS_WAIT = 3
local DRESS_RETRY = 0.25
local TRY_ON = Enum and Enum.ItemTryOnReason or {}
local TRY_ON_SUCCESS, TRY_ON_PENDING = TRY_ON.Success or 0, TRY_ON.DataPending or 3

-- True when the player's own character is an orc.
local function PlayerIsOrc()
	if not UnitRace then
		return false
	end
	local _, raceFile = UnitRace("player")
	return raceFile == "Orc"
end

-- Characters and creatures: measured by the active box only, and their scale
-- kept within a sane range (they're about life size at scale 1).
local CHARACTER = { runner = true, jogger = true, alliance = true, charger = true, windRider = true, boss = true, tauren = true }
local CHARACTER_SCALE_MIN, CHARACTER_SCALE_MAX = 0.5, 2.0
-- Bosses are bigger than life and come in all shapes (a devilsaur, a
-- dwarf), so their range is wider. BOSS_WIDTH caps how wide one looms.
local BOSS_SCALE_MIN, BOSS_SCALE_MAX = 0.2, 4.0
local BOSS_WIDTH = 6.5
-- Seconds a spear takes to fly from the runner to the boss, and how long the
-- boss takes to come out of the fog and to run off at the end.
local SPEAR_FLIGHT = 0.45
local BOSS_ARRIVE = 1.4
local BOSS_LEAVE = 2.2
-- Fog is measured from the camera, which sits well behind the runner, so a
-- boss at its spot would stand deep in it (a fire elemental faded out
-- altogether). In a fight the fog draws back until the boss is at most
-- BOSS_FOG of the way into it.
local BOSS_FOG = 0.15
-- Road marks: red where a boss's throw will land, and the hazard markers'
-- colours by what a hazard asks of you.
local MARK_RED = { 0.88, 0.21, 0.16 }
local MARK_COLOR = {
	jump = { 0.94, 0.62, 0.15 },
	duck = { 0.22, 0.54, 0.87 },
	avoid = MARK_RED,
}
-- How far a hazard marker reaches past its hazard, front and back, in yards.
local MARK_MARGIN = 0.6
-- How high a thrown hazard arcs, in yards.
local THROW_ARC = 4
-- Posts that hold up high bars: plain fence posts, then a Tauren totem.
local POSTS = {
	{ fileID = 199210 }, -- world/generic/orc/passive doodads/orcfence/orcfencepost.m2
	{ fileID = 189137 }, -- azeroth/burningsteppes/passivedoodads/fences/burningsteppesfencepost.m2
	{ fileID = 200577 }, -- generic/tauren/passive doodads/totems/taurentotem01.m2
}

-- Yards ahead of a jogger who answers back (Tauren, famous faces) at which
-- the runner speaks, so their reply stays on screen.
local CALL_DISTANCE = 9
-- Chase camera: how far ahead it looks, its distance from that point and its tilt.
-- Aimed so the runner sits a little below centre at the same zoom as 0.2.0.
local CAMERA = { lookAhead = 4, distance = 16, pitch = math.rad(20), height = 1.6, fov = Scene.FIELD_OF_VIEW }
-- In a boss fight. The chase camera's view spans about 28 degrees top to
-- bottom (measured from a 0.10.0 screenshot), so its top edge is about 6
-- degrees below eye level and a boss 58 yards up the road stands out of
-- sight above it. This camera sits a little lower (5.5 yards up, 10 behind
-- the runner), tilts less and sees wider: even a 6-yard boss shows under the
-- boss bar, the runner stays whole and about as big, and the runner hides
-- 9 yards of its lane rather than 6. FIGHT_CAMERA_TIME: seconds to move over.
local FIGHT_CAMERA = { lookAhead = 5.6, distance = 16, pitch = math.rad(12.5), height = 2.0, fov = 1.2 }
local FIGHT_CAMERA_TIME = 1.2
-- Orc runs: pulled back about 28 yards from the orc (the chase camera is 12.5)
-- and looking at a spot behind it, so the orc runs a fifth of the way down
-- the view with about 19 yards of road behind it in sight, where the Tauren
-- come from. Wide, so the road ahead still reaches the horizon above it.
local ORC_CAMERA = { lookAhead = -14, distance = 14, pitch = math.rad(20), height = 1.6, fov = 1.3 }
-- Orc runs: a Tauren yells as it comes this close behind the orc, so its
-- line can be read before it runs off up the road.
local TAUREN_CALL = 3
Renderer.CAMERA, Renderer.FIGHT_CAMERA, Renderer.ORC_CAMERA = CAMERA, FIGHT_CAMERA, ORC_CAMERA

-- What the view looks like in each kind of run (Reset picks one):
--   camera     the base camera (a boss fight moves from it to FIGHT_CAMERA)
--   runner     the runner's model list in Assets
--   ownOrc     the list used instead when the player's character is an orc
--   behind     how far behind the runner, in yards, the road and scenery reach
--   clearAhead keeps the fog clear this many yards past the runner, for a
--              camera far enough back that the fog would cover it (nil: none)
--   joggers    whether joggers run beside the road
-- An orc run pulls the camera back, so the road behind (where the Tauren
-- come from) shows down to just past the bottom of the view.
local VIEWS = {
	normal = { camera = CAMERA, runner = "runner", behind = -6, joggers = true },
	orc = { camera = ORC_CAMERA, runner = "orcRunner", ownOrc = "orcPlayerRunner", behind = -24, clearAhead = 10, joggers = false },
}

-- A camera setting part way (fight, 0 to 1) from the base camera to the fight camera.
local function CameraSetting(key, fight, base)
	base = base or CAMERA
	return base[key] + (FIGHT_CAMERA[key] - base[key]) * fight
end

-- Distance from a camera to the road `ahead` yards past the runner.
local function CameraToRoad(camera, ahead)
	local y = camera.lookAhead - camera.distance * math.cos(camera.pitch)
	local z = camera.height + camera.distance * math.sin(camera.pitch)
	return math.sqrt((ahead - y) ^ 2 + z * z)
end

-- Distance from the fight camera to the boss's spot, ignoring the small
-- sway with the runner's lane, so the fog it sets stays put through a fight.
local function FightCameraToBoss()
	local camera = FIGHT_CAMERA
	local y = camera.lookAhead - camera.distance * math.cos(camera.pitch)
	local z = camera.height + camera.distance * math.sin(camera.pitch)
	return math.sqrt((ns.Tuning.boss.distance - y) ^ 2 + z * z)
end
local HALF_PI = math.pi / 2

-- Target sizes per role, in yards: height, lateral width, lift off the ground.
-- Kept well inside a 2.6-yard lane and low enough to see the road past them.
-- depth caps how far a model reaches toward or away from you.
local TARGET = {
	low = { height = 0.9, width = 1.5, depth = 1.6 },
	high = { height = 0.7, width = 1.8, depth = 1.0, lift = 1.7 },
	block = { height = 2.0, width = 1.5, depth = 1.8 },
	wall = { height = 2.2, width = 1.8, depth = 1.6 },
	charger = { height = 2.3, width = 2.0 },
}

local CandidateKey = ns.Models.Key

-- Distance from the middle of the road to its edge.
local function RoadHalf()
	local lanes = ns.Tuning.lanes
	return (lanes[#lanes] - lanes[1]) * 0.75
end

-- Scenery starts a few yards past the road's edge.
local function SceneryInner()
	return RoadHalf() + 3
end

-- Scenery stands clear of the road however big or turned it is: once its
-- size is known, it moves out until no corner of its box (as turned, either
-- side of where it stands) comes within this many yards of the edge.
local SCENERY_CLEARANCE = 1.5

local function OffRoad(x, box, yaw, scale)
	local c, s = math.cos(yaw), math.sin(yaw)
	local reach = math.max(
		math.abs(box[1] * c - box[2] * s), math.abs(box[1] * c - box[5] * s),
		math.abs(box[4] * c - box[2] * s), math.abs(box[4] * c - box[5] * s)) * scale
	local side = x < 0 and -1 or 1
	return side * math.max(math.abs(x), RoadHalf() + SCENERY_CLEARANCE + reach)
end

local function Fade(y, far)
	if y > far then
		return 0
	elseif y > far - 12 then
		return (far - y) / 12
	end
	return 1
end

function Renderer.Create(scene, ground)
	local self = setmetatable({}, Renderer)
	self.scene = scene
	self.ground = ground
	self.records = {}
	self.bounds = {}
	self.badModels = {}
	self.failures = {}
	self.scenery = {}
	self.joggers = {}
	self.passes = {}
	self.sparePasses = {}
	self.seen = {}
	self.joggerNext = 20
	self.sceneryNext = 0
	self.sceneryDistance = 0
	self.shots = {}
	self.markers = { count = 0 }
	self.view = VIEWS.normal
	return self
end

-- Model loading ----------------------------------------------------------------

function Renderer:LoadCandidate(record)
	local candidate = record.list[record.index]
	while candidate and self.badModels[CandidateKey(candidate)] do
		record.index = record.index + 1
		candidate = record.list[record.index]
	end
	if not candidate then
		record.failed = true
		record.actor:Hide()
		return
	end
	record.candidate = candidate
	record.key = CandidateKey(candidate)
	record.startedAt = GetTime()
	record.ready = self.bounds[record.key] ~= nil
	record.dressed, record.dressIndex, record.dressRetryAt = nil, nil, nil
	local actor = record.actor
	actor:ClearModel()
	local ok
	if candidate.unit then
		-- That unit's own look (sheathed, its gear on until Dress).
		ok = actor:SetModelByUnit(candidate.unit, true, true, true)
	elseif candidate.displayID then
		ok = actor:SetModelByCreatureDisplayID(candidate.displayID)
	else
		ok = actor:SetModelByFileID(candidate.fileID)
	end
	if ok == false then
		self:MarkBad(record)
	end
end

function Renderer:MarkBad(record)
	-- A copied character can fail for a passing reason (still streaming in
	-- after a loading screen), so it's tried again next time rather than
	-- remembered, and isn't reported as a missing model.
	if record.candidate and record.candidate.unit then
		record.index = record.index + 1
		self:LoadCandidate(record)
		return
	end
	-- Several copies of one model can fail together; report each model once.
	if not self.badModels[record.key] then
		self.badModels[record.key] = true
		tinsert(self.failures, record.key)
	end
	record.index = record.index + 1
	self:LoadCandidate(record)
end

-- Puts a copied character in its outfit: everything off, then each slot's
-- first item that goes on (only Success counts, as in the game's own
-- dressing room). An item whose data hasn't loaded is asked for once and
-- tried again every DRESS_RETRY, for up to DRESS_WAIT from the first
-- try-on; then the next is tried. Sets record.dressed once every slot is
-- settled, worn or left bare.
function Renderer:Dress(record)
	local actor = record.actor
	local now = GetTime()
	if not actor:IsLoaded() or now < (record.dressRetryAt or 0) then
		return
	end
	if not record.dressIndex then
		actor:Undress(true)
		record.dressIndex, record.dressRequested, record.dressStartedAt = {}, {}, now
	end
	local waiting = false
	for slot, items in ipairs(record.candidate.dress) do
		local index = record.dressIndex[slot] or 1
		while index <= #items do
			local id = items[index]
			local reason = actor:TryOn("item:" .. id)
			if reason == TRY_ON_SUCCESS then
				index = math.huge
			elseif reason == TRY_ON_PENDING and now - record.dressStartedAt < DRESS_WAIT then
				if not record.dressRequested[id] and C_Item and C_Item.RequestLoadItemDataByID then
					record.dressRequested[id] = true
					C_Item.RequestLoadItemDataByID(id)
				end
				waiting = true
				break
			else
				-- Not for this race, not wearable, missing, or still not loaded:
				-- the next one.
				index = index + 1
			end
		end
		record.dressIndex[slot] = index
	end
	record.dressed = not waiting
	record.dressRetryAt = waiting and now + DRESS_RETRY or nil
end

-- Reads the bounding box once the model has loaded; gives up after a while.
-- A copied character is dressed first, so it's measured as it will look.
function Renderer:CheckLoaded(record)
	if record.failed then
		return
	end
	if record.candidate and record.candidate.dress and not record.dressed then
		record.ready = false
		self:Dress(record)
		if not record.dressed then
			-- Only a model that never loads gives up: waiting on its items
			-- has its own limit (DRESS_WAIT).
			if not record.actor:IsLoaded() and GetTime() - record.startedAt > LOAD_TIMEOUT then
				self:MarkBad(record)
			end
			return
		end
	end
	if record.ready then
		return
	end
	local actor = record.actor
	if actor:IsLoaded() then
		-- When the game says the geometry isn't ready, wait briefly so the size
		-- isn't read from a placeholder. Only briefly: in Forever this never
		-- turns true for props loaded by file, and waiting on it hid them.
		if actor.IsGeoReady and actor:IsGeoReady() == false and GetTime() - record.startedAt < GEO_WAIT then
			return
		end
		local minX, minY, minZ, maxX, maxY, maxZ = Scene.GetActorBounds(actor, CHARACTER[record.role])
		if minX and (maxZ - minZ) > 0.01 then
			-- For a creature, also where its body's middle is (see Fit).
			self.bounds[record.key] = { minX, minY, minZ, maxX, maxY, maxZ, CHARACTER[record.role] and Scene.GetMaxCenterY(actor) or nil }
			record.ready = true
			return
		end
	end
	if GetTime() - record.startedAt > LOAD_TIMEOUT then
		self:MarkBad(record)
	end
end

function Renderer:NewRecord(list, role, entity)
	local actor = self.scene:AcquireActor()
	if not actor then
		return nil
	end
	-- Hidden until first placed, so nothing flashes up at the scene's origin.
	actor:SetAlpha(0)
	local record = { actor = actor, list = list, index = 1, role = role, entity = entity, spin = math.random() * 6.28 }
	self:LoadCandidate(record)
	return record
end

function Renderer:FreeRecord(record)
	self.scene:ReleaseActor(record.actor)
	for _, post in ipairs(record.posts or {}) do
		if post then
			self.scene:ReleaseActor(post.actor)
		end
	end
	record.posts = nil
end

-- Scale and ground offset for a loaded record.
function Renderer:Fit(record)
	local box = self.bounds[record.key]
	if not box then
		return nil
	end
	local sizeX, sizeY, sizeZ = box[4] - box[1], box[5] - box[2], box[6] - box[3]
	local role = record.role
	local target = TARGET[role]
	local candidate = record.candidate
	local scale, yaw, center
	if role == "runner" or role == "tauren" then
		-- A Tauren in an orc run is as big as the Schmoovin Man himself.
		scale = Assets.runnerHeight / sizeZ
	elseif role == "post" then
		scale = (TARGET.high.lift + TARGET.high.height) / sizeZ
	elseif role == "jogger" or role == "alliance" then
		scale = Assets.joggerHeight / sizeZ
	elseif role == "windRider" then
		scale = Assets.windRiderLength / math.max(sizeX, sizeY)
	elseif role == "boss" then
		-- Faces you, like a charger: its side-to-side size is the model's y.
		scale = math.min((record.height or 3) / sizeZ, BOSS_WIDTH / math.max(sizeY, 0.05))
		scale = math.max(BOSS_SCALE_MIN, math.min(BOSS_SCALE_MAX, scale))
		center = true
	elseif role == "charger" then
		-- Faces you, so its side-to-side size is the model's y.
		scale = math.min(target.height / sizeZ, target.width / math.max(sizeY, 0.05))
		center = true
	elseif target then
		-- Long side across the track, then fit height, width and depth.
		yaw = sizeY > sizeX and HALF_PI or 0
		local width = math.max(sizeX, sizeY)
		local depth = math.min(sizeX, sizeY)
		-- Part of a multi-lane barrier: fill the whole lane so the pieces meet.
		local targetWidth = target.width
		local entity = record.entity
		if entity and (entity.joinLeft or entity.joinRight) then
			local lanes = ns.Tuning.lanes
			targetWidth = (lanes[2] - lanes[1]) * 1.05
		end
		scale = math.min(target.height / sizeZ, targetWidth / width, target.depth / math.max(depth, 0.05))
		center = true
	elseif candidate.size then
		-- Tokens and pickups: the largest side fits `size`, so wide piles stay small.
		scale = candidate.size / math.max(sizeX, sizeY, sizeZ, 0.05)
	else
		scale = (candidate.height or 1) / math.max(sizeZ, 0.05)
	end
	-- A character's reading outside the sane range means a bad measurement,
	-- not a giant or tiny model: clamp it so it can never vanish or fill the screen.
	if CHARACTER[role] and role ~= "boss" then
		scale = math.max(CHARACTER_SCALE_MIN, math.min(CHARACTER_SCALE_MAX, scale))
	end
	-- Hazards are centred on their lane by their box, not their pivot, so a
	-- model built off-centre doesn't reach into the next lane.
	local centerX, centerY
	if center then
		centerX, centerY = (box[1] + box[4]) / 2, (box[2] + box[5]) / 2
		-- A creature's standing box is lopsided wherever a tail, a turned head
		-- or antlers reach further to one side (a devilsaur, a stag), so
		-- centring on it pushed the animal off its lane. Nor can its pivot be
		-- trusted: some models sit to one side of it (seen with the Barrens'
		-- charger). Its body's middle is taken from its box over all its
		-- animations, which is even about the body; failing that, its pivot.
		-- Its length is still centred on the standing box, to match the hit box.
		if CHARACTER[role] then
			centerY = box[7] or 0
		end
	end
	return scale, -box[3] * scale, yaw or 0, centerX, centerY
end

-- Posts either side of a high bar, at the lane's edges.
function Renderer:DrawPosts(record, entity, y, alpha)
	local lanes = ns.Tuning.lanes
	local offset = (lanes[2] - lanes[1]) * 0.47
	for index, post in ipairs(record.posts) do
		if post then
			self:CheckLoaded(post)
			-- A bar across several lanes has posts only at its two outer ends.
			local joined = (index == 1 and entity.joinLeft) or (index == 2 and entity.joinRight)
			if post.ready and not entity.smashed and not joined then
				local scale, zOffset = self:Fit(post)
				local x = entity.x + (index == 1 and -offset or offset)
				self.scene:Place(post.actor, x, y, zOffset, 0, scale)
				post.actor:SetAlpha(alpha)
			else
				post.actor:SetAlpha(0)
			end
		end
	end
end

-- Entities -------------------------------------------------------------------------

function Renderer:ListFor(entity, zone)
	local role = entity.role
	-- Hazards, chargers, coins and gems: the zone's models, or the one picked
	-- for it in Options, then backups (Render/Models.lua).
	if ns.Models.PICKABLE[role] then
		return ns.Models.List(zone, role)
	elseif role == "spear" then
		return Assets.spear
	elseif Assets.powerups[role] then
		return Assets.powerups[role]
	elseif role == "alliance" then
		return Assets.alliance[math.random(#Assets.alliance)]
	elseif role == "tauren" then
		return Assets.stampede[math.random(#Assets.stampede)]
	end
	return {}
end

-- Hazards of the same kind side by side in one row are one barrier, so it's
-- clear they block those lanes together. Each entity learns whether it joins
-- the lane to its left or right.
local GROUPED = { low = 1, high = 2, wall = 3, block = 4 }

-- One number per grouped hazard: its row (arrival, to the millisecond), kind
-- and lane, so the lanes either side are the keys one below and one above.
-- Lanes run 1 to 3 in a slot of 8, so a neighbour never lands on another
-- kind. The table is reused, so this makes no garbage each frame.
local groupAt = {}

local function GroupKey(entity)
	return (math.floor(entity.arrive * 1000 + 0.5) * 8 + GROUPED[entity.role]) * 8 + entity.lane
end

local function MarkGroups(entities)
	wipe(groupAt)
	for _, entity in ipairs(entities) do
		entity.joinLeft, entity.joinRight = nil, nil
		if GROUPED[entity.role] and not entity.smashed then
			groupAt[GroupKey(entity)] = true
		end
	end
	for _, entity in ipairs(entities) do
		if GROUPED[entity.role] and not entity.smashed then
			local key = GroupKey(entity)
			entity.joinLeft = groupAt[key - 1] ~= nil
			entity.joinRight = groupAt[key + 1] ~= nil
		end
	end
end

function Renderer:SyncEntities(world, zone, now)
	local seen = self.seen
	wipe(seen)
	local far = zone.fog.far + 5
	MarkGroups(world.entities)
	local hazardMarkers = ns.db.settings.markers == true
	for _, entity in ipairs(world.entities) do
		seen[entity.id] = true
		local record = self.records[entity.id]
		if not record and entity.y < far + 20 then
			-- Each entity keeps the zone it spawned in.
			entity.zoneKey = entity.zoneKey or world.zoneKey
			record = self:NewRecord(self:ListFor(entity, ns.ZonesByKey[entity.zoneKey] or zone), entity.role, entity)
			-- High bars stand on two posts, so they read as a gate to duck under.
			if record and entity.role == "high" then
				-- Index 1 is the left post and 2 the right; a post that couldn't get
				-- an actor is false, so neither ipairs nor FreeRecord stops early.
				record.posts = { self:NewRecord(POSTS, "post") or false, self:NewRecord(POSTS, "post") or false }
			end
			self.records[entity.id] = record
		end
		if record then
			self:DrawEntity(record, entity, far, now)
		end
		-- An orc run's Tauren yells as it comes level with you (see TakePasses),
		-- passing on your left (-1) or right (1), or in your own lane (no side).
		if entity.role == "tauren" and not entity.called and entity.y >= -TAUREN_CALL then
			entity.called = true
			local lane = world.runner.lane
			local side = entity.lane < lane and -1 or entity.lane > lane and 1 or nil
			tinsert(self.passes, { tauren = entity, side = side })
		end
		-- A throw's landing mark doesn't wait for the hazard's model to load.
		if entity.thrown and entity.phase == "flying" then
			local _, progress = ns.Rules.ThrowPhase(ns.Tuning, entity.y, self.speed or 0)
			self:AddMarker(entity, entity.y, progress, far)
		elseif hazardMarkers and entity.role ~= "tauren" and (not entity.thrown or entity.phase == "landed") then
			self:AddHazardMarker(entity, far)
		end
	end
	for id, record in pairs(self.records) do
		if not seen[id] then
			self:FreeRecord(record)
			self.records[id] = nil
		end
	end
end

function Renderer:DrawEntity(record, entity, far, now)
	self:CheckLoaded(record)
	local actor = record.actor
	if not record.ready then
		actor:SetAlpha(0)
		return
	end
	local scale, zOffset, yaw, centerX, centerY = self:Fit(record)
	local role = entity.role
	local z = entity.z
	local target = TARGET[role]
	if target and target.lift then
		z = target.lift
	end
	local pitch, roll = 0, 0
	if role == "coin" or role == "gem" or role == "spear" or ns.Rules.POWERUP[role] then
		yaw = now * 2.5 + record.spin
		z = z - 0.5 + math.sin(now * 4 + record.spin) * 0.1
	elseif role == "charger" then
		yaw = -HALF_PI
		if not record.animated then
			actor:SetAnimation(Assets.anims.creatureRun[1], nil, 1.4)
			record.animated = true
		end
	elseif role == "tauren" then
		-- Running past you up the road, their stride quickening with their speed.
		yaw = HALF_PI
		local pace = math.max(0.8, math.min(2.6, (self.taurenSpeed or 11) / 11))
		if not record.pace or math.abs(record.pace - pace) > 0.1 then
			record.pace = pace
			actor:SetAnimation(Assets.anims.run[1], nil, pace)
		end
		-- They fade as they get far ahead, before they're dropped.
		far = math.min(far, ns.Tuning.orcRun.despawnAhead)
	elseif role == "alliance" then
		-- Jogging away from you, like the roadside joggers.
		yaw = HALF_PI
		if not record.animated then
			actor:SetAnimation(Assets.anims.run[1], nil, 0.9)
			record.animated = true
		end
	end
	local x, y = entity.x, entity.y
	local landed = true
	if entity.thrown then
		-- Thrown by the boss: hidden in its hand, then arcing from it to where
		-- it lands, with a marker on that spot. Positions are those it will
		-- have on the road, so the marker moves with the ground. The phase is
		-- the world's (it never goes back); progress never goes back either.
		local phase = entity.phase or "waiting"
		if phase == "waiting" then
			actor:SetAlpha(0)
			if record.posts then
				self:DrawPosts(record, entity, y, 0)
			end
			return
		elseif phase == "flying" then
			landed = false
			local _, progress = ns.Rules.ThrowPhase(ns.Tuning, y, self.speed or 0)
			progress = math.max(record.throwProgress or 0, progress)
			record.throwProgress = progress
			if not record.launched then
				-- It leaves from where the boss is now, and keeps that start
				-- while the boss moves on to its next throw or runs off.
				record.launched = true
				-- Before the boss is drawn (its model still loading), from its spot.
				record.fromX = self.bossAimX or x
				record.fromY = self.bossY or ns.Tuning.boss.distance
				record.fromZ = self.bossHandZ or 3
				self.bossThrowAt = now
			end
			local fromX, fromY, fromZ = record.fromX, record.fromY, record.fromZ
			x = fromX + (x - fromX) * progress
			y = fromY + (y - fromY) * progress
			z = fromZ + (z - fromZ) * progress + 4 * progress * (1 - progress) * THROW_ARC
			pitch = (1 - progress) * 5
		end
	end
	if entity.knocked then
		-- Bowled over: flung up and off the side of the road, tumbling.
		record.knockedAt = record.knockedAt or now
		local side = entity.x < -0.1 and -1 or entity.x > 0.1 and 1 or (entity.id % 2 == 0 and 1 or -1)
		local t = now - record.knockedAt
		x = x + side * 9 * t
		y = y + 5 * t
		z = z + 10 * t - 9 * t * t
		pitch = t * 7
		roll = side * t * 9
		if t > 1.4 then
			actor:SetAlpha(0)
			return
		end
	elseif entity.smashed then
		-- Knocked away: fly up and spin off.
		record.smashedAt = record.smashedAt or now
		local t = now - record.smashedAt
		z = z + 9 * t - 12 * t * t
		y = y + 6 * t
		pitch = t * 8
		roll = t * 5
		if t > 0.8 then
			actor:SetAlpha(0)
			return
		end
	end
	self.scene:Place(actor, x, y, z + zOffset, yaw, scale, pitch, roll, centerX, centerY)
	if record.posts then
		-- A bar's posts appear once it lands.
		self:DrawPosts(record, entity, y, landed and Fade(y, far) or 0)
	end
	local alpha = Fade(y, far)
	if role == "tauren" then
		-- An orc run's Tauren fades in over its first few yards, coming in at
		-- the bottom edge.
		alpha = math.max(0, math.min(alpha, (y + ns.Tuning.orcRun.spawnBehind) / 3))
	end
	actor:SetAlpha(alpha)
end

-- A red mark on the road where a thrown hazard will land, as wide as the
-- hazard's lane and stronger as it falls.
function Renderer:AddMarker(entity, y, progress, far)
	local markers = self.markers
	markers.count = markers.count + 1
	local marker = markers[markers.count]
	if not marker then
		marker = {}
		markers[markers.count] = marker
	end
	local lanes = ns.Tuning.lanes
	marker.x = entity.x
	marker.y = y
	marker.halfWidth = (lanes[2] - lanes[1]) * 0.42
	marker.halfDepth = 0.9
	marker.alpha = (0.35 + 0.3 * progress) * Fade(y, far)
	marker.r, marker.g, marker.b = MARK_RED[1], MARK_RED[2], MARK_RED[3]
end

-- Hazard markers (an Options setting, off by default): a mark on the road
-- under each hazard, in the colour of what it asks of you. It's nearly the
-- width of the lane and reaches a little past the hazard front and back, so
-- it shows around the model standing on it.
function Renderer:AddHazardMarker(entity, far)
	local color = MARK_COLOR[ns.Rules.REQUIREMENT[entity.role]]
	local shape = ns.Rules.SHAPES[entity.role]
	local y = entity.y
	if not (color and shape) or entity.smashed then
		return
	end
	local halfDepth = shape.halfDepth + MARK_MARGIN
	if y < -halfDepth or y > far then
		return
	end
	local markers = self.markers
	markers.count = markers.count + 1
	local marker = markers[markers.count]
	if not marker then
		marker = {}
		markers[markers.count] = marker
	end
	local lanes = ns.Tuning.lanes
	-- Side by side, the marks of one barrier meet, as its pieces do.
	local joined = entity.joinLeft or entity.joinRight
	marker.x = entity.x
	marker.halfWidth = (lanes[2] - lanes[1]) * (joined and 0.5 or 0.46)
	marker.halfDepth = halfDepth
	marker.y = y
	marker.alpha = 0.6 * Fade(y, far)
	marker.r, marker.g, marker.b = color[1], color[2], color[3]
end

-- Boss ------------------------------------------------------------------------------

function Renderer:FreeBoss()
	if self.bossRecord then
		self:FreeRecord(self.bossRecord)
		self.bossRecord = nil
	end
	self.bossFight = nil
	self.bossX, self.bossAimX, self.bossY, self.bossHandZ = nil, nil, nil, nil
	self.bossHitAt, self.bossThrowAt = nil, nil
	for _, shot in ipairs(self.shots) do
		self:FreeRecord(shot.record)
	end
	wipe(self.shots)
end

function Renderer:PlayBoss(key, speed)
	local record = self.bossRecord
	if record.anim ~= key then
		record.anim = key
		record.actor:SetAnimation(Assets.anims[key][1], nil, speed or 1)
	end
end

-- The boss backs away up the road ahead, sliding over to the lane of its
-- next throw; it flinches when a spear hits and runs off when the fight ends.
function Renderer:DrawBoss(world, far, now)
	local fight = world.boss
	if fight ~= self.bossFight then
		self:FreeBoss()
		self.bossFight = fight
		local zone = fight and ns.ZonesByKey[fight.key]
		if zone and zone.boss then
			self.bossRecord = self:NewRecord(zone.boss.models, "boss")
			if self.bossRecord then
				self.bossRecord.height = zone.boss.height
			end
			self.bossX = 0
			self.bossHits = 0
		end
	end
	local record = self.bossRecord
	if not record then
		return
	end
	-- Gone once it has run off, drawn or not: a boss whose model never
	-- loaded must go too, or the fight camera would stay. Still this fight,
	-- so it isn't drawn again.
	if fight.state ~= "fight" and world.time - fight.endedAt > BOSS_LEAVE then
		self:FreeBoss()
		self.bossFight = fight
		return
	end

	-- A spear that hits flies from the runner to the boss.
	if fight.hits > (self.bossHits or 0) then
		self.bossHits = fight.hits
		local shot = self:NewRecord(Assets.spear, "spear")
		if shot then
			tinsert(self.shots, { record = shot, startAt = now, fromX = world.runner.x, fromZ = world.runner.z + 1.6 })
		end
		self.bossHitAt = now + SPEAR_FLIGHT
	end

	self:CheckLoaded(record)
	if not record.ready then
		record.actor:SetAlpha(0)
		return
	end
	local tuning = ns.Tuning
	local elapsed = math.min(1 / 15, now - (self.lastBossDraw or now))
	self.lastBossDraw = now

	-- Toward the lane of the next hazard still in its hand.
	local targetX, nearest = 0, nil
	for _, entity in ipairs(world.entities) do
		if entity.thrown and entity.phase == "waiting" and (not nearest or entity.y < nearest) then
			nearest = entity.y
			targetX = entity.x
		end
	end
	local x = self.bossX + (targetX - self.bossX) * math.min(1, elapsed * 3)
	self.bossX = x
	local y = tuning.boss.distance
	local yaw = -HALF_PI
	local alpha = 1
	local since = world.time - fight.start
	if fight.state ~= "fight" then
		-- Runs off up the road and to the side, fading out.
		local left = world.time - fight.endedAt
		local side = x <= 0 and -1 or 1
		yaw = HALF_PI + side * 0.6
		x = x + side * 6 * left
		y = y + 9 * left
		alpha = 1 - left / BOSS_LEAVE
		self:PlayBoss("bossFlee", 1.5)
	elseif since < BOSS_ARRIVE then
		-- Comes out of the fog to its spot.
		y = y + (1 - since / BOSS_ARRIVE) * 25
		self:PlayBoss("bossBack", 1.4)
	elseif self.bossHitAt and now >= self.bossHitAt and now < self.bossHitAt + 0.5 then
		self:PlayBoss("bossHit")
	elseif self.bossThrowAt and now - self.bossThrowAt < 0.45 then
		self:PlayBoss("bossThrow", 1.3)
	else
		self:PlayBoss("bossBack", 1.4)
	end
	local scale, zOffset, _, centerX, centerY = self:Fit(record)
	-- Where it is now, running off included: spears and throws use this.
	self.bossAimX = x
	self.bossY = y
	local box = self.bounds[record.key]
	self.bossHandZ = (box[6] - box[3]) * scale * 0.75
	self.scene:Place(record.actor, x, y, zOffset, yaw, scale, 0, 0, centerX, centerY)
	record.actor:SetAlpha(alpha * Fade(y, far))
end

-- How far the view has moved to the fight camera, from 0 to 1 (eased): it
-- moves over while a boss is here and back once it's gone.
function Renderer:UpdateFightView(now)
	local elapsed = math.min(1 / 15, now - (self.lastViewAt or now))
	self.lastViewAt = now
	local target = self.bossRecord and 1 or 0
	local view = self.fightView or 0
	if view ~= target then
		local step = elapsed / FIGHT_CAMERA_TIME
		view = target > view and math.min(target, view + step) or math.max(target, view - step)
		self.fightView = view
	end
	return view * view * (3 - 2 * view)
end

-- Draws the fog back as the view moves to the fight camera, and in an orc
-- run, where the camera is further back, enough to keep the road clear just
-- past the orc.
function Renderer:UpdateFog(zone, fight)
	local fog = zone.fog
	local lift = 0
	local view = self.view
	if view.clearAhead then
		lift = math.max(0, CameraToRoad(view.camera, view.clearAhead) - fog.near)
	elseif fight > 0 then
		lift = fight * math.max(0, FightCameraToBoss() - fog.near - BOSS_FOG * (fog.far - fog.near))
	end
	if lift ~= (self.fogLift or 0) then
		self.fogLift = lift
		self.scene:SetFog(fog, lift)
	end
end

-- Spears in flight toward the boss.
function Renderer:DrawShots(now)
	local index = 1
	while index <= #self.shots do
		local shot = self.shots[index]
		local record = shot.record
		local progress = (now - shot.startAt) / SPEAR_FLIGHT
		if progress >= 1 or not self.bossY then
			self:FreeRecord(record)
			tremove(self.shots, index)
		else
			self:CheckLoaded(record)
			if record.ready then
				local scale, zOffset = self:Fit(record)
				local toX, toY, toZ = self.bossAimX or 0, self.bossY, self.bossHandZ or 3
				local x = shot.fromX + (toX - shot.fromX) * progress
				local y = 0.5 + (toY - 0.5) * progress
				local z = shot.fromZ + (toZ - shot.fromZ) * progress + 8 * progress * (1 - progress)
				self.scene:Place(record.actor, x, y, z + zOffset, HALF_PI, scale, -0.4 + progress * 0.8, 0)
				record.actor:SetAlpha(1)
			else
				record.actor:SetAlpha(0)
			end
			index = index + 1
		end
	end
end

-- Runner ---------------------------------------------------------------------------

-- The runner is the Schmoovin Man, or in an orc run an orc.
function Renderer:SetupRunner()
	local list = Assets[self.view.runner]
	-- An orc player's orc run shows their own character.
	if self.view.ownOrc and PlayerIsOrc() then
		list = Assets[self.view.ownOrc]
	end
	if self.runner and self.runner.list ~= list then
		self:FreeRecord(self.runner)
		self.runner = nil
	end
	if not self.runner then
		self.runner = self:NewRecord(list, "runner")
	end
	self.runnerAnim = nil
end

function Renderer:PlayRunner(key, speed)
	local runner = self.runner
	if not (runner and runner.ready) then
		return
	end
	speed = speed or 1
	if self.runnerAnim == key and math.abs((self.runnerAnimSpeed or 1) - speed) < 0.08 then
		return
	end
	self.runnerAnim, self.runnerAnimSpeed = key, speed
	runner.actor:SetAnimation(Assets.anims[key][1], nil, speed)
end

function Renderer:UpdateMount(world)
	local runner = world.runner
	if runner.flying and not self.mount then
		self.mount = self:NewRecord(Assets.windRider, "windRider")
		self.mountAttached = false
	elseif not runner.flying and self.mount and runner.z < 0.5 then
		self:Dismount()
	end
	local mount = self.mount
	if mount then
		self:CheckLoaded(mount)
		if mount.ready and not mount.animated then
			mount.actor:SetAnimation(Assets.anims.windRiderFly[1], nil, 1)
			mount.animated = true
		end
	end
end

-- Takes the runner off the wind rider. Riding leaves the runner's actor
-- scaled by the mount even after detaching, so the runner gets a fresh actor
-- and the old one is retired rather than pooled, where it would make some
-- later jogger or prop huge.
function Renderer:Dismount()
	local mount = self.mount
	if not mount then
		return
	end
	local runner = self.runner
	if self.mountAttached and runner then
		pcall(mount.actor.DetachFromMount, mount.actor, runner.actor)
	end
	-- The new runner is made before the mount goes back to the pool, so it
	-- can't be handed the actor that was just the mount.
	if self.mountAttachTried and runner then
		runner.actor:ClearModel()
		runner.actor:Hide()
		self.runner = nil
		self:SetupRunner()
	end
	self:FreeRecord(mount)
	self.mount = nil
	self.mountAttached = false
	self.mountAttachTried = false
	self.runnerAnim = nil
end

function Renderer:DrawRunner(world, now)
	local runner = self.runner
	if not runner then
		return
	end
	self:CheckLoaded(runner)
	if not runner.ready then
		runner.actor:SetAlpha(0)
		return
	end
	local state = world.runner
	local scale, zOffset = self:Fit(runner)
	local lean = (state.x - (self.lastRunnerX or state.x)) * -1.5
	self.lastRunnerX = state.x
	local speedFactor = math.max(0.8, math.min(2.2, world.speed / 11))

	local mount = self.mount
	if mount and mount.ready then
		local mountScale, mountZ = self:Fit(mount)
		local mx, mz = state.x, math.max(state.z - 1.2, 0)
		self.scene:Place(mount.actor, mx, 0, mz + mountZ, HALF_PI, mountScale, 0, lean)
		mount.actor:SetAlpha(1)
		if not self.mountAttached and not self.mountAttachTried then
			self.mountAttachTried = true
			local ok, attached = pcall(mount.actor.AttachToMount, mount.actor, runner.actor, Assets.anims.mount[1])
			self.mountAttached = ok and attached ~= false
		end
		if self.mountAttached then
			runner.actor:SetAlpha(1)
			return
		end
		self:PlayRunner("mount")
		self.scene:Place(runner.actor, state.x, -0.2, state.z + zOffset + 0.4, HALF_PI, scale, 0, lean)
		runner.actor:SetAlpha(1)
		return
	end

	if state.state == "crash" then
		self:PlayRunner("death")
	elseif state.state == "duck" then
		self:PlayRunner("duck", speedFactor)
	elseif state.z > 0.05 then
		self:PlayRunner(state.vz > 0 and "jump" or "fall")
	else
		self:PlayRunner("run", speedFactor)
	end
	self.scene:Place(runner.actor, state.x, 0, state.z + zOffset, HALF_PI, scale, 0, lean)
	runner.actor:SetAlpha(world.safeLeft > 0 and (math.floor(now * 12) % 2 == 0 and 0.45 or 1) or 1)
end

-- Scenery --------------------------------------------------------------------------

function Renderer:UpdateScenery(world, zone)
	local moved = world.distance - self.sceneryDistance
	self.sceneryDistance = world.distance
	local far = zone.fog.far + 5
	local spawnY = far

	-- Spawn new pieces at the horizon as distance is covered.
	self.sceneryNext = self.sceneryNext - moved
	while self.sceneryNext <= 0 do
		self.sceneryNext = self.sceneryNext + 5 + math.random() * 5
		local side = math.random() < 0.5 and -1 or 1
		local list = zone.scenery
		local candidate = list[math.random(#list)]
		local record = self:NewRecord({ candidate }, "scenery")
		if record then
			record.x = side * (SceneryInner() + math.random() * 12)
			record.y = spawnY + self.sceneryNext
			record.yaw = math.random() * 6.28
			tinsert(self.scenery, record)
		end
	end

	-- Compacted in place: kept pieces slide down, so no list is made each frame.
	local scenery = self.scenery
	local count, kept = #scenery, 0
	local gone = self.view.behind - 4
	for index = 1, count do
		local record = scenery[index]
		record.y = record.y - moved
		if record.y < gone or record.failed then
			self:FreeRecord(record)
		else
			self:CheckLoaded(record)
			if record.ready then
				local scale, zOffset = self:Fit(record)
				if not record.offRoad then
					record.offRoad = true
					record.x = OffRoad(record.x, self.bounds[record.key], record.yaw, scale)
				end
				self.scene:Place(record.actor, record.x, record.y, zOffset, record.yaw, scale)
				record.actor:SetAlpha(Fade(record.y, far))
			else
				record.actor:SetAlpha(0)
			end
			kept = kept + 1
			scenery[kept] = record
		end
	end
	for index = kept + 1, count do
		scenery[index] = nil
	end
end

-- Joggers ------------------------------------------------------------------------

-- Jogger lists are picked in proportion to their `weight` (default 1).
local function JoggerWeight(list)
	return list.weight or 1
end

-- Joggers run alongside the road, slower than you, and report each overtake.
function Renderer:UpdateJoggers(world, zone, moved, now)
	local far = zone.fog.far + 5
	local lanes = ns.Tuning.lanes
	local roadHalf = (lanes[#lanes] - lanes[1]) * 0.75
	-- You close on them at the share of your speed they don't match.
	local relative = 1 - Assets.joggerSpeed

	self.joggerNext = self.joggerNext - moved
	if self.joggerNext <= 0 then
		self.joggerNext = 30 + math.random() * 40
		local list = ns.Random.Weighted(Assets.joggers, JoggerWeight, math.random()) or Assets.joggers[1]
		local record = self:NewRecord(list, "jogger")
		if record then
			record.race = list.race
			record.name = list.name
			record.lines = list.lines
			record.replies = list.replies
			record.side = math.random() < 0.5 and -1 or 1
			record.x = record.side * (roadHalf + 1.0 + math.random() * 1.2)
			record.y = far
			tinsert(self.joggers, record)
		end
	end

	local joggers = self.joggers
	local count, kept = #joggers, 0
	for index = 1, count do
		local record = joggers[index]
		local before = record.y
		record.y = record.y - moved * relative
		-- An exchange (Tauren, famous faces) starts a little before you reach
		-- them, so their reply stays on screen; for the rest you speak as you go by.
		local callAt = (record.race == "tauren" or record.replies) and CALL_DISTANCE or 0
		if before > callAt and record.y <= callAt and not record.passed then
			record.passed = true
			tinsert(self.passes, record)
		end
		if record.y < -14 or record.failed then
			record.gone = true
			self:FreeRecord(record)
		else
			self:CheckLoaded(record)
			if record.ready then
				local scale, zOffset = self:Fit(record)
				if not record.animated then
					record.actor:SetAnimation(Assets.anims.run[1], nil, 0.9)
					record.animated = true
				end
				self.scene:Place(record.actor, record.x, record.y, zOffset, HALF_PI, scale)
				record.actor:SetAlpha(Fade(record.y, far))
			else
				record.actor:SetAlpha(0)
			end
			kept = kept + 1
			joggers[kept] = record
		end
	end
	for index = kept + 1, count do
		joggers[index] = nil
	end
end

-- Joggers overtaken since the last call (each has .side -1 or 1 and .race,
-- and famous faces .name, .lines and .replies). The list is only good until
-- the next call: two lists take turns, so none is made each frame.
function Renderer:TakePasses()
	local passes = self.passes
	wipe(self.sparePasses)
	self.passes, self.sparePasses = self.sparePasses, passes
	return passes
end

-- The name of the model an entity is drawn with (the one that loaded, which
-- may be a backup or an Options pick), or nil if it has none.
function Renderer:EntityModelName(id)
	local record = id and self.records[id]
	local candidate = record and not record.failed and record.candidate
	return candidate and candidate.name or nil
end

-- Screen position above a jogger's head, or nil once they've left the view.
function Renderer:JoggerHeadPoint(record)
	if record.gone or not record.ready then
		return nil
	end
	return self.scene:Project(record.x, record.y, Assets.joggerHeight + 0.4)
end

-- Screen position above an orc run's Tauren's head, or nil once it's gone.
function Renderer:EntityHeadPoint(entity)
	local record = self.records[entity.id]
	if not (record and record.ready) then
		return nil
	end
	return self.scene:Project(entity.x, entity.y, Assets.runnerHeight + 0.4)
end

-- Screen position above the runner's head, for the speech bubble.
function Renderer:RunnerHeadPoint(world)
	local state = world.runner
	return self.scene:Project(state.x, 0, state.z + Assets.runnerHeight + 0.4)
end

-- Scatters scenery along the whole visible track, for a full view at the start.
function Renderer:FillScenery(world, zone)
	local far = zone.fog.far + 5
	local y = self.view.behind
	while y < far do
		local side = math.random() < 0.5 and -1 or 1
		local candidate = zone.scenery[math.random(#zone.scenery)]
		local record = self:NewRecord({ candidate }, "scenery")
		if record then
			record.x = side * (SceneryInner() + math.random() * 12)
			record.y = y
			record.yaw = math.random() * 6.28
			tinsert(self.scenery, record)
		end
		y = y + 4 + math.random() * 4
	end
	self.sceneryDistance = world.distance
	self.sceneryNext = 0
end

-- Frame ------------------------------------------------------------------------------

-- Clears the view for a new run (or the start screen). mode: nil, or "orc"
-- for an orc run.
function Renderer:Reset(mode)
	self.view = VIEWS[mode] or VIEWS.normal
	self.ground:SetNear(self.view.behind)
	for id, record in pairs(self.records) do
		self:FreeRecord(record)
		self.records[id] = nil
	end
	for _, record in ipairs(self.scenery) do
		self:FreeRecord(record)
	end
	wipe(self.scenery)
	for _, record in ipairs(self.joggers) do
		self:FreeRecord(record)
	end
	wipe(self.joggers)
	wipe(self.passes)
	self.joggerNext = 20
	self.joggerDistance = nil
	self:Dismount()
	self:FreeBoss()
	self.fightView = 0
	self.fogLift = 0
	-- The camera starts each run in place, not still easing down from the
	-- last run's flight or across from its lane.
	self.camX, self.camZ, self.lastCameraAt = nil, nil, nil
	self.markers.count = 0
	self.ground:DrawMarkers(self.markers)
	self.lastRunnerX = nil
	self:SetupRunner()
end

function Renderer:SetZone(zone)
	self.zone = zone
	self.scene:SetLighting(zone.light)
	self.scene:SetFog(zone.fog, self.fogLift)
	self.ground:SetZone(zone)
end

function Renderer:Update(world, now)
	local zone = self.zone
	local state = world.runner
	if not self.scene.calibrated then
		self.scene:Calibrate()
	end
	local fight = self:UpdateFightView(now)
	local base = self.view.camera
	-- Camera eases toward the runner's lane and rises in flight. The shares
	-- are those of one frame at 60 a second, scaled by the time that passed,
	-- so it moves the same at any frame rate.
	local frames = math.min(1 / 15, now - (self.lastCameraAt or (now - 1 / 60))) * 60
	self.lastCameraAt = now
	local easeX, easeZ = 1 - 0.88 ^ frames, 1 - 0.92 ^ frames
	local camX = (self.camX or 0) + (state.x * 0.55 - (self.camX or 0)) * easeX
	local baseZ = CameraSetting("height", fight, base)
	local camZ = (self.camZ or baseZ) + ((state.flying and state.z + 1.5 or baseZ + state.z * 0.3) - (self.camZ or baseZ)) * easeZ
	self.camX, self.camZ = camX, camZ
	self.scene:SetFieldOfView(CameraSetting("fov", fight, base))
	self.scene:LookAt(camX, CameraSetting("lookAhead", fight, base), camZ, CameraSetting("distance", fight, base), CameraSetting("pitch", fight, base))

	self:UpdateMount(world)
	self:DrawRunner(world, now)
	self.speed = world.speed
	self.taurenSpeed = world.taurenSpeed
	self.markers.count = 0
	self:DrawBoss(world, zone.fog.far + 5, now)
	self:UpdateFog(zone, fight)
	self:DrawShots(now)
	self:SyncEntities(world, zone, now)
	local moved = world.distance - (self.joggerDistance or world.distance)
	self.joggerDistance = world.distance
	self:UpdateScenery(world, zone)
	-- An orc run has its Tauren on the road instead of joggers beside it.
	if self.view.joggers then
		self:UpdateJoggers(world, zone, moved, now)
	end
	self.ground:Draw(world.distance)
	self.ground:DrawMarkers(self.markers)
end

-- For working out why a creature sits off its lane: one line for each charger
-- and boss on screen, with its model, where the middle of its standing box
-- and of its all-animation box are (model yards, side to side), its scale and
-- how far it's shifted to centre it.
function Renderer:Measurements()
	local lines = {}
	local function Add(record)
		local box = record and record.key and self.bounds[record.key]
		if box and (record.role == "charger" or record.role == "boss") then
			local scale = self:Fit(record)
			lines[#lines + 1] = ("%s %s (%s): standing box %.2f to %.2f (middle %.2f), all-animation middle %s, scale %.2f, shifted %.2f yd"):format(
				record.role, record.candidate.name or "?", record.key, box[2], box[5], (box[2] + box[5]) / 2,
				box[7] and ("%.2f"):format(box[7]) or "none", scale, (box[7] or 0) * scale)
		end
	end
	for _, record in pairs(self.records) do
		Add(record)
	end
	Add(self.bossRecord)
	return lines
end

-- Reports models that never loaded, once per run.
function Renderer:TakeFailures()
	local failures = self.failures
	self.failures = {}
	return failures
end
