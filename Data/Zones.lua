local _, ns = ...

--[[ The run's zones. Mulgore is always first; the rest come in a random order.

Sources as in Data/Assets.lua (listfile 202611050009, wago.tools tables).
Original-world (Classic) doodads and tilesets are used throughout, as they're
the likeliest to ship with Forever.

ground / road: terrain tileset file IDs, drawn as tiled UI textures. If one
  can't be drawn, the flat groundColor / roadColor shows instead.
sky = { top, bottom }, fog = { color, near, far }, light = { ambient, diffuse }
scenery: roadside models, each scaled to `height` yards.
obstacles: model lists per role (low, high, block, wall), each scaled to the
  role's size. charger: creature displays that run at you.
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
		{ fileID = 199632 }, -- generic/passivedoodads/crate01/crate01.m2
		{ fileID = 199652 }, -- deadtreelogs/deadtreelog01.m2
	},
	high = {
		{ fileID = 199209 }, -- generic/orc/passive doodads/orcfence/orcfence.m2
	},
	block = {
		{ fileID = 199563 }, -- generic/passivedoodads/barrel/barrel01.m2
		{ fileID = 199634 }, -- crate02.m2
	},
	wall = {
		{ fileID = 199634 }, -- crate02.m2
	},
}
ns.GenericObstacles = GENERIC

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
			low = { { fileID = 202305 }, { fileID = 200372 } }, -- mullgorethorn01, largebasket01
			high = { { fileID = 200596 }, { fileID = 200614 } }, -- warharnesswall01, windbreak02
			block = { { fileID = 200578 }, { fileID = 202301 } }, -- taurentotem02, mullgorerock02
			wall = { { fileID = 200615 }, { fileID = 202292 } }, -- windbreak03, burnedgypsywagon01
		},
		charger = { { displayID = 1230 }, { displayID = 179 }, { displayID = 38 } }, -- kodo, kodo, tallstrider
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
			low = { { fileID = 201371 }, { fileID = 201375 } }, -- barrensbush02, kodoegg01
			high = { { fileID = 201364 }, { fileID = 201365 } }, -- kotobeastbone02/03
			block = { { fileID = 201384 }, { fileID = 201377 } }, -- termite mound, lamppost
			wall = { { fileID = 201416 }, { fileID = 201413 } }, -- barrenswagon01, bustedwagon
		},
		charger = { { displayID = 1532 }, { displayID = 180 } }, -- thunder lizard, raptor
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
			low = { { fileID = 202695 }, { fileID = 202710 } }, -- haybail straightaway01, saltflatrock_01
			high = { { fileID = 202693 }, { fileID = 202696 } }, -- bridge, haybail straightaway02
			block = { { fileID = 202711 }, { fileID = 202733 } }, -- saltflatrock_02, snake nest
			wall = { { fileID = 202694 }, { fileID = 202697 } }, -- haybail back-stop, straightaway03
		},
		charger = { { displayID = 1308 }, { displayID = 322 } }, -- kodo, raptor
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
			low = { { fileID = 201217 }, { fileID = 201208 } }, -- treelog01, stump01
			high = { { fileID = 201236 }, { fileID = 201218 } }, -- satyr arch, treelog02
			block = { { fileID = 201252 }, { fileID = 201211 } }, -- satyr totem, tree stump
			wall = { { fileID = 201246 }, { fileID = 201247 } }, -- satyr ruin walls
		},
		charger = { { displayID = 1917 }, { displayID = 706 }, { displayID = 145 } }, -- stag, bear, furbolg
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
			low = { { fileID = 189218 }, { fileID = 189226 } }, -- lavarock01, burnedbeam
			high = { { fileID = 189135 }, { fileID = 189124 } }, -- fence, rope bridge
			block = { { fileID = 189212 }, { fileID = 189236 } }, -- boulders01, stoneblock01
			wall = { { fileID = 189213 }, { fileID = 189135 } }, -- boulders02, fence
		},
		charger = { { displayID = 1070 }, { displayID = 10193 } }, -- fire elemental, core hound
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
			low = { { fileID = 202490 }, { fileID = 202477 } }, -- silithid egg, crystal nub
			high = { { fileID = 202498 }, { fileID = 202587 } }, -- ruin arch, wasp husk
			block = { { fileID = 202534 }, { fileID = 202555 } }, -- silithus pod, quiraj ruin block
			wall = { { fileID = 202573 }, { fileID = 202565 } }, -- ruins wall, quiraj wall
		},
		charger = { { displayID = 91 }, { displayID = 157 }, { displayID = 92 } }, -- silithid tank, silithid, wasp
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
			low = { { fileID = 202771 }, { fileID = 366958 } }, -- ungororock07, coconut bunch
			high = { { fileID = 202747 }, { fileID = 202784 } }, -- ungoro archway, tree break 2
			block = { { fileID = 202772 }, { fileID = 202755 } }, -- ungororock08, yellow crystal
			wall = { { fileID = 202773 }, { fileID = 202774 } }, -- ungororock09/10
		},
		charger = { { displayID = 5238 }, { displayID = 615 } }, -- devilsaur, raptor
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
			low = { { fileID = 202872 }, { fileID = 202868 } }, -- fallen branch, bush
			high = { { fileID = 202873 }, { fileID = 202884 } }, -- fallen tree, world tree root
			block = { { fileID = 202846 }, { fileID = 202842 } }, -- rock02, furbolg totem 2
			wall = { { fileID = 202847 }, { fileID = 202874 } }, -- rock03, fallen tree 2
		},
		charger = { { displayID = 21597 }, { displayID = 10914 }, { displayID = 161 } }, -- yeti, wooly kodo, wolf
	},
}

ns.ZonesByKey = {}
for _, zone in ipairs(ns.Zones) do
	ns.ZonesByKey[zone.key] = zone
end
