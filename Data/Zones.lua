local _, ns = ...

--[[ The run's zones. Mulgore is always first; the rest come in a random order.
Westfall, Moonglade and the six capitals were added in 0.9.0, with Classic
tilesets and props like the rest.

Sources as in Data/Assets.lua (listfile 202611050009, wago.tools tables).
Original-world (Classic) doodads and tilesets are used throughout, as they're
the likeliest to ship with Forever.

ground / road: terrain tileset file IDs, drawn as tiled UI textures. If one
  can't be drawn, the flat groundColor / roadColor shows instead.
sky = { top, bottom }, fog = { color, near, far }, light = { ambient, diffuse }
scenery: roadside models, each scaled to `height` yards.
obstacles: model lists per role (low, high, block, wall), each scaled to the
  role's size. charger: creature displays that run at you.
boss: the zone's boss (see Tuning.boss): name, height in yards, and models,
  the boss's Forever display (from Wowhead's Forever NPC pages, 2026-11-08)
  then a backup. Thunder Bluff, Orgrimmar and Undercity have none for now, so
  a boss due there waits for the next zone that has one.
Colours are { r, g, b } from 0 to 1.
]]

local function C(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

-- Shared fallbacks used when a zone's own models don't load.
local GENERIC = {
	low = {
		{ fileID = 199632, name = "Crate" }, -- generic/passivedoodads/crate01/crate01.m2
		{ fileID = 199652, name = "Dead log" }, -- deadtreelogs/deadtreelog01.m2
	},
	high = {
		{ fileID = 199209, name = "Orc fence" }, -- generic/orc/passive doodads/orcfence/orcfence.m2
	},
	block = {
		{ fileID = 199563, name = "Barrel" }, -- generic/passivedoodads/barrel/barrel01.m2
		{ fileID = 199634, name = "Big crate" }, -- crate02.m2
	},
	wall = {
		{ fileID = 199634, name = "Big crate" }, -- crate02.m2
	},
}
ns.GenericObstacles = GENERIC

-- Accessibility: brighter, easy-to-spot Classic props offered in Options as
-- extra choices for any zone, on top of the zone's own models and the shared
-- ones above. Never used unless picked. (Listfile via wago.tools, 2026-11-09.)
ns.ExtraModels = {
	low = {
		{ fileID = 197464, name = "Powder keg with fuse" }, -- generic/dwarf/passive doodads/powderkegs/powderkegfused.m2
	},
	high = {
		{ fileID = 204080, name = "Tirisfal barricade" }, -- lordaeron/tirisfalglade/passivedoodads/barricade/tirisfallbarricade.m2
	},
	block = {
		{ fileID = 197463, name = "Powder keg" }, -- generic/dwarf/passive doodads/powderkegs/powderkeg01.m2
		{ fileID = 198004, name = "Beer keg" }, -- generic/human/passive doodads/beerkegs/beerkeg01.m2
	},
	wall = {
		{ fileID = 204080, name = "Tirisfal barricade" }, -- tirisfallbarricade.m2
	},
	coin = {
		{ fileID = 200135, size = 0.75, name = "Large gold pile" }, -- generic/passivedoodads/treasurepiles/goldpilelarge01.m2
	},
	gem = {
		{ fileID = 201056, size = 1.0, name = "Red jewel" }, -- world/goober/g_jewelred.m2
		{ fileID = 201054, size = 1.0, name = "Blue jewel" }, -- world/goober/g_jewelblue.m2
		{ fileID = 203112, size = 1.0, name = "Museum gem" }, -- khazmodan/blackrock/passivedoodads/museumgem/museumgem01.m2
	},
}

ns.Zones = {
	{
		key = "mulgore",
		name = "Mulgore",
		ground = 188654, -- tileset/mullgore/mullgorebasegrass.blp
		-- Smooth pale stone: calmer than the pebbled road01, so hazards and coins read.
		road = 188666, -- tileset/mullgore/mullgorerocksolid.blp
		groundColor = C("6f8a3c"),
		-- Darkens the grass so the road, hazards and coins stand out.
		groundTint = { 0.62, 0.66, 0.58 },
		roadColor = C("c8a888"),
		sky = { top = C("5b8fc9"), bottom = C("e8d7a8") },
		fog = { color = C("e8d7a8"), near = 45, far = 85 },
		light = { ambient = C("b0a890"), diffuse = C("fff2d8") },
		scenery = {
			{ fileID = 202322, height = 9 }, -- kalimdor/mulgore/passivedoodads/trees/mullgoretree01.m2
			{ fileID = 202323, height = 8 }, -- mullgoretree02.m2
			{ fileID = 200577, height = 4 }, -- generic/tauren/passive doodads/totems/taurentotem01.m2
			{ fileID = 200581, height = 4 }, -- taurentotem05.m2
			{ fileID = 200613, height = 3 }, -- tauren windbreak01.m2
			{ fileID = 202300, height = 3 }, -- mullgorerock01.m2
			{ fileID = 200426, height = 3.5 }, -- taurenlamppost.m2
		},
		obstacles = {
			low = { { fileID = 202305, name = "Thorn bush" }, { fileID = 200372, name = "Large basket" } }, -- mullgorethorn01, largebasket01
			high = { { fileID = 200596, name = "War harness" }, { fileID = 200614, name = "Windbreak" } }, -- warharnesswall01, windbreak02
			block = { { fileID = 200578, name = "Tauren totem" }, { fileID = 202301, name = "Rock" } }, -- taurentotem02, mullgorerock02
			wall = { { fileID = 200615, name = "Windbreak" }, { fileID = 202292, name = "Burned wagon" } }, -- windbreak03, burnedgypsywagon01
		},
		charger = { { displayID = 1230, name = "Kodo" }, { displayID = 179, name = "Kodo (brown)" }, { displayID = 38, name = "Tallstrider" } }, -- kodo, kodo, tallstrider
	},
	{
		key = "barrens",
		name = "The Barrens",
		ground = 186908, -- tileset/barrens/barrensbasegrassgold.blp
		road = 186917, -- barrensroad01.blp
		groundColor = C("b39a55"),
		roadColor = C("a0805a"),
		sky = { top = C("6a9ad0"), bottom = C("f1dcae") },
		fog = { color = C("f1dcae"), near = 45, far = 85 },
		light = { ambient = C("c0aa88"), diffuse = C("fff0d0") },
		scenery = {
			{ fileID = 201394, height = 9 }, -- barrenstree01.m2
			{ fileID = 201398, height = 8 }, -- barrenstree03.m2
			{ fileID = 201383, height = 5 }, -- barrenstermitemound01.m2
			{ fileID = 201370, height = 2.5 }, -- barrensbush01.m2
			{ fileID = 201363, height = 4 }, -- kotobeastbone01.m2
			{ fileID = 201389, height = 5 }, -- raptorhut01.m2
		},
		obstacles = {
			low = { { fileID = 201371, name = "Bush" }, { fileID = 201375, name = "Kodo egg" } }, -- barrensbush02, kodoegg01
			high = { { fileID = 201364, name = "Kodo bones" }, { fileID = 201365, name = "Kodo ribs" } }, -- kotobeastbone02/03
			block = { { fileID = 201384, name = "Termite mound" }, { fileID = 201377, name = "Lamppost" } }, -- termite mound, lamppost
			wall = { { fileID = 201416, name = "Wagon" }, { fileID = 201413, name = "Busted wagon" } }, -- barrenswagon01, bustedwagon
		},
		charger = { { displayID = 1532, name = "Thunder lizard" }, { displayID = 180, name = "Raptor" } }, -- thunder lizard, raptor
		boss = { name = "Verog the Dervish", height = 4.3, models = { { displayID = 9446 }, { displayID = 1532 } } }, -- npc 3395
	},
	{
		key = "thousandneedles",
		name = "Thousand Needles",
		ground = 188929, -- tileset/thousandneedles/thousandneedlesdirt.blp
		road = 188944, -- thousandneedlessaltflats.blp
		groundColor = C("b8925a"),
		roadColor = C("d8c49a"),
		sky = { top = C("c98a4a"), bottom = C("f0d6a0") },
		fog = { color = C("f0d6a0"), near = 45, far = 85 },
		light = { ambient = C("c8a880"), diffuse = C("ffe8c0") },
		scenery = {
			{ fileID = 202716, height = 14 }, -- thousandrock01.m2
			{ fileID = 202718, height = 12 }, -- thousandrock02.m2
			{ fileID = 202719, height = 10 }, -- thousandrock03.m2
			{ fileID = 202709, height = 4 }, -- racingflag01.m2
			{ fileID = 202690, height = 5 }, -- gnomebleachers.m2
		},
		obstacles = {
			low = { { fileID = 202695, name = "Hay bale" }, { fileID = 202710, name = "Salt flat rock" } }, -- haybail straightaway01, saltflatrock_01
			high = { { fileID = 202693, name = "Bridge" }, { fileID = 202696, name = "Hay bale bar" } }, -- bridge, haybail straightaway02
			block = { { fileID = 202711, name = "Salt flat boulder" }, { fileID = 202733, name = "Snake nest" } }, -- saltflatrock_02, snake nest
			wall = { { fileID = 202694, name = "Hay bale stop" }, { fileID = 202697, name = "Hay bale wall" } }, -- haybail back-stop, straightaway03
		},
		charger = { { displayID = 1308, name = "Kodo" }, { displayID = 322, name = "Raptor" } }, -- kodo, raptor
		boss = { name = "Arnak Grimtotem", height = 4.1, models = { { displayID = 10243 }, { displayID = 1308 } } }, -- npc 10896
	},
	{
		key = "ashenvale",
		name = "Ashenvale",
		ground = 186832, -- tileset/ashenvale/ashenvalegrass.blp
		road = 186838, -- ashenvaleroad.blp
		groundColor = C("2f4a2c"),
		roadColor = C("5a4a38"),
		sky = { top = C("24324d"), bottom = C("6f8fa0") },
		fog = { color = C("6f8fa0"), near = 35, far = 75 },
		light = { ambient = C("7088a0"), diffuse = C("c8d8e8") },
		scenery = {
			{ fileID = 201223, height = 16 }, -- ashenvaletree01.m2
			{ fileID = 201224, height = 15 }, -- ashenvaletree02.m2
			{ fileID = 201226, height = 14 }, -- ashenvaletree03.m2
			{ fileID = 201238, height = 6 }, -- ruinssatyrpillar01.m2
			{ fileID = 201264, height = 4 }, -- dryadshrine01.m2
			{ fileID = 201195, height = 3 }, -- ashenvalerock01.m2
		},
		obstacles = {
			low = { { fileID = 201217, name = "Log" }, { fileID = 201208, name = "Stump" } }, -- treelog01, stump01
			high = { { fileID = 201236, name = "Satyr arch" }, { fileID = 201218, name = "Fallen log" } }, -- satyr arch, treelog02
			block = { { fileID = 201252, name = "Satyr totem" }, { fileID = 201211, name = "Tree stump" } }, -- satyr totem, tree stump
			wall = { { fileID = 201246, name = "Satyr ruin wall" }, { fileID = 201247, name = "Satyr ruin" } }, -- satyr ruin walls
		},
		charger = { { displayID = 1917, name = "Stag" }, { displayID = 706, name = "Bear" }, { displayID = 145, name = "Furbolg" } }, -- stag, bear, furbolg
		boss = { name = "Ursangous", height = 4.3, models = { { displayID = 2281 }, { displayID = 706 } } }, -- npc 12678
	},
	{
		key = "burningsteppes",
		name = "Burning Steppes",
		ground = 186933, -- tileset/burningstepps/burningsteppsash01.blp
		road = 186940, -- burningsteppscharcoal01.blp
		groundColor = C("3a2a24"),
		roadColor = C("1f1814"),
		sky = { top = C("2a0e08"), bottom = C("b0482a") },
		fog = { color = C("8a3a22"), near = 35, far = 75 },
		light = { ambient = C("a05a40"), diffuse = C("ffb080") },
		scenery = {
			{ fileID = 189253, height = 10 }, -- ashtree01.m2
			{ fileID = 189254, height = 9 }, -- ashtree02.m2
			{ fileID = 189158, height = 8 }, -- lavapillar01.m2
			{ fileID = 189270, height = 4 }, -- volcanicventlarge01.m2
			{ fileID = 189127, height = 12 }, -- cliffrock01.m2
			{ fileID = 189118, height = 3 }, -- orcbonfire.m2
		},
		obstacles = {
			low = { { fileID = 189218, name = "Lava rock" }, { fileID = 189226, name = "Burned beam" } }, -- lavarock01, burnedbeam
			high = { { fileID = 189135, name = "Fence" }, { fileID = 189124, name = "Rope bridge" } }, -- fence, rope bridge
			block = { { fileID = 189212, name = "Boulders" }, { fileID = 189236, name = "Stone block" } }, -- boulders01, stoneblock01
			wall = { { fileID = 189213, name = "Boulder pile" }, { fileID = 189135, name = "Fence" } }, -- boulders02, fence
		},
		charger = { { displayID = 1070, name = "Fire elemental" }, { displayID = 10193, name = "Core hound" } }, -- fire elemental, core hound
		boss = { name = "Volchan", height = 5.4, models = { { displayID = 12232 }, { displayID = 1070 } } }, -- npc 10119
	},
	{
		key = "silithus",
		name = "Silithus",
		ground = 188779, -- tileset/silithis/silithissand01.blp
		road = 188781, -- silithissanddetail.blp
		groundColor = C("c8a868"),
		roadColor = C("a88850"),
		sky = { top = C("8a6a40"), bottom = C("e8c88a") },
		fog = { color = C("e0c080"), near = 35, far = 75 },
		light = { ambient = C("c0a070"), diffuse = C("ffe0a0") },
		scenery = {
			{ fileID = 202483, height = 10 }, -- silithus_crystal_spike_01.m2
			{ fileID = 202471, height = 8 }, -- silithus_crystal_formation_01.m2
			{ fileID = 202515, height = 6 }, -- smallhive01.m2
			{ fileID = 202569, height = 8 }, -- silithusruinsobelisk01.m2
			{ fileID = 202553, height = 9 }, -- quirajpillar.m2
		},
		obstacles = {
			low = { { fileID = 202490, name = "Silithid egg" }, { fileID = 202477, name = "Crystal nub" } }, -- silithid egg, crystal nub
			high = { { fileID = 202498, name = "Ruin arch" }, { fileID = 202587, name = "Wasp husk" } }, -- ruin arch, wasp husk
			block = { { fileID = 202534, name = "Silithid pod" }, { fileID = 202555, name = "Qiraji block" } }, -- silithus pod, quiraj ruin block
			wall = { { fileID = 202573, name = "Ruin wall" }, { fileID = 202565, name = "Qiraji wall" } }, -- ruins wall, quiraj wall
		},
		charger = { { displayID = 91, name = "Silithid tank" }, { displayID = 157, name = "Silithid" }, { displayID = 92, name = "Wasp" } }, -- silithid tank, silithid, wasp
		boss = { name = "Krellack", height = 4.1, models = { { displayID = 6068 }, { displayID = 91 } } }, -- npc 14476
	},
	{
		key = "ungoro",
		name = "Un'Goro Crater",
		ground = 188975, -- tileset/ungoro/ungoromossroot.blp
		road = 188974, -- ungorodirt.blp
		groundColor = C("3e5a24"),
		roadColor = C("6a5434"),
		sky = { top = C("4a7a6a"), bottom = C("c8d8a0") },
		fog = { color = C("a8c090"), near = 35, far = 75 },
		light = { ambient = C("90a880"), diffuse = C("f0ffd0") },
		scenery = {
			{ fileID = 202782, height = 14 }, -- ungorotreebite.m2
			{ fileID = 202783, height = 12 }, -- ungorotreebreak.m2
			{ fileID = 202759, height = 6 }, -- ungorocrystalpylon01.m2
			{ fileID = 202766, height = 3 }, -- ungorogeyser01.m2
			{ fileID = 202770, height = 4 }, -- ungororock06.m2
		},
		obstacles = {
			low = { { fileID = 202771, name = "Rock" }, { fileID = 366958, name = "Coconuts" } }, -- ungororock07, coconut bunch
			high = { { fileID = 202747, name = "Archway" }, { fileID = 202784, name = "Fallen tree" } }, -- ungoro archway, tree break 2
			block = { { fileID = 202772, name = "Boulder" }, { fileID = 202755, name = "Yellow crystal" } }, -- ungororock08, yellow crystal
			wall = { { fileID = 202773, name = "Rock wall" }, { fileID = 202774, name = "Rock slab" } }, -- ungororock09/10
		},
		charger = { { displayID = 5238, name = "Devilsaur" }, { displayID = 615, name = "Raptor" } }, -- devilsaur, raptor
		boss = { name = "King Mosh", height = 6, models = { { displayID = 5305 }, { displayID = 5238 } } }, -- npc 6584
	},
	{
		key = "winterspring",
		name = "Winterspring",
		ground = 189053, -- tileset/winterspring grove/winterspringsnowsolid.blp
		road = 189051, -- winterspringsnowripple.blp
		groundColor = C("e8eef4"),
		roadColor = C("b8c8d8"),
		sky = { top = C("6a88b0"), bottom = C("e0e8f0") },
		fog = { color = C("e0e8f0"), near = 30, far = 70 },
		light = { ambient = C("a8b8d0"), diffuse = C("f0f8ff") },
		scenery = {
			{ fileID = 202876, height = 14 }, -- winterspringtree01.m2
			{ fileID = 202877, height = 13 }, -- winterspringtree02.m2
			{ fileID = 202857, height = 12 }, -- newwinterspringtree01.m2
			{ fileID = 202845, height = 4 }, -- winterspringrock01.m2
			{ fileID = 202839, height = 5 }, -- furbolgtentsnow.m2
			{ fileID = 202841, height = 4 }, -- furbolgtotemsnow01.m2
		},
		obstacles = {
			low = { { fileID = 202872, name = "Fallen branch" }, { fileID = 202868, name = "Bush" } }, -- fallen branch, bush
			high = { { fileID = 202873, name = "Fallen tree" }, { fileID = 202884, name = "Giant root" } }, -- fallen tree, world tree root
			block = { { fileID = 202846, name = "Rock" }, { fileID = 202842, name = "Furbolg totem" } }, -- rock02, furbolg totem 2
			wall = { { fileID = 202847, name = "Rock wall" }, { fileID = 202874, name = "Fallen trunk" } }, -- rock03, fallen tree 2
		},
		charger = { { displayID = 10579, name = "Ice Thistle yeti" }, { displayID = 21601, name = "Yeti" }, { displayID = 10914, name = "Woolly kodo" }, { displayID = 161, name = "Wolf" } }, -- Ice Thistle Yeti, older yeti with other skins, wooly kodo, wolf
		boss = { name = "Rak'shiri", height = 3.4, models = { { displayID = 10054 }, { displayID = 10579 } } }, -- npc 10200
	},	{
		key = "westfall",
		name = "Westfall",
		ground = 188991, -- tileset/westwood/westfallgrassbase.blp
		road = 188989, -- westfalldirtbase.blp
		groundColor = C("a89a52"),
		roadColor = C("9a7a52"),
		sky = { top = C("7aa0d0"), bottom = C("f0e0b0") },
		fog = { color = C("e8d8a8"), near = 45, far = 85 },
		light = { ambient = C("c0b090"), diffuse = C("fff0d0") },
		scenery = {
			{ fileID = 190519, height = 12 }, -- azeroth/westfall/passivedoodads/westfallwindmill.m2
			{ fileID = 190508, height = 10 }, -- westfallgrainsilo01.m2
			{ fileID = 190638, height = 9 }, -- westfalltree01.m2
			{ fileID = 190629, height = 4 }, -- westfallscarecrow.m2
			{ fileID = 190597, height = 3 }, -- westfallhaystack01.m2
			{ fileID = 190612, height = 4 }, -- westfalllamppost.m2
		},
		obstacles = {
			low = { { fileID = 190598, name = "Haystack" }, { fileID = 190619, name = "Plow" } }, -- haystack02, plow
			high = { { fileID = 190659, name = "Fence" }, { fileID = 190620, name = "Rake cart" } }, -- westfallfence, rakecart
			block = { { fileID = 190623, name = "Boulder" }, { fileID = 190535, name = "Barrel" } }, -- boulder01, barrel01
			wall = { { fileID = 190599, name = "Hay wagon" }, { fileID = 190536, name = "Broken cart" } }, -- haywagon, brokencart
		},
		charger = { { displayID = 378, name = "Harvest Watcher" }, { displayID = 367, name = "Harvest Golem" } }, -- Harvest Watcher, Harvest Golem
		boss = { name = "Edwin VanCleef", height = 3.8, models = { { displayID = 2029 }, { displayID = 378 } } }, -- npc 639
	},
	{
		key = "moonglade",
		name = "Moonglade",
		ground = 188639, -- tileset/moonglade/moongladegrassbase.blp
		road = 188637, -- moongladedirtnograss.blp
		groundColor = C("3f6a3a"),
		roadColor = C("8a7a5a"),
		sky = { top = C("2a3a6a"), bottom = C("a8b8e0") },
		fog = { color = C("a0b0d8"), near = 40, far = 80 },
		light = { ambient = C("8a90b8"), diffuse = C("e0e8ff") },
		scenery = {
			{ fileID = 202271, height = 14 }, -- kalimdor/moonglade/passivedoodads/moongladetree01.m2
			{ fileID = 202272, height = 13 }, -- moongladetree02.m2
			{ fileID = 202273, height = 12 }, -- moongladetree03.m2
			{ fileID = 202258, height = 5 }, -- druidstone.m2
			{ fileID = 202261, height = 2.5 }, -- moongladebush01.m2
			{ fileID = 198780, height = 3.5 }, -- generic/nightelf/passive doodads/lanterns/nightelflantern01.m2
		},
		obstacles = {
			low = { { fileID = 202263, name = "Bush" }, { fileID = 202044, name = "Log" } }, -- moongladebush02, kalidartreelog01
			high = { { fileID = 202045, name = "Fallen log" }, { fileID = 198762, name = "Gazebo" } }, -- kalidartreelog02, kalidargazibo
			block = { { fileID = 202259, name = "Druid stone" }, { fileID = 198949, name = "Rune stone" } }, -- druidstonetopless, kalidarstonerune01
			wall = { { fileID = 198834, name = "Ruins" }, { fileID = 198835, name = "Ruined wall" } }, -- nightelfruins01/02
		},
		charger = { { displayID = 12236, name = "Moonkin" }, { displayID = 12238, name = "Owlbeast" }, { displayID = 1917, name = "Stag" } }, -- Moonkin Oracle, Vicious Owlbeast, stag
		boss = { name = "Omen", height = 6, models = { { displayID = 15879 }, { displayID = 12238 } } }, -- npc 15467
	},
	{
		key = "stormwind",
		name = "Stormwind City",
		ground = 187126, -- tileset/elwynn/elwynngrassbase.blp
		road = 187099, -- elwynncobblestonebase.blp
		groundColor = C("4f7a3a"),
		roadColor = C("a09a8a"),
		sky = { top = C("5f8fd0"), bottom = C("dce8f4") },
		fog = { color = C("d0dce8"), near = 45, far = 85 },
		light = { ambient = C("b0b8c0"), diffuse = C("fff8f0") },
		scenery = {
			{ fileID = 189629, height = 12 }, -- azeroth/elwynn/passivedoodads/humanguardtower.m2
			{ fileID = 198591, height = 12 }, -- generic/human/passive doodads/stormwind/stormwindnightelftree.m2
			{ fileID = 189927, height = 11 }, -- elwynntreecanopy01.m2
			{ fileID = 189908, height = 6 }, -- lionstatue.m2
			{ fileID = 197953, height = 5 }, -- allianceveteranbanner01.m2
			{ fileID = 189825, height = 4 }, -- lamppost.m2
		},
		obstacles = {
			low = { { fileID = 198158, name = "Grain crate" }, { fileID = 189810, name = "Haystack" } }, -- crategrain01, haystack01
			high = { { fileID = 189795, name = "Wooden fence" }, { fileID = 197851, name = "Garden arch" } }, -- elwynnwoodfence01, gardenarch
			block = { { fileID = 198004, name = "Beer keg" }, { fileID = 189956, name = "Water basin" } }, -- beerkeg01, waterbasin
			wall = { { fileID = 198288, name = "Wagon" }, { fileID = 189840, name = "Ruined catapult" } }, -- stormwindgypsywagon01, ruinedcatapult
		},
		charger = { { displayID = 3167, name = "City guard" }, { displayID = 3258, name = "Guard" } }, -- Stormwind City Guard, Stormwind Guard
		boss = { name = "Highlord Bolvar Fordragon", height = 4, models = { { displayID = 5566 }, { displayID = 3167 } } }, -- npc 1748
	},
	{
		key = "darnassus",
		name = "Darnassus",
		ground = 188595, -- tileset/kalidar/kalidarleaf.blp
		road = 188583, -- kalidardarnroad.blp
		groundColor = C("3a5a3a"),
		roadColor = C("8a8aa0"),
		sky = { top = C("304070"), bottom = C("90a0c8") },
		fog = { color = C("8090c0"), near = 40, far = 80 },
		light = { ambient = C("8088b0"), diffuse = C("d8e0ff") },
		scenery = {
			{ fileID = 202050, height = 16 }, -- kalimdor/kalidar/passivedoodads/kalidartrees/kalidartree01.m2
			{ fileID = 202051, height = 15 }, -- kalidartree02.m2
			{ fileID = 202052, height = 14 }, -- kalidartree03.m2
			{ fileID = 198945, height = 6 }, -- generic/nightelf/passive doodads/statues/statuenepriestess.m2
			{ fileID = 198770, height = 4 }, -- darnassusstreetlamp01.m2
			{ fileID = 198754, height = 3 }, -- elvenfountain.m2
		},
		obstacles = {
			low = { { fileID = 202022, name = "Bush" }, { fileID = 202059, name = "Tree stump" } }, -- kalidarbush02, kalidartreestump01
			high = { { fileID = 198761, name = "Moongate" }, { fileID = 202034, name = "Giant root" } }, -- kalidarmoongate, kalidargiantroot01
			block = { { fileID = 198936, name = "Wooden statue" }, { fileID = 198950, name = "Rune stone" } }, -- kalidarwoodstatue01, kalidarstonerune02
			wall = { { fileID = 198824, name = "Elf ruin" }, { fileID = 198825, name = "Elf ruin wall" } }, -- newelfruin01/02
		},
		charger = { { displayID = 6805, name = "Nightsaber" }, { displayID = 1917, name = "Stag" } }, -- Nightsaber, stag
		boss = { name = "Tyrande Whisperwind", height = 4, models = { { displayID = 7274 }, { displayID = 6805 } } }, -- npc 7999
	},
	{
		key = "ironforge",
		name = "Ironforge",
		ground = 188573, -- tileset/ironforge/ironforgesnow01solid.blp
		road = 188565, -- ironforgerock06road2.blp
		groundColor = C("e0e6ee"),
		roadColor = C("8a7a6a"),
		sky = { top = C("6a88b0"), bottom = C("e0e8f0") },
		fog = { color = C("d8e0ec"), near = 35, far = 75 },
		light = { ambient = C("a8b0c8"), diffuse = C("f0f4ff") },
		scenery = {
			{ fileID = 203255, height = 12 }, -- khazmodan/ironforge/passivedoodads/ironforgepine01.m2
			{ fileID = 203256, height = 11 }, -- ironforgepine02.m2
			{ fileID = 203221, height = 9 }, -- ironforgestatue_01.m2
			{ fileID = 203208, height = 8 }, -- snowytowerrock01.m2
			{ fileID = 203139, height = 5 }, -- dwarfbannerblue01.m2
			{ fileID = 203226, height = 4 }, -- ironforgesteamtank.m2
		},
		obstacles = {
			low = { { fileID = 203265, name = "Iron stump" }, { fileID = 197603, name = "Ale keg" } }, -- ironstump01, alekegsingle
			high = { { fileID = 203158, name = "Stone fence" }, { fileID = 203213, name = "Signpost" } }, -- dunmoroghstonefence01, ironforgesignpost
			block = { { fileID = 197238, name = "Dwarven barrel" }, { fileID = 197463, name = "Powder keg" } }, -- dwarvenbarrel01, powderkeg01
			wall = { { fileID = 203230, name = "Ruined steam tank" }, { fileID = 203159, name = "Stone wall" } }, -- ironforgesteamtankruined01, dunmoroghstonefence02
		},
		charger = { { displayID = 3524, name = "Ironforge guard" }, { displayID = 704, name = "Mountain boar" } }, -- Ironforge Guard, Mountain Boar
		boss = { name = "King Magni Bronzebeard", height = 3.6, models = { { displayID = 3597 }, { displayID = 3524 } } }, -- npc 2784
	},
	{
		key = "thunderbluff",
		name = "Thunder Bluff",
		ground = 188658, -- tileset/mullgore/mullgorebaserock01.blp
		road = 188662, -- mullgorecrackeddirt.blp
		groundColor = C("8a7a5a"),
		roadColor = C("b8a07a"),
		sky = { top = C("4f88d0"), bottom = C("f0dcb0") },
		fog = { color = C("e8d4a8"), near = 45, far = 85 },
		light = { ambient = C("b8a888"), diffuse = C("fff0d8") },
		scenery = {
			{ fileID = 202322, height = 9 }, -- kalimdor/mulgore/passivedoodads/trees/mullgoretree01.m2
			{ fileID = 200581, height = 5 }, -- generic/tauren/passive doodads/totems/taurentotem05.m2
			{ fileID = 200410, height = 5 }, -- kites/taurenkite01.m2
			{ fileID = 200397, height = 4 }, -- dreamcatchers/dreamcatcher01.m2
			{ fileID = 200401, height = 3 }, -- drums/taurendrumgiant01.m2
			{ fileID = 200406, height = 3 }, -- hitchingposts/taurenhitchingpost.m2
		},
		obstacles = {
			low = { { fileID = 200420, name = "Kodo skulls" }, { fileID = 200373, name = "Large basket" } }, -- kodoskulls01, largebasket02
			high = { { fileID = 200406, name = "Hitching post" }, { fileID = 200615, name = "Windbreak" } }, -- taurenhitchingpost, windbreak03
			block = { { fileID = 200409, name = "Kiln" }, { fileID = 200579, name = "Tauren totem" } }, -- taurenkiln01, taurentotem03
			wall = { { fileID = 200431, name = "Blue loom" }, { fileID = 199195, name = "Kodo wagon" } }, -- taurenloomblue, kodowagon
		},
		charger = { { displayID = 1220, name = "Plainstrider" }, { displayID = 1230, name = "Kodo" } }, -- Adult Plainstrider, kodo
	},
	{
		key = "orgrimmar",
		name = "Orgrimmar",
		ground = 187017, -- tileset/durotar/durotardirt.blp
		road = 187034, -- durotarroad.blp
		groundColor = C("a0603a"),
		roadColor = C("b08a5a"),
		sky = { top = C("b06a3a"), bottom = C("f0c890") },
		fog = { color = C("e8b880"), near = 40, far = 80 },
		light = { ambient = C("c0906a"), diffuse = C("ffd8b0") },
		scenery = {
			{ fileID = 201800, height = 9 }, -- kalimdor/durotar/passivedoodads/durotarpalm01.m2
			{ fileID = 199384, height = 6 }, -- generic/orc/passive doodads/tents/durotarorctent01.m2
			{ fileID = 199173, height = 5 }, -- hordebanners/hordebanner01.m2
			{ fileID = 199056, height = 5 }, -- banners/clanbanner.m2
			{ fileID = 199197, height = 4 }, -- lampposts/orcbrazierlamppost01.m2
			{ fileID = 202360, height = 3 }, -- kalimdor/orgrimmar/passivedoodads/orgrimmarbonfire01.m2
		},
		obstacles = {
			low = { { fileID = 199094, name = "Orc crate" }, { fileID = 199049, name = "Boar skull" } }, -- orccrate01, boarskull
			high = { { fileID = 199209, name = "Orc fence" }, { fileID = 199203, name = "Meat rack" } }, -- orcfence, rawmeatrack01
			block = { { fileID = 199090, name = "Orc barrel" }, { fileID = 199141, name = "Tall brazier" } }, -- orcbarrel01, tallbrazier01
			wall = { { fileID = 199414, name = "Orc wagon" }, { fileID = 199415, name = "Orc cart" } }, -- orcwagon01/02
		},
		charger = { { displayID = 381, name = "Dire Mottled Boar" }, { displayID = 193, name = "Elder Mottled Boar" } }, -- Dire Mottled Boar, Elder Mottled Boar
	},
	{
		key = "undercity",
		name = "Undercity",
		ground = 188950, -- tileset/tirisfall/tirisfalldirtrock02.blp
		road = 188963, -- tirisfallstoneroad01.blp
		groundColor = C("3a4a32"),
		roadColor = C("6a6a5a"),
		sky = { top = C("1a2018"), bottom = C("5a6a40") },
		fog = { color = C("4a5a38"), near = 30, far = 70 },
		light = { ambient = C("708060"), diffuse = C("b0c8a0") },
		scenery = {
			{ fileID = 200660, height = 12 }, -- generic/undead/passive doodads/lordaerontowers/undercitytower01.m2
			{ fileID = 200754, height = 7 }, -- statues/lordaeron_statue_01.m2
			{ fileID = 200664, height = 4 }, -- meatwagon/meatwagon.m2
			{ fileID = 200655, height = 3 }, -- lordaeronbrazier/lordaeronbrazier01.m2
			{ fileID = 200788, height = 3 }, -- undercity torches/undead_torch01.m2
			{ fileID = 204105, height = 2 }, -- lordaeron/tirisfalglade/passivedoodads/brillgraves01.m2
		},
		obstacles = {
			low = { { fileID = 204104, name = "Coffins" }, { fileID = 200672, name = "Wagon wheel" } }, -- brillcoffins, meatwagonwheel
			high = { { fileID = 200761, name = "Iron fence" }, { fileID = 204080, name = "Barricade" } }, -- undeadstonewroughtironfence, tirisfallbarricade
			block = { { fileID = 200655, name = "Brazier" }, { fileID = 200772, name = "Crank wheel" } }, -- lordaeronbrazier01, undead_crankwheel
			wall = { { fileID = 200666, name = "Wrecked wagon" }, { fileID = 204090, name = "Mass grave" } }, -- meatwagonwrecked01, massgrave
		},
		charger = { { displayID = 10699, name = "Undercity Guardian" }, { displayID = 11401, name = "Skeletal Executioner" } }, -- Undercity Guardian, Skeletal Executioner
	},
}

ns.ZonesByKey = {}
for _, zone in ipairs(ns.Zones) do
	ns.ZonesByKey[zone.key] = zone
end
