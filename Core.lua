local ADDON_NAME, ns = ...

local DB_VERSION = 1

local DEFAULTS = {
	version = DB_VERSION,
	-- Personal top 10, shared across characters.
	scores = {},
	-- Guild boards: guild key -> { [player] = best }.
	guild = {},
	-- Characters whose first-name-only runs were moved to their full name.
	fullNames = {},
	settings = {
		sound = true,
		duck = true,
		windowSize = "medium",
		zoneLength = 25,
	},
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

local function PrintHelp()
	ns.Print("Commands:")
	print("  /schmoove - open or close the game")
	print("  /schmoove start - open the game straight into a run")
	print("  /schmoove sound - turn sound on or off")
	print("  /schmoove duck - turn ducking on or off (off swaps high bars for blocks)")
	print("  /schmoove zones 15|25|35|45 - seconds per zone (shorter is harder)")
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

ns.commands["sound"] = function()
	ns.SetSound(not ns.db.settings.sound)
	ns.Print("Sound " .. (ns.db.settings.sound and "on." or "off."))
end

ns.commands["duck"] = function()
	ns.SetDuck(not ns.db.settings.duck)
	ns.Print("Ducking " .. (ns.db.settings.duck and "on" or "off") .. ". Takes effect from your next run.")
end

ns.commands["zones"] = function(rest)
	local choice = ns.ChooseZoneLength(rest)
	ns.Print(("Zones last %d seconds (%s). Takes effect from your next run."):format(choice.seconds, choice.name))
end

ns.commands["start"] = function()
	ns.Controller:QuickStart()
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
