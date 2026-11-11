-- Schmoovin Man game logic tests. Run with any Lua:
--   lua tests/schmoovin_spec.lua <addon folder, usually .> [seeds] [minutes] [seconds per zone]

local root = arg and arg[1] or "."
local seedCount = tonumber(arg and arg[2]) or 20
local minutes = tonumber(arg and arg[3]) or 10

local ns = {}
for _, file in ipairs({ "Data/Tuning.lua", "Data/Assets.lua", "Data/Zones.lua", "Data/OrcRun.lua", "Game/Random.lua", "Game/Rules.lua", "Game/Patterns.lua", "Game/Runner.lua", "Game/World.lua", "Social/Codec.lua" }) do
	local chunk = assert(loadfile(root .. "/" .. file))
	chunk("SchmoovinMan", ns)
end
local Tuning, Rules, Patterns, World, Codec = ns.Tuning, ns.Rules, ns.Patterns, ns.World, ns.Codec
-- Optional 4th argument: seconds per zone, to test the other zone length choices.
if arg and tonumber(arg[4]) then
	Tuning.zoneLength = tonumber(arg[4])
end

local failures, total = 0, 0
local function check(name, condition, detail)
	total = total + 1
	if not condition then
		failures = failures + 1
		print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
	end
end
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-6)
end
local function copy(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = type(value) == "table" and copy(value) or value
	end
	return result
end

-- Scoring -----------------------------------------------------------------------

check("coin value", Rules.TokenValue(Tuning, "coin", false) == 10)
check("gem value", Rules.TokenValue(Tuning, "gem", false) == 50)
check("gold rush doubles", Rules.TokenValue(Tuning, "coin", true) == 20)
check("time rate zone 1", Rules.TimeRate(Tuning, 1) == 10)
check("time rate zone 4", Rules.TimeRate(Tuning, 4) == 16)
check("score floors", Rules.Score(120, 33.9) == 153)
check("slow start scores x0.75", Rules.Score(100, 0, 0, 0, 0.75) == 75)
check("fast start scores x1.25", Rules.Score(100, 1, 0, 0, 1.25) == 126)
check("three starting speeds, Normal at 11", #Tuning.startSpeeds == 3 and Tuning.startSpeeds[2].speed == 11 and Tuning.startSpeeds[2].multiplier == 1)

-- Speed curve -------------------------------------------------------------------

local L = Tuning.zoneLength
check("starts at base", near(Rules.Speed(Tuning, 0), Tuning.baseSpeed))
local previous = Rules.Speed(Tuning, 0)
local rising, capped = true, true
for step = 1, 20 * L * 10 do
	local t = step / 10
	local speed = Rules.Speed(Tuning, t)
	if speed < previous - 1e-9 then
		rising = false
	end
	if speed > Tuning.maxSpeed + 1e-9 then
		capped = false
	end
	previous = speed
end
check("speed never drops", rising)
check("speed respects cap", capped)
for zone = 1, 5 do
	local boundary = zone * L
	local before = Rules.Speed(Tuning, boundary - 0.01)
	local after = Rules.Speed(Tuning, boundary + Tuning.bumpTime)
	local rampOnly = Tuning.rampPerSecond * (Tuning.bumpTime + 0.01)
	check("not capped by zone " .. (zone + 1), after < Tuning.maxSpeed, after)
	check("bump on entering zone " .. (zone + 1), near(after - before, Tuning.zoneBump + rampOnly, 1e-3), after - before)
	local early = Rules.Speed(Tuning, (zone - 1) * L + Tuning.bumpTime + 1)
	local late = Rules.Speed(Tuning, zone * L - 1)
	check("ramps within zone " .. zone, late > early)
end
check("tempo shrinks", Rules.Tempo(Tuning, 5) < Rules.Tempo(Tuning, 1))
check("tempo floor", Rules.Tempo(Tuning, 100) == Tuning.tempoMin)
check("gap floor", Rules.Gap(Tuning, 100) == Tuning.gapMin)

-- Weighted picks ----------------------------------------------------------------

do
	local Weighted = ns.Random.Weighted
	local items = { { name = "a", w = 1 }, { name = "b", w = 0 }, { name = "c", w = 3 } }
	local function weightOf(item)
		return item.w
	end
	check("weighted: low roll", Weighted(items, weightOf, 0).name == "a")
	check("weighted: zero weight skipped", Weighted(items, weightOf, 0.25).name == "c")
	check("weighted: high roll", Weighted(items, weightOf, 0.999).name == "c")
	check("weighted: nothing weighted", Weighted(items, function() return 0 end, 0.5) == nil)
	-- Tauren joggers come up about one in six.
	local tauren, steps = 0, 1000
	for step = 0, steps - 1 do
		local list = Weighted(ns.Assets.joggers, function(item) return item.weight or 1 end, step / steps)
		if list.race == "tauren" then
			tauren = tauren + 1
		end
	end
	check("weighted: tauren joggers about one in six", near(tauren / steps, 1 / 6, 0.01), tauren / steps)
end

-- Patterns ----------------------------------------------------------------------

for _, pattern in ipairs(Patterns.LIST) do
	for _, duck in ipairs({ true, false }) do
		for _, mirrored in ipairs({ false, true }) do
			for _, tempo in ipairs({ 1, Tuning.tempoMin }) do
				local items = Patterns.Expand(pattern, tempo, mirrored, duck)
				local ok, at = Patterns.Feasible(items, Tuning)
				local name = ("pattern %s duck=%s mirror=%s tempo=%.2f"):format(pattern.name, tostring(duck), tostring(mirrored), tempo)
				if duck or not pattern.needsDuck then
					check(name, ok, at)
				else
					-- Marked as needing ducking: confirm it really can't be done without.
					check(name .. " is correctly marked needsDuck", not ok)
				end
			end
		end
	end
	for _, row in ipairs(pattern.rows) do
		check("pattern " .. pattern.name .. " row width", #row[2] == 3)
	end
end
do
	local rng = ns.Random.New(99)
	local picked, wide = false, 0
	for _ = 1, 5000 do
		local pattern = Patterns.Pick(rng, 10, false)
		if pattern.needsDuck then
			picked = true
		end
	end
	check("duck-only patterns never picked with ducking off", not picked)
	for _ = 1, 5000 do
		local pattern = Patterns.Pick(rng, 10, true)
		if pattern.needsDuck then
			wide = wide + 1
		end
	end
	check("duck-only patterns do appear with ducking on", wide > 0, wide)
end
local noDuck = Patterns.Expand({ rows = { { 0, ".H." } } }, 1, false, false)
check("high bar becomes block with ducking off", noDuck[1].code == "B")

-- Zone order --------------------------------------------------------------------

do
	local world = World.New(7, Tuning)
	check("first zone is Mulgore", world:ZoneKey(1) == "mulgore")
	local seen, repeats = {}, false
	local poolSize = #World.DEFAULT_ZONES
	for index = 2, poolSize do
		local key = world:ZoneKey(index)
		if seen[key] or key == "mulgore" then
			repeats = true
		end
		seen[key] = true
	end
	check("first round visits every other zone once", not repeats)
	for _, key in ipairs(World.DEFAULT_ZONES) do
		check("zone data for " .. key, ns.ZonesByKey and ns.ZonesByKey[key] ~= nil)
	end
	local neighbourRepeat = false
	for index = 2, 80 do
		if world:ZoneKey(index) == world:ZoneKey(index - 1) then
			neighbourRepeat = true
		end
	end
	check("never the same zone twice in a row", not neighbourRepeat)
	local other = World.New(7, Tuning)
	check("same seed gives same order", other:ZoneKey(5) == world:ZoneKey(5))
end

-- Runner ------------------------------------------------------------------------

do
	local runner = ns.Runner.New(Tuning)
	runner:Input("jump")
	local peak, airtime = 0, 0
	for _ = 1, 240 do
		runner:Update(Tuning.step)
		if runner.z > 0 then
			airtime = airtime + Tuning.step
		end
		peak = math.max(peak, runner.z)
	end
	check("jump clears low obstacles", peak > Rules.SHAPES.low.top + 0.5, peak)
	check("jump lands", runner.z == 0 and runner.state == "run")
	check("jump airtime about 0.7s", near(airtime, 2 * Tuning.jumpSpeed / Tuning.gravity, 0.03), airtime)
	runner:Input("left")
	runner:Input("left")
	check("lane stops at edge", runner.lane == 1)
	runner:Input("duck")
	check("duck lowers runner", runner:Height() == Tuning.duckHeight)
	check("duck fits under high bar", Tuning.duckHeight < Rules.SHAPES.high.bottom)
end

-- Spawn timelines are fair ------------------------------------------------------

local function RunTimeline(seed, tuning, seconds, mode)
	local world = World.New(seed, tuning, { recordTimeline = true, mode = mode })
	while world.time < seconds do
		world.safeLeft = 1e9
		world:Step(0.1)
		world:DrainEvents()
	end
	return world.timeline
end

for seed = 1, seedCount do
	for _, duck in ipairs({ true, false }) do
		local tuning = copy(Tuning)
		tuning.duckEnabled = duck
		local timeline = RunTimeline(seed, tuning, minutes * 60)
		table.sort(timeline, function(a, b)
			return a.t < b.t
		end)
		local ok, at = Patterns.Feasible(timeline, tuning)
		check(("timeline seed %d duck=%s"):format(seed, tostring(duck)), ok, at)
	end
end

-- A planning bot survives -------------------------------------------------------

local ROLE_CODE = { low = "L", high = "H", block = "B", wall = "B", charger = "B", tauren = "B" }

-- Lane of the planned path at the first row still ahead.
local function NextLane(states, startState, now)
	local path = {}
	local state = states[1]
	while state and state ~= startState do
		table.insert(path, 1, state)
		state = state.parent
	end
	for _, step in ipairs(path) do
		-- A row is only behind us once it has fully passed the runner.
		if step.t > now - 0.1 then
			return step.lane
		end
	end
	return path[#path] and path[#path].lane
end

local function SortByTime(items)
	table.sort(items, function(a, b)
		return a.t < b.t
	end)
end

local function PlayBot(seed, tuning, seconds, mode)
	local world = World.New(seed, tuning, { mode = mode })
	local runner = world.runner
	local lastJump, lastDuck = -1000, -1000
	local target = runner.lane
	local planTimer = 0
	while world.time < seconds and not world.over do
		planTimer = planTimer - tuning.step
		if planTimer <= 0 and not runner.flying then
			planTimer = 0.02
			local items = {}
			local spear
			-- An orc run's Tauren overlaps you for a moment either side of drawing
			-- level: its lane is blocked for all of that.
			local window = world.mode == "orc" and world:TaurenWindow() + 0.05
			for _, entity in ipairs(world.entities) do
				if entity.role == "tauren" then
					for _, t in ipairs({ entity.arrive - window, entity.arrive + window }) do
						if t > world.time - 0.1 then
							items[#items + 1] = { t = t, lane = entity.lane, code = "B" }
						end
					end
				end
				local code = ROLE_CODE[entity.role]
				-- A jump or duck already under way counts as done in this lane, and
				-- as a block in the others (too late to jump there).
				if (code == "L" or code == "H") and entity.arrive < world.time + 0.1 then
					code = entity.lane ~= runner.lane and "B" or nil
				end
				if code and not entity.smashed and entity.arrive > world.time - 0.1 then
					items[#items + 1] = { t = entity.arrive, lane = entity.lane, code = code }
				end
				if entity.role == "spear" and entity.arrive > world.time + 0.05 and (not spear or entity.arrive < spear.arrive) then
					spear = entity
				end
			end
			SortByTime(items)
			local start = { lane = runner.lane, t = world.time - Patterns.LIMITS.reaction, jump = lastJump, duck = lastDuck }
			-- Go for the next spear if a safe path takes it: plan as if the other
			-- lanes were blocked when it arrives.
			local planned = false
			if spear then
				local withSpear = {}
				for _, item in ipairs(items) do
					withSpear[#withSpear + 1] = item
				end
				for lane = 1, 3 do
					if lane ~= spear.lane then
						withSpear[#withSpear + 1] = { t = spear.arrive, lane = lane, code = "B" }
					end
				end
				SortByTime(withSpear)
				local ok, states = Patterns.Feasible(withSpear, tuning, { start })
				if ok then
					target = NextLane(states, start, world.time) or target
					planned = true
				end
			end
			if not planned then
				local ok, states = Patterns.Feasible(items, tuning, { start })
				if ok and #items > 0 then
					target = NextLane(states, start, world.time) or target
				end
			end
		end

		if runner.lane < target then
			world:Input("right")
		elseif runner.lane > target then
			world:Input("left")
		end

		for _, entity in ipairs(world.entities) do
			local untilArrive = entity.arrive - world.time
			local code = ROLE_CODE[entity.role]
			local shape = Rules.SHAPES[entity.role]
			-- Judge by position, not the chosen lane: a lane change takes time.
			local overlaps = shape and (entity.lane == runner.lane or math.abs(entity.x - runner.x) < shape.halfWidth + tuning.runnerHalfWidth + 0.3)
			if overlaps and not entity.smashed and untilArrive > 0 then
				if code == "L" and untilArrive <= 0.36 and runner.z == 0 and not runner.flying then
					world:Input("jump")
					lastJump = entity.arrive
				elseif code == "H" and untilArrive <= 0.25 and runner.state ~= "duck" and not runner.flying then
					world:Input("duck")
					lastDuck = entity.arrive
				end
			end
		end
		world:Step(tuning.step)
		world:DrainEvents()
	end
	return world
end

local clock = os.clock()
for seed = 1, seedCount do
	for _, duck in ipairs({ true, false }) do
		local tuning = copy(Tuning)
		tuning.duckEnabled = duck
		local world = PlayBot(seed, tuning, minutes * 60)
		check(("bot survives seed %d duck=%s"):format(seed, tostring(duck)), not world.over,
			("crashed into %s at %.1fs in zone %d"):format(tostring(world.crashRole), world.time, world.zoneIndex))
		if seed == 1 and duck then
			check("bot collects tokens", world.tokens > 50, world.tokens)
			check("score includes time", world.score >= math.floor(world.timePoints), world.score)
			-- Zones follow the zone clock, which stops for bosses.
			check("zones advance", world.zoneIndex >= math.floor(world.course / Tuning.zoneLength), world.zoneIndex)
			check("bot earns jump and duck points", world.movePoints > 0 and world.jumps > 0, world.movePoints)
			if minutes >= 3 then
				check("bot meets bosses", world.bossesDriven + world.bossesSurvived > 0, world.bossesDriven + world.bossesSurvived)
				check("bot drives off a boss by taking spears", world.bossesDriven > 0 and world.spearHits >= Tuning.boss.spears, world.spearHits)
				check("score includes boss points", world.score >= math.floor(world.timePoints + world.bossPoints), world.score)
			end
		end
	end
end

-- World behaviour ---------------------------------------------------------------

do
	local world = World.New(3, Tuning)
	world:Step(0.05)
	world:DrainEvents()
	world.entities = {}
	world.cursor = 1e9
	world:AddEntity("block", world.runner.lane, world.time + 0.5, 0)
	world.shield = true
	for _ = 1, 120 do
		world:Step(Tuning.step)
	end
	local events = world:DrainEvents()
	local broke = false
	for _, event in ipairs(events) do
		if event.type == "shieldBreak" then
			broke = true
		end
	end
	check("shield absorbs a hit", broke and not world.over and not world.shield)

	world:AddEntity("block", world.runner.lane, world.time + 0.5, 0)
	for _ = 1, 120 do
		world:Step(Tuning.step)
	end
	check("unshielded hit ends the run", world.over and world.crashRole == "block")
end

do
	local world = World.New(4, Tuning)
	world.cursor = 1e9
	world:AddEntity("windRider", world.runner.lane, world.time + 0.3, 0.9)
	for _ = 1, 120 do
		world:Step(Tuning.step)
	end
	check("wind rider makes the runner fly", world.runner.flying and world.powerups.windRider ~= nil)
	world:AddEntity("block", world.runner.lane, world.time + 0.5, 0)
	for _ = 1, 120 do
		world:Step(Tuning.step)
	end
	check("flying passes over obstacles", not world.over and world.runner.z > 4)
	local sky = 0
	for _, entity in ipairs(world.entities) do
		if entity.role == "coin" and entity.z > 5 then
			sky = sky + 1
		end
	end
	check("sky tokens spawn while flying", sky > 0, sky)
end

do
	local world = World.New(5, Tuning)
	world.cursor = 1e9
	world.powerups.goldRush = 5
	world:AddEntity("coin", world.runner.lane, world.time + 0.2, 0.9)
	for _ = 1, 60 do
		world:Step(Tuning.step)
	end
	check("gold rush coin worth 20", world.tokenPoints == 20 and world.tokens == 1, world.tokenPoints)
	world.powerups.magnet = 5
	local far = world.runner.lane == 1 and 3 or 1
	world:AddEntity("coin", far, world.time + 0.8, 0.9)
	for _ = 1, 150 do
		world:Step(Tuning.step)
	end
	check("magnet pulls coins from other lanes", world.tokens == 2, world.tokens)
end

do
	local world = World.New(6, Tuning)
	local zoneEvent
	while world.time < Tuning.zoneLength + 0.1 do
		world.safeLeft = 1e9
		world:Step(0.05)
		for _, event in ipairs(world:DrainEvents()) do
			if event.type == "zone" then
				zoneEvent = event
			end
		end
	end
	check("zone event fires", zoneEvent and zoneEvent.index == 2 and zoneEvent.key ~= "mulgore")
end

-- Jump and duck points ------------------------------------------------------------

local function MoveWorld(seed)
	local world = World.New(seed, Tuning)
	world.cursor = 1e9
	world:Step(0.05)
	world:DrainEvents()
	world.entities = {}
	return world
end

local function RunFor(world, seconds, action, at)
	local acted = false
	local target = world.time + seconds
	while world.time < target do
		if action and not acted and world.time >= at then
			world:Input(action)
			acted = true
		end
		world:Step(Tuning.step)
	end
end

do
	local world = MoveWorld(21)
	local arrive = world.time + 1.0
	world:AddEntity("low", world.runner.lane, arrive, 0)
	RunFor(world, 1.6, "jump", arrive - 0.35)
	check("jumping a low obstacle scores 2", world.movePoints == 2 and world.jumps == 1 and not world.over, world.movePoints)
	local cleared = false
	for _, event in ipairs(world:DrainEvents()) do
		if event.type == "cleared" and event.move == "jump" and event.points == 2 then
			cleared = true
		end
	end
	check("jump fires a cleared event", cleared)
	check("score includes jump points", world.score == math.floor(world.tokenPoints + world.timePoints + world.movePoints), world.score)
end

do
	local world = MoveWorld(22)
	local arrive = world.time + 1.0
	world:AddEntity("high", world.runner.lane, arrive, 0)
	RunFor(world, 1.6, "duck", arrive - 0.25)
	check("ducking a high bar scores 3", world.movePoints == 3 and world.ducks == 1 and not world.over, world.movePoints)
end

do
	local world = MoveWorld(23)
	local arrive = world.time + 1.0
	local other = world.runner.lane == 1 and 3 or 1
	world:AddEntity("low", other, arrive, 0)
	RunFor(world, 1.6, "jump", arrive - 0.35)
	check("jumping beside an obstacle scores nothing", world.movePoints == 0, world.movePoints)
end

do
	local world = MoveWorld(24)
	local arrive = world.time + 1.0
	world:AddEntity("low", world.runner.lane, arrive, 0)
	world.safeLeft = 5
	RunFor(world, 1.6)
	check("walking through while invulnerable scores nothing", world.movePoints == 0 and not world.over, world.movePoints)
end

do
	local world = MoveWorld(25)
	local arrive = world.time + 1.0
	world:AddEntity("block", world.runner.lane, arrive, 0)
	world.shield = true
	RunFor(world, 1.6, "jump", arrive - 0.35)
	check("blocks give no move points", world.movePoints == 0, world.movePoints)
end

-- Alliance joggers ----------------------------------------------------------------

do
	-- Running into one knocks them over for points, and never ends the run.
	local world = MoveWorld(31)
	local arrive = world.time + 1.0
	world:AddEntity("alliance", world.runner.lane, arrive, 0)
	RunFor(world, 2.0)
	local knocked = false
	for _, event in ipairs(world:DrainEvents()) do
		knocked = knocked or (event.type == "knock" and event.points == Tuning.points.knock)
	end
	check("knocking an Alliance jogger scores " .. Tuning.points.knock, knocked and world.knocks == 1 and world.movePoints == Tuning.points.knock, world.movePoints)
	check("knocking an Alliance jogger doesn't end the run", not world.over)

	-- Jumping over one, or being in another lane, leaves them be.
	world = MoveWorld(32)
	arrive = world.time + 1.0
	world:AddEntity("alliance", world.runner.lane, arrive, 0)
	-- They close at a share of your speed, so time the jump on their real distance.
	local jumped = false
	while world.time < arrive + 1.5 and not world.over do
		local entity = world.entities[1]
		if not jumped and entity and entity.y < 2.2 then
			world:Input("jump")
			jumped = true
		end
		world:Step(Tuning.step)
	end
	check("jumping over an Alliance jogger leaves them be", world.knocks == 0 and not world.over, world.knocks)
	world = MoveWorld(33)
	world:AddEntity("alliance", world.runner.lane == 1 and 3 or 1, world.time + 1.0, 0)
	RunFor(world, 2.0)
	check("an Alliance jogger in another lane isn't knocked", world.knocks == 0)
end

do
	-- They spawn, and never in a lane where they'd jog through a hazard.
	local spawns = {}
	local realAdd = World.AddEntity
	World.AddEntity = function(self, role, lane, arrive, z)
		local entity = realAdd(self, role, lane, arrive, z)
		if role == "alliance" then
			spawns[#spawns + 1] = { lane = lane, arrive = arrive, spawned = self.time }
		end
		return entity
	end
	local world = World.New(41, copy(Tuning), { recordTimeline = true })
	-- No bot here, so keep the runner untouchable: a crash would stop the clock.
	while world.time < 300 and not world.over do
		world.safeLeft = 1
		world:Step(Tuning.step)
		world:DrainEvents()
	end
	World.AddEntity = realAdd
	check("Alliance joggers spawn", #spawns > 10, #spawns)
	local share = Tuning.alliance.speedShare
	local solid = { L = true, H = true, B = true, W = true, C = true, A = true }
	local clashes = 0
	for _, spawn in ipairs(spawns) do
		local from = spawn.arrive - share * (spawn.arrive - spawn.spawned)
		for _, item in ipairs(world.timeline) do
			if solid[item.code] and item.lane == spawn.lane and item.t >= from and item.t <= spawn.arrive + 0.3 then
				clashes = clashes + 1
			end
		end
	end
	check("Alliance joggers never jog through a hazard", clashes == 0, clashes)
end

-- Bosses ----------------------------------------------------------------------------

do
	check("3 spears in zone 3", Rules.SpearsNeeded(Tuning, 3) == 3)
	check("3 spears in zone 4", Rules.SpearsNeeded(Tuning, 4) == 3)
	check("one more spear every 2 zones", Rules.SpearsNeeded(Tuning, 5) == 4 and Rules.SpearsNeeded(Tuning, 6) == 4 and Rules.SpearsNeeded(Tuning, 7) == 5, Rules.SpearsNeeded(Tuning, 7))
	check("score adds boss points", Rules.Score(10, 20, 3, 500) == 533)
	local speed = 20
	check("a far throw waits in the boss's hand", Rules.ThrowPhase(Tuning, 60, speed) == "waiting")
	local phase, progress = Rules.ThrowPhase(Tuning, 30, speed)
	check("a mid throw is flying", phase == "flying" and progress > 0 and progress < 1, phase)
	check("a near throw has landed", Rules.ThrowPhase(Tuning, 5, speed) == "landed")
	local landsEarly = true
	for speed = Tuning.baseSpeed, Tuning.maxSpeed do
		-- 0.9 s away: on the road already, and thrown from no nearer than 1.5 s.
		if Rules.ThrowPhase(Tuning, speed * 0.9, speed) ~= "landed" or Rules.ThrowPhase(Tuning, speed * 1.5, speed) == "landed" then
			landsEarly = false
		end
	end
	check("a throw lands at least 0.9 s before reaching you, at every speed", landsEarly)
end

-- Zones that have a boss, from the zone data.
local function HasBoss(key)
	return ns.ZonesByKey[key].boss ~= nil
end

check("no boss in Thunder Bluff, Orgrimmar or Undercity", not HasBoss("thunderbluff") and not HasBoss("orgrimmar") and not HasBoss("undercity"))

-- Plays an untouchable run without a bot, logging fights and Wind Rider flights.
local function BossRun(seed, seconds)
	local world = World.New(seed, copy(Tuning))
	local fights, flights, spears = {}, {}, {}
	while world.time < seconds do
		world.safeLeft = 1
		world:Step(0.05)
		for _, event in ipairs(world:DrainEvents()) do
			if event.type == "bossStart" then
				fights[#fights + 1] = { zone = world.zoneIndex, key = world.zoneKey, start = world.time, course = world.course, needed = event.needed, spears = 0 }
			elseif event.type == "bossEnd" then
				local fight = fights[#fights]
				fight.ends, fight.endCourse, fight.result, fight.points = world.time, world.course, event.result, event.points
			elseif event.type == "powerup" and event.role == "windRider" then
				flights[#flights + 1] = world.time
			elseif event.type == "zone" and fights[#fights] and not fights[#fights].ends then
				fights[#fights].zoneChanged = true
			end
		end
		for _, entity in ipairs(world.entities) do
			if entity.role == "spear" and not entity.counted then
				entity.counted = true
				spears[#spears + 1] = entity.arrive
			end
		end
	end
	-- Spears spawn ahead, so they're counted against the fight they arrive in.
	for _, fight in ipairs(fights) do
		for _, at in ipairs(spears) do
			if at >= fight.start and at <= (fight.ends or math.huge) then
				fight.spears = fight.spears + 1
			end
		end
	end
	return world, fights, flights
end

do
	local scheduleOk, gapOk, bosslessOk, pauseOk, supplyOk, flightOk = true, true, true, true, true, true
	local scheduleDetail, supplyDetail
	local met = 0
	for seed = 1, math.max(4, math.min(seedCount, 8)) do
		local world, fights, flights = BossRun(seed, 420)
		met = met + #fights
		-- The first boss is in zone 3 to 6, or later only when every zone from
		-- 6 up to it has no boss (a boss due there is passed on).
		local first = fights[1]
		if not first or first.zone < 3 then
			scheduleOk = false
		else
			for zone = 6, first.zone - 1 do
				if HasBoss(world:ZoneKey(zone)) then
					scheduleOk = false
					scheduleDetail = ("seed %d: first boss in zone %d"):format(seed, first.zone)
				end
			end
		end
		for index, fight in ipairs(fights) do
			bosslessOk = bosslessOk and HasBoss(fight.key)
			-- 3 to 6 zones after the last, or later only when the zones from 6
			-- on up to it have no boss.
			if index > 1 then
				local previous = fights[index - 1].zone
				local ok = fight.zone - previous >= 3
				for zone = previous + 6, fight.zone - 1 do
					if HasBoss(world:ZoneKey(zone)) then
						ok = false
					end
				end
				if not ok then
					gapOk = false
					scheduleDetail = ("seed %d: bosses in zones %d and %d"):format(seed, previous, fight.zone)
				end
			end
			if fight.ends then
				-- The zone clock stood still, and the zone didn't change.
				if math.abs(fight.endCourse - fight.course) > 0.05 or fight.zoneChanged then
					pauseOk = false
				end
				if fight.spears < fight.needed then
					supplyOk = false
					supplyDetail = ("seed %d zone %d: %d spears for %d"):format(seed, fight.zone, fight.spears, fight.needed)
				end
			end
			-- No Wind Rider flight still on when a boss turns up.
			for _, at in ipairs(flights) do
				if at < fight.start and at + Tuning.durations.windRider > fight.start - 0.5 then
					flightOk = false
				end
			end
		end
	end
	check("bosses turn up", met > 0, met)
	check("first boss in zone 3 to 6, or the next zone with a boss", scheduleOk, scheduleDetail)
	check("next boss 3 to 6 zones later, or the next zone with a boss", gapOk, scheduleDetail)
	check("bosses only in zones that have one", bosslessOk)
	check("zone clock stops during a fight", pauseOk)
	check("every fight offers enough spears", supplyOk, supplyDetail)
	check("no Wind Rider flight runs into a boss", flightOk)
end

-- A fight on demand: the next boss is made due now, in the current zone.
local function FightWorld(seed)
	local world = World.New(seed, copy(Tuning))
	world:Step(0.05)
	world:DrainEvents()
	world.entities = {}
	world.cursor = 1e9
	-- Due at once: the zone that has a boss is this one, already under way.
	world.zoneKey = "westfall"
	world.zoneOrder[world.zoneIndex] = "westfall"
	world.bossZone = world.zoneIndex
	world.paused = world.paused - (world:BossStart() - world.time)
	return world
end

local function Events(world, kind)
	local found = {}
	for _, event in ipairs(world:DrainEvents()) do
		if event.type == kind then
			found[#found + 1] = event
		end
	end
	return found
end

do
	-- Taking the spears drives the boss off, for 50 each and 500 at the end.
	local world = FightWorld(51)
	world:Step(Tuning.step * 2)
	local started = Events(world, "bossStart")
	check("boss turns up when due", #started == 1 and world.boss and world.boss.name == "Edwin VanCleef", #started)
	local needed = world.boss.needed
	world.safeLeft = 1e9
	for _ = 1, needed do
		world:AddEntity("spear", world.runner.lane, world.time + 0.2, 0.9)
		for _ = 1, 60 do
			world:Step(Tuning.step)
		end
	end
	check("spears hit the boss", world.spearHits == needed, world.spearHits)
	check("enough spears drive the boss off", world.boss.state == "driven" and world.bossesDriven == 1)
	check("driving off scores " .. Tuning.points.bossDriven .. " plus " .. Tuning.points.spear .. " a spear",
		world.bossPoints == Tuning.points.bossDriven + needed * Tuning.points.spear, world.bossPoints)
	local course = world.course
	for _ = 1, 120 do
		world:Step(Tuning.step)
	end
	check("zone clock runs again after the boss leaves", world.course > course + 0.5)
	check("next boss 3 or more zones on", world.bossZone and world.bossZone >= world.boss.zone + 3, world.bossZone)

	-- Spears after the fight do nothing.
	world:AddEntity("spear", world.runner.lane, world.time + 0.2, 0.9)
	for _ = 1, 60 do
		world:Step(Tuning.step)
	end
	check("a spear with no boss out scores nothing", world.spearHits == needed)
end

do
	-- Lasting until the boss gives up is worth 150.
	local world = FightWorld(52)
	world.safeLeft = 1e9
	local seconds = 0
	while seconds < Tuning.boss.limit + 1 do
		world.safeLeft = 1e9
		world:Step(0.05)
		seconds = seconds + 0.05
	end
	check("the boss gives up after " .. Tuning.boss.limit .. " seconds", world.boss.state == "survived" and world.bossesSurvived == 1, world.boss.state)
	check("lasting it out scores " .. Tuning.points.bossSurvived, world.bossPoints == Tuning.points.bossSurvived, world.bossPoints)
end

do
	-- The boss takes the throws still in its hand with it, and the spears.
	local world = FightWorld(53)
	world.cursor = world.time + 0.5
	world.safeLeft = 1e9
	for _ = 1, 120 do
		world.safeLeft = 1e9
		world:Step(Tuning.step)
	end
	local waiting = 0
	for _, entity in ipairs(world.entities) do
		if entity.thrown and entity.phase == "waiting" then
			waiting = waiting + 1
		end
	end
	check("the boss throws hazards", waiting > 0, waiting)
	world.boss.hits = world.boss.needed - 1
	world:AddEntity("spear", world.runner.lane, world.time + 0.2, 0.9)
	for _ = 1, 60 do
		world.safeLeft = 1e9
		world:Step(Tuning.step)
	end
	local left, spears = 0, 0
	for _, entity in ipairs(world.entities) do
		if entity.thrown and entity.phase == "waiting" then
			left = left + 1
		elseif entity.role == "spear" then
			spears = spears + 1
		end
	end
	check("unthrown hazards leave with the boss", world.boss.state == "driven" and left == 0, left)
	check("spears leave with the boss", spears == 0, spears)
end

do
	-- A Stampede running out mid-fight slows you, which moves where throws
	-- leave and land; a hazard already down stays down, one in the air stays up.
	local world = FightWorld(54)
	world.cursor = world.time + 0.5
	world.powerups.stampede = 30
	local backwards = false
	local seen = {}
	for step = 1, 2400 do
		world.safeLeft = 1e9
		if step == 600 then
			world.powerups.stampede = 0.01
		end
		world:Step(Tuning.step)
		for _, entity in ipairs(world.entities) do
			if entity.thrown then
				local order = ({ waiting = 1, flying = 2, landed = 3 })[entity.phase]
				if seen[entity] and order < seen[entity] then
					backwards = true
				end
				seen[entity] = order
			end
		end
	end
	check("a throw never goes back to the boss's hand or back into the air", not backwards)
end

do
	-- The deciding spear and a crash in the same step: the spear still counts.
	local world = FightWorld(55)
	world:Step(Tuning.step * 2)
	world:DrainEvents()
	world.boss.hits = world.boss.needed
	world.bossBeaten = true
	world.safeLeft, world.shield, world.powerups = 0, false, {}
	world:AddEntity("block", world.runner.lane, world.time + Tuning.step, 0)
	world:Step(Tuning.step * 1.5)
	check("a deciding spear counts even with a crash in the same step",
		world.over and world.boss.state == "driven" and world.bossPoints >= Tuning.points.bossDriven,
		tostring(world.over) .. " " .. world.boss.state)
end

-- Orc runs ----------------------------------------------------------------------

local OrcRun = ns.OrcRun
check("name fingerprint is fixed", OrcRun.NameKey("Test") == "7c9e6865", OrcRun.NameKey("Test"))
check("name fingerprint ignores case", OrcRun.NameKey("TEST") == OrcRun.NameKey("test"))
check("name fingerprints differ", OrcRun.NameKey("Testa") ~= OrcRun.NameKey("Testb"))
check("name fingerprint skips the surname separator", OrcRun.NameKey("Grunk Smasher") == OrcRun.NameKey("Grunk-Smasher")
	and OrcRun.NameKey("Grunk Smasher") == OrcRun.NameKey("grunksmasher"))
check("one target listed", (function()
	local targets = 0
	for _ in pairs(OrcRun.targets) do targets = targets + 1 end
	return targets == 1
end)())
do
	local targets = OrcRun.targets
	OrcRun.targets = { [OrcRun.NameKey("Grunk Smasher")] = true, [OrcRun.NameKey("Testy")] = true }
	check("target by full name", OrcRun.RoleFor("Grunk Smasher", "Grunk") == "target")
	check("target by first name", OrcRun.RoleFor("Testy Mctest", "Testy") == "target")
	check("anyone else has no role", OrcRun.RoleFor("Someone", "Someone") == nil)
	check("no name has no role", OrcRun.RoleFor(nil, nil) == nil)
	OrcRun.targets = targets
end
-- Odds: about 1 in 25 for the target, every run when forced, never for
-- anyone else.
do
	local rng = ns.Random.New(99)
	local rolls = 20000
	local counts = { target = 0, none = 0, forced = 0 }
	for _ = 1, rolls do
		for key, role in pairs({ target = "target", none = false }) do
			if OrcRun.Roll(role or nil, false, rng:Next()) then
				counts[key] = counts[key] + 1
			end
		end
		if OrcRun.Roll(nil, true, rng:Next()) then
			counts.forced = counts.forced + 1
		end
	end
	check("target gets about 1 run in 25", near(counts.target / rolls, 1 / 25, 0.006), counts.target / rolls)
	check("nobody else gets one", counts.none == 0, counts.none)
	check("forced is every run", counts.forced == rolls, counts.forced)
end

-- An untouchable orc run: what's on the road, speeds, Tauren movement, dodges.
do
	local world = World.New(11, Tuning, { mode = "orc" })
	local roles, seen = {}, {}
	local startBehind, rising, orcSteady, taurenRising = true, true, true, true
	local lastTauren = world.taurenSpeed
	while world.time < 150 do
		world.safeLeft = 1e9
		world:Step(0.05)
		world:DrainEvents()
		if not near(world.speed, Rules.Speed(Tuning, 0)) then
			orcSteady = false
		end
		if world.taurenSpeed < lastTauren - 1e-9 then
			taurenRising = false
		end
		lastTauren = world.taurenSpeed
		for _, entity in ipairs(world.entities) do
			roles[entity.role] = true
			if entity.role == "tauren" then
				if not seen[entity.id] then
					startBehind = startBehind and entity.y < 0 and entity.y >= -Tuning.orcRun.spawnBehind - 1e-6
				elseif entity.y < seen[entity.id] - 1e-9 then
					rising = false
				end
				seen[entity.id] = entity.y
			end
		end
	end
	local others = {}
	for role in pairs(roles) do
		if role ~= "tauren" and role ~= "coin" and role ~= "gem" then
			others[#others + 1] = role
		end
	end
	check("orc run: only Tauren and tokens on the road", #others == 0 and roles.tauren and roles.coin, table.concat(others, ", "))
	check("orc run: no bosses", world.boss == nil and world.bossZone == nil)
	check("orc run: Tauren start behind you", startBehind)
	check("orc run: Tauren only move up the road", rising)
	check("orc run: you keep the zone-1 speed", orcSteady)
	check("orc run: Tauren speed up", taurenRising and world.taurenSpeed > Rules.TaurenSpeed(Tuning, 0) + 10, world.taurenSpeed)
	check("orc run: zones advance", world.zoneIndex >= 6, world.zoneIndex)
	check("orc run: each Tauren past is a dodge", world.dodges > 50 and world.movePoints == world.dodges * Tuning.points.dodge, world.dodges)
end

-- One Tauren in another lane goes by for points; one in your lane tramples you.
do
	local world = World.New(12, Tuning, { mode = "orc" })
	world:Step(0.05)
	world.cursor, world.coinNext = 1e9, 1e9
	world.entities = {}
	world:DrainEvents()
	local other = world.runner.lane == 1 and 3 or 1
	world:AddEntity("tauren", other, world.time + 1, 0)
	for _ = 1, 240 do
		world:Step(Tuning.step)
	end
	local dodged = 0
	for _, event in ipairs(world:DrainEvents()) do
		if event.type == "dodge" then
			dodged = dodged + 1
		end
	end
	check("orc run: a Tauren in another lane is dodged once", not world.over and dodged == 1 and world.dodges == 1, dodged)
	world:AddEntity("tauren", world.runner.lane, world.time + 1, 0)
	for _ = 1, 240 do
		world:Step(Tuning.step)
	end
	check("orc run: a Tauren in your lane tramples you", world.over and world.crashRole == "tauren" and world.dodges == 1)
end

-- Slow and fast starts: the run starts at that speed, scores with its
-- multiplier, stays fair, and the planning bot gets through, orc runs too.
for _, choice in ipairs(Tuning.startSpeeds) do
	if choice.multiplier ~= 1 then
		local tuning = copy(Tuning)
		tuning.baseSpeed, tuning.scoreMultiplier = choice.speed, choice.multiplier
		local world = World.New(5, tuning)
		world:Step(0.05)
		check(("%s start begins at %d yd/s"):format(choice.name, choice.speed), near(world.speed, choice.speed + tuning.rampPerSecond * world.time, 0.01), world.speed)
		local timeline = RunTimeline(5, tuning, minutes * 60)
		table.sort(timeline, function(a, b)
			return a.t < b.t
		end)
		check(("%s start timeline"):format(choice.name), (Patterns.Feasible(timeline, tuning)))
		for _, mode in ipairs({ false, "orc" }) do
			local played = PlayBot(5, copy(tuning), minutes * 60, mode or nil)
			local label = ("bot survives a %s start%s"):format(choice.name, mode and " orc run" or "")
			check(label, not played.over, ("crashed into %s at %.1fs"):format(tostring(played.crashRole), played.time))
			local raw = played.tokenPoints + played.timePoints + played.movePoints + played.bossPoints
			check(label .. ": score multiplied", played.score == math.floor(raw * choice.multiplier), played.score)
		end
	end
end

-- Every orc run leaves a way through, and a planning bot gets through it.
for seed = 1, math.min(seedCount, 10) do
	local timeline = RunTimeline(seed, copy(Tuning), minutes * 60, "orc")
	table.sort(timeline, function(a, b)
		return a.t < b.t
	end)
	local ok, at = Patterns.Feasible(timeline, Tuning)
	check(("orc timeline seed %d"):format(seed), ok, at)
	local world = PlayBot(seed, copy(Tuning), minutes * 60, "orc")
	check(("bot survives orc run seed %d"):format(seed), not world.over,
		("trampled at %.1fs in zone %d"):format(world.time, world.zoneIndex))
	if seed == 1 then
		check("orc bot collects tokens and dodges", world.tokens > 20 and world.dodges > 100, ("%d tokens, %d dodges"):format(world.tokens, world.dodges))
	end
end

-- Guild messages ----------------------------------------------------------------

do
	local best = { score = 18905, tenths = 2421, tokens = 171, zones = 6, when = 1793900000 }
	local kind, decoded = Codec.Decode(Codec.EncodeBest(best))
	check("best round-trips", kind == "best" and decoded.score == 18905 and decoded.tenths == 2421 and decoded.when == 1793900000)
	check("request decodes", Codec.Decode(Codec.EncodeRequest()) == "request")
	check("rejects junk", Codec.Decode("hello") == nil)
	check("rejects negative", Codec.Decode("B|-5|10|1|1|1793900000") == nil)
	check("rejects missing field", Codec.Decode("B|5|10|1|1793900000") == nil)
	check("rejects decimals", Codec.Decode("B|5.5|10|1|1|1793900000") == nil)
	check("rejects huge score", Codec.Decode("B|999999999|10|1|1|1793900000") == nil)
	check("rejects extra field", Codec.Decode("B|5|10|1|1|1793900000|9") == nil)
	check("rejects non-string", Codec.Decode(nil) == nil)
	check("prefix fits 16 chars", #Codec.PREFIX <= 16)
	check("message fits 255 chars", #Codec.EncodeBest({ score = 100000000, tenths = 3600000, tokens = 1000000, zones = 100000, when = 9999999999 }) <= 255)
end

-- Zone models, event lists and Alliance joggers' lanes -------------------------------

do
	local world = World.New(7, copy(Tuning), { bosses = false })
	local later = world:AddEntity("low", 2, Tuning.zoneLength + 2, 0)
	local sooner = world:AddEntity("low", 2, 1, 0)
	check("an entity keeps the zone it arrives in", later.zoneKey == world:ZoneKey(2) and sooner.zoneKey == world:ZoneKey(1))
	world:DrainEvents()
	world:Emit({ type = "test" })
	local first = world:DrainEvents()
	check("drained events come back once", #first == 1 and first[1].type == "test" and #world:DrainEvents() == 0)

	-- A charger starts further off than the road's hazards, so its lane is
	-- never offered to an Alliance jogger, however soon it's due.
	local tuning = copy(Tuning)
	tuning.alliance = { chance = 1, minZone = 1, speedShare = 0.45 }
	local busy = World.New(3, tuning, { bosses = false })
	busy.speed = 20
	busy:AddEntity("charger", 1, 2.7, 0)
	busy:AddEntity("charger", 2, 2.7, 0)
	for _ = 1, 20 do
		busy:SpawnAlliance({}, 0, 6, 1)
	end
	local joggers, clear = 0, true
	for _, entity in ipairs(busy.entities) do
		if entity.role == "alliance" then
			joggers = joggers + 1
			clear = clear and entity.lane == 3
		end
	end
	check("Alliance joggers keep out of a charger's lane", joggers == 20 and clear, joggers)
end

print(("%d of %d checks passed (%d seeds, %d minutes each, bot time %.1fs)"):format(total - failures, total, seedCount, minutes, os.clock() - clock))
if failures > 0 then
	os.exit(1)
end
