local _, ns = ...

-- Personal top 10, saved for the account and shared across characters.
local Scores = {}
ns.Scores = Scores

local KEEP = 10

local function ByScore(a, b)
	if a.score ~= b.score then
		return a.score > b.score
	end
	return (a.when or 0) < (b.when or 0)
end

function Scores.List()
	return ns.db.scores
end

function Scores.Best()
	return ns.db.scores[1]
end

-- Saves a finished run. Returns the entry, its rank (nil when it didn't make
-- the top 10) and whether it's a new best.
function Scores.Add(world)
	local previousBest = Scores.Best()
	local entry = {
		score = world.score,
		tenths = math.floor(world.time * 10 + 0.5),
		tokens = world.tokens,
		gems = world.gems,
		zones = world.zoneIndex,
		zoneKey = world.crashZoneKey or world.zoneKey,
		zoneLength = world.tuning.zoneLength,
		-- Starting speed, whose multiplier is already in the score.
		startSpeed = world.tuning.baseSpeed,
		character = (ns.PlayerName()),
		when = time(),
		-- An orc run (Data/OrcRun.lua), shown with a candle.
		orc = world.mode == "orc" or nil,
	}
	-- This character's own best, kept even when other characters fill the top 10.
	local name = entry.character
	if name then
		local best = ns.db.bests[name]
		if not best or entry.score > best.score then
			ns.db.bests[name] = entry
		end
	end
	local list = ns.db.scores
	tinsert(list, entry)
	table.sort(list, ByScore)
	while #list > KEEP do
		tremove(list)
	end
	local rank
	for index, saved in ipairs(list) do
		if saved == entry then
			rank = index
		end
	end
	local isBest = rank == 1 and (not previousBest or entry.score > previousBest.score)
	ns.db.stats.runs = ns.db.stats.runs + 1
	ns.db.stats.tokens = ns.db.stats.tokens + world.tokens
	return entry, rank, isBest
end
