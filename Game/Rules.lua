local _, ns = ...

-- Difficulty, scoring and hit shapes. No WoW API, so tests can load it.
local Rules = {}
ns.Rules = Rules

local function Smooth(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

-- Zone number (1-based) for a run time.
function Rules.ZoneIndex(tuning, time)
	return math.floor(time / tuning.zoneLength) + 1
end

-- Base running speed: a gentle ramp, plus a bump that eases in over bumpTime
-- after each zone change, capped at maxSpeed.
function Rules.Speed(tuning, time)
	local zone = Rules.ZoneIndex(tuning, time)
	local bumps = 0
	if zone > 1 then
		local sinceChange = time - (zone - 1) * tuning.zoneLength
		bumps = (zone - 2) + Smooth(sinceChange / tuning.bumpTime)
	end
	local speed = tuning.baseSpeed + tuning.rampPerSecond * time + tuning.zoneBump * bumps
	return math.min(speed, tuning.maxSpeed)
end

-- Row spacing multiplier for chunks: 1 at the start, smaller later.
function Rules.Tempo(tuning, zone)
	return math.max(tuning.tempoMin, tuning.tempoStart - tuning.tempoPerZone * (zone - 1))
end

-- Seconds between chunks.
function Rules.Gap(tuning, zone)
	return math.max(tuning.gapMin, tuning.gapStart - tuning.gapPerZone * (zone - 1))
end

-- Time points earned per second in a zone.
function Rules.TimeRate(tuning, zone)
	return tuning.points.perSecond + tuning.points.perSecondPerZone * (zone - 1)
end

function Rules.TokenValue(tuning, role, goldRush)
	local value = tuning.points[role] or 0
	if goldRush then
		value = value * tuning.goldRushMultiplier
	end
	return value
end

-- Hit shapes by role: half width, half depth, bottom and top heights.
Rules.SHAPES = {
	low = { halfWidth = 0.8, halfDepth = 0.5, bottom = 0, top = 1.0 },
	high = { halfWidth = 0.9, halfDepth = 0.4, bottom = 1.5, top = 3.6 },
	block = { halfWidth = 0.85, halfDepth = 0.8, bottom = 0, top = 4.0 },
	wall = { halfWidth = 0.95, halfDepth = 0.6, bottom = 0, top = 4.0 },
	charger = { halfWidth = 0.85, halfDepth = 1.2, bottom = 0, top = 3.0 },
}

Rules.OBSTACLE = { low = true, high = true, block = true, wall = true, charger = true }
Rules.TOKEN = { coin = true, gem = true }
Rules.POWERUP = { windRider = true, magnet = true, shield = true, goldRush = true, stampede = true }

-- What the runner must do to survive an obstacle in its lane.
Rules.REQUIREMENT = { low = "jump", high = "duck", block = "avoid", wall = "avoid", charger = "avoid" }

-- True when the runner (at x, feet at z, standing height) touches the obstacle
-- at lateral position ex and distance ey.
function Rules.HitsObstacle(tuning, role, ex, ey, runnerX, runnerZ, runnerHeight)
	local shape = Rules.SHAPES[role]
	if not shape then
		return false
	end
	if math.abs(ey) >= shape.halfDepth + tuning.runnerHalfDepth then
		return false
	end
	if math.abs(ex - runnerX) >= shape.halfWidth + tuning.runnerHalfWidth then
		return false
	end
	return runnerZ < shape.top and runnerZ + runnerHeight > shape.bottom
end

-- Tokens and power-ups are picked up with a generous box.
function Rules.Touches(ex, ey, ez, runnerX, runnerZ, runnerHeight)
	if math.abs(ey) >= 1.0 or math.abs(ex - runnerX) >= 1.0 then
		return false
	end
	return ez > runnerZ - 0.6 and ez < runnerZ + runnerHeight + 0.6
end

function Rules.Score(tokenPoints, timePoints, movePoints)
	return math.floor(tokenPoints + timePoints + (movePoints or 0))
end

-- Points for getting past an obstacle in your path with the move it asks for:
-- jumping a low one or ducking a high bar. Others score nothing.
function Rules.MovePoints(tuning, role)
	if role == "low" then
		return tuning.points.jump, "jump"
	elseif role == "high" then
		return tuning.points.duck, "duck"
	end
	return nil
end
