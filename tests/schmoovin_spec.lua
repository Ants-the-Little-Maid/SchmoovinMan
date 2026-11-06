-- Schmoovin Man game logic tests. Run with any Lua:
--   lua tests/schmoovin_spec.lua <addon folder, usually .> [seeds] [minutes] [seconds per zone]

local root = arg and arg[1] or "."
local seedCount = tonumber(arg and arg[2]) or 20
local minutes = tonumber(arg and arg[3]) or 10

local ns = {}
for _, file in ipairs({ "Data/Tuning.lua", "Data/Assets.lua", "Data/Zones.lua", "Game/Random.lua", "Game/Rules.lua", "Game/Patterns.lua", "Game/Runner.lua", "Game/World.lua", "Social/Codec.lua" }) do
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

local function RunTimeline(seed, tuning, seconds)
	local world = World.New(seed, tuning, { recordTimeline = true })
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

local ROLE_CODE = { low = "L", high = "H", block = "B", wall = "B", charger = "B" }

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

local function PlayBot(seed, tuning, seconds)
	local world = World.New(seed, tuning)
	local runner = world.runner
	local lastJump, lastDuck = -1000, -1000
	local target = runner.lane
	local planTimer = 0
	while world.time < seconds and not world.over do
		planTimer = planTimer - tuning.step
		if planTimer <= 0 and not runner.flying then
			planTimer = 0.02
			local items = {}
			for _, entity in ipairs(world.entities) do
				local code = ROLE_CODE[entity.role]
				-- A jump or duck already under way counts as done in this lane, and
				-- as a block in the others (too late to jump there).
				if (code == "L" or code == "H") and entity.arrive < world.time + 0.1 then
					code = entity.lane ~= runner.lane and "B" or nil
				end
				if code and not entity.smashed and entity.arrive > world.time - 0.1 then
					items[#items + 1] = { t = entity.arrive, lane = entity.lane, code = code }
				end
			end
			table.sort(items, function(a, b)
				return a.t < b.t
			end)
			local start = { lane = runner.lane, t = world.time - Patterns.LIMITS.reaction, jump = lastJump, duck = lastDuck }
			local ok, states = Patterns.Feasible(items, tuning, { start })
			if ok and #items > 0 then
				target = NextLane(states, start, world.time) or target
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
			check("zones advance", world.zoneIndex >= math.floor(minutes * 60 / Tuning.zoneLength), world.zoneIndex)
			check("bot earns jump and duck points", world.movePoints > 0 and world.jumps > 0, world.movePoints)
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

print(("%d of %d checks passed (%d seeds, %d minutes each, bot time %.1fs)"):format(total - failures, total, seedCount, minutes, os.clock() - clock))
if failures > 0 then
	os.exit(1)
end
