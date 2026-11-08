local _, ns = ...

-- Every gameplay number lives here. Distances are in yards, times in seconds.
ns.Tuning = {
	-- Simulation runs in fixed steps so jumps and timings match on every frame rate.
	step = 1 / 120,
	maxFrame = 0.25,

	-- Lane centres. The road is three lanes wide; widening these widens it.
	lanes = { -2.6, 0, 2.6 },

	-- Speed: a gentle ramp inside each zone plus a bump on entering a new zone.
	zoneLength = 25,
	-- Choices on the start screen: seconds per zone. Shorter is harder, as
	-- speed and new obstacles arrive sooner.
	zoneLengths = {
		{ seconds = 15, name = "Frantic" },
		{ seconds = 25, name = "Normal" },
		{ seconds = 35, name = "Relaxed" },
		{ seconds = 45, name = "Marathon" },
	},
	baseSpeed = 11,
	rampPerSecond = 0.03,
	zoneBump = 2.2,
	bumpTime = 1.5,
	maxSpeed = 38,

	-- Spawning. A chunk is spawned when its first row is this far away.
	spawnAhead = 80,
	despawnBehind = -6,
	-- No chunk arrives within this many seconds either side of a zone change.
	zoneBreather = 1.25,
	-- Chunk timings shrink by zone: rows get closer together and gaps shorter.
	tempoStart = 1.0,
	tempoPerZone = 0.05,
	tempoMin = 0.62,
	gapStart = 1.6,
	gapPerZone = 0.1,
	gapMin = 0.8,
	chargerSpeed = 7,

	-- Runner.
	laneChangeTime = 0.14,
	gravity = 30,
	jumpSpeed = 10.5,
	fastFallSpeed = 16,
	duckEnabled = true,
	duckTime = 0.6,
	runnerHalfWidth = 0.4,
	runnerHalfDepth = 0.4,
	runnerHeight = 2.3,
	duckHeight = 1.1,

	-- Power-ups.
	flyHeight = 5.5,
	flyRiseRate = 12,
	landSafeTime = 1.0,
	hitSafeTime = 1.0,
	durations = {
		windRider = 8,
		magnet = 10,
		goldRush = 12,
		stampede = 5,
	},
	powerupWeights = {
		magnet = { weight = 3, minZone = 1 },
		goldRush = { weight = 3, minZone = 1 },
		shield = { weight = 2, minZone = 1 },
		windRider = { weight = 2, minZone = 2 },
		stampede = { weight = 2, minZone = 3 },
	},
	powerupMinGap = 12,
	magnetRange = 16,
	magnetPull = 10,
	goldRushMultiplier = 2,
	stampedeMultiplier = 1.5,
	stampedeRamp = 0.4,
	skyCoinSpacing = 0.22,

	-- Scoring.
	points = {
		coin = 10,
		gem = 50,
		perSecond = 10,
		perSecondPerZone = 2,
		-- For each obstacle in your path that you jump over or duck under.
		jump = 2,
		duck = 3,
		-- For each Alliance jogger knocked out of your lane.
		knock = 5,
		-- Boss fights: each spear that hits, and the bonus for driving the boss
		-- off or for lasting until it gives up.
		spear = 50,
		bossDriven = 500,
		bossSurvived = 150,
	},
	-- Alliance joggers on the track: the chance one jogs in the gap after a
	-- chunk, from this zone on, at this share of your speed.
	alliance = { chance = 0.35, minZone = 1, speedShare = 0.45 },

	-- Bosses. The first comes in a random zone from `first`; after each fight
	-- the next comes `every` zones later (a random count in that range). A zone
	-- with no boss passes it on to the next zone that has one. The boss turns up
	-- `delay` seconds into its zone and the zone clock stops until it leaves.
	boss = {
		first = { 3, 6 },
		every = { 3, 6 },
		delay = 4,
		-- Seconds before the boss gives up and leaves.
		limit = 25,
		-- Seconds from the boss turning up to its first throw reaching you.
		leadIn = 3.5,
		-- Spears to drive it off: `spears` in zone `spearsFrom`, one more every
		-- `spearsEvery` zones after that.
		spears = 3,
		spearsFrom = 3,
		spearsEvery = 2,
		-- Spears offered over a fight, as a multiple of those needed.
		spearSupply = 1.6,
		-- Where the boss stands, in yards ahead. A thrown hazard leaves its hand
		-- `throwLead` seconds before it would reach you (no further than
		-- `throwMax` yards) and lands `landLead` seconds before; near top speed
		-- the throwMax cap brings that down to about a second.
		distance = 58,
		throwLead = 2.4,
		throwMax = 54,
		landLead = 1.1,
	},
}
