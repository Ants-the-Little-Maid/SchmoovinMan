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
	-- Starting speed choices (start screen and Options): the speed a run starts
	-- at, and what its final score is multiplied by to match. baseSpeed and
	-- scoreMultiplier hold the one chosen (see ns.SetStartSpeed).
	startSpeeds = {
		{ speed = 8, name = "Slow", multiplier = 0.75 },
		{ speed = 11, name = "Normal", multiplier = 1 },
		{ speed = 14, name = "Fast", multiplier = 1.25 },
	},
	scoreMultiplier = 1,
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
	-- How fast a crosswind pushes you off your lane's middle in the air, and
	-- lets you back onto it on landing, in yards a second.
	driftRate = 2.5,
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
		-- For each ramp taken over a pit.
		ramp = 5,
		-- For each wisp caught (Ashenvale's twist).
		wisp = 1,
		-- Boss fights: each spear that hits, and the bonus for driving the boss
		-- off or for lasting until it gives up.
		spear = 50,
		bossDriven = 500,
		bossSurvived = 150,
		-- Orc runs: each Tauren that gets past without trampling you.
		dodge = 5,
	},
	-- Combos: a run of clean moves (jumps, ducks, ramps and Alliance knocks).
	-- Every `every` of them raises what a move pays by `step`, up to `max`
	-- times. Thick Hide breaking ends it. Left `timeout` seconds without a
	-- move it starts to run down, losing `decay` every `decayEvery` seconds;
	-- only time with something ahead to jump, duck, ride or knock counts.
	combo = { every = 5, step = 0.5, max = 3, timeout = 5, decay = 2, decayEvery = 2 },

	-- Pits: a hole right across the road, `tile` yards to a tile and 2 or 3
	-- tiles long (set by the pattern), with a ramp at its edge in one or two
	-- lanes. Running onto a ramp throws you over it in an arc `height` yards
	-- high, coming down `landing` seconds past the far edge; `coins` air coins
	-- a tile lie along the way. The pit starts `lead` yards past the ramp row.
	pit = { tile = 8, lead = 0.8, landing = 0.15, height = 2.6, coins = 2 },

	-- Zone twists: one special rule in some zones, by zone key.
	--   laneChange, spacing  seconds a lane change takes there, and what the
	--               time between rows and chunks is multiplied by to make up
	--               for it. The fairness check allows laneChangeTime plus a
	--               reaction time (0.15 s) for each lane moved; spacing is at
	--               least (laneChange + 0.15) / (laneChangeTime + 0.15), so
	--               whatever can be passed elsewhere can be passed there
	--   ventChance  chance of a lava vent in the gap after a chunk; ventExtra
	--               seconds of clear road are added after it, so it can always
	--               be stepped round and the next chunk still reached
	--   gustEvery, gustLength, gustPull  a gust every so many seconds, lasting
	--               gustLength, that pulls the fog in by gustPull of its range
	--               (drawing only)
	--   drift, driftEvery  yards a crosswind pushes you sideways in the air
	--               (too little to reach the next lane's hazard), turning
	--               round every driftEvery seconds
	--   steam       the vents are steam vents (Ironforge): the same rule, drawn
	--               as a grate and a plume
	--   chargers, chargerEarly  what the weight of patterns with a charging
	--               creature is multiplied by, and how many zones sooner they
	--               start; it also allows the patterns marked twist = "chargers"
	--   wisps       a trail of wisps along one safe way through each chunk
	--               (Tuning.wisps), a point each
	--   powerups, powerupGap  what the weight of the power-up pattern and the
	--               shortest time between power-ups are multiplied by
	--   loot, gemChance  what the weight of patterns with only tokens is
	--               multiplied by, and the chance a ground coin is a gem instead
	--   gravity, jumpSpeed  the runner's there, for floaty jumps, with `spacing`
	--               to match: a jump lasts 2 * jumpSpeed / gravity seconds, and
	--               spacing is at least that plus 0.05, over the fairness
	--               check's 0.75 s between jumps
	--   allianceChance  the chance of an Alliance jogger after a chunk there
	--   shield      you're given Thick Hide on entering the zone
	twists = {
		winterspring = { name = "Icy road: lane changes slide", laneChange = 0.2, spacing = 1.25 },
		burningsteppes = { name = "Lava vents: keep off the glow", ventChance = 0.45, ventExtra = 0.8 },
		silithus = { name = "Sandstorm: gusts hide the road", gustEvery = 11, gustLength = 5, gustPull = 0.4 },
		thousandneedles = { name = "Crosswind: jumps drift", drift = 0.4, driftEvery = 4 },
		barrens = { name = "Stampede country: more chargers", chargers = 3, chargerEarly = 1 },
		ashenvale = { name = "Wisps: follow them through", wisps = true },
		ungoro = { name = "Crystal pylons: more power-ups", powerups = 3, powerupGap = 0.5 },
		westfall = { name = "Defias loot: more coins and gems", loot = 2.5, gemChance = 0.08 },
		moonglade = { name = "Moonlight: jumps float", gravity = 22, jumpSpeed = 9.9, spacing = 1.3 },
		stormwind = { name = "Crowded streets: more joggers to knock", allianceChance = 0.9 },
		darnassus = { name = "Moonwell blessing: Thick Hide", shield = true },
		ironforge = { name = "Steam vents: keep out of the steam", ventChance = 0.45, ventExtra = 0.8, steam = true },
	},
	-- Escorts: in the Horde capitals, which have no boss, a boss due there is
	-- a leader instead (by zone key). They turn up as a boss would, run ahead
	-- beside the road for the rest of the zone and throw a gift into a lane
	-- every giftEvery seconds or so, in the gap after a chunk, with giftExtra
	-- seconds of clear road after it. The gifts take turns: a power-up's
	-- name, or "coins" for a short line of them (Tuning.escort). `name` is
	-- one of the famous faces in Assets.joggers, whose model they use.
	escorts = {
		thunderbluff = { name = "Cairne Bloodhoof", gifts = { "stampede", "coins" }, giftEvery = 6, giftExtra = 1.0 },
		orgrimmar = { name = "Thrall", gifts = { "goldRush", "coins" }, giftEvery = 6, giftExtra = 1.0 },
		undercity = { name = "Sylvanas Windrunner", gifts = { "shield", "coins" }, giftEvery = 6, giftExtra = 1.0 },
	},
	-- Wisps: one `lead` seconds before each row on the way, unless something
	-- solid stands in that lane within `clear` seconds of the spot.
	wisps = { lead = 0.3, clear = 0.35 },
	-- Escorts: where one runs, in yards ahead (near enough to see without the
	-- boss camera), and a gift of coins: how many, and the seconds between them.
	-- A gift is thrown from no further than the escort, and the first lands no
	-- sooner than `lead` seconds after they turn up.
	escort = { distance = 24, coins = 4, coinSpacing = 0.18, lead = 2.5 },

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

	-- Orc runs (see Data/OrcRun.lua). The orc runs at the zone-1 speed all run.
	-- Tauren come up from behind `taurenLead` yards a second faster at first,
	-- and speed up on the normal speed curve (a rise through each zone and a
	-- step up on each new one), so they get harder to dodge.
	orcRun = {
		taurenLead = 5,
		-- A Tauren appears this far back (the bottom of the pulled-back view) and
		-- is gone this far ahead. Coins left behind go at despawnBehind.
		spawnBehind = 20,
		despawnAhead = 45,
		despawnBehind = -30,
		-- Seconds to the first Tauren drawing level with you.
		firstRow = 4,
		-- Seconds between rows of Tauren, shrinking each zone to rowGapMin.
		rowGapStart = 1.8,
		rowGapPerZone = 0.12,
		rowGapMin = 0.8,
		-- From zone pairFrom, the chance of two Tauren in a row (never three),
		-- growing each zone up to pairMax.
		pairFrom = 2,
		pairChance = 0.2,
		pairPerZone = 0.08,
		pairMax = 0.6,
		-- Coin lines from ahead: one every coinGap seconds (a random time in the
		-- range), coinCount long, sometimes ending in a gem.
		coinGap = { 2.5, 4.5 },
		coinCount = 5,
		coinSpacing = 0.22,
		gemChance = 0.15,
	},
}
