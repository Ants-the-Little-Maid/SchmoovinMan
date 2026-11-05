local _, ns = ...

-- In-run HUD, laid out as in the mock-up's live-run board: score top left,
-- timer and zone top centre, tokens top right, power-up bars down the left,
-- key reminder bottom right and the zone banner in the middle.
local Hud = {}
Hud.__index = Hud
ns.Hud = Hud

local UI = ns.UI
local POWERUP_ORDER = { "windRider", "goldRush", "magnet", "stampede" }

function Hud.Create(layer)
	local self = setmetatable({}, Hud)
	self.layer = layer
	local C = UI.COLORS

	-- Score.
	local score = UI.Panel(layer)
	score:SetPoint("TOPLEFT", 14, -12)
	score:SetSize(170, 74)
	local scoreLabel = UI.Text(score, 11, C.label)
	scoreLabel:SetPoint("TOPLEFT", 14, -9)
	scoreLabel:SetText("SCORE")
	self.score = UI.Text(score, 26, C.gold)
	self.score:SetPoint("TOPLEFT", scoreLabel, "BOTTOMLEFT", 0, -3)
	self.best = UI.Text(score, 12, C.subText)
	self.best:SetPoint("TOPLEFT", self.score, "BOTTOMLEFT", 0, -3)

	-- Timer, zone, next-zone bar and speed.
	-- Kept light so it doesn't pull the eye from the track: a faint panel,
	-- no border, the time and one line of zone details.
	local timer = UI.Panel(layer, "0c0804", 0.35, "0c0804")
	UI.SetBorderColor(timer, "000000", 0)
	timer:SetPoint("TOP", 0, -8)
	timer:SetSize(250, 50)
	self.time = UI.Text(timer, 19, C.white)
	self.time:SetPoint("TOP", 0, -6)
	self.time:SetAlpha(0.9)
	self.zone = UI.Text(timer, 10, C.subText)
	self.zone:SetPoint("TOP", self.time, "BOTTOM", 0, -3)
	self.zone:SetAlpha(0.85)
	self.zoneBar = UI.Bar(timer, 2, C.gold, "2a1d10")
	self.zoneBar.track:SetPoint("BOTTOMLEFT", 30, 6)
	self.zoneBar.track:SetPoint("BOTTOMRIGHT", -30, 6)
	self.zoneBar.fill:SetAlpha(0.8)

	-- Tokens.
	local tokens = UI.Panel(layer)
	tokens:SetPoint("TOPRIGHT", -14, -12)
	tokens:SetSize(120, 56)
	local coin = tokens:CreateTexture(nil, "ARTWORK")
	coin:SetSize(28, 28)
	coin:SetPoint("LEFT", 12, 0)
	coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	self.tokens = UI.Text(tokens, 22, C.white)
	self.tokens:SetPoint("TOPLEFT", coin, "TOPRIGHT", 10, 1)
	local tokensLabel = UI.Text(tokens, 11, C.subText)
	tokensLabel:SetPoint("TOPLEFT", self.tokens, "BOTTOMLEFT", 0, -2)
	tokensLabel:SetText("tokens")

	-- Power-up bars, stacked under the score.
	self.powerups = {}
	for index, role in ipairs(POWERUP_ORDER) do
		local style = UI.POWERUP_STYLE[role]
		local panel = UI.Panel(layer, nil, nil, style.color)
		panel:SetSize(190, 40)
		local name = UI.Text(panel, 13, style.color)
		name:SetPoint("TOPLEFT", 10, -7)
		name:SetText(style.name)
		local left = UI.Text(panel, 13, C.text)
		left:SetPoint("TOPRIGHT", -10, -7)
		local bar = UI.Bar(panel, 5, style.color, style.track)
		bar.track:SetPoint("BOTTOMLEFT", 10, 8)
		bar.track:SetPoint("BOTTOMRIGHT", -10, 8)
		panel:Hide()
		self.powerups[role] = { panel = panel, left = left, bar = bar, order = index }
	end
	local shield = UI.Panel(layer, nil, nil, UI.POWERUP_STYLE.shield.color)
	shield:SetSize(190, 30)
	local shieldName = UI.Text(shield, 13, UI.POWERUP_STYLE.shield.color)
	shieldName:SetPoint("LEFT", 10, 0)
	shieldName:SetText("Thick Hide")
	local shieldLeft = UI.Text(shield, 13, C.text)
	shieldLeft:SetPoint("RIGHT", -10, 0)
	shieldLeft:SetText("1 hit")
	shield:Hide()
	self.shield = shield

	-- Key reminder.
	local hint = UI.Panel(layer, "0c0804", 0.6, "0c0804")
	hint:SetPoint("BOTTOMRIGHT", -14, 12)
	local hintText = UI.Text(hint, 11, C.subText)
	hintText:SetPoint("CENTER")
	hint:SetSize(260, 22)
	self.hint, self.hintText = hint, hintText

	-- Zone banner.
	local banner = CreateFrame("Frame", nil, layer)
	banner:SetSize(520, 110)
	banner:SetPoint("TOP", 0, -168)
	local bannerFill = banner:CreateTexture(nil, "BACKGROUND")
	bannerFill:SetAllPoints()
	bannerFill:SetColorTexture(1, 1, 1, 1)
	bannerFill:SetGradient("HORIZONTAL", CreateColor(0.05, 0.03, 0.02, 0), CreateColor(0.05, 0.03, 0.02, 0.8))
	local bannerFillRight = banner:CreateTexture(nil, "BACKGROUND")
	bannerFillRight:SetPoint("TOPLEFT", banner, "TOP")
	bannerFillRight:SetPoint("BOTTOMRIGHT")
	bannerFillRight:SetColorTexture(1, 1, 1, 1)
	bannerFillRight:SetGradient("HORIZONTAL", CreateColor(0.05, 0.03, 0.02, 0.8), CreateColor(0.05, 0.03, 0.02, 0))
	bannerFill:ClearAllPoints()
	bannerFill:SetPoint("TOPLEFT")
	bannerFill:SetPoint("BOTTOMRIGHT", banner, "BOTTOM")
	local entering = UI.Text(banner, 13, C.label)
	entering:SetPoint("TOP", 0, -14)
	entering:SetText("ENTERING")
	self.bannerName = UI.Text(banner, 38, C.gold, nil, "OUTLINE")
	self.bannerName:SetPoint("TOP", entering, "BOTTOM", 0, -6)
	self.bannerSpeed = UI.Text(banner, 15, C.orange)
	self.bannerSpeed:SetPoint("TOP", self.bannerName, "BOTTOM", 0, -6)
	banner:SetAlpha(0)
	self.banner = banner
	self.bannerUntil = 0

	self:SetHint(ns.Tuning.duckEnabled)
	return self
