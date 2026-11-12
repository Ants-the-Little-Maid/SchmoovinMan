local _, ns = ...

-- Start, pause and game-over screens from the mock-up, drawn over the view.
local Screens = {}
Screens.__index = Screens
ns.Screens = Screens

local UI = ns.UI
local BUTTON_FONT = "Fonts\\FRIZQT__.TTF"

-- "a Kodo", "an Ironforge guard": a model's name with its article.
local function WithArticle(name)
	return (name:find("^[AEIOUaeiou]") and "an " or "a ") .. name
end

-- What charged you: the model that was drawn (which may be a backup or an
-- Options pick), else the first in that zone's chain, else "a beast".
local function ChargerName(zone, drawnName)
	local name = drawnName
	if not name and zone then
		local first = ns.Models.List(zone, "charger")[1]
		name = first and first.name
	end
	return name and WithArticle(name) or "a beast"
end

local CRASH_TEXT = {
	low = "Tripped over an obstacle",
	high = "Clotheslined by a high bar",
	block = "Ran into a block",
	wall = "Ran into a wall",
	pitedge = "Fell into a pit",
	vent = "Scorched by a lava vent",
	tauren = "Trampled by a Schmoover",
}

-- Orc runs are marked with a candle, inline before the text.
local function Candle(text)
	return "|T" .. ns.Assets.icons.candle[1] .. ":16:16|t " .. text
end

local function Overlay(parent, alpha)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:EnableMouse(true)
	local dim = frame:CreateTexture(nil, "BACKGROUND")
	dim:SetAllPoints()
	dim:SetColorTexture(0.047, 0.031, 0.016, alpha)
	frame:Hide()
	return frame
end

local function Row(parent, labelText, valueText, size)
	local label = UI.Text(parent, size or 15, UI.COLORS.text)
	label:SetText(labelText or "")
	local value = UI.Text(parent, size or 15, UI.COLORS.white)
	value:SetText(valueText or "")
	return label, value
end

function Screens.Create(layer, controller)
	local self = setmetatable({}, Screens)
	self.controller = controller
	self:BuildStart(layer)
	self:BuildPaused(layer)
	self:BuildGameOver(layer)
	return self
end

-- Start ------------------------------------------------------------------------------

