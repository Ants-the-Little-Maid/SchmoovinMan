local _, ns = ...

--[[ Models, animations and sounds that aren't tied to a zone.

Sources, looked up 2026-11-06:
  File IDs: wowdev/wow-listfile release 202611050009 (community-listfile.csv).
  Display IDs: wago.tools CreatureDisplayInfo, CreatureDisplayInfoExtra,
    CreatureModelData and Creature tables (latest build).
  Animation IDs: wowdev.wiki M2/AnimationList.
  Sound kits: Blizzard_SharedXML/Mainline/SoundKitConstants.lua at
    Gethe/wow-ui-source forever@eac30af5 (1.60.1.70790).

Every list is tried in order: if a model doesn't load in the Forever client,
the renderer moves to the next one. A candidate is { displayID = n } or
{ fileID = n }. Models are scaled from their bounding box to `height`
(yards), so only the ID matters.
]]

ns.Assets = {
	-- Generic Tauren male (race 6, body type 1): a Classic NPC appearance, then
	-- the bare models. Later "Tauren Male" displays (45379, 43012, 43611) aren't
	-- in Forever.
	runner = {
		{ displayID = 2141 }, -- Orgrimmar Brave
		{ fileID = 968705 }, -- character/tauren/male/taurenmale_hd.m2
		{ fileID = 122055 }, -- character/tauren/male/taurenmale.m2
	},
	runnerHeight = 2.6,
	-- Orc runs (Data/OrcRun.lua): the runner is an orc, the Orgrimmar Grunt
	-- appearances the orc joggers use.
	orcRunner = {
		{ displayID = 4259 },
		{ displayID = 4032 },
		{ displayID = 3743 },
	},
	-- Orc runs for a player whose own character is an orc: their own look
	-- (hair, colour, face), undressed and put in the orc warlock's starting
	-- clothes, head bare. Item IDs per slot, tried in order: the Classic
	-- robe, then the later orc and human ones. (Warcraft Wiki, 2026-11-09.)
	orcPlayerDress = {
		{ 6129, 52543, 57 }, -- Acolyte's Robe
		{ 1396, 52679 }, -- Acolyte's Pants
		{ 59 }, -- Acolyte's Shoes
	},

	-- Joggers beside the road: generic Horde NPC appearances, body types 1 and 2.
	-- Skyborne was asked for but isn't in the game data, so female Tauren stand in.
	-- Each jogger picks one list; the rest of that list are its backups. `race`
	-- picks the lines: Tauren joggers greet you in their own words. `weight`
	-- (default 1) sets how often a list is picked: Tauren look like the runner
	-- and stand out, so they come up about one jogger in six.
	-- Famous Horde faces (Classic displays, from Wowhead's Classic NPC pages)
	-- are rarer still. They have their own `lines` for the runner to say and
	-- `replies` they answer with; if their model is missing, a generic jogger of
	-- the same race stands in.
	joggers = {
		{ race = "orc", { displayID = 4259 }, { displayID = 4032 }, { displayID = 3743 } }, -- body type 1 (Orgrimmar Grunt)
		{ race = "orc", { displayID = 4260 }, { displayID = 5706 }, { displayID = 4601 } }, -- body type 2 (Orgrimmar Grunt, Onlooker)
		{ race = "troll", { displayID = 4622 }, { displayID = 11109 }, { displayID = 7037 } }, -- body type 1 (Skullsplitter Thug)
		{ race = "troll", { displayID = 4241 }, { displayID = 4782 } }, -- body type 2 (Classic displays; 31738 is later and missing in Forever)
		{ race = "tauren", weight = 0.4, { displayID = 2141 }, { displayID = 4262 }, { displayID = 11774 } }, -- body type 1 (Orgrimmar Brave)
		{ race = "tauren", weight = 0.4, { displayID = 8572 }, { displayID = 11775 }, { displayID = 9392 } }, -- body type 2 (Orgrimmar Brave)

		{
			name = "Thrall", race = "orc", weight = 0.12, { displayID = 4527 }, { displayID = 4259 },
			lines = { "Morning, Warchief!", "Race you to the Barrens, Thrall!" },
			replies = { "Keep schmoovin', Tauren.", "For the Horde... and for cardio!" },
		},
		{
			name = "Cairne Bloodhoof", race = "tauren", weight = 0.06, { displayID = 4307 }, { displayID = 2141 },
			lines = { "Hey Schmoover! Oh, it's you, Chief!", "Lookin' schmoove, High Chieftain!" },
			replies = { "My hooves aren't what they used to be.", "The Earth Mother made you for this." },
		},
		{
			name = "Vol'jin", race = "troll", weight = 0.12, { displayID = 10357 }, { displayID = 4622 },
			lines = { "Ey mon, keep up!", "Coming through, Vol'jin!" },
			replies = { "Dis one got da schmooves, mon.", "Slow down, ya crazy cow!" },
		},
		{
			name = "Sylvanas Windrunner", race = "undead", weight = 0.12, { displayID = 11657 }, { displayID = 4259 },
			lines = { "Lovely day for a jog, Dark Lady!", "On your left, Banshee Queen!" },
			replies = { "...Fine. That was fast.", "I was letting you win." },
		},
		{
			name = "Varimathras", race = "demon", weight = 0.12, { displayID = 11658 }, { displayID = 4259 },
			lines = { "Is that a dreadlord... jogging?", "Nice wings. Shame about the pace." },
			replies = { "I am doing this ironically.", "You will regret that overtake." },
		},
		{
			name = "Eitrigg", race = "orc", weight = 0.12, { displayID = 1619 }, { displayID = 4259 },
			lines = { "On your left, old timer!", "Keep at it, Eitrigg!" },
			replies = { "Back in my day, we walked.", "Bah! Youth." },
		},
		{
			name = "Magatha Grimtotem", race = "tauren", weight = 0.06, { displayID = 4510 }, { displayID = 8572 },
			lines = { "Lookin' schmoove, Elder!", "Morning, Magatha!" },
			replies = { "Hmph. Show-off.", "Enjoy it while it lasts." },
		},
		{
			name = "Hamuul Runetotem", race = "tauren", weight = 0.06, { displayID = 4519 }, { displayID = 2141 },
			lines = { "Schmoove on, Arch Druid!", "Try cat form, Hamuul!" },
			replies = { "The Earth Mother smiles on your stride.", "Such balance! Such schmoove!" },
		},
		{
			name = "Drek'Thar", race = "orc", weight = 0.12, { displayID = 11894 }, { displayID = 4259 },
			lines = { "Coming through, Drek'Thar!", "Mind the hooves, Elder!" },
			replies = { "I heard you coming a mile away.", "The spirits say you're showing off." },
		},
		{
			name = "High Overlord Saurfang", race = "orc", weight = 0.12, { displayID = 14732 }, { displayID = 4260 },
			lines = { "Out of the way, High Overlord!", "Can't stop, Saurfang!" },
			replies = { "Hah! Not bad, calf.", "Run, then. Run!" },
		},
	},
	joggerHeight = 2.3,

	-- Alliance joggers on the track itself. They jog away from you in a lane,
	-- slower than you; run into one to knock them flying for bonus points (see
	-- Tuning.alliance). They never end a run. Classic displays, from Wowhead's
	-- Classic NPC pages: civilians and adventurers, not guards, so they don't
	-- look like the city guards that charge at you.
	alliance = {
		{ { displayID = 3278 }, { displayID = 2677 } }, -- human (Godric Rothgar, Menethil Sentry)
		{ { displayID = 2677 }, { displayID = 3278 } }, -- human (Menethil Sentry)
		{ { displayID = 4950 }, { displayID = 5648 } }, -- dwarf (Tormus Deepforge)
		{ { displayID = 5648 }, { displayID = 4950 } }, -- dwarf (Onin MacHammar)
		{ { displayID = 4864 }, { displayID = 3278 } }, -- gnome (Tog Rustsprocket)
		{ { displayID = 2306 }, { displayID = 3278 } }, -- night elf (Darnassus Sentinel)
	},
	-- Joggers run at this share of your speed, so you overtake them.
	joggerSpeed = 0.45,

	-- What's said on overtaking a jogger. Orcs and trolls get the runner's
	-- `general` or side lines (the side lines match the jogger's side). Fellow
	-- Tauren get an exchange instead: the runner compliments them with a
	-- `toTauren` line, then they answer with a `taurenReply` line over their head.
	-- These two lists are only ever used with Tauren joggers.
	quips = {
		passLeft = "On your left!",
		passRight = "On your right!",
		general = {
			"OUTTA MY WAY I GOTTA SCHMOOVE",
			"Looks like someone *isn't* schmooving",
			"Schmoove it or lose it!",
			"Coming through!",
			"Can't stop, won't stop!",
			"Is that a jog or a nap?",
			"Keep up!",
			"Beep beep!",
			"Looks like someone can't schmoove",
			"Sorry I can't hear you, I'm already too far away",
			"I can't hear you! Sound can't schmoove like this",
			"I got the schmooves, I got the schmooves",
		},
		toTauren = {
			"Hey Schmoover!",
			"Lookin' schmoove!",
			"Ooooooh he's schmoovin'",
			"Schmoove on, brother!",
		},
		taurenReply = {
			"SCHMOOVIN GOOD!",
			"Wow! He's schmoovin",
			"Oh he's schmoove",
			"Could it be? The Schmoover!?",
			"Earth Mother, look at him go!",
		},
		-- Said on knocking an Alliance jogger out of your lane.
		knock = {
			"Excuse me!",
			"Pardon my hooves!",
			"Should've schmooved!",
			"Nothing personal, just schmoovin'!",
			"Moo-ve!",
			"STRIKE!",
			"You were in my lane!",
			"Watch the horns!",
			"Schmoove or be schmooved!",
			"Sorry! Not sorry!",
		},
		-- Said when a boss turns up, and when it's driven off or gives up.
		bossStart = {
			"You picked the wrong road!",
			"Out of my way, I've got schmoovin' to do!",
			"Bring it on!",
			"Not today!",
		},
		bossDriven = {
			"And stay out!",
			"Schmooved!",
			"That's what I thought!",
			"Don't come back!",
		},
		bossSurvived = {
			"Can't catch what you can't schmoove!",
			"Too schmoove for you!",
			"Giving up already?",
		},
		-- Orc runs: what a Tauren yells as it passes the orc. Half the time the
		-- side it passes on, then "... Again" if the last side line was on the
		-- same side; otherwise a taurenToOrc line. The orc answers with an
		-- orcRun line (pants and complaints), now and then.
		passLeftAgain = "On your left... Again",
		passRightAgain = "On your right... Again",
		taurenToOrc = {
			"Schmoove over candle man",
			"Candles can't schmoove",
			"I take that candle",
		},
		orcRun = {
			"*pant* *pant*",
			"Can't... keep... up...",
			"How are you all so FAST?",
			"Wait for me!",
			"I'm schmoovin' as fast as I can!",
			"SCHMOOVING AINT IN MY DNA",
			"I can't schmoove! I can barely walk!",
			"My legs... are on fire...",
			"I wish... I could... Schmoo...veee",
		},
		-- Seconds after one of the orc's complaints before the next can come.
		complaintGap = 2.5,
		-- Seconds between the runner's compliment and the Tauren's reply.
		replyDelay = 0.9,
		-- Chance of a side line rather than a general one.
		sideChance = 0.5,
		-- Seconds a bubble stays up, and the quiet gap before the next one.
		duration = 2.2,
		gap = 0.6,
	},

	windRider = {
		{ displayID = 295 }, -- creature/wyvern/wyvern.m2
		{ displayID = 2154 },
		{ displayID = 29310 }, -- "Wind Rider"
	},
	windRiderLength = 5,

	tokens = {
		-- name: shown in the Options model picker. backupOnly: a copy that
		-- looks the same, kept as a backup but not offered there.
		coin = {
			{ fileID = 200137, size = 0.75, name = "Gold pile" }, -- world/generic/passivedoodads/treasurepiles/goldpilesmall01.m2
			{ fileID = 953606, size = 0.75, name = "Gold pile", backupOnly = true }, -- goldpilesmall01_nocollide.m2
			{ fileID = 916363, size = 0.75, name = "Coin pile" }, -- spells/treasuregoblin_coinpile.m2
		},
		gem = {
			{ fileID = 202443, size = 1.0, name = "Purple crystal" }, -- kalimdor/silithus/passivedoodads/crystals/floatingpurplecrystal01.m2
			{ fileID = 202748, size = 1.0, name = "Blue crystal (Magnet)" }, -- kalimdor/ungoro/passivedoodads/crystals/ungorocrystal_blue01.m2
		},
	},

	-- Boss fights only: grab one and it's thrown at the boss.
	spear = {
		{ fileID = 200611, size = 1.8 }, -- generic/tauren/passive doodads/weapons/tauren_weaponspear.m2
		{ fileID = 199436, size = 1.8 }, -- generic/orc/passive doodads/weapons/orcspear01.m2
		{ fileID = 200237, size = 1.8 }, -- generic/passivedoodads/weapons/steelspear01.m2
	},

	-- Power-up pickups: each a different, easy-to-spot object.
	powerups = {
		windRider = {
			{ fileID = 202737, size = 1.0 }, -- thousandneedles/passivedoodads/wyverneggs/wyverneggs01.m2
			{ fileID = 202738, size = 1.0 },
		},
		magnet = {
			{ fileID = 202748, size = 1.0 }, -- ungorocrystal_blue01.m2
			{ fileID = 202749, size = 1.0 },
		},
		shield = {
			{ fileID = 202750, size = 1.0 }, -- ungorocrystal_green01.m2
			{ fileID = 202751, size = 1.0 },
		},
		goldRush = {
			{ fileID = 202754, size = 1.0 }, -- ungorocrystal_yellow01.m2
			{ fileID = 200136, size = 0.9 }, -- goldpilemedium01.m2
		},
		stampede = {
			{ fileID = 202752, size = 1.0 }, -- ungorocrystal_red01.m2
			{ fileID = 202753, size = 1.0 },
		},
	},

	-- Animation IDs (AnimationData). Each list is tried until the model has one;
	-- the client falls back on its own when a model lacks an animation.
	anims = {
		stand = { 0 },
		run = { 5 },
		sprint = { 143, 5 },
		jumpStart = { 37 },
		jump = { 38 },
		jumpEnd = { 187, 39 }, -- JumpLandRun, JumpEnd
		fall = { 40 },
		duck = { 223, 119, 120 }, -- StealthRun, StealthWalk, StealthStand
		death = { 1 },
		dead = { 6 },
		mount = { 91 },
		cheer = { 68 },
		creatureRun = { 5 },
		windRiderFly = { 135, 556, 5 }, -- Fly, MountFlightRun, Run
		-- Bosses back away from you up the road, throw, flinch when a spear hits
		-- and run off at the end.
		bossBack = { 13 }, -- Walkbackwards (falls back to Walk)
		bossThrow = { 107 }, -- an attack (falls back to AttackUnarmed)
		bossHit = { 9 }, -- CombatWound
		bossFlee = { 5 }, -- Run
	},

	-- Orc runs: the candle that marks their scores (the first is used).
	icons = {
		candle = { "Interface\\Icons\\INV_Misc_Candle_01", "Interface\\Icons\\INV_Misc_Candle_02", "Interface\\Icons\\INV_Misc_Candle_03" },
	},

	-- SOUNDKIT names; missing ones are skipped.
	sounds = {
		coin = "LOOT_WINDOW_COIN_SOUND",
		gem = "IG_BACKPACK_COIN_SELECT",
		powerup = "IG_QUEST_LIST_COMPLETE",
		zone = "PVP_THROUGH_QUEUE",
		crash = "IG_QUEST_LOG_ABANDON_QUEST",
		shieldBreak = "UI_RAID_BOSS_WHISPER_WARNING",
		knock = "UI_GARRISON_ARCHITECT_TABLE_BUILDING_PLACEMENT",
		newBest = "LFG_REWARDS",
		start = "UI_PET_BATTLE_START",
		click = "U_CHAT_SCROLL_BUTTON",
		bossStart = "RAID_WARNING",
		spear = "UI_QUEST_ROLLING_FORWARD_01",
		bossDriven = "UI_EPICLOOT_TOAST",
		bossSurvived = "UI_WORLDQUEST_COMPLETE",
	},
}

-- Orc runs for an orc player: their own character first (unit = a model
-- copied from that unit, then put in `dress`), the generic orcs as backups.
ns.Assets.orcPlayerRunner = { { unit = "player", dress = ns.Assets.orcPlayerDress } }
for _, candidate in ipairs(ns.Assets.orcRunner) do
	ns.Assets.orcPlayerRunner[#ns.Assets.orcPlayerRunner + 1] = candidate
end

-- Orc runs: the Tauren that stream past the orc are the generic Tauren
-- joggers (both body types), each list with its backups.
ns.Assets.stampede = {}
for _, list in ipairs(ns.Assets.joggers) do
	if list.race == "tauren" and not list.name then
		ns.Assets.stampede[#ns.Assets.stampede + 1] = list
	end
end