end

function Hud:SetHint(duckEnabled)
	self.hintText:SetText(duckEnabled and "A/D lanes  -  W jump  -  S duck  -  Esc pause" or "A/D lanes  -  W jump  -  Esc pause")
	self.hint:SetWidth(self.hintText:GetStringWidth() + 24)
end

function Hud:ShowBanner(zoneName, fromSpeed, toSpeed, now)
	self.bannerName:SetText(zoneName)
	if fromSpeed then
		self.bannerSpeed:SetText(string.format("Speed up! %.1f -> %.1f yd/s", fromSpeed, toSpeed))
	else
		self.bannerSpeed:SetText("")
	end
	self.bannerShownAt = now
	self.bannerUntil = now + 3
end

function Hud:SetShown(shown)
	self.layer:SetShown(shown)
end

function Hud:Update(world, best, zoneName, now)
	local tuning = world.tuning
	self.score:SetText(UI.FormatNumber(world.score))
	if best and world.score > best then
		self.best:SetText("New best!")
		self.best:SetTextColor(UI.Hex(UI.COLORS.green))
	else
		self.best:SetText("Best " .. UI.FormatNumber(best or 0))
		self.best:SetTextColor(UI.Hex(UI.COLORS.subText))
	end
	self.time:SetText(UI.FormatTime(world.time))
	local intoZone = world.time - world.zoneStart
	self.zoneBar:SetValue(intoZone / tuning.zoneLength)
	local left = math.max(0, tuning.zoneLength - intoZone)
	self.zone:SetText(string.format("%s  -  zone %d  -  next in %d:%02d  -  %.1f yd/s", zoneName, world.zoneIndex, math.floor(left / 60), math.floor(left % 60), world.speed))
	self.tokens:SetText(UI.FormatNumber(world.tokens))

	-- Power-up bars, top to bottom in a fixed order.
	local anchor
	for _, role in ipairs(POWERUP_ORDER) do
		local item = self.powerups[role]
		local remaining = world.powerups[role]
		if remaining then
			item.panel:ClearAllPoints()
			if anchor then
				item.panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
			else
				item.panel:SetPoint("TOPLEFT", self.layer, "TOPLEFT", 14, -106)
			end
			item.panel:Show()
			item.left:SetText(string.format("%.1fs", remaining))
			item.bar:SetValue(remaining / tuning.durations[role])
			anchor = item.panel
		else
			item.panel:Hide()
		end
	end
	self.shield:ClearAllPoints()
	if anchor then
		self.shield:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
	else
		self.shield:SetPoint("TOPLEFT", self.layer, "TOPLEFT", 14, -106)
	end
	self.shield:SetShown(world.shield)

	-- Banner fades in and out.
	local alpha = 0
	if now < self.bannerUntil then
		local shown = now - self.bannerShownAt
		alpha = math.min(1, shown / 0.25, (self.bannerUntil - now) / 0.6)
	end
	self.banner:SetAlpha(alpha)
end