function Screens:BuildStart(layer)
	local C = UI.COLORS
	local start = Overlay(layer, 0.55)
	self.start = start

	local title = UI.Text(start, 50, C.gold, nil, "OUTLINE")
	title:SetPoint("TOPLEFT", 36, -110)
	title:SetJustifyH("LEFT")
	title:SetText("Schmoovin\nMan")
	title:SetSpacing(4)

	local blurb = UI.Text(start, 15, C.text)
	blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
	blurb:SetWidth(400)
	blurb:SetJustifyH("LEFT")
	blurb:SetText("Run, hop and duck across Kalimdor and beyond. Grab tokens, dodge everything, survive as long as you can.")

	local button = UI.Button(start, "Start run", "primary", 170, 48)
	button.text:SetFont("Fonts\\FRIZQT__.TTF", 20, "")
	button:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -18)
	button:SetScript("OnClick", function()
		self.controller:StartRun()
	end)

	-- Zone length and starting speed, stacked beside Start: click to cycle
	-- through the choices.
	local zoneButton = UI.Button(start, "", nil, 250, 22)
	zoneButton.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	zoneButton:SetPoint("TOPLEFT", button, "TOPRIGHT", 12, 0)
	zoneButton:SetScript("OnClick", function()
		ns.CycleZoneLength()
		self:UpdateZoneButton()
		ns.PlaySound("click")
	end)
	zoneButton:SetScript("OnEnter", function(widget)
		GameTooltip:SetOwner(widget, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Zone length")
		GameTooltip:AddLine("How long each zone lasts. Shorter zones bring speed-ups and new obstacles sooner.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	zoneButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self.zoneButton = zoneButton

	-- Wide enough for "Start: 14 yd/s (Fast, score x1.25)".
	local speedButton = UI.Button(start, "", nil, 250, 22)
	speedButton.text:SetFont(BUTTON_FONT, 12, "")
	speedButton:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 12, 0)
	speedButton:SetScript("OnClick", function()
		ns.CycleStartSpeed()
		self:UpdateZoneButton()
		ns.PlaySound("click")
	end)
	speedButton:SetScript("OnEnter", function(widget)
		GameTooltip:SetOwner(widget, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Starting speed")
		GameTooltip:AddLine("How fast a run starts. Slow gives more time to react and scores x0.75; Fast scores x1.25.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	speedButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self.speedButton = speedButton

	self.startInfo = UI.Text(start, 12, C.subText)
	self.startInfo:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -10)
	self.startInfo:SetJustifyH("LEFT")

	local options = UI.Button(start, "Options", nil, 120, 26)
	options.text:SetFont(BUTTON_FONT, 12, "")
	options:SetPoint("TOPLEFT", self.startInfo, "BOTTOMLEFT", 0, -10)
	options:SetScript("OnClick", function()
		self.controller:OpenOptions()
	end)
	self.optionsButton = options

	-- Controls and power-ups on the right.
	local controls = UI.Dialog(start)
	controls:SetPoint("TOPLEFT", start, "TOP", 12, -120)
	controls:SetSize(430, 140)
	local controlsTitle = UI.Text(controls, 15, C.gold)
	controlsTitle:SetPoint("TOPLEFT", 20, -18)
	controlsTitle:SetText("Controls")
	self.controlRows = {}
	local controlLines = {
		{ "A / D, Left / Right", "Change lane" },
		{ "W, Up, Space", "Jump" },
		{ "S, Down", "Duck" },
		{ "Esc, P", "Pause" },
	}
	for index, line in ipairs(controlLines) do
		local key, action = Row(controls, line[1], line[2], 13)
		key:SetTextColor(UI.Hex(C.white))
		key:SetPoint("TOPLEFT", 20, -20 - index * 22)
		action:SetTextColor(UI.Hex(C.text))
		action:SetPoint("TOPLEFT", 220, -20 - index * 22)
		self.controlRows[index] = { key, action }
	end

	local powerups = UI.Dialog(start)
	powerups:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -12)
	powerups:SetSize(430, 164)
	local powerTitle = UI.Text(powerups, 15, C.gold)
	powerTitle:SetPoint("TOPLEFT", 20, -18)
	powerTitle:SetText("Power-ups")
	local powerLines = {
		{ "windRider", "Fly over everything" },
		{ "magnet", "Pulls in tokens" },
		{ "shield", "Survive one hit" },
		{ "goldRush", "Tokens worth x2" },
		{ "stampede", "Smash through" },
	}
	for index, line in ipairs(powerLines) do
		local style = UI.POWERUP_STYLE[line[1]]
		local name, effect = Row(powerups, (style.name:gsub(" x2", "")), line[2], 13)
		name:SetTextColor(UI.Hex(style.color))
		name:SetPoint("TOPLEFT", 20, -20 - index * 22)
		effect:SetTextColor(UI.Hex(C.text))
		effect:SetPoint("TOPLEFT", 220, -20 - index * 22)
	end

	local footnote = UI.Text(start, 12, C.subText)
	footnote:SetPoint("TOPLEFT", powerups, "BOTTOMLEFT", 0, -10)
	-- Held to the panel's width, so the longer score line wraps.
	footnote:SetPoint("RIGHT", powerups, "RIGHT")
	footnote:SetJustifyH("LEFT")
	footnote:SetText("Each new zone speeds you up. Score = tokens + time + jumps (+2), ducks (+3), Alliance joggers knocked over (+5), more for each in a combo, and bosses (+50 a spear, +500 driven off, +150 outlasted).")
	self.footnote = footnote
end

function Screens:UpdateZoneButton()
	local seconds = ns.Tuning.zoneLength
	local name = ""
	for _, choice in ipairs(ns.Tuning.zoneLengths) do
		if choice.seconds == seconds then
			name = choice.name
		end
	end
	self.zoneButton.text:SetText(("Zones: %d s (%s)"):format(seconds, name))
	self.speedButton.text:SetText("Start: " .. ns.StartSpeedText())
end

function Screens:ShowStart(best, guildBest)
	self:UpdateZoneButton()
	local parts = { "Enter to start" }
	if best then
		tinsert(parts, string.format("Your best: %s (%s)", UI.FormatNumber(best.score), UI.FormatTime(best.tenths / 10)))
	end
	if guildBest then
		tinsert(parts, "Guild best: " .. UI.FormatNumber(guildBest.score))
	end
	self.startInfo:SetText(table.concat(parts, "  -  "))
	local duck = ns.Tuning.duckEnabled
	local row = self.controlRows[3]
	row[1]:SetShown(duck)
	row[2]:SetShown(duck)
	self.start:Show()
end

-- Paused -----------------------------------------------------------------------------

function Screens:BuildPaused(layer)
	local C = UI.COLORS
	local paused = Overlay(layer, 0.5)
	self.paused = paused

	local box = UI.Dialog(paused)
	box:SetPoint("CENTER")
	box:SetSize(380, 300)

	local title = UI.Text(box, 30, C.gold)
	title:SetPoint("TOP", 0, -20)
	title:SetText("Paused")

	self.pauseReason = UI.Text(box, 13, C.orange)
	self.pauseReason:SetPoint("TOP", title, "BOTTOM", 0, -8)

	self.pauseStats = {}
	local labels = { "Score", "Time", "Tokens" }
	for index, labelText in ipairs(labels) do
		local x = (index - 2) * 110
		local label = UI.Text(box, 12, C.label)
		label:SetPoint("TOP", box, "TOP", x, -96)
		label:SetText(labelText)
		local value = UI.Text(box, 17, C.white)
		value:SetPoint("TOP", label, "BOTTOM", 0, -3)
		self.pauseStats[index] = value
	end

	local options = UI.Button(box, "Options", nil, 90, 24)
	options.text:SetFont(BUTTON_FONT, 12, "")
	options:SetPoint("TOPRIGHT", -14, -14)
	options:SetScript("OnClick", function()
		self.controller:OpenOptions()
	end)

	local resume = UI.Button(box, "Resume (P)", "primary", 328, 44)
	resume:SetPoint("TOP", 0, -150)
	resume:SetScript("OnClick", function()
		self.controller:Resume()
	end)
	self.resumeButton = resume

	local restart = UI.Button(box, "Restart", nil, 160, 44)
	restart:SetPoint("TOPLEFT", resume, "BOTTOMLEFT", 0, -8)
	restart:SetScript("OnClick", function()
		self.controller:StartRun()
	end)
	local quit = UI.Button(box, "Quit run", nil, 160, 44)
	quit:SetPoint("TOPRIGHT", resume, "BOTTOMRIGHT", 0, -8)
	quit:SetScript("OnClick", function()
		self.controller:QuitRun()
	end)

	local note = UI.Text(box, 11, C.subText)
	note:SetPoint("BOTTOM", 0, 12)
	note:SetWidth(340)
	note:SetText("Your keyboard is back to normal while paused. Esc closes the window. Resume is blocked during combat.")
end

function Screens:ShowPaused(world, reason)
	self.pauseReason:SetText(reason or "")
	self.pauseStats[1]:SetText(UI.FormatNumber(world.score))
	self.pauseStats[2]:SetText(UI.FormatTime(world.time))
	self.pauseStats[3]:SetText(UI.FormatNumber(world.tokens))
	self.paused:Show()
end

-- Game over --------------------------------------------------------------------------

function Screens:BuildGameOver(layer)
	local C = UI.COLORS
	local over = Overlay(layer, 0.6)
	self.over = over

	-- Results on the left.
	local results = UI.Dialog(over)
	results:SetPoint("TOPLEFT", 28, -24)
	results:SetPoint("BOTTOMRIGHT", over, "BOTTOM", -10, 24)

	local title = UI.Text(results, 30, C.gold)
	title:SetPoint("TOPLEFT", 24, -24)
	title:SetText("You stumbled!")
	self.crashText = UI.Text(results, 13, C.subText)
	self.crashText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	self.crashText:SetWidth(380)
	self.crashText:SetJustifyH("LEFT")

	local top = results:CreateTexture(nil, "ARTWORK")
	top:SetColorTexture(UI.Hex(C.divider))
	top:SetHeight(1)
	top:SetPoint("TOPLEFT", 22, -118)
	top:SetPoint("TOPRIGHT", -22, -118)

	self.timeLabel, self.timeValue = Row(results)
	self.timeLabel:SetPoint("TOPLEFT", 22, -132)
	self.timeValue:SetPoint("TOPRIGHT", -22, -132)
	self.tokenLabel, self.tokenValue = Row(results)
	self.tokenLabel:SetPoint("TOPLEFT", 22, -158)
	self.tokenValue:SetPoint("TOPRIGHT", -22, -158)
	self.moveLabel, self.moveValue = Row(results)
	self.moveLabel:SetPoint("TOPLEFT", 22, -184)
	self.moveValue:SetPoint("TOPRIGHT", -22, -184)
	self.bossLabel, self.bossValue = Row(results)
	self.bossLabel:SetPoint("TOPLEFT", 22, -210)
	self.bossValue:SetPoint("TOPRIGHT", -22, -210)
	local totalLabel
	totalLabel, self.totalValue = Row(results, "Total", "", 20)
	self.totalLabel = totalLabel
	totalLabel:SetTextColor(UI.Hex(C.gold))
	self.totalValue:SetTextColor(UI.Hex(C.gold))
	totalLabel:SetPoint("TOPLEFT", 22, -238)
	self.totalValue:SetPoint("TOPRIGHT", -22, -238)

	local bottom = results:CreateTexture(nil, "ARTWORK")
	bottom:SetColorTexture(UI.Hex(C.divider))
	bottom:SetHeight(1)
	bottom:SetPoint("TOPLEFT", 22, -270)
	bottom:SetPoint("TOPRIGHT", -22, -270)

	self.personalBadge = UI.Panel(results, "2f4a1a", 1, C.green)
	self.personalBadge:SetPoint("TOPLEFT", 22, -284)
	self.personalBadge:SetSize(110, 24)
	self.personalText = UI.Text(self.personalBadge, 13, "d8f2b0")
	self.personalText:SetPoint("CENTER")
	self.guildBadge = UI.Panel(results, "1a2f4a", 1, "7fd1ff")
	self.guildBadge:SetPoint("LEFT", self.personalBadge, "RIGHT", 8, 0)
	self.guildBadge:SetSize(110, 24)
	self.guildText = UI.Text(self.guildBadge, 13, "c8ecff")
	self.guildText:SetPoint("CENTER")
	self.bestText = UI.Text(results, 13, C.green)
	self.bestText:SetPoint("TOPLEFT", self.personalBadge, "BOTTOMLEFT", 0, -10)

	local again = UI.Button(results, "Again (Enter)", "primary", 180, 46)
	again:SetPoint("BOTTOMLEFT", 22, 22)
	again:SetScript("OnClick", function()
		self.controller:StartRun()
	end)
	local close = UI.Button(results, "Close", nil, 180, 46)
	close:SetPoint("BOTTOMRIGHT", -22, 22)
	close:SetScript("OnClick", function()
		self.controller:Close()
	end)

	-- Scoreboard on the right.
	local board = UI.Dialog(over)
	board:SetPoint("TOPLEFT", over, "TOP", 10, -24)
	board:SetPoint("BOTTOMRIGHT", -28, 24)
	self.board = board

	self.mineTab = UI.Button(board, "My best", nil, 100, 32)
	self.mineTab:SetPoint("TOPLEFT", 18, -18)
	self.mineTab:SetPoint("TOPRIGHT", board, "TOP", -3, -18)
	self.guildTab = UI.Button(board, "Guild", nil, 100, 32)
	self.guildTab:SetPoint("TOPLEFT", board, "TOP", 3, -18)
	self.guildTab:SetPoint("TOPRIGHT", -18, -18)
	self.mineTab:SetScript("OnClick", function()
		self:ShowBoard("mine")
	end)
	self.guildTab:SetScript("OnClick", function()
		self:ShowBoard("guild")
	end)

	local columns = { { "#", 18, "LEFT" }, { "", 44, "LEFT" }, { "Time", 236, "RIGHT" }, { "Tokens", 296, "RIGHT" }, { "Score", 376, "RIGHT" } }
	self.header = {}
	for index, column in ipairs(columns) do
		local text = UI.Text(board, 12, C.label)
		text:SetText(column[1])
		if column[3] == "RIGHT" then
			text:SetPoint("TOPRIGHT", board, "TOPLEFT", column[2] + 2, -66)
		else
			text:SetPoint("TOPLEFT", column[2], -66)
		end
		self.header[index] = text
	end

	self.rows = {}
	for index = 1, 10 do
		local y = -84 - (index - 1) * 26
		local row = CreateFrame("Frame", nil, board)
		row:SetPoint("TOPLEFT", 12, y)
		row:SetPoint("TOPRIGHT", -12, y)
		row:SetHeight(24)
		local fill = row:CreateTexture(nil, "BACKGROUND")
		fill:SetAllPoints()
		row.fill = fill
		UI.Border(row, C.gold)
		local cells = {}
		for column = 1, 5 do
			local text = UI.Text(row, 13, column == 5 and C.white or C.text)
			local spec = columns[column]
			if spec[3] == "RIGHT" then
				text:SetPoint("RIGHT", row, "LEFT", spec[2] - 10, 0)
			else
				text:SetPoint("LEFT", spec[2] - 12, 0)
			end
			cells[column] = text
		end
		cells[2]:SetWidth(150)
		cells[2]:SetJustifyH("LEFT")
		cells[2]:SetWordWrap(false)
		row.cells = cells
		self.rows[index] = row
	end

	self.boardFooter = UI.Text(board, 11, C.label)
	self.boardFooter:SetPoint("BOTTOMLEFT", 18, 16)
end

function Screens:ShowBoard(tab)
	self.tab = tab
	UI.SetTabSelected(self.mineTab, tab == "mine")
	UI.SetTabSelected(self.guildTab, tab == "guild")
	local entries, highlight, footer
	if tab == "mine" then
		entries = ns.Scores.List()
		highlight = self.lastEntry
		footer = "Shared across your characters on this account."
		self.header[2]:SetText("Character")
	else
		entries, footer = ns.GuildBoard.List()
		highlight = ns.GuildBoard.PlayerName()
		self.header[2]:SetText("Guildmate")
	end
	for index, row in ipairs(self.rows) do
		local entry = entries[index]
		if entry then
			row.cells[1]:SetText(index)
			local name = entry.name or entry.character or "?"
			-- Your own orc runs carry a candle (guild messages don't say).
			row.cells[2]:SetText(entry.orc and Candle(name) or name)
			row.cells[3]:SetText(UI.FormatTime((entry.tenths or 0) / 10))
			row.cells[4]:SetText(UI.FormatNumber(entry.tokens or 0))
			row.cells[5]:SetText(UI.FormatNumber(entry.score or 0))
			local isMine = (tab == "mine" and entry == highlight) or (tab == "guild" and entry.name == highlight)
			if isMine then
				row.fill:SetColorTexture(UI.Hex("4a3a14"))
				for _, edge in pairs(row.borderEdges) do
					edge:Show()
				end
			else
				row.fill:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0)
				for _, edge in pairs(row.borderEdges) do
					edge:Hide()
				end
			end
			row:Show()
		else
			row:Hide()
		end
	end
	self.boardFooter:SetText(footer or "")
end

-- crashName: the name of the model you ran into, if it was drawn.
function Screens:ShowGameOver(world, entry, personalRank, guildRank, isBest, crashName)
	self.lastEntry = entry
	local zone = ns.ZonesByKey[world.crashZoneKey or world.zoneKey]
	local zoneName = zone and zone.name or "?"
	local cause
	if world.crashRole == "charger" then
		cause = "Charged by " .. ChargerName(zone, crashName)
	else
		cause = CRASH_TEXT[world.crashRole] or "Run ended"
		-- Ironforge's vents are steam.
		if ns.Rules.IsSteam(ns.Tuning, world.crashRole, world.crashZoneKey or world.zoneKey) then
			cause = "Scalded by a steam vent"
		elseif world.crashRole == "pitedge" and zone and zone.pit then
			-- What's down a pit depends on the zone.
			cause = "Fell into " .. zone.pit.name
		end
	end
	if world:InFight() then
		self.crashText:SetText(string.format("%s in %s (zone %d), fighting %s.", cause, zoneName, world.zoneIndex, world.boss.name))
	else
		self.crashText:SetText(string.format("%s in %s (zone %d).", cause, zoneName, world.zoneIndex))
	end

	self.timeLabel:SetText("Time survived " .. UI.FormatTime(world.time))
	self.timeValue:SetText(UI.FormatNumber(world.timePoints))
	local gemText = world.gems > 0 and string.format(" (%d gem%s)", world.gems, world.gems == 1 and "" or "s") or ""
	self.tokenLabel:SetText(string.format("Tokens %s%s", UI.FormatNumber(world.tokens), gemText))
	self.tokenValue:SetText(UI.FormatNumber(world.tokenPoints))
	-- A slow or fast start multiplies the total.
	local total = "Total"
	local multiplier = world.tuning.scoreMultiplier or 1
	if multiplier ~= 1 then
		for _, choice in ipairs(ns.Tuning.startSpeeds) do
			if choice.speed == world.tuning.baseSpeed then
				total = ("Total (%s start x%s)"):format(choice.name, tostring(multiplier))
			end
		end
	end
	if world.mode == "orc" then
		-- An orc run: Tauren dodged instead of moves, and no bosses.
		self.moveLabel:SetText(string.format("Tauren dodged %d", world.dodges or 0))
		self.bossLabel:SetText("Orc run: no bosses")
		self.totalLabel:SetText(Candle(total))
	else
		self.moveLabel:SetText(string.format("Jumps %d, ducks %d, knocks %d (best combo %d)", world.jumps or 0, world.ducks or 0, world.knocks or 0, world.bestCombo or 0))
		self.bossLabel:SetText(string.format("Bosses: %d driven off, %d outlasted (%d spear%s)", world.bossesDriven or 0, world.bossesSurvived or 0, world.spearHits or 0, world.spearHits == 1 and "" or "s"))
		self.totalLabel:SetText(total)
	end
	self.moveValue:SetText(UI.FormatNumber(world.movePoints or 0))
	self.bossValue:SetText(UI.FormatNumber(world.bossPoints or 0))
	self.totalValue:SetText(UI.FormatNumber(world.score))

	self.personalBadge:SetShown(personalRank ~= nil)
	self.personalText:SetText(personalRank and ("#" .. personalRank .. " personal") or "")
	self.guildBadge:SetShown(guildRank ~= nil)
	self.guildText:SetText(guildRank and ("#" .. guildRank .. " in guild") or "")
	if not personalRank then
		self.guildBadge:ClearAllPoints()
		self.guildBadge:SetPoint("TOPLEFT", self.personalBadge, "TOPLEFT")
	else
		self.guildBadge:ClearAllPoints()
		self.guildBadge:SetPoint("LEFT", self.personalBadge, "RIGHT", 8, 0)
	end
	self.bestText:SetText(isBest and "New personal best!" or "")

	self:ShowBoard(self.tab or "mine")
	self.over:Show()
end

function Screens:HideAll()
	self.start:Hide()
	self.paused:Hide()
	self.over:Hide()
end
