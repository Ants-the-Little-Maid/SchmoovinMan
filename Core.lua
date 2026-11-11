local ADDON_NAME, ns = ...

local DB_VERSION = 1

local DEFAULTS = {
	version = DB_VERSION,
	-- Personal top 10, shared across characters.
	scores = {},
	-- Each character's own best run, by name: it may not be in the shared top
	-- 10, and it's the one that character shares with its guild.
	bests = {},
	-- Guild boards: guild key -> { [player] = best }.
	guild = {},
	-- Characters whose first-name-only runs were moved to their full name.
	fullNames = {},
	settings = {
		sound = true,
		duck = true,
		windowSize = "medium",
		zoneLength = 25,
		startSpeed = 11,
		-- A 3-2-1 countdown before a paused run goes on.
		countdown = true,
		-- A coloured mark on the road in front of each hazard (see
		-- Renderer:AddHazardMarker). Off unless turned on in Options.
		markers = false,
	},
	-- Models picked in Options, by zone key and role: the candidate's key
	-- (see ns.Models.Key in Render/Models.lua), shown first in place of the
	-- zone's usual model.
	models = {},
	stats = {
		runs = 0,
		tokens = 0,
	},
	minimapAngle = 200,
}

ns.commands = {}

local loadCallbacks = {}

-- Runs once saved data is ready.
function ns.OnLoaded(callback)
	tinsert(loadCallbacks, callback)
end

-- This character's name as guildmates see it, then its first name. Forever
-- characters can have a surname, which UnitName returns second (where Retail
-- returns the realm), and addon messages carry the full name.
function ns.PlayerName()
	local name, surname = (UnitNameUnmodified or UnitName)("player")
	if name and surname and surname ~= "" then
		local constants = Constants and Constants.CharacterNameSeparatorConsts
		local separator = constants and constants.CHARACTERNAME_SURNAME_SEPARATOR or " "
		return name .. separator .. surname, name
	end
	return name, name
end

function ns.Print(message)
	print("|cffffd100Schmoovin Man:|r " .. tostring(message))
end

