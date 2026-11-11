local _, ns = ...

-- Hand-made chunks of obstacles and tokens. Each row is { seconds, "abc" },
-- one character per lane (left, middle, right). Seconds are at tempo 1 and
-- shrink as zones get harder.
--   .  empty         c  coin            a  coin in the air      g  gem
--   L  low (jump)    A  low + air coin  H  high bar (duck)      P  power-up
--   B  block         W  wall piece      C  charging creature
--   R  ramp over a pit   X  the pit's edge in a lane with no ramp
-- A pattern with `pit = { fewest, most }` is a pit that many tiles long,
-- right across the road, after its one row of ramps and edges.
-- A pattern with `twist = "field"` is only used in a zone whose twist
-- (Tuning.twists) has that field.
local Patterns = {}
ns.Patterns = Patterns

local function Line(code, lane, count, spacing, start)
	local rows = {}
	for index = 0, count - 1 do
		local cells = { ".", ".", "." }
		cells[lane] = code
		rows[#rows + 1] = { (start or 0) + index * spacing, table.concat(cells) }
	end
	return rows
end

Patterns.LIST = {
	{ name = "coinLine", minZone = 1, weight = 3, rows = Line("c", 2, 6, 0.22) },
	{ name = "lowCenter", minZone = 1, weight = 3, rows = { { 0, "c.c" }, { 0.25, "cAc" }, { 0.5, "c.c" } } },
	{ name = "lowPair", minZone = 1, weight = 3, rows = { { 0, "LL." }, { 0.25, "..c" }, { 0.5, "..c" }, { 1.1, ".LL" }, { 1.35, "c.." } } },
	{ name = "blockWeave", minZone = 1, weight = 3, rows = { { 0, "B.." }, { 0.3, ".c." }, { 1.1, "..B" }, { 1.4, ".c." }, { 2.2, "B.." } } },
	{ name = "jumpLine", minZone = 1, weight = 2, rows = { { 0, ".A." }, { 0.9, ".A." }, { 1.8, ".A." } } },
	{ name = "powerup", minZone = 1, weight = 2, rows = { { 0, "c.c" }, { 0.3, ".P." }, { 0.6, "c.c" } } },
	{ name = "gemDodge", minZone = 1, weight = 1, rows = { { 0, "BgB" }, { 0.8, "c.c" } } },
	{ name = "highBar", minZone = 2, weight = 3, rows = { { 0, "BH." }, { 1.0, ".HB" } } },
	{ name = "wallGap", minZone = 2, weight = 3, rows = { { 0, "WW." }, { 1.2, ".WW" }, { 2.4, "WW." } } },
	{ name = "highLow", minZone = 2, weight = 2, rows = { { 0, "H.L" }, { 0.5, "..c" }, { 1.0, ".B." } } },
	{ name = "charger", minZone = 3, weight = 3, rows = { { 0, "c.c" }, { 0.5, ".C." }, { 0.8, "c.c" } } },
	{ name = "doubleCharger", minZone = 3, weight = 2, rows = { { 0, "C.." }, { 1.0, ".c." }, { 1.0, "..C" } } },
	{ name = "chargeWall", minZone = 3, weight = 2, rows = { { 0, "C.W" }, { 0.3, ".g." } } },
	{ name = "slalom", minZone = 4, weight = 2, rows = { { 0, "B.." }, { 0.7, ".B." }, { 1.4, "..B" }, { 2.1, ".B." }, { 2.8, "B.." } } },
	{ name = "jumpDuck", minZone = 4, weight = 2, rows = { { 0, "LLB" }, { 0.9, "HH." } } },
	{ name = "gauntlet", minZone = 5, weight = 2, rows = { { 0, "LBL" }, { 1.25, "BLB" }, { 2.5, "LBL" } } },
	{ name = "mixed", minZone = 5, weight = 2, rows = { { 0, "WW." }, { 1.0, "..L" }, { 2.0, "BH." } } },

	-- Multi-lane hazards: one barrier across two or three lanes, always with a
	-- free lane or a jump/duck way through. needsDuck patterns are only used
	-- with ducking on; with it off their bars would close every lane.
	{ name = "logJump", minZone = 2, weight = 2, rows = { { 0, "AAA" }, { 0.6, "c.c" } } },
	{ name = "wallJump", minZone = 3, weight = 2, rows = { { 0, "WWL" }, { 0.5, "..c" }, { 1.0, ".c." } } },
	{ name = "limbo", minZone = 3, weight = 2, needsDuck = true, rows = { { 0, "HHH" }, { 0.4, ".c." } } },
	{ name = "barricade", minZone = 4, weight = 2, rows = { { 0, "WW." }, { 1.0, "LLL" } } },
	{ name = "underpass", minZone = 4, weight = 2, needsDuck = true, rows = { { 0, "HHB" }, { 1.0, "BHH" } } },
	{ name = "hurdles", minZone = 5, weight = 1, needsDuck = true, rows = { { 0, "LLL" }, { 0.9, "HHH" }, { 1.8, "LLL" } } },

	-- Stampede country (the Barrens' twist): two chargers abreast.
	{ name = "chargerPair", minZone = 3, weight = 2, twist = "chargers", rows = { { 0, ".c." }, { 0.5, "C.C" }, { 0.8, ".c." } } },

	-- Pits: get to a lane with a ramp, which throws you over. Two ramps are
	-- easier to reach than one; mirroring puts a side ramp on either side.
	{ name = "pitTwoRamps", minZone = 2, weight = 2, pit = { 2, 2 }, rows = { { 0, "RXR" } } },
	{ name = "pitSideRamps", minZone = 2, weight = 2, pit = { 2, 3 }, rows = { { 0, "RRX" } } },
	{ name = "pitMiddleRamp", minZone = 3, weight = 2, pit = { 2, 3 }, rows = { { 0, "XRX" } } },
	{ name = "pitOneRamp", minZone = 4, weight = 2, pit = { 2, 3 }, rows = { { 0, "RXX" } } },
}

-- Requirement for each code; codes not listed ask nothing of the runner.
-- T is a Tauren coming up from behind in an orc run (never in a pattern).
Patterns.REQUIREMENT = { L = "jump", A = "jump", H = "duck", B = "avoid", W = "avoid", C = "avoid", X = "avoid", T = "avoid" }

-- Fairness limits used by Feasible: seconds per lane moved, and the shortest
-- time between two actions in a row.
Patterns.LIMITS = {
	reaction = 0.15,
	jumpThenJump = 0.75,
	jumpThenDuck = 0.35,
	duckThenJump = 0.3,
}

-- Turns a pattern into a flat list of { t, lane, code }, scaled by tempo.
-- Mirrored swaps left and right. With ducking off, high bars become blocks.
function Patterns.Expand(pattern, tempo, mirrored, duckEnabled)
	local items = {}
	for _, row in ipairs(pattern.rows) do
		local cells = row[2]
		for lane = 1, 3 do
			local code = cells:sub(lane, lane)
			if code ~= "." then
				if code == "H" and not duckEnabled then
					code = "B"
				end
				items[#items + 1] = { t = row[1] * tempo, lane = mirrored and (4 - lane) or lane, code = code }
			end
		end
	end
	table.sort(items, function(a, b)
		return a.t < b.t
	end)
	return items
end

function Patterns.Duration(pattern, tempo)
	local last = 0
	for _, row in ipairs(pattern.rows) do
		last = math.max(last, row[1])
	end
	return last * tempo
end

-- True when a pattern has this code anywhere (remembered on the pattern).
local function Has(pattern, code)
	local has = pattern.has
	if not has then
		has = {}
		pattern.has = has
	end
	if has[code] == nil then
		has[code] = false
		for _, row in ipairs(pattern.rows) do
			if row[2]:find(code, 1, true) then
				has[code] = true
			end
		end
	end
	return has[code]
end

-- twist: the zone's (Tuning.twists), if it has one.
local function Allowed(pattern, zone, duckEnabled, twist)
	if pattern.twist and not (twist and twist[pattern.twist]) then
		return false
	end
	local minZone = pattern.minZone
	if twist and twist.chargerEarly and Has(pattern, "C") then
		minZone = minZone - twist.chargerEarly
	end
	return minZone <= zone and (duckEnabled ~= false or not pattern.needsDuck)
end

-- True when a pattern asks something of the runner (not just tokens).
local function HasHazard(pattern)
	if pattern.hasHazard == nil then
		pattern.hasHazard = false
		for _, row in ipairs(pattern.rows) do
			for lane = 1, 3 do
				if Patterns.REQUIREMENT[row[2]:sub(lane, lane)] then
					pattern.hasHazard = true
				end
			end
		end
	end
	return pattern.hasHazard
end

Patterns.HasHazard = HasHazard

-- A pattern's weight in a zone with this twist: more chargers, power-ups or
-- token-only patterns where the twist says so.
local function Weight(pattern, twist)
	local weight = pattern.weight
	if twist then
		if twist.chargers and Has(pattern, "C") then
			weight = weight * twist.chargers
		end
		if twist.powerups and Has(pattern, "P") then
			weight = weight * twist.powerups
		end
		if twist.loot and not HasHazard(pattern) and not Has(pattern, "P") then
			weight = weight * twist.loot
		end
	end
	return weight
end

-- Weighted pick among patterns unlocked by this zone. With ducking off,
-- patterns that need it are left out. `accept`, if given, must also pass
-- (a boss uses it for hazards that fit before it gives up); with it, nil
-- comes back when nothing does. `twist`: the zone's, if it has one.
function Patterns.Pick(rng, zone, duckEnabled, accept, twist)
	local pattern = ns.Random.Weighted(Patterns.LIST, function(item)
		return Allowed(item, zone, duckEnabled, twist) and (not accept or accept(item)) and Weight(item, twist) or 0
	end, rng:Next())
	if pattern then
		return pattern, rng:Next() < 0.5
	elseif accept then
		return nil
	end
	return Patterns.LIST[1], false
end

local NEVER = -1000

function Patterns.StartStates()
	return {
		{ lane = 1, t = NEVER, jump = NEVER, duck = NEVER },
		{ lane = 2, t = NEVER, jump = NEVER, duck = NEVER },
		{ lane = 3, t = NEVER, jump = NEVER, duck = NEVER },
	}
end

local function Combine(current, new)
	if not current then
		return new
	end
	if current == new then
		return current
	end
	return "avoid"
end

-- Checks a timeline of { t, lane, code } (absolute times) can be survived by a
-- player obeying LIMITS. Returns true and the end states, or false and the time
-- of the first impossible row. States carry over between calls.
-- laneChangeTime: seconds a lane change takes, where it isn't the usual
-- (on ice, for placing something between rows whose spacing allows for it).
function Patterns.Feasible(items, tuning, states, laneChangeTime)
	local limits = Patterns.LIMITS
	local moveCost = (laneChangeTime or tuning.laneChangeTime) + limits.reaction
	states = states or Patterns.StartStates()

	local index = 1
	while index <= #items do
		local t = items[index].t
		local requirement = {}
		local hasRequirement = false
		while index <= #items and math.abs(items[index].t - t) < 1e-6 do
			local item = items[index]
			local need = Patterns.REQUIREMENT[item.code]
			if need then
				requirement[item.lane] = Combine(requirement[item.lane], need)
				hasRequirement = true
			end
			index = index + 1
		end

		if hasRequirement then
			local nextStates = {}
			for lane = 1, 3 do
				local need = requirement[lane]
				if need ~= "avoid" then
					local best
					for _, state in ipairs(states) do
						local elapsed = t - state.t
						if math.abs(lane - state.lane) * moveCost <= elapsed + 1e-9 then
							local ok = true
							if need == "jump" then
								ok = t - state.jump >= limits.jumpThenJump - 1e-9 and t - state.duck >= limits.duckThenJump - 1e-9
							elseif need == "duck" then
								ok = t - state.jump >= limits.jumpThenDuck - 1e-9
							end
							if ok then
								local candidate = {
									lane = lane,
									t = t,
									jump = need == "jump" and t or state.jump,
									duck = need == "duck" and t or state.duck,
									parent = state,
								}
								-- Keep the state whose last actions are oldest: it has the most freedom.
								if not best or candidate.jump + candidate.duck < best.jump + best.duck then
									best = candidate
								end
							end
						end
					end
					if best then
						nextStates[#nextStates + 1] = best
					end
				end
			end
			if #nextStates == 0 then
				return false, t
			end
			states = nextStates
		end
	end
	return true, states
end
