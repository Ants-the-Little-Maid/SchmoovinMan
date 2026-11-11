local _, ns = ...

--[[ The run's simulation. Pure Lua: no WoW API.

API for the renderer and UI:
  world = ns.World.New(seed, tuning [, options])
      options.zones          ordered zone keys; the first is always first
      options.recordTimeline true to keep world.timeline ({t, lane, code})
      options.bosses         false to leave bosses out
      options.mode           "orc" for an orc run (see Data/OrcRun.lua): you
                             keep the zone-1 speed while Tauren come up from
                             behind, faster and faster; only coins come from
                             ahead, with no bosses, power-ups or Alliance joggers
  world:Step(dt)             advances in fixed steps (tuning.step)
  world:Input(action)        "left" | "right" | "jump" | "duck"
  world:DrainEvents()        returns and clears this frame's events

Fields:
  mode (nil, or "orc")
  time (seconds run), course (the zone clock: time less the time spent in boss
      fights, which zones and speed follow), speed (your speed), distance
      (yards run, for scrolling the ground)
  taurenSpeed (orc runs only: the Tauren's speed, the one shown)
  zoneIndex, zoneKey, zoneStart (course time the current zone began)
  score, tokenPoints, timePoints, movePoints, bossPoints, tokens, gems, jumps,
      ducks, knocks, dodges, spearHits, bossesDriven, bossesSurvived
  combo (clean moves in a row: jumps, ducks and knocks), bestCombo
  powerups = { windRider = left, magnet = left, goldRush = left, stampede = left }
  shield (bool), safeLeft (seconds of no-hit after a shield break or landing)
  runner = { lane, x, z, state, flying }   state: run | jump | duck | fly | crash
  boss = nil, or the latest fight: { key, name, zone, start, ends, needed, hits,
      state = "fight" | "driven" | "survived", endedAt }
  entities = array of { id, role, lane, x, y, z, arrive, magnet, smashed, knocked, thrown }
      role: low | high | block | wall | charger | vent | pit | pitedge | ramp | coin | gem |
            wisp | alliance | spear |
            windRider | magnet | shield | goldRush | stampede | tauren
      tauren: orc runs only, a Tauren coming up from behind (y below 0) and
            on past you; arrive is when it draws level
      alliance: an Alliance jogger in a lane, jogging away from you; knocked
            (and worth points) when you run into it, never a hazard
      pit: a hole right across the road from arrive to leave (both run times),
            drawn only; pitedge: its edge in a lane with no ramp, which is what
            you fall in at; ramp: throws you over it (near, leave: the run
            times of the pit's near and far edges)
      thrown: a hazard the boss throws, with phase "waiting" (in its hand),
            "flying" or "landed" (see Rules.ThrowPhase; it only ever moves on);
            spear: a boss-only pickup that's thrown at the boss when you grab it
      gift: a coin or power-up an escort throws (thrown too, from throwMax
            yards at most); it can be taken once it has landed
  over (bool), crashRole, crashZoneKey

Events ({ type = ..., ... }):
  collect {role, points}, powerup {role}, expire {role}, zone {index, key, fromSpeed},
  cleared {role, move, points} (jumped a low obstacle or ducked a high bar in your path),
  knock {points} (ran into an Alliance jogger), dodge {points} (a Tauren got past),
  bossStart {name, needed, limit}, spear {hits, needed, points},
  bossEnd {result = "driven" | "survived", name, points},
  comboEnd {count}, crash {role}, shieldBreak {role}, smash {role}, jump, duck, land, lane
]]

local World = {}
World.__index = World
ns.World = World

local Rules, Patterns, Runner, Random = ns.Rules, ns.Patterns, ns.Runner, ns.Random

World.DEFAULT_ZONES = {
	"mulgore", "burningsteppes", "ashenvale", "silithus", "ungoro", "barrens", "thousandneedles", "winterspring",
	"westfall", "moonglade", "stormwind", "darnassus", "ironforge", "thunderbluff", "orgrimmar", "undercity",
}

local CODE_ROLE = { L = "low", H = "high", B = "block", W = "wall", C = "charger", R = "ramp", X = "pitedge", c = "coin", a = "coin", g = "gem" }
local GROUND_TOKEN_Z = 0.9
local AIR_TOKEN_Z = 2.2
-- What a boss throws for each pattern code: hazards only, and a charging
-- creature becomes a block (it can't be thrown; a block asks the same of you).
local BOSS_CODE = { L = "L", A = "L", H = "H", B = "B", W = "W", C = "B" }
local NEVER = -1000
-- What a combo can be kept up on (with Alliance joggers).
local MOVE_ROLE = { low = true, high = true, ramp = true, alliance = true }

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
	self.movePoints, self.jumps, self.ducks, self.knocks, self.dodges = 0, 0, 0, 0, 0
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
	-- Combo: clean moves in a row, the longest this run, and when the last was.
	self.combo, self.bestCombo, self.comboAt = 0, 0, 0

	if options.mode == "orc" then
		self.mode = "orc"
		self.speed = Rules.OrcSpeed(tuning)
		self.taurenSpeed = Rules.TaurenSpeed(tuning, 0)
		self.cursor = tuning.orcRun.firstRow
		self.coinNext = 1.5
		-- Where you could be after the last row of Tauren (see SpawnTaurenRow).
		self.rowStates = Patterns.StartStates()
	elseif options.bosses ~= false and tuning.boss then
		local first = tuning.boss.first
		self.bossZone = self:FindBossZone(self.rng:Int(first[1], first[2]))
	end
	return self
end

-- The current zone's twist (Tuning.twists), or nil.
function World:Twist()
	return self:TwistFor(self.zoneIndex)
end

-- The twist of a zone number (Tuning.twists), or nil. An orc run has none.
function World:TwistFor(zone)
	local twists = self.tuning.twists
	if self.mode == "orc" or not twists then
		return nil
	end
	return twists[self:ZoneKey(zone)]
end

-- Row spacing and the gap between chunks for a zone number, stretched by
-- that zone's twist if it has one (ice, moonlight: see Tuning.twists).
function World:Spacing(zone)
	local twist = self:TwistFor(zone)
	local stretch = twist and twist.spacing or 1
	-- Also the stretch itself and the zone's lane-change time, if not the usual.
	return Rules.Tempo(self.tuning, zone) * stretch, Rules.Gap(self.tuning, zone) * stretch, stretch, twist and twist.laneChange or nil
end

-- Counts a clean move into the combo and returns what it pays: its points
-- times the combo's multiplier, rounded.
function World:ComboPoints(points)
	self.combo = self.combo + 1
	self.comboAt = self.time
	if self.combo > self.bestCombo then
		self.bestCombo = self.combo
	end
	return math.floor(points * Rules.ComboMultiplier(self.tuning, self.combo) + 0.5)
end

function World:BreakCombo()
	if self.combo > 0 then
		self:Emit({ type = "comboEnd", count = self.combo })
		self.combo = 0
	end
end

-- Runs a combo down when it's left too long without a move. Time with
-- nothing to do doesn't count against it: on a Wind Rider, or with no move ahead.
function World:UpdateCombo(h)
	local combo = self.tuning.combo
	if self.combo == 0 or not combo then
		return
	end
	-- The clock only runs while there's something ahead to jump, duck, ride
	-- or knock (movesAhead, from the last step): not through the clear road
	-- before a boss or at a zone change, nor a stretch of blocks and coins.
	if self.runner.flying or not self.movesAhead then
		self.comboAt = self.comboAt + h
	elseif self.time - self.comboAt > combo.timeout then
		-- Left too long, it runs down a little at a time rather than ending.
		self.comboAt = self.comboAt + combo.decayEvery
		local left = self.combo - combo.decay
		if left > 0 then
			self.combo = left
		else
			self:BreakCombo()
		end
	end
end

-- Sets the runner up for the zone's twist: slower lane changes on ice,
-- floaty jumps by moonlight, and a crosswind that turns round every
-- driftEvery seconds.
function World:ApplyTwist()
	local twist = self:Twist()
	local runner = self.runner
	runner.laneChangeTime = twist and twist.laneChange or nil
	runner.gravity = twist and twist.gravity or nil
	runner.jumpSpeed = twist and twist.jumpSpeed or nil
	local drift = 0
	if twist and twist.drift then
		-- By run time, not the zone clock, so it still turns in a boss fight.
		local turn = math.floor(self.time / twist.driftEvery)
		drift = (turn % 2 == 0) and twist.drift or -twist.drift
	end
	runner.drift = drift
end

-- Speed shown at a zone-clock time: yours, or in an orc run the Tauren's.
function World:SpeedAt(course)
	if self.mode == "orc" then
		return Rules.TaurenSpeed(self.tuning, course)
	end
	return Rules.Speed(self.tuning, course)
end

-- How fast you close on an entity of this role, in yards a second. Negative
-- for a Tauren in an orc run: it closes on you from behind.
function World:Closing(role)
	local tuning = self.tuning
	if role == "charger" then
		return self.speed + tuning.chargerSpeed
	elseif role == "alliance" then
		-- Jogging away from you, so you close on them more slowly.
		return self.speed * (1 - tuning.alliance.speedShare)
	elseif role == "tauren" then
		return self.speed - (self.taurenSpeed or self.speed)
	end
	return self.speed
end

function World:Emit(event)
	self.events[#self.events + 1] = event
end

-- The returned list is only good until the next call: two lists take turns,
-- so draining every frame makes no new tables.
function World:DrainEvents()
	local events = self.events
	local spare = self.spareEvents or {}
	for index = #spare, 1, -1 do
		spare[index] = nil
	end
	self.events = spare
	self.spareEvents = events
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
		elseif entity.thrown and not entity.gift then
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
	local _, bossGap = self:Spacing(boss.zone)
	self.cursor = math.max(self.time + tuning.spawnAhead / self.speed, last + bossGap)
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

-- The zone an entity arriving at run time `arrive` will be met in: the boss's
-- zone for a fight (the zone clock stands still through it), otherwise by the
-- zone clock as it stands now.
function World:ZoneKeyAt(arrive)
	local index = self:FightAt(arrive)
	if not index then
		index = Rules.ZoneIndex(self.tuning, math.max(0, arrive - self.paused))
	end
	return self:ZoneKey(math.max(index, self.zoneIndex))
end

function World:AddEntity(role, lane, arrive, z)
	self.nextId = self.nextId + 1
	local entity = {
		id = self.nextId,
		role = role,
		lane = lane,
		-- Drawn with the models of the zone it's met in, not the one it was
		-- spawned from: chunks are placed well ahead, across zone changes.
		zoneKey = self:ZoneKeyAt(arrive),
		x = self.tuning.lanes[lane],
		z = z or 0,
		arrive = arrive,
		y = (arrive - self.time) * self:Closing(role),
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
local SOLID_ROLE = { low = true, high = true, block = true, wall = true, charger = true, vent = true }

-- Sometimes an Alliance jogger jogs into the gap after a chunk. They move
-- away from you, so before you reach them they cover part of the track ahead:
-- only a lane with nothing solid along that stretch is used, so they never
-- run through a hazard. `items` are the chunk just placed, from `start`.
-- chance: the zone's own, where its twist sets one (crowded streets).
function World:SpawnAlliance(items, start, arrive, zone, chance)
	local alliance = self.tuning.alliance
	if not alliance or zone < alliance.minZone or self.rng:Next() >= (chance or alliance.chance) then
		return
	end
	-- Anything arriving from `from` on lies on the stretch they jog over.
	local from = arrive - alliance.speedShare * (arrive - self.time) - 0.5
	local blocked = {}
	for _, item in ipairs(items) do
		local at = start + item.t
		-- A charger closes faster than the road does, so it starts further off
		-- and can cross their stretch whenever it's due: its lane is always out.
		if SOLID[item.code] and (at >= from or item.code == "C") then
			blocked[item.lane] = true
		end
	end
	for _, entity in ipairs(self.entities) do
		if SOLID_ROLE[entity.role] and (entity.arrive >= from or entity.role == "charger") then
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
	-- On ice the margins stretch as the rows do, and the check allows for
	-- the slower lane change (both set by SpawnBossChunk).
	local near = 0.45 * (self.spearStretch or 1)
	local later = {}
	for _, item in ipairs(hazards) do
		if item.lane == lane and math.abs(item.t - at) < near then
			return false
		end
		if item.t > at then
			later[#later + 1] = item
		end
	end
	return (Patterns.Feasible(later, self.tuning, { { lane = lane, t = at, jump = NEVER, duck = NEVER } }, self.spearLaneTime))
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
	local tempo, gap, stretch, laneTime = self:Spacing(zone)
	self.spearStretch, self.spearLaneTime = stretch, laneTime
	local room = ends - tuning.zoneBreather - self.cursor
	local pattern, mirrored = Patterns.Pick(self.rng, zone, tuning.duckEnabled, function(item)
		return Patterns.HasHazard(item) and not item.pit and Patterns.Duration(item, tempo) <= room
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
	-- it, and no nearer than 0.45 s after the last one (both longer on ice).
	local plan = self.spearPlan
	if not plan or plan.zone ~= zone then
		plan = { zone = zone, left = math.ceil(Rules.SpearsNeeded(tuning, zone) * tuning.boss.spearSupply) }
		self.spearPlan = plan
	end
	local window = duration + gap
	local remaining = math.max(window, ends - tuning.zoneBreather - self.cursor)
	local count = math.min(plan.left, math.ceil(plan.left * window / remaining))
	local earliest = self.cursor - math.max(0, gap - 0.45 * stretch)
	plan.left = plan.left - self:PlaceSpears(hazards, self.cursor, self.cursor + duration + math.max(0, gap - 0.6 * stretch), count, earliest)
	self.cursor = self.cursor + duration + gap
	return true
end

-- A zone with wisps (its twist): a trail of them along one way through the
-- chunk just placed, a point each. The way is one the fairness check finds.
-- For each row on it that asks something of you there's a wisp a moment
-- before, in the lane to be in (unless something solid stands there), and one
-- at the row itself: in the air over something to jump, on the ground under a
-- bar or in a clear lane. `items` are the chunk's, from `start`.
function World:SpawnWisps(items, start)
	local wisps = self.tuning.wisps
	local timed = {}
	for index, item in ipairs(items) do
		timed[index] = { t = start + item.t, lane = item.lane, code = item.code }
	end
	local ok, states = Patterns.Feasible(timed, self.tuning)
	if not ok then
		return
	end
	local state = states[self.rng:Int(1, #states)]
	while state and state.parent do
		local before = state.t - wisps.lead
		local need, taken, crowded
		for _, item in ipairs(timed) do
			if item.lane == state.lane then
				local asks = Patterns.REQUIREMENT[item.code]
				if math.abs(item.t - state.t) < 1e-6 then
					-- Something's there already: a hazard to jump or duck, or a
					-- token (a low obstacle's air coin included).
					need = asks or need
					taken = taken or not asks or item.code == "A"
				elseif asks and math.abs(item.t - before) < wisps.clear then
					crowded = true
				end
			end
		end
		if not crowded then
			self:AddEntity("wisp", state.lane, before, GROUND_TOKEN_Z)
		end
		if not taken then
			self:AddEntity("wisp", state.lane, state.t, need == "jump" and AIR_TOKEN_Z or GROUND_TOKEN_Z)
		end
		state = state.parent
	end
end

-- An escort's gift (its zone's twist): thrown back down the road to land in
-- a lane at `at`. The zone's gifts take turns, starting again each zone. A
-- gift of coins is a short line of them.
function World:SpawnGift(twist, zone, at)
	local tuning = self.tuning
	local escort = tuning.escort
	if self.giftZone ~= zone then
		self.giftZone, self.giftCount = zone, 0
	end
	self.giftCount = self.giftCount + 1
	self.giftNext = at + twist.giftEvery
	local kind = twist.gifts[(self.giftCount - 1) % #twist.gifts + 1]
	local lane = self.rng:Int(1, #tuning.lanes)
	local count = kind == "coins" and escort.coins or 1
	for index = 1, count do
		local gift = self:AddEntity(kind == "coins" and "coin" or kind, lane, at + (index - 1) * escort.coinSpacing, GROUND_TOKEN_Z)
		gift.thrown, gift.gift, gift.phase = true, true, "waiting"
		gift.throwMax = escort.distance - 2
	end
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
	local twist = self:TwistFor(zone)
	local pattern, mirrored = Patterns.Pick(self.rng, zone, tuning.duckEnabled, nil, twist)
	local tempo, gap = self:Spacing(zone)
	local duration = Patterns.Duration(pattern, tempo)
	-- A pit lasts as long as its length takes to cover at the speed it's met
	-- at, plus the moment past its far edge that a ramp sets you down.
	local pitNear, pitLeave
	if pattern.pit then
		local pit = tuning.pit
		local speedAt = Rules.Speed(tuning, math.max(0, self.cursor - self.paused))
		pitNear = self.cursor + pit.lead / speedAt
		pitLeave = pitNear + self.rng:Int(pattern.pit[1], pattern.pit[2]) * pit.tile / speedAt
		duration = pitLeave - self.cursor + pit.landing
	end

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
			-- (Sooner after the last one where the zone's twist says so.)
			if arrive - self.lastPowerupTime >= tuning.powerupMinGap * (twist and twist.powerupGap or 1) then
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
			-- Where the zone's twist says so, a coin is sometimes a gem.
			if code == "c" and twist and twist.gemChance and self.rng:Next() < twist.gemChance then
				code = "g"
			end
			self:AddEntity(CODE_ROLE[code], item.lane, arrive, GROUND_TOKEN_Z)
		elseif code == "R" then
			-- A ramp knows where its pit ends, and has air coins along the flight.
			local ramp = self:AddEntity("ramp", item.lane, arrive, 0)
			ramp.leave = pitLeave
			ramp.near = pitNear
			local coins = math.floor((pitLeave - pitNear) * self.speed / tuning.pit.tile + 0.5) * tuning.pit.coins
			for index = 1, coins do
				self:AddEntity("coin", item.lane, pitNear + (pitLeave - pitNear) * (index - 0.5) / coins, AIR_TOKEN_Z)
			end
		else
			self:AddEntity(CODE_ROLE[code], item.lane, arrive, 0)
		end
		self:Record(arrive, item.lane, code)
	end
	if pitNear then
		-- The hole itself, for drawing: lane 2, as it's centred on the road.
		local pit = self:AddEntity("pit", 2, pitNear, 0)
		pit.leave = pitLeave
	end
	if twist and twist.wisps then
		self:SpawnWisps(items, self.cursor)
	end
	local after = self.cursor + duration + gap / 2
	-- A zone with vents (its twist) sometimes has one in the gap after a
	-- chunk, in any lane, with ventExtra seconds of clear road after it: half
	-- a gap before is time to step out of its lane, and what follows is time
	-- to reach any lane of the next chunk. Never across a zone change or a
	-- boss turning up. An escort's gift lands in the same spot, with clear
	-- road after it so that taking it never costs you the next chunk.
	local room = math.min(boundary, bossStart or math.huge) - tuning.zoneBreather - after
	local extra = 0
	if twist and twist.ventChance and twist.ventExtra < room and self.rng:Next() < twist.ventChance then
		local lane = self.rng:Int(1, #tuning.lanes)
		self:AddEntity("vent", lane, after, 0)
		self:Record(after, lane, "B")
		extra = twist.ventExtra
	elseif twist and twist.gifts and twist.giftExtra < room and after >= (self.giftNext or 0) then
		self:SpawnGift(twist, zone, after)
		extra = twist.giftExtra
	elseif not pitNear then
		-- (No jogger after a pit: they'd have jogged across it.)
		self:SpawnAlliance(items, self.cursor, after, zone, twist and twist.allianceChance)
	end
	self.cursor = self.cursor + duration + gap + extra
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

-- Orc runs ----------------------------------------------------------------------

-- Seconds either side of drawing level that a Tauren overlaps you, at the
-- speed it's closing now. It only closes faster later, so this is the most
-- it can be.
function World:TaurenWindow()
	local reach = Rules.SHAPES.tauren.halfDepth + self.tuning.runnerHalfDepth
	return reach / (self.taurenSpeed - self.speed)
end

-- A row of Tauren drawing level at self.cursor: one, or from pairFrom
-- sometimes two, never all three lanes. Each is checked with Feasible over
-- the whole time it overlaps you, carrying on from the rows before, so a lane
-- can always be reached in time.
function World:SpawnTaurenRow()
	local tuning = self.tuning
	local orc = tuning.orcRun
	local at = self.cursor
	local zone = Rules.ZoneIndex(tuning, at - self.paused)
	local window = self:TaurenWindow()
	local pairChance = 0
	if zone >= orc.pairFrom then
		pairChance = math.min(orc.pairMax, orc.pairChance + orc.pairPerZone * (zone - orc.pairFrom))
	end
	local lanes = self.rng:Shuffle({ 1, 2, 3 })
	local candidates = {}
	if self.rng:Next() < pairChance then
		for first = 1, 3 do
			candidates[#candidates + 1] = { lanes[first], lanes[first % 3 + 1] }
		end
	end
	for _, lane in ipairs(lanes) do
		candidates[#candidates + 1] = { lane }
	end
	for _, row in ipairs(candidates) do
		local items = {}
		for _, lane in ipairs(row) do
			for _, t in ipairs({ at - window, at, at + window }) do
				items[#items + 1] = { t = t, lane = lane, code = "T" }
			end
		end
		table.sort(items, function(a, b)
			return a.t < b.t
		end)
		local ok, states = Patterns.Feasible(items, tuning, self.rowStates)
		if ok then
			self.rowStates = states
			for _, lane in ipairs(row) do
				self:AddEntity("tauren", lane, at, 0)
			end
			for _, item in ipairs(items) do
				self:Record(item.t, item.lane, "T")
			end
			break
		end
	end
	-- Long enough apart that one row is past before the next can catch you
	-- changing lanes.
	self.cursor = at + math.max(Rules.RowGap(tuning, zone), 2 * window + 0.6)
end

-- A short line of coins coming from ahead in a random lane, sometimes ending
-- in a gem. It may well lie in a Tauren's path.
function World:SpawnCoinLine()
	local orc = self.tuning.orcRun
	local lane = self.rng:Int(1, #self.tuning.lanes)
	local arrive = self.coinNext
	for index = 1, orc.coinCount do
		local at = arrive + (index - 1) * orc.coinSpacing
		local role = "coin"
		if index == orc.coinCount and self.rng:Next() < orc.gemChance then
			role = "gem"
		end
		self:AddEntity(role, lane, at, GROUND_TOKEN_Z)
		self:Record(at, lane, role == "gem" and "g" or "c")
	end
	local gap = orc.coinGap
	self.coinNext = arrive + (orc.coinCount - 1) * orc.coinSpacing + gap[1] + self.rng:Next() * (gap[2] - gap[1])
end

-- Tauren appear spawnBehind yards back; coins as far ahead as any chunk.
function World:SpawnOrcRun()
	local tuning = self.tuning
	while self.cursor - self.time <= tuning.orcRun.spawnBehind / (self.taurenSpeed - self.speed) do
		self:SpawnTaurenRow()
	end
	while self.coinNext - self.time <= tuning.spawnAhead / self.speed do
		self:SpawnCoinLine()
	end
end

-- A Tauren fully past you without trampling you is a dodge, paid once.
function World:CheckDodge(entity)
	if entity.dodged or self.over then
		return
	end
	if entity.y >= Rules.SHAPES.tauren.halfDepth + self.tuning.runnerHalfDepth then
		entity.dodged = true
		local points = self.tuning.points.dodge or 0
		self.dodges = self.dodges + 1
		self.movePoints = self.movePoints + points
		self:Emit({ type = "dodge", points = points })
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
		local fromSpeed = self.taurenSpeed or self.baseSpeed
		self.zoneIndex = index
		self.zoneKey = self:ZoneKey(index)
		self.zoneStart = (index - 1) * tuning.zoneLength
		self:Emit({ type = "zone", index = index, key = self.zoneKey, fromSpeed = fromSpeed })
		-- A zone that blesses you (its twist) gives Thick Hide on the way in.
		local twist = self:Twist()
		if twist and twist.shield and not self.shield then
			self:ApplyPowerup("shield")
		end
	end
end

function World:UpdateSpeed(h)
	local tuning = self.tuning
	self.baseSpeed = Rules.Speed(tuning, self.course)
	if self.mode == "orc" then
		self.taurenSpeed = Rules.TaurenSpeed(tuning, self.course)
		self.speed = Rules.OrcSpeed(tuning)
		return
	end
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
	self.crashId = entity.id
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
		self:BreakCombo()
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
	local points = self:ComboPoints(self.tuning.points.knock or 0)
	entity.knocked = true
	self.knocks = self.knocks + 1
	self.movePoints = self.movePoints + points
	self:Emit({ type = "knock", points = points })
end

-- Touching a ramp throws you over its pit, to come down just past the far
-- edge. It counts as a clean move, like a jump. A jump already under way
-- becomes the throw, so the ramp can't be hopped over into the pit.
function World:CheckRamp(entity, runner)
	if entity.used or self.over or runner.flying or runner.launch then
		return
	end
	local tuning = self.tuning
	local shape = Rules.SHAPES.ramp
	if math.abs(entity.y) < shape.halfDepth + tuning.runnerHalfDepth
		and math.abs(entity.x - runner.x) < shape.halfWidth + tuning.runnerHalfWidth then
		entity.used = true
		runner:Launch(entity.leave - self.time + tuning.pit.landing, tuning.pit.height)
		local points = self:ComboPoints(tuning.points.ramp or 0)
		self.movePoints = self.movePoints + points
		self.jumps = self.jumps + 1
		self:Emit({ type = "cleared", role = "ramp", move = "jump", points = points })
	end
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
			points = self:ComboPoints(points)
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
	self:ApplyTwist()
	self:UpdatePowerups(h)
	self:UpdateCombo(h)
	self:UpdateSpeed(h)
	self.distance = self.distance + self.speed * h
	self.timePoints = self.timePoints + Rules.TimeRate(tuning, self.zoneIndex) * h

	if self.mode == "orc" then
		self:SpawnOrcRun()
	else
		while self.cursor - self.time <= tuning.spawnAhead / self.speed do
			if not self:SpawnChunk() then
				break
			end
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
	-- In an orc run the road behind you is in view, so things go further back
	-- before they're dropped, and Tauren go once they're well ahead.
	local orc = self.mode == "orc" and tuning.orcRun
	local behind = orc and orc.despawnBehind or tuning.despawnBehind
	-- Compacted in place: kept entities slide down, so nothing is allocated per step.
	local entities = self.entities
	local count = #entities
	local kept = 0
	local movesAhead = false
	for index = 1, count do
		local entity = entities[index]
		entity.y = (entity.arrive - self.time) * self:Closing(entity.role)
		if entity.y > 0 and MOVE_ROLE[entity.role] and not entity.smashed and not entity.knocked then
			movesAhead = true
		end
		if entity.thrown and entity.phase ~= "landed" then
			-- Once thrown it stays thrown, and once down it stays down, even if
			-- the speed (and so where throws leave and land) changes.
			local phase = Rules.ThrowPhase(tuning, entity.y, self.speed, entity.throwMax)
			if phase ~= "waiting" then
				entity.phase = phase
			end
		end

		local keep = true
		-- A pit and its ramps stay until the pit's far edge is behind you.
		local back = entity.leave and (entity.leave - self.time) * self.speed or entity.y
		if back < behind or (orc and entity.role == "tauren" and entity.y > orc.despawnAhead) then
			keep = false
		elseif entity.role == "ramp" then
			self:CheckRamp(entity, runner)
		elseif entity.role == "pit" then
			-- Drawn only: its edges and ramps are what you meet.
		elseif Rules.OBSTACLE[entity.role] then
			-- In the air off a ramp, the pit's edge in the next lane is below you.
			if not self.over and not (runner.launch and entity.role == "pitedge")
				and Rules.HitsObstacle(tuning, entity.role, entity.x, entity.y, runner.x, runner.z, height) then
				self:HitObstacle(entity)
			end
			if entity.role == "tauren" then
				self:CheckDodge(entity)
			else
				self:CheckMove(entity, runner)
			end
		elseif entity.role == "alliance" then
			if not self.over and not entity.knocked and Rules.Touches(entity.x, entity.y, entity.z, runner.x, runner.z, height) then
				self:Knock(entity)
			end
		elseif entity.thrown and entity.phase ~= "landed" then
			-- An escort's gift still in the air: nothing to take yet.
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
	self.movesAhead = movesAhead
	-- A deciding spear counts even if something hit you in the same step.
	if not self.over or self.bossBeaten then
		self:UpdateBoss()
	end
	self.score = Rules.Score(self.tokenPoints, self.timePoints, self.movePoints, self.bossPoints, tuning.scoreMultiplier)
end