local function ApplyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = {}
				ApplyDefaults(target[key], value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			ApplyDefaults(target[key], value)
		end
	end
end

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- Several handlers may share an event; each receives the payload.
function ns.RegisterEvent(event, handler)
	if not eventHandlers[event] then
		eventHandlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	tinsert(eventHandlers[event], handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local handlers = eventHandlers[event]
	if handlers then
		for _, handler in ipairs(handlers) do
			handler(...)
		end
	end
end)

ns.RegisterEvent("ADDON_LOADED", function(loadedName)
	if loadedName ~= ADDON_NAME then
		return
	end
	SchmoovinManDB = SchmoovinManDB or {}
	ApplyDefaults(SchmoovinManDB, DEFAULTS)
	ns.db = SchmoovinManDB
	ns.Tuning.duckEnabled = ns.db.settings.duck ~= false
	ns.SetZoneLength(ns.db.settings.zoneLength)
	ns.SetStartSpeed(ns.db.settings.startSpeed)
	for _, callback in ipairs(loadCallbacks) do
		callback()
	end
end)

function ns.PlaySound(name)
	if not (ns.db and ns.db.settings.sound) then
		return
	end
	local kit = SOUNDKIT and SOUNDKIT[ns.Assets.sounds[name] or ""]
	if kit and kit ~= 0 then
		PlaySound(kit)
	end
end

-- Sets seconds per zone to one of the allowed choices; returns the choice.
function ns.SetZoneLength(seconds)
	local chosen = ns.Tuning.zoneLengths[2]
	for _, choice in ipairs(ns.Tuning.zoneLengths) do
		if choice.seconds == tonumber(seconds) then
			chosen = choice
		end
	end
	ns.Tuning.zoneLength = chosen.seconds
	if ns.db then
		ns.db.settings.zoneLength = chosen.seconds
	end
	return chosen
end

-- Moves to the next zone length choice, wrapping round.
function ns.CycleZoneLength()
	local choices = ns.Tuning.zoneLengths
	for index, choice in ipairs(choices) do
		if choice.seconds == ns.Tuning.zoneLength then
			return ns.SetZoneLength(choices[index % #choices + 1].seconds)
		end
	end
	return ns.SetZoneLength(25)
end

-- Sets the starting speed to one of the allowed choices, with its score
-- multiplier; returns the choice.
function ns.SetStartSpeed(speed)
	local chosen = ns.Tuning.startSpeeds[2]
	for _, choice in ipairs(ns.Tuning.startSpeeds) do
		if choice.speed == tonumber(speed) then
			chosen = choice
		end
	end
	ns.Tuning.baseSpeed = chosen.speed
	ns.Tuning.scoreMultiplier = chosen.multiplier
	if ns.db then
		ns.db.settings.startSpeed = chosen.speed
	end
	return chosen
end

-- The starting speed choice in use.
function ns.StartSpeedChoice()
	for _, choice in ipairs(ns.Tuning.startSpeeds) do
		if choice.speed == ns.Tuning.baseSpeed then
			return choice
		end
	end
	return ns.Tuning.startSpeeds[2]
end

-- "11 yd/s (Normal)", with the multiplier when it isn't 1.
function ns.StartSpeedText(choice)
	choice = choice or ns.StartSpeedChoice()
	if choice.multiplier == 1 then
		return ("%d yd/s (%s)"):format(choice.speed, choice.name)
	end
	return ("%d yd/s (%s, score x%s)"):format(choice.speed, choice.name, tostring(choice.multiplier))
end

-- Moves to the next starting speed choice, wrapping round.
function ns.CycleStartSpeed()
	local choices = ns.Tuning.startSpeeds
	for index, choice in ipairs(choices) do
		if choice.speed == ns.Tuning.baseSpeed then
			return ns.ChooseStartSpeed(choices[index % #choices + 1].speed)
		end
	end
	return ns.ChooseStartSpeed(11)
end

local function PrintHelp()
	ns.Print("Commands:")
	print("  /schmoove - open or close the game")
	print("  /schmoove start - open the game straight into a run")
	print("  /schmoove sound - turn sound on or off")
	print("  /schmoove duck - turn ducking on or off (off swaps high bars for blocks)")
	print("  /schmoove zones 15|25|35|45 - seconds per zone (shorter is harder)")
	print("  /schmoove speed 8|11|14 - starting speed (slower scores less, faster more)")
	print("  /schmoove markers - turn the coloured marks under hazards on or off")
	print("  /schmoove options - open the options")
end

-- Setting changes shared by the slash commands and the minimap menu.
function ns.SetSound(enabled)
	ns.db.settings.sound = enabled and true or false
end

-- Ducking applies from the next run; the running one keeps its own copy.
function ns.SetDuck(enabled)
	ns.db.settings.duck = enabled and true or false
	ns.Tuning.duckEnabled = ns.db.settings.duck
	ns.Controller:RefreshStart()
end

-- Zone length also applies from the next run.
function ns.ChooseZoneLength(seconds)
	local choice = ns.SetZoneLength(seconds)
	ns.Controller:RefreshStart()
	return choice
end

-- So does the starting speed.
function ns.ChooseStartSpeed(speed)
	local choice = ns.SetStartSpeed(speed)
	ns.Controller:RefreshStart()
	return choice
end

-- The resume countdown applies straight away.
function ns.SetCountdown(enabled)
	ns.db.settings.countdown = enabled and true or false
end

-- Hazard markers apply straight away too.
function ns.SetMarkers(enabled)
	ns.db.settings.markers = enabled and true or false
end

ns.commands["markers"] = function()
	ns.SetMarkers(not ns.db.settings.markers)
	ns.Print("Hazard markers " .. (ns.db.settings.markers and "on: amber to jump, blue to duck, red to keep clear." or "off."))
end

ns.commands["sound"] = function()
	ns.SetSound(not ns.db.settings.sound)
	ns.Print("Sound " .. (ns.db.settings.sound and "on." or "off."))
end

ns.commands["duck"] = function()
	ns.SetDuck(not ns.db.settings.duck)
	ns.Print("Ducking " .. (ns.db.settings.duck and "on" or "off") .. ". Takes effect from your next run.")
end

-- True when `value` is one of the choices' `field` values. A missing or wrong
-- number leaves the setting alone rather than putting it back to Normal.
local function IsChoice(choices, field, value)
	for _, choice in ipairs(choices) do
		if choice[field] == tonumber(value) then
			return true
		end
	end
	return false
end

ns.commands["zones"] = function(rest)
	if not IsChoice(ns.Tuning.zoneLengths, "seconds", rest) then
		ns.Print(("Zones last %d seconds. Choose 15, 25, 35 or 45, as in /schmoove zones 35."):format(ns.Tuning.zoneLength))
		return
	end
	local choice = ns.ChooseZoneLength(rest)
	ns.Print(("Zones last %d seconds (%s). Takes effect from your next run."):format(choice.seconds, choice.name))
end

ns.commands["speed"] = function(rest)
	if not IsChoice(ns.Tuning.startSpeeds, "speed", rest) then
		ns.Print(("Runs start at %s. Choose 8, 11 or 14, as in /schmoove speed 14."):format(ns.StartSpeedText()))
		return
	end
	local choice = ns.ChooseStartSpeed(rest)
	ns.Print(("Runs start at %s. Takes effect from your next run."):format(ns.StartSpeedText(choice)))
end

ns.commands["options"] = function()
	ns.Controller:OpenOptions()
end

ns.commands["start"] = function()
	ns.Controller:QuickStart()
end

-- Left out of the help: makes every run an orc run (see Data/OrcRun.lua), on
-- any character, until it's turned off or the UI reloads. For trying it out.
ns.commands["orc"] = function()
	ns.OrcRun.forced = not ns.OrcRun.forced
	if ns.OrcRun.forced then
		ns.Print("Orc runs forced on: every run is one until you turn it off or reload.")
	else
		ns.Print("Orc runs back to normal.")
	end
end

-- Left out of the help: for working out why a creature sits off its lane.
-- Lists the chargers and boss on screen with their measurements.
ns.commands["measure"] = function()
	local renderer = ns.Controller.renderer
	local lines = renderer and renderer:Measurements() or {}
	if #lines == 0 then
		ns.Print("No charger or boss on screen. Pause with one in view, then try again.")
	end
	for _, line in ipairs(lines) do
		ns.Print(line)
	end
end

ns.commands["help"] = PrintHelp

SLASH_SCHMOOVINMAN1 = "/schmoove"
SLASH_SCHMOOVINMAN2 = "/schmoovin"
SlashCmdList.SCHMOOVINMAN = function(input)
	local command, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	command = (command or ""):lower()
	if command == "" then
		ns.Controller:Toggle()
		return
	end
	local handler = ns.commands[command]
	if handler then
		handler(rest or "")
	else
		PrintHelp()
	end
end
