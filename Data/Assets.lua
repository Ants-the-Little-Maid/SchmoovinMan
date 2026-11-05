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
	-- Generic Tauren male (race 6, body type 1) NPC appearances, then the bare models.
	runner = {
		{ displayID = 45379 }, -- "Tauren Male"
		{ displayID = 43012 }, -- "Tauren 01"
		{ displayID = 43611 }, -- "Tauren"
		{ displayID = 2141 }, -- Orgrimmar Brave (older appearance)
		{ fileID = 968705 }, -- character/tauren/male/taurenmale_hd.m2
		{ fileID = 122055 }, -- character/tauren/male/taurenmale.m2
	},
	runnerHeight = 2.6,

	-- Joggers beside the road: generic Horde NPC appearances, body types 1 and 2.
	-- Skyborne was asked for but isn't in the game data, so female Tauren stand in.
	-- Each jogger picks one list; the rest of that list are its backups. `race`
	-- picks the lines: Tauren joggers greet you in their own words.
	joggers = {
		{ race = "orc", { displayID = 4259 }, { displayID = 4032 }, { displayID = 3743 } }, -- body type 1 (Orgrimmar Grunt)
		{ race = "orc", { displayID = 4260 }, { displayID = 5706 }, { displayID = 4601 } }, -- body type 2 (Orgrimmar Grunt, Onlooker)
		{ race = "troll", { displayID = 4622 }, { displayID = 11109 }, { displayID = 7037 } }, -- body type 1 (Skullsplitter Thug)
		{ race = "troll", { displayID = 31738 }, { displayID = 4241 }, { displayID = 4782 } }, -- body type 2 (Sen'jin Guardian)
		{ race = "tauren", { displayID = 2141 }, { displayID = 4262 }, { displayID = 11774 } }, -- body type 1 (Orgrimmar Brave)
		{ race = "tauren", { displayID = 8572 }, { displayID = 11775 }, { displayID = 9392 } }, -- body type 2 (Orgrimmar Brave)
	},
	joggerHeight = 2.3,
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
		coin = {
			{ fileID = 200137, size = 0.75 }, -- world/generic/passivedoodads/treasurepiles/goldpilesmall01.m2
			{ fileID = 953606, size = 0.75 }, -- goldpilesmall01_nocollide.m2
			{ fileID = 916363, size = 0.75 }, -- spells/treasuregoblin_coinpile.m2
		},
		gem = {
			{ fileID = 202443, size = 1.0 }, -- kalimdor/silithus/passivedoodads/crystals/floatingpurplecrystal01.m2
			{ fileID = 202748, size = 1.0 }, -- kalimdor/ungoro/passivedoodads/crystals/ungorocrystal_blue01.m2
		},
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
	},

	-- SOUNDKIT names; missing ones are skipped.
	sounds = {
		coin = "LOOT_WINDOW_COIN_SOUND",
		gem = "IG_BACKPACK_COIN_SELECT",
		powerup = "IG_QUEST_LIST_COMPLETE",
		zone = "PVP_THROUGH_QUEUE",
		crash = "IG_QUEST_LOG_ABANDON_QUEST",
		shieldBreak = "UI_RAID_BOSS_WHISPER_WARNING",
		newBest = "LFG_REWARDS",
		start = "UI_PET_BATTLE_START",
		click = "U_CHAT_SCROLL_BUTTON",
	},
}
