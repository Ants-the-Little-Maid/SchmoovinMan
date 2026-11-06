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

-- Characters and creatures: measured by the active box only, and their scale
-- kept within a sane range (they're about life size at scale 1).
local CHARACTER = { runner = true, jogger = true, alliance = true, charger = true, windRider = true }
local CHARACTER_SCALE_MIN, CHARACTER_SCALE_MAX = 0.5, 2.0
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
local CAMERA = { lookAhead = 4, distance = 16, pitch = math.rad(20), height = 1.6 }
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

local function CandidateKey(candidate)
	return candidate.fileID and ("f" .. candidate.fileID) or ("d" .. tostring(candidate.displayID))
end

-- Scenery starts a few yards past the road's edge.
local function SceneryInner()
	local lanes = ns.Tuning.lanes
	return (lanes[#lanes] - lanes[1]) * 0.75 + 3
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
	self.joggerNext = 20
	self.sceneryNext = 0
	self.sceneryDistance = 0
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
	local actor = record.actor
	actor:ClearModel()
	local ok
	if candidate.displayID then
		ok = actor:SetModelByCreatureDisplayID(candidate.displayID)
	else
		ok = actor:SetModelByFileID(candidate.fileID)
	end
	if ok == false then
		self:MarkBad(record)
	end
end

function Renderer:MarkBad(record)
	-- Several copies of one model can fail together; report each model once.
	if not self.badModels[record.key] then
		self.badModels[record.key] = true
		tinsert(self.failures, record.key)
	end
	record.index = record.index + 1
	self:LoadCandidate(record)
end

-- Reads the bounding box once the model has loaded; gives up after a while.
function Renderer:CheckLoaded(record)
	if record.ready or record.failed then
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
			self.bounds[record.key] = { minX, minY, minZ, maxX, maxY, maxZ }
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
	if role == "runner" then
		scale = Assets.runnerHeight / sizeZ
	elseif role == "post" then
		scale = (TARGET.high.lift + TARGET.high.height) / sizeZ
	elseif role == "jogger" or role == "alliance" then
		scale = Assets.joggerHeight / sizeZ
	elseif role == "windRider" then
		scale = Assets.windRiderLength / math.max(sizeX, sizeY)
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
	if CHARACTER[role] then
		scale = math.max(CHARACTER_SCALE_MIN, math.min(CHARACTER_SCALE_MAX, scale))
	end
	-- Hazards are centred on their lane by their box, not their pivot, so a
	-- model built off-centre doesn't reach into the next lane.
	local centerX, centerY
	if center then
		centerX, centerY = (box[1] + box[4]) / 2, (box[2] + box[5]) / 2
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
	if role == "coin" or role == "gem" then
		return Assets.tokens[role]
	elseif Assets.powerups[role] then
		return Assets.powerups[role]
	elseif role == "charger" then
		return zone.charger
	elseif role == "alliance" then
		return Assets.alliance[math.random(#Assets.alliance)]
	end
	-- Zone models first, then the shared fallbacks.
	local list = {}
	for _, candidate in ipairs(zone.obstacles[role] or {}) do
		tinsert(list, candidate)
	end
	for _, candidate in ipairs(ns.GenericObstacles[role] or {}) do
		tinsert(list, candidate)
	end
	return list
end

-- Hazards of the same kind side by side in one row are one barrier, so it's
-- clear they block those lanes together. Each entity learns whether it joins
-- the lane to its left or right.
local GROUPED = { low = true, high = true, wall = true, block = true }

local function MarkGroups(entities)
	local rows = {}
	for _, entity in ipairs(entities) do
		entity.joinLeft, entity.joinRight = nil, nil
		if GROUPED[entity.role] and not entity.smashed then
			local key = entity.role .. ":" .. math.floor(entity.arrive * 1000 + 0.5)
			rows[key] = rows[key] or {}
			rows[key][entity.lane] = entity
		end
	end
	for _, lanes in pairs(rows) do
		for lane, entity in pairs(lanes) do
			entity.joinLeft = lanes[lane - 1] ~= nil
			entity.joinRight = lanes[lane + 1] ~= nil
		end
	end
end

function Renderer:SyncEntities(world, zone, now)
	local seen = {}
	local far = zone.fog.far + 5
	MarkGroups(world.entities)
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
	if role == "coin" or role == "gem" or ns.Rules.POWERUP[role] then
		yaw = now * 2.5 + record.spin
		z = z - 0.5 + math.sin(now * 4 + record.spin) * 0.1
	elseif role == "charger" then
		yaw = -HALF_PI
		if not record.animated then
			actor:SetAnimation(Assets.anims.creatureRun[1], nil, 1.4)
			record.animated = true
		end
	elseif role == "alliance" then
		-- Jogging away from you, like the roadside joggers.
		yaw = HALF_PI
		if not record.animated then
			actor:SetAnimation(Assets.anims.run[1], nil, 0.9)
			record.animated = true
		end
	end
	local x, y = entity.x, entity.y
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
		self:DrawPosts(record, entity, y, Fade(y, far))
	end
	actor:SetAlpha(Fade(y, far))
end

-- Runner ---------------------------------------------------------------------------

function Renderer:SetupRunner()
	if not self.runner then
		self.runner = self:NewRecord(Assets.runner, "runner")
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
		if self.mountAttached then
			pcall(self.mount.actor.DetachFromMount, self.mount.actor, self.runner.actor)
		end
		self:FreeRecord(self.mount)
		self.mount = nil
		self.mountAttached = false
		self.runnerAnim = nil
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
	self.mountAttachTried = false

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

	local keep = {}
	for _, record in ipairs(self.scenery) do
		record.y = record.y - moved
		if record.y < -10 or record.failed then
			self:FreeRecord(record)
		else
			self:CheckLoaded(record)
			if record.ready then
				local scale, zOffset = self:Fit(record)
				self.scene:Place(record.actor, record.x, record.y, zOffset, record.yaw, scale)
				record.actor:SetAlpha(Fade(record.y, far))
			else
				record.actor:SetAlpha(0)
			end
			tinsert(keep, record)
		end
	end
	self.scenery = keep
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

	local keep = {}
	for _, record in ipairs(self.joggers) do
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
			tinsert(keep, record)
		end
	end
	self.joggers = keep
end

-- Joggers overtaken since the last call (each has .side -1 or 1 and .race,
-- and famous faces .name, .lines and .replies).
function Renderer:TakePasses()
	local passes = self.passes
	self.passes = {}
	return passes
end

-- Screen position above a jogger's head, or nil once they've left the view.
function Renderer:JoggerHeadPoint(record)
	if record.gone or not record.ready then
		return nil
	end
	return self.scene:Project(record.x, record.y, Assets.joggerHeight + 0.4)
end

-- Screen position above the runner's head, for the speech bubble.
function Renderer:RunnerHeadPoint(world)
	local state = world.runner
	return self.scene:Project(state.x, 0, state.z + Assets.runnerHeight + 0.4)
end

-- Scatters scenery along the whole visible track, for a full view at the start.
function Renderer:FillScenery(world, zone)
	local far = zone.fog.far + 5
	local y = -6
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

function Renderer:Reset()
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
	if self.mount then
		self:FreeRecord(self.mount)
		self.mount = nil
	end
	self.mountAttached = false
	self.mountAttachTried = false
	self.lastRunnerX = nil
	self:SetupRunner()
end

function Renderer:SetZone(zone)
	self.zone = zone
	self.scene:SetLighting(zone.light)
	self.scene:SetFog(zone.fog)
	self.ground:SetZone(zone)
end

function Renderer:Update(world, now)
	local zone = self.zone
	local state = world.runner
	if not self.scene.calibrated then
		self.scene:Calibrate()
	end
	-- Camera eases toward the runner's lane and rises in flight.
	local camX = (self.camX or 0) + (state.x * 0.55 - (self.camX or 0)) * 0.12
	local baseZ = CAMERA.height
	local camZ = (self.camZ or baseZ) + ((state.flying and state.z + 1.5 or baseZ + state.z * 0.3) - (self.camZ or baseZ)) * 0.08
	self.camX, self.camZ = camX, camZ
	self.scene:LookAt(camX, CAMERA.lookAhead, camZ, CAMERA.distance, CAMERA.pitch)

	self:UpdateMount(world)
	self:DrawRunner(world, now)
	self:SyncEntities(world, zone, now)
	local moved = world.distance - (self.joggerDistance or world.distance)
	self.joggerDistance = world.distance
	self:UpdateScenery(world, zone)
	self:UpdateJoggers(world, zone, moved, now)
	self.ground:Draw(world.distance)
end

-- Reports models that never loaded, once per run.
function Renderer:TakeFailures()
	local failures = self.failures
	self.failures = {}
	return failures
end
