local _, ns = ...

--[[ The run's simulation. Pure Lua: no WoW API.

API for the renderer and UI:
  world = ns.World.New(seed, tuning [, options])
      options.zones          ordered zone keys; the first is always first
      options.recordTimeline true to keep world.timeline ({t, lane, code})
      options.bosses         false to leave bosses out
  world:Step(dt)             advances in fixed steps (tuning.step)
  world:Input(action)        "left" | "right" | "jump" | "duck"
  world:DrainEvents()        returns and clears this frame's events

Fields:
  time (seconds run), course (the zone clock: time less the time spent in boss
      fights, which zones and speed follow), speed (shown speed), distance
      (yards run, for scrolling the ground)
  zoneIndex, zoneKey, zoneStart (course time the current zone began)
  score, tokenPoints, timePoints, movePoints, bossPoints, tokens, gems, jumps,
      ducks, knocks, spearHits, bossesDriven, bossesSurvived
  powerups = { windRider = left, magnet = left, goldRush = left, stampede = left }
  shield (bool), safeLeft (seconds of no-hit after a shield break or landing)
  runner = { lane, x, z, state, flying }   state: run | jump | duck | fly | crash
  boss = nil, or the latest fight: { key, name, zone, start, ends, needed, hits,
      state = "fight" | "driven" | "survived", endedAt }
  entities = array of { id, role, lane, x, y, z, arrive, magnet, smashed, knocked, thrown }
      role: low | high | block | wall | charger | coin | gem | alliance | spear |
            windRider | magnet | shield | goldRush | stampede
      alliance: an Alliance jogger in a lane, jogging away from you; knocked
            (and worth points) when you run into it, never a hazard
      thrown: a hazard the boss throws, with phase "waiting" (in its hand),
            "flying" or "landed" (see Rules.ThrowPhase; it only ever moves on);
            spear: a boss-only pickup that's thrown at the boss when you grab it
  over (bool), crashRole, crashZoneKey

Events ({ type = ..., ... }):
  collect {role, points}, powerup {role}, expire {role}, zone {index, key, fromSpeed},
  cleared {role, move, points} (jumped a low obstacle or ducked a high bar in your path),
  knock {points} (ran into an Alliance jogger),
  bossStart {name, needed, limit}, spear {hits, needed, points},
  bossEnd {result = "driven" | "survived", name, points},
  crash {role}, shieldBreak {role}, smash {role}, jump, duck, land, lane
]]

local World = {}
World.__index = World
ns.World = World

local Rules, Patterns, Runner, Random = ns.Rules, ns.Patterns, ns.Runner, ns.Random

World.DEFAULT_ZONES = {
	"mulgore", "burningsteppes", "ashenvale", "silithus", "ungoro", "barrens", "thousandneedles", "winterspring",
	"westfall", "moonglade", "stormwind", "darnassus", "ironforge", "thunderbluff", "orgrimmar", "undercity",
}

