local _, ns = ...

-- Guild board: swaps best runs with guildmates who have the addon, using
-- hidden addon messages on the GUILD channel. Scores are trusted as sent.
local GuildBoard = {}
ns.GuildBoard = GuildBoard

local Codec = ns.Codec
local KEEP = 50
local RETRY_DELAY = 30
local REPLY_COOLDOWN = 60
local REQUEST_DELAY = 10

local pending = {}
local retryScheduled = false
local lastReply = 0

local function Readable(value)
	return not canaccessvalue or canaccessvalue(value)
end

function GuildBoard.PlayerName()
	return (ns.PlayerName())
end

-- Versions up to 0.8.1 saved this character under its first name only. Once
-- per character with a surname, move those runs and its guild board entry to
-- the full name, so it isn't listed twice or ranked against itself.
function GuildBoard.AdoptFullName()
	local full, first = ns.PlayerName()
	if not full or full == first or ns.db.fullNames[full] then
		return
	end
	ns.db.fullNames[full] = true
	for _, entry in ipairs(ns.db.scores) do
		if entry.character == first then
			entry.character = full
		end
	end
	for _, board in pairs(ns.db.guild) do
		local old = board.players and board.players[first]
		if old then
			board.players[first] = nil
			local current = board.players[full]
			if not current or current.score < old.score then
				old.name = full
				board.players[full] = old
			end
		end
	end
end

-- This character's own best. The personal top 10 is shared across the
-- account, so its first entry may belong to another character; only runs
-- made by the one logged in are shared under its name. Its best is also kept
-- by name (ns.db.bests), as other characters' runs can push it out of the
-- top 10; runs from before that was kept are found in the top 10.
function GuildBoard.MyBest()
	local name = GuildBoard.PlayerName()
	local best = name and ns.db.bests[name]
	for _, entry in ipairs(ns.Scores.List()) do
		if entry.character == name then
			if not best or entry.score > best.score then
				best = entry
			end
			break
		end
	end
	return best
end

local function GuildKey()
	if not IsInGuild() then
		return nil
	end
	local guildName = GetGuildInfo("player")
	if not guildName then
		return nil
	end
	return guildName .. "-" .. (GetRealmName() or "")
end

local function Board()
	local key = GuildKey()
	if not key then
		return nil
	end
	ns.db.guild[key] = ns.db.guild[key] or { players = {}, updated = 0 }
	return ns.db.guild[key]
end

local function Store(name, best)
	local board = Board()
	if not board then
		return
	end
	local current = board.players[name]
	if current and current.score >= best.score then
		return
	end
	board.players[name] = {
		name = name,
		score = best.score,
		tenths = best.tenths,
		tokens = best.tokens,
		zones = best.zones,
		when = best.when,
	}
	board.updated = time()
	-- Keep the board small: drop the lowest once over the limit.
	local list = {}
	for _, entry in pairs(board.players) do
		tinsert(list, entry)
	end
	if #list > KEEP then
		table.sort(list, function(a, b)
			return a.score > b.score
		end)
		for index = KEEP + 1, #list do
			board.players[list[index].name] = nil
		end
	end
end

-- Sorted board for the current guild, with your own best included, and a footer line.
function GuildBoard.List()
	local board = Board()
	if not board then
		return {}, "Join a guild to compare scores with guildmates."
	end
	local best = GuildBoard.MyBest()
	if best then
		Store(GuildBoard.PlayerName(), best)
	end
	local list = {}
	for _, entry in pairs(board.players) do
		tinsert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	local footer = "From guildmates with Schmoovin Man."
	if board.updated and board.updated > 0 then
		local minutes = math.floor((time() - board.updated) / 60)
		footer = footer .. (minutes < 1 and " Updated just now." or string.format(" Updated %d min ago.", minutes))
	end
	return list, footer
end

-- Where a score would place among guildmates' bests, or nil outside a guild.
function GuildBoard.RankFor(score)
	if not GuildKey() then
		return nil
	end
	local list = GuildBoard.List()
	local rank = 1
	for _, entry in ipairs(list) do
		if entry.name ~= GuildBoard.PlayerName() and entry.score > score then
			rank = rank + 1
		end
	end
	return rank
end

function GuildBoard.TopScore()
	local list = GuildBoard.List()
	return list[1]
end

-- Sending -------------------------------------------------------------------------

local function CanSend()
	if not IsInGuild() then
		return false
	end
	local inInstance = IsInInstance()
	return not inInstance
end

local Flush

local function ScheduleRetry()
	if not retryScheduled then
		retryScheduled = true
		C_Timer.After(RETRY_DELAY, function()
			retryScheduled = false
			Flush()
		end)
	end
end

local function TrySend(message)
	if not CanSend() then
		return false
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, Codec.PREFIX, message, "GUILD")
	if not ok or result == false then
		return false
	end
	local codes = Enum and Enum.SendAddonMessageResult
	if type(result) == "number" and codes and result ~= codes.Success then
		return false
	end
	return true
end

Flush = function()
	-- Out of a guild there's nobody to send to, and nothing to wait for: a
	-- queued best mustn't go to whichever guild is joined next.
	if not IsInGuild() then
		wipe(pending)
		return
	end
	while pending[1] do
		if not TrySend(pending[1]) then
			ScheduleRetry()
			return
		end
		tremove(pending, 1)
	end
end

local function Send(message)
	-- Only the newest best matters; drop older queued ones.
	for index = #pending, 1, -1 do
		if pending[index] ~= "Q" and message ~= "Q" then
			tremove(pending, index)
		end
	end
	tinsert(pending, message)
	Flush()
end

function GuildBoard.ShareBest(entry)
	if IsInGuild() then
		Send(Codec.EncodeBest(entry))
	end
end

-- Receiving -----------------------------------------------------------------------

local function OnMessage(prefix, text, channel, sender)
	if prefix ~= Codec.PREFIX or channel ~= "GUILD" then
		return
	end
	if not (Readable(text) and Readable(sender)) or type(sender) ~= "string" then
		return
	end
	local name = Ambiguate(sender, "guild")
	if name == GuildBoard.PlayerName() then
		return
	end
	local kind, best = Codec.Decode(text)
	if kind == "best" then
		Store(name, best)
	elseif kind == "request" then
		local mine = GuildBoard.MyBest()
		if mine and GetTime() - lastReply > REPLY_COOLDOWN then
			lastReply = GetTime()
			C_Timer.After(1 + math.random() * 5, function()
				Send(Codec.EncodeBest(mine))
			end)
		end
	end
end

ns.OnLoaded(function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(Codec.PREFIX)
	end
	ns.RegisterEvent("CHAT_MSG_ADDON", OnMessage)
	local asked = false
	ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
		GuildBoard.AdoptFullName()
		Flush()
		if not asked then
			asked = true
			C_Timer.After(REQUEST_DELAY, function()
				if IsInGuild() then
					Send(Codec.EncodeRequest())
					local best = GuildBoard.MyBest()
					if best then
						Send(Codec.EncodeBest(best))
					end
				end
			end)
		end
	end)
end)
