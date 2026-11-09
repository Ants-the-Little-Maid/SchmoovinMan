local _, ns = ...

-- Which model each hazard, charger, coin and gem uses, zone by zone. Each
-- role has a chain of models tried in order (the zone's own, then shared
-- ones) so a model missing from the client falls back to the next. A model
-- picked in Options goes first (saved in ns.db.models by zone key and role);
-- the choices offered are the chain plus the brighter extras in
-- ns.ExtraModels (Data/Zones.lua).
local Models = {}
ns.Models = Models

-- What Options lists, in order.
Models.ROLES = {
	{ role = "low", label = "Low (jump)" },
	{ role = "high", label = "High bar (duck)" },
	{ role = "block", label = "Block" },
	{ role = "wall", label = "Wall" },
	{ role = "charger", label = "Charger" },
	{ role = "coin", label = "Coin" },
	{ role = "gem", label = "Gem" },
}
Models.PICKABLE = {}
for _, item in ipairs(Models.ROLES) do
	Models.PICKABLE[item.role] = true
end

-- A model's key: "f" and its file ID, "d" and its display ID, or "u" and
-- the unit its look is copied from.
function Models.Key(candidate)
	if candidate.unit then
		return "u" .. candidate.unit
	end
	return candidate.fileID and ("f" .. candidate.fileID) or ("d" .. tostring(candidate.displayID))
end

-- A role's usual chain in a zone, before any pick.
local function BaseList(zone, role)
	if role == "coin" or role == "gem" then
		return ns.Assets.tokens[role]
	elseif role == "charger" then
		return zone.charger
	end
	local list = {}
	for _, candidate in ipairs(zone.obstacles[role] or {}) do
		list[#list + 1] = candidate
	end
	for _, candidate in ipairs(ns.GenericObstacles[role] or {}) do
		list[#list + 1] = candidate
	end
	return list
end

-- What Options offers for a zone and role: the usual chain, then the extras,
-- each model once, leaving out backup copies.
function Models.Choices(zone, role)
	local choices, seen = {}, {}
	local function Add(list)
		for _, candidate in ipairs(list or {}) do
			local key = Models.Key(candidate)
			if not seen[key] and not candidate.backupOnly then
				seen[key] = true
				choices[#choices + 1] = candidate
			end
		end
	end
	Add(BaseList(zone, role))
	Add(ns.ExtraModels[role])
	return choices
end

-- The key of the model picked for a zone and role, or nil for the usual one.
function Models.Picked(zoneKey, role)
	local picks = ns.db and ns.db.models and ns.db.models[zoneKey]
	return picks and picks[role]
end

-- Chains built so far, by zone and role; cleared when a pick changes.
local built = {}

-- Picks a model by key, or nil for the zone's usual one. Models drawn from
-- now on use it.
function Models.Pick(zoneKey, role, key)
	local zones = ns.db.models
	zones[zoneKey] = zones[zoneKey] or {}
	zones[zoneKey][role] = key
	if next(zones[zoneKey]) == nil then
		zones[zoneKey] = nil
	end
	built = {}
end

-- The chain a model is loaded from: the pick first (if it's still on offer),
-- then the usual chain without it.
function Models.List(zone, role)
	local id = zone.key .. ":" .. role
	if built[id] then
		return built[id]
	end
	local list = BaseList(zone, role)
	local picked = Models.Picked(zone.key, role)
	if picked then
		for _, candidate in ipairs(Models.Choices(zone, role)) do
			if Models.Key(candidate) == picked then
				local ordered = { candidate }
				for _, other in ipairs(list) do
					if Models.Key(other) ~= picked then
						ordered[#ordered + 1] = other
					end
				end
				list = ordered
				break
			end
		end
	end
	built[id] = list
	return list
end