local CODE_ROLE = { L = "low", H = "high", B = "block", W = "wall", C = "charger", c = "coin", a = "coin", g = "gem" }
local GROUND_TOKEN_Z = 0.9
local AIR_TOKEN_Z = 2.2
-- What a boss throws for each pattern code: hazards only, and a charging
-- creature becomes a block (it can't be thrown; a block asks the same of you).
local BOSS_CODE = { L = "L", A = "L", H = "H", B = "B", W = "W", C = "B" }
local NEVER = -1000

function World.New(seed, tuning, options)
	options = options or {}
	local self = setmetatable({}, World)
	self.tuning = tuning
	self.rng = Random.New(seed)
	self.zonePool = options.zones or World.DEFAULT_ZONES
	self.zoneOrder = { self.zonePool[1] }
	self.timeline = options.recordTimeline and {} or nil

	self.time = 0
	self.course = 0
	self.paused = 0
	self.accumulator = 0
	self.distance = 0
	self.zoneIndex = 1
	self.zoneKey = self.zoneOrder[1]
	self.zoneStart = 0
	self.baseSpeed = Rules.Speed(tuning, 0)
	self.speed = self.baseSpeed
	self.stampedeBlend = 0

	self.score, self.tokenPoints, self.timePoints = 0, 0, 0
	self.movePoints, self.jumps, self.ducks, self.knocks = 0, 0, 0, 0
	self.bossPoints, self.spearHits, self.bossesDriven, self.bossesSurvived = 0, 0, 0, 0
	self.tokens, self.gems = 0, 0
	self.powerups = {}
	self.shield = false
	self.safeLeft = 0
	self.lastPowerupTime = -1000

	self.runner = Runner.New(tuning)
	self.entities = {}
	self.events = {}
	self.nextId = 0
	self.cursor = 2.5
	self.skyNext = 0
	self.skyLane = 2
	self.over = false

	if options.bosses ~= false and tuning.boss then
		local first = tuning.boss.first
		self.bossZone = self:FindBossZone(self.rng:Int(first[1], first[2]))
	end
	return self
end

function World:Emit(event)
	self.events[#self.events + 1] = event
end

function World:DrainEvents()
	local events = self.events
	self.events = {}
	return events
end

-- Zone key for a zone number: the first pool entry, then shuffled rounds of
-- the rest, never repeating the zone just left.
function World:ZoneKey(index)
	local order = self.zoneOrder
	while #order < index do
		local bag = {}
		for position = 2, #self.zonePool do
			bag[#bag + 1] = self.zonePool[position]
		end
		self.rng:Shuffle(bag)
		if #bag > 1 and bag[1] == order[#order] then
			bag[1], bag[#bag] = bag[#bag], bag[1]
		end
		for _, key in ipairs(bag) do
			order[#order + 1] = key
		end
	end
	return order[index]
end

function World:Input(action)
	if self.over then
		return
	end
	local event = self.runner:Input(action)
	if event then
		self:Emit({ type = event })
	end
end

function World:Step(dt)
	local tuning = self.tuning
	self.accumulator = self.accumulator + math.min(dt, tuning.maxFrame)
	while self.accumulator >= tuning.step do
		self.accumulator = self.accumulator - tuning.step
		if self.over then
			self.accumulator = 0
			return
		end
		self:Tick(tuning.step)
	end
end

-- Bosses -------------------------------------------------------------------------

-- The boss data for a zone key, if that zone has one.
local function BossData(key)
	local zone = ns.ZonesByKey and ns.ZonesByKey[key]
	return zone and zone.boss
end

-- The first zone from `index` on that has a boss.
function World:FindBossZone(index)
	if #self.zonePool < 2 then
		return nil
	end
	for zone = index, index + 2 * #self.zonePool do
		if BossData(self:ZoneKey(zone)) then
			return zone
		end
	end
	return nil
end

-- Run time the next boss turns up. Only valid between fights, while the zone
-- clock runs in step with the run.
function World:BossStart()
	local tuning = self.tuning
	return (self.bossZone - 1) * tuning.zoneLength + tuning.boss.delay + self.paused
end

function World:InFight()
	return self.boss ~= nil and self.boss.state == "fight"
end

-- The fight a chunk arriving at `at` falls in: its zone and the run time the
-- boss gives up. Chunks are spawned seconds ahead, so this also covers a fight
-- that hasn't started yet.
function World:FightAt(at)
	if self:InFight() then
		return self.boss.zone, self.boss.ends
	elseif self.bossZone then
		local start = self:BossStart()
		if at >= start then
			return self.bossZone, start + self.tuning.boss.limit
		end
	end
	return nil
end

function World:StartBoss()
	local tuning = self.tuning
	local zone = self.bossZone
	local key = self:ZoneKey(zone)
	local data = BossData(key)
	self.bossZone = nil
	self.boss = {
		key = key,
		name = data.name,
		zone = zone,
		start = self.time,
		ends = self.time + tuning.boss.limit,
		needed = Rules.SpearsNeeded(tuning, zone),
		hits = 0,
		state = "fight",
	}
	self:Emit({ type = "bossStart", name = data.name, needed = self.boss.needed, limit = tuning.boss.limit })
end

-- Drops an entity, and its timeline record (so tests don't count it).
local function Forget(entity)
	if entity.record then
		entity.record.code = "."
	end
end

function World:EndBoss(result)
	local tuning = self.tuning
	local boss = self.boss
	boss.state = result
	boss.endedAt = self.time
	local points = result == "driven" and tuning.points.bossDriven or tuning.points.bossSurvived
	self.bossPoints = self.bossPoints + points
	if result == "driven" then
		self.bossesDriven = self.bossesDriven + 1
	else
		self.bossesSurvived = self.bossesSurvived + 1
	end

	-- The boss takes what it hasn't thrown yet with it, and spears go too.
	local last = self.time
	local kept = 0
	local entities = self.entities
	local count = #entities
	for index = 1, count do
		local entity = entities[index]
		local keep = true
		if entity.role == "spear" then
			keep = false
		elseif entity.thrown then
			if entity.phase == "waiting" then
				keep = false
			else
				last = math.max(last, entity.arrive)
			end
		end
		if keep then
			kept = kept + 1
			entities[kept] = entity
		else
			Forget(entity)
		end
	end
	for index = kept + 1, count do
		entities[index] = nil
	end

	-- Ordinary chunks start again after the last hazard still coming, and far
	-- enough ahead to come out of the fog like any other.
	self.cursor = math.max(self.time + tuning.spawnAhead / self.speed, last + Rules.Gap(tuning, boss.zone))
	self.bossFull = nil
	local every = tuning.boss.every
	self.bossZone = self:FindBossZone(boss.zone + self.rng:Int(every[1], every[2]))
	self:Emit({ type = "bossEnd", result = result, name = boss.name, points = points })
end

function World:UpdateBoss()
	if self:InFight() then
		if self.bossBeaten then
			self.bossBeaten = nil
			self:EndBoss("driven")
		elseif self.time >= self.boss.ends then
			self:EndBoss("survived")
		end
	elseif self.bossZone and self.time >= self:BossStart() then
		self:StartBoss()
	end
end

-- A spear grabbed in a fight is thrown at the boss.
function World:HitBoss()
	local boss = self.boss
	if not self:InFight() then
		return
	end
	local points = self.tuning.points.spear
	boss.hits = boss.hits + 1
	self.spearHits = self.spearHits + 1
	self.bossPoints = self.bossPoints + points
	self:Emit({ type = "spear", hits = boss.hits, needed = boss.needed, points = points })
	if boss.hits >= boss.needed then
		-- Ended after this step's entity pass, which mustn't see the list change.
		self.bossBeaten = true
	end
end

-- Spawning ------------------------------------------------------------------

function World:AddEntity(role, lane, arrive, z)
	self.nextId = self.nextId + 1
	local entity = {
		id = self.nextId,
		role = role,
		lane = lane,
		x = self.tuning.lanes[lane],
		z = z or 0,
		arrive = arrive,
		y = (arrive - self.time) * self.speed,
	}
	self.entities[#self.entities + 1] = entity
	return entity
end

local POWERUP_NAMES = { "magnet", "goldRush", "shield", "windRider", "stampede" }

-- noFlight leaves the Wind Rider out, so a flight never runs into a boss.
function World:PickPowerup(zone, noFlight)
	local weights = self.tuning.powerupWeights
	return Random.Weighted(POWERUP_NAMES, function(name)
		if noFlight and name == "windRider" then
			return 0
		end
		return weights[name].minZone <= zone and weights[name].weight or 0
	end, self.rng:Next()) or "magnet"
end

-- Pattern codes an Alliance jogger mustn't run through.
local SOLID = { L = true, H = true, B = true, W = true, C = true, A = true }
local SOLID_ROLE = { low = true, high = true, block = true, wall = true, charger = true }

-- Sometimes an Alliance jogger jogs into the gap after a chunk. They move
-- away from you, so before you reach them they cover part of the track ahead:
-- only a lane with nothing solid along that stretch is used, so they never
-- run through a hazard. `items` are the chunk just placed, from `start`.
function World:SpawnAlliance(items, start, arrive, zone)
	local alliance = self.tuning.alliance
	if not alliance or zone < alliance.minZone or self.rng:Next() >= alliance.chance then
		return
	end
	-- Anything arriving from `from` on lies on the stretch they jog over.
	local from = arrive - alliance.speedShare * (arrive - self.time) - 0.5
	local blocked = {}
	for _, item in ipairs(items) do
		local at = start + item.t
		if SOLID[item.code] and at >= from then
			blocked[item.lane] = true
		end
	end
	for _, entity in ipairs(self.entities) do
		if SOLID_ROLE[entity.role] and entity.arrive >= from then
			blocked[entity.lane] = true
		end
	end
	local free = {}
	for lane = 1, #self.tuning.lanes do
		if not blocked[lane] then
			free[#free + 1] = lane
		end
	end
	if #free > 0 then
		self:AddEntity("alliance", self.rng:Pick(free), arrive, 0)
	end
end

function World:Record(arrive, lane, code)
	if self.timeline then
		local record = { t = arrive, lane = lane, code = code }
		self.timeline[#self.timeline + 1] = record
		return record
	end
end

-- Spears go where a runner can take one and still get through the rest of
-- the chunk: a lane with nothing solid close by, from which every later row
-- can still be passed. `hazards` are the chunk's items at run times, sorted.
function World:SpearSafe(hazards, lane, at)
	local later = {}
	for _, item in ipairs(hazards) do
		if item.lane == lane and math.abs(item.t - at) < 0.45 then
			return false
		end
		if item.t > at then
			later[#later + 1] = item
		end
	end
	return (Patterns.Feasible(later, self.tuning, { { lane = lane, t = at, jump = NEVER, duck = NEVER } }))
end

-- Places up to `count` spears spread between `from` and `to` (searching back
-- as far as `earliest`), at least half a second apart. Returns how many it
-- placed.
function World:PlaceSpears(hazards, from, to, count, earliest)
	earliest = earliest or from
	local placedAt = {}
	for index = 1, count do
		local base = from + (to - from) * (index - 0.5) / count
		local placed = false
		for step = 0, 12 do
			-- Search outward from the even spot: +0.15, -0.15, +0.3, ...
			local at = base + math.ceil(step / 2) * 0.15 * (step % 2 == 0 and -1 or 1)
			local spaced = at >= earliest and at <= to
			for _, other in ipairs(placedAt) do
				if math.abs(other - at) < 0.5 then
					spaced = false
				end
			end
			if spaced then
				local lanes = { 1, 2, 3 }
				self.rng:Shuffle(lanes)
				for _, lane in ipairs(lanes) do
					if self:SpearSafe(hazards, lane, at) then
						self:AddEntity("spear", lane, at, GROUND_TOKEN_Z)
						self:Record(at, lane, "S")
						placedAt[#placedAt + 1] = at
						placed = true
						break
					end
				end
			end
			if placed then
				break
			end
		end
	end
	return #placedAt
end

-- A chunk the boss throws: the pattern's hazards (see BOSS_CODE) and spears
-- in safe spots. Returns false when there's no room before the boss gives up.
function World:SpawnBossChunk(zone, ends)
	local tuning = self.tuning
	if self.bossFull == zone then
		return false
	end
	-- A pattern with hazards that ends before the boss gives up.
	local tempo = Rules.Tempo(tuning, zone)
	local room = ends - tuning.zoneBreather - self.cursor
	local pattern, mirrored = Patterns.Pick(self.rng, zone, tuning.duckEnabled, function(item)
		return Patterns.HasHazard(item) and Patterns.Duration(item, tempo) <= room
	end)
	if not pattern then
		-- None fits: no more throws this fight.
		self.bossFull = zone
		return false
	end
	local duration = Patterns.Duration(pattern, tempo)
	local hazards = {}
	for _, item in ipairs(Patterns.Expand(pattern, tempo, mirrored, tuning.duckEnabled)) do
		local code = BOSS_CODE[item.code]
		if code then
			local arrive = self.cursor + item.t
			local entity = self:AddEntity(CODE_ROLE[code], item.lane, arrive, 0)
			entity.thrown = true
			entity.phase = "waiting"
			entity.record = self:Record(arrive, item.lane, code)
			hazards[#hazards + 1] = { t = arrive, lane = item.lane, code = code }
		end
	end
	table.sort(hazards, function(a, b)
		return a.t < b.t
	end)

	-- Spears: spearSupply times those needed over the fight, shared out over
	-- the throws still to come (a little ahead, so none are left over), and
	-- placed up to 0.6 s before the next chunk so any lane can be reached for
	-- it, and no nearer than 0.45 s after the last one.
	local gap = Rules.Gap(tuning, zone)
	local plan = self.spearPlan
	if not plan or plan.zone ~= zone then
		plan = { zone = zone, left = math.ceil(Rules.SpearsNeeded(tuning, zone) * tuning.boss.spearSupply) }
		self.spearPlan = plan
	end
	local window = duration + gap
	local remaining = math.max(window, ends - tuning.zoneBreather - self.cursor)
	local count = math.min(plan.left, math.ceil(plan.left * window / remaining))
	local earliest = self.cursor - math.max(0, gap - 0.45)
	plan.left = plan.left - self:PlaceSpears(hazards, self.cursor, self.cursor + duration + math.max(0, gap - 0.6), count, earliest)
	self.cursor = self.cursor + duration + gap
	return true
end

-- Places the next chunk. Returns false when nothing can be placed yet (the
-- boss is still out and has no room for another throw).
function World:SpawnChunk()
	local tuning = self.tuning
	local fightZone, fightEnds = self:FightAt(self.cursor)
	if fightZone then
		return self:SpawnBossChunk(fightZone, fightEnds)
	end

	local zone = Rules.ZoneIndex(tuning, self.cursor - self.paused)
	local pattern, mirrored = Patterns.Pick(self.rng, zone, tuning.duckEnabled)
	local tempo = Rules.Tempo(tuning, zone)
	local duration = Patterns.Duration(pattern, tempo)

	-- Keep zone changes clear, so the speed bump never lands mid-chunk.
	local boundary = zone * tuning.zoneLength + self.paused
	if self.cursor + duration > boundary - tuning.zoneBreather then
		self.cursor = boundary + tuning.zoneBreather
		return true
	end
	-- And clear the road for a boss: its first throw arrives leadIn after it.
	local bossStart = self.bossZone and self:BossStart()
	if bossStart and self.cursor + duration > bossStart - tuning.zoneBreather then
		self.cursor = math.max(self.cursor, bossStart + tuning.boss.leadIn)
		return true
	end

	local items = Patterns.Expand(pattern, tempo, mirrored, tuning.duckEnabled)
	for _, item in ipairs(items) do
		local arrive = self.cursor + item.t
		local code = item.code
		if code == "P" then
			if arrive - self.lastPowerupTime >= tuning.powerupMinGap then
				self.lastPowerupTime = arrive
				-- No Wind Rider whose flight could still be on when a boss turns up.
				local noFlight = bossStart and arrive + tuning.durations.windRider + 2 > bossStart
				self:AddEntity(self:PickPowerup(zone, noFlight), item.lane, arrive, GROUND_TOKEN_Z)
			else
				code = "c"
				self:AddEntity("coin", item.lane, arrive, GROUND_TOKEN_Z)
			end
		elseif code == "A" then
			self:AddEntity("low", item.lane, arrive, 0)
			self:AddEntity("coin", item.lane, arrive, AIR_TOKEN_Z)
		elseif code == "a" then
			self:AddEntity("coin", item.lane, arrive, AIR_TOKEN_Z)
		elseif code == "c" or code == "g" then
			self:AddEntity(CODE_ROLE[code], item.lane, arrive, GROUND_TOKEN_Z)
		else
			self:AddEntity(CODE_ROLE[code], item.lane, arrive, 0)
		end
		self:Record(arrive, item.lane, code)
	end
	local gap = Rules.Gap(tuning, zone)
	self:SpawnAlliance(items, self.cursor, self.cursor + duration + gap / 2, zone)
	self.cursor = self.cursor + duration + gap
	return true
end

function World:SpawnSkyTokens()
	local tuning = self.tuning
	local flightEnds = self.time + (self.powerups.windRider or 0)
	while self.skyNext <= self.time + tuning.spawnAhead / self.speed do
		local arrive = math.max(self.skyNext, self.time + 1)
		if arrive >= flightEnds - 0.3 then
			break
		end
		if self.rng:Next() < 0.2 then
			self.skyLane = math.max(1, math.min(3, self.skyLane + (self.rng:Next() < 0.5 and -1 or 1)))
		end
		self:AddEntity("coin", self.skyLane, arrive, tuning.flyHeight + 1)
		self.skyNext = arrive + tuning.skyCoinSpacing
	end
end

-- Simulation -----------------------------------------------------------------

function World:ApplyPowerup(role)
	local tuning = self.tuning
	if role == "shield" then
		self.shield = true
	else
		self.powerups[role] = tuning.durations[role]
		if role == "windRider" then
			self.runner:SetFlying(true)
			self.skyNext = self.time + 1
		end
	end
	self:Emit({ type = "powerup", role = role })
end

function World:UpdatePowerups(h)
	for role, left in pairs(self.powerups) do
		left = left - h
		if left <= 0 then
			self.powerups[role] = nil
			if role == "windRider" then
				self.runner:SetFlying(false)
				self.safeLeft = math.max(self.safeLeft, self.tuning.landSafeTime + 0.6)
			end
			self:Emit({ type = "expire", role = role })
		else
			self.powerups[role] = left
		end
	end
	if self.safeLeft > 0 then
		self.safeLeft = math.max(0, self.safeLeft - h)
	end
end

function World:UpdateZone()
	local tuning = self.tuning
	local index = Rules.ZoneIndex(tuning, self.course)
	if index ~= self.zoneIndex then
		local fromSpeed = self.baseSpeed
		self.zoneIndex = index
		self.zoneKey = self:ZoneKey(index)
		self.zoneStart = (index - 1) * tuning.zoneLength
		self:Emit({ type = "zone", index = index, key = self.zoneKey, fromSpeed = fromSpeed })
	end
end

function World:UpdateSpeed(h)
	local tuning = self.tuning
	self.baseSpeed = Rules.Speed(tuning, self.course)
	local target = self.powerups.stampede and 1 or 0
	local rate = h / tuning.stampedeRamp
	if self.stampedeBlend < target then
		self.stampedeBlend = math.min(target, self.stampedeBlend + rate)
	elseif self.stampedeBlend > target then
		self.stampedeBlend = math.max(target, self.stampedeBlend - rate)
	end
	self.speed = self.baseSpeed * (1 + (tuning.stampedeMultiplier - 1) * self.stampedeBlend)
end

function World:Crash(entity)
	self.over = true
	self.crashRole = entity.role
	self.crashZoneKey = self.zoneKey
	self.runner:Crash()
	self:Emit({ type = "crash", role = entity.role })
end

function World:HitObstacle(entity)
	local tuning = self.tuning
	if self.safeLeft > 0 or entity.smashed then
		return
	end
	if self.powerups.stampede then
		entity.smashed = true
		self:Emit({ type = "smash", role = entity.role })
	elseif self.shield then
		self.shield = false
		entity.smashed = true
		self.safeLeft = tuning.hitSafeTime
		self:Emit({ type = "shieldBreak", role = entity.role })
	else
		self:Crash(entity)
	end
end

function World:Collect(entity)
	local role = entity.role
	if Rules.POWERUP[role] then
		self:ApplyPowerup(role)
		return
	elseif role == "spear" then
		self:HitBoss()
		return
	end
	local points = Rules.TokenValue(self.tuning, role, self.powerups.goldRush ~= nil)
	self.tokenPoints = self.tokenPoints + points
	self.tokens = self.tokens + 1
	if role == "gem" then
		self.gems = self.gems + 1
	end
	self:Emit({ type = "collect", role = role, points = points })
end

-- Running into an Alliance jogger knocks them flying, for points.
function World:Knock(entity)
	local points = self.tuning.points.knock or 0
	entity.knocked = true
	self.knocks = self.knocks + 1
	self.movePoints = self.movePoints + points
	self:Emit({ type = "knock", points = points })
end

-- Scores a jump or duck: while the obstacle passes through you, it must be in
-- your path and you must be making its move (in the air for a low one,
-- ducking for a high bar). Paid once it's behind you. Flying, smashing,
-- being hit and invulnerable pass-throughs don't count.
function World:CheckMove(entity, runner)
	if entity.moveScored or entity.smashed or self.over then
		return
	end
	local points, move = Rules.MovePoints(self.tuning, entity.role)
	if not points then
		return
	end
	local tuning = self.tuning
	local shape = Rules.SHAPES[entity.role]
	local reach = shape.halfDepth + tuning.runnerHalfDepth
	if math.abs(entity.y) < reach then
		local inPath = math.abs(entity.x - runner.x) < shape.halfWidth + tuning.runnerHalfWidth
		local doing = (move == "jump" and runner.z > 0 and not runner.flying)
			or (move == "duck" and runner.state == "duck")
		if inPath and doing and self.safeLeft <= 0 then
			entity.moveMade = true
		elseif inPath then
			entity.moveMissed = true
		end
	elseif entity.y <= -reach then
		entity.moveScored = true
		if entity.moveMade and not entity.moveMissed then
			self.movePoints = self.movePoints + points
			if move == "jump" then
				self.jumps = self.jumps + 1
			else
				self.ducks = self.ducks + 1
			end
			self:Emit({ type = "cleared", role = entity.role, move = move, points = points })
		end
	end
end

function World:Tick(h)
	local tuning = self.tuning
	local runner = self.runner

	self.time = self.time + h
	-- The zone clock stands still while a boss is out.
	if self:InFight() then
		self.paused = self.paused + h
	end
	self.course = self.time - self.paused
	self:UpdateZone()
	self:UpdatePowerups(h)
	self:UpdateSpeed(h)
	self.distance = self.distance + self.speed * h
	self.timePoints = self.timePoints + Rules.TimeRate(tuning, self.zoneIndex) * h

	while self.cursor - self.time <= tuning.spawnAhead / self.speed do
		if not self:SpawnChunk() then
			break
		end
	end
	if self.powerups.windRider then
		self:SpawnSkyTokens()
	end

	local landed = runner:Update(h)
	if landed then
		self:Emit({ type = landed })
	end

	local height = runner:Height()
	local magnet = self.powerups.magnet
	local pull = math.min(1, tuning.magnetPull * h)
	-- Compacted in place: kept entities slide down, so nothing is allocated per step.
	local entities = self.entities
	local count = #entities
	local kept = 0
	for index = 1, count do
		local entity = entities[index]
		local closing = self.speed
		if entity.role == "charger" then
			closing = closing + tuning.chargerSpeed
		elseif entity.role == "alliance" then
			-- Jogging away from you, so you close on them more slowly.
			closing = closing * (1 - tuning.alliance.speedShare)
		end
		entity.y = (entity.arrive - self.time) * closing
		if entity.thrown and entity.phase ~= "landed" then
			-- Once thrown it stays thrown, and once down it stays down, even if
			-- the speed (and so where throws leave and land) changes.
			local phase = Rules.ThrowPhase(tuning, entity.y, self.speed)
			if phase ~= "waiting" then
				entity.phase = phase
			end
		end

		local keep = true
		if entity.y < tuning.despawnBehind then
			keep = false
		elseif Rules.OBSTACLE[entity.role] then
			if not self.over and Rules.HitsObstacle(tuning, entity.role, entity.x, entity.y, runner.x, runner.z, height) then
				self:HitObstacle(entity)
			end
			self:CheckMove(entity, runner)
		elseif entity.role == "alliance" then
			if not self.over and not entity.knocked and Rules.Touches(entity.x, entity.y, entity.z, runner.x, runner.z, height) then
				self:Knock(entity)
			end
		elseif not self.over then
			if magnet and Rules.TOKEN[entity.role] and entity.y > 0 and entity.y < tuning.magnetRange then
				entity.magnet = true
			end
			if entity.magnet then
				entity.x = entity.x + (runner.x - entity.x) * pull
				entity.z = entity.z + (runner.z + 1 - entity.z) * pull
			end
			if Rules.Touches(entity.x, entity.y, entity.z, runner.x, runner.z, height) then
				self:Collect(entity)
				keep = false
			end
		end
		if keep then
			kept = kept + 1
			entities[kept] = entity
		end
	end
	for index = kept + 1, count do
		entities[index] = nil
	end
	-- A deciding spear counts even if something hit you in the same step.
	if not self.over or self.bossBeaten then
		self:UpdateBoss()
	end
	self.score = Rules.Score(self.tokenPoints, self.timePoints, self.movePoints, self.bossPoints)
end
