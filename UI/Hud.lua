local _, ns = ...

-- In-run HUD. The middle of the road stays clear:
--   top left:   score, best, run time, zone, speed and the next-zone bar,
--               with the power-up bars stacked under it
--   top middle: one slim slot, empty in a normal run. Banners (entering a
--               zone, a boss turning up or leaving) show there, and so does
--               the boss bar during a fight, fading in as its banner goes
--   top right:  tokens
--   bottom right: key reminder
local Hud = {}
Hud.__index = Hud
ns.Hud = Hud

local UI = ns.UI
local POWERUP_ORDER = { "windRider", "goldRush", "magnet", "stampede" }
local LEFT_WIDTH = 190
local LEFT_HEIGHT = 120
-- Power-up bars start under the left panel (it sits 12 down), 8 below it.
local POWERUPS_TOP = -12 - LEFT_HEIGHT - 8
-- Boss bar: one pip per spear needed, up to this many.
local MAX_PIPS = 16
local BOSS_RED = "c0392b"
local BOSS_NAME = "ff9b8a"
local PIP_ON = "ff9b5e"
local PIP_OFF = "3a1410"

function Hud.Create(layer)
	local self = setmetatable({}, Hud)
	self.layer = layer
	local C = UI.COLORS

	-- Left panel: score and best, the run time beside the label, then the
	-- zone with its speed on the same row, time to the next zone (or that
	-- it's paused for a boss) and a thin bar of the zone so far.
	local panel = UI.Panel(layer)
	panel:SetPoint("TOPLEFT", 14, -12)
	panel:SetSize(LEFT_WIDTH, LEFT_HEIGHT)
	local scoreLabel = UI.Text(panel, 11, C.label)
	scoreLabel:SetPoint("TOPLEFT", 14, -9)
	scoreLabel:SetText("SCORE")
	self.time = UI.Text(panel, 15, C.white)
	self.time:SetPoint("TOPRIGHT", -12, -7)
	self.score = UI.Text(panel, 26, C.gold)
	self.score:SetPoint("TOPLEFT", scoreLabel, "BOTTOMLEFT", 0, -3)
	self.best = UI.Text(panel, 12, C.subText)
	self.best:SetPoint("TOPLEFT", self.score, "BOTTOMLEFT", 0, -3)
	local divider = panel:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(UI.Hex(C.divider))
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", 12, -72)
	divider:SetPoint("TOPRIGHT", -12, -72)
	-- Rows at fixed offsets, so each text has one anchor and the bar stays
	-- clear of the text above it. The speed shares the zone name's row, the
	-- shorter of the two lines.
	self.zone = UI.Text(panel, 11, C.text)
	self.zone:SetPoint("TOPLEFT", 14, -79)
	self.speed = UI.Text(panel, 11, C.subText)
	self.speed:SetPoint("TOPRIGHT", -12, -79)
	self.zoneNext = UI.Text(panel, 11, C.subText)
	self.zoneNext:SetPoint("TOPLEFT", 14, -95)
	self.zoneBar = UI.Bar(panel, 2, C.gold, "2a1d10")
	self.zoneBar.track:SetPoint("BOTTOMLEFT", 14, 8)
	self.zoneBar.track:SetPoint("BOTTOMRIGHT", -12, 8)
	self.zoneBar.fill:SetAlpha(0.8)

	-- Boss bar in the top slot: name and spears so far, a pip per spear
	-- needed (lit as they hit), the time until it gives up beside the pips and
	-- as a thin line along the bottom. See-through, as it sits over the sky
	-- and the far road where the boss stands.
	local boss = UI.Panel(layer, "1e0604", 0.5, BOSS_RED)
	boss:SetPoint("TOP", 0, -8)
	boss:SetSize(330, 42)
	self.bossName = UI.Text(boss, 14, BOSS_NAME)
	self.bossName:SetPoint("TOPLEFT", 12, -6)
	self.bossCount = UI.Text(boss, 11, C.text)
	self.bossCount:SetPoint("TOPRIGHT", -12, -8)
	self.bossLeft = UI.Text(boss, 11, C.subText)
	self.bossLeft:SetPoint("TOPRIGHT", -12, -24)
	self.pips = {}
	for index = 1, MAX_PIPS do
		local pip = boss:CreateTexture(nil, "ARTWORK")
		pip:SetHeight(7)
		pip:Hide()
		self.pips[index] = pip
	end
	self.bossTimer = UI.Bar(boss, 2, C.text, "3a1410")
	self.bossTimer.track:SetPoint("BOTTOMLEFT", 6, 4)
	self.bossTimer.track:SetPoint("BOTTOMRIGHT", -6, 4)
	self.bossTimer.fill:SetAlpha(0.7)
	boss:Hide()
	self.boss = boss
	self.pipCount = 0

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

	-- Power-up bars, stacked under the left panel.
	self.powerups = {}
	for index, role in ipairs(POWERUP_ORDER) do
		local style = UI.POWERUP_STYLE[role]
		local bar = UI.Panel(layer, nil, nil, style.color)
		bar:SetSize(LEFT_WIDTH, 40)
		local name = UI.Text(bar, 13, style.color)
		name:SetPoint("TOPLEFT", 10, -7)
		name:SetText(style.name)
		local left = UI.Text(bar, 13, C.text)
		left:SetPoint("TOPRIGHT", -10, -7)
		local fill = UI.Bar(bar, 5, style.color, style.track)
		fill.track:SetPoint("BOTTOMLEFT", 10, 8)
		fill.track:SetPoint("BOTTOMRIGHT", -10, 8)
		bar:Hide()
		self.powerups[role] = { panel = bar, left = left, bar = fill, order = index }
	end
	local shield = UI.Panel(layer, nil, nil, UI.POWERUP_STYLE.shield.color)
	shield:SetSize(LEFT_WIDTH, 30)
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

	-- Banner, in the top slot: a short label, a title and one line, on a
	-- backing that fades out to both sides.
	local banner = CreateFrame("Frame", nil, layer)
	banner:SetSize(520, 72)
	banner:SetPoint("TOP", 0, -6)
	local bannerFill = banner:CreateTexture(nil, "BACKGROUND")
	bannerFill:SetPoint("TOPLEFT")
	bannerFill:SetPoint("BOTTOMRIGHT", banner, "BOTTOM")
	bannerFill:SetColorTexture(1, 1, 1, 1)
	local bannerFillRight = banner:CreateTexture(nil, "BACKGROUND")
	bannerFillRight:SetPoint("TOPLEFT", banner, "TOP")
	bannerFillRight:SetPoint("BOTTOMRIGHT")
	bannerFillRight:SetColorTexture(1, 1, 1, 1)
	self.bannerFills = { bannerFill, bannerFillRight }
	self.bannerLabel = UI.Text(banner, 11, C.label)
	self.bannerLabel:SetPoint("TOP", 0, -7)
	self.bannerName = UI.Text(banner, 26, C.gold, nil, "OUTLINE")
	self.bannerName:SetPoint("TOP", self.bannerLabel, "BOTTOM", 0, -3)
	self.bannerLine = UI.Text(banner, 13, C.orange)
	self.bannerLine:SetPoint("TOP", self.bannerName, "BOTTOM", 0, -3)
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

-- Banner styles: label colour, line colour and backing tint.
local BANNER_STYLE = {
	zone = { label = UI.COLORS.label, line = UI.COLORS.orange, tint = { 0.05, 0.03, 0.02 } },
	boss = { label = BOSS_NAME, line = UI.COLORS.text, tint = { 0.12, 0.02, 0.016 } },
	won = { label = UI.COLORS.green, line = UI.COLORS.text, tint = { 0.05, 0.03, 0.02 } },
}

function Hud:ShowMessage(style, label, title, line, now)
	style = BANNER_STYLE[style]
	self.bannerLabel:SetText(label)
	self.bannerLabel:SetTextColor(UI.Hex(style.label))
	self.bannerName:SetText(title)
	self.bannerLine:SetText(line or "")
	self.bannerLine:SetTextColor(UI.Hex(style.line))
	local r, g, b = style.tint[1], style.tint[2], style.tint[3]
	self.bannerFills[1]:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.8))
	self.bannerFills[2]:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.8), CreateColor(r, g, b, 0))
	self.bannerShownAt = now
	self.bannerUntil = now + 3
end

function Hud:ShowBanner(zoneName, fromSpeed, toSpeed, now)
	local line = fromSpeed and string.format("Speed up! %.1f -> %.1f yd/s", fromSpeed, toSpeed) or ""
	self:ShowMessage("zone", "ENTERING", zoneName, line, now)
end

local function Clock(seconds)
	seconds = math.ceil(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The boss bar; `alpha` lets it give way to a banner in the same slot.
function Hud:UpdateBoss(world, alpha)
	local fight = world.boss
	if not world:InFight() then
		self.boss:Hide()
		return
	end
	self.boss:Show()
	self.boss:SetAlpha(alpha)
	self.bossName:SetText(fight.name)
	self.bossCount:SetText(string.format("%d of %d spears", fight.hits, fight.needed))
	-- Pips share the row left of the countdown, laid out again only when the
	-- count changes.
	local count = math.min(fight.needed, MAX_PIPS)
	if count ~= self.pipCount then
		self.pipCount = count
		self.pipLit = nil
		local gap = 4
		local width = (self.boss:GetWidth() - 24 - 44 - gap * (count - 1)) / count
		for index, pip in ipairs(self.pips) do
			pip:ClearAllPoints()
			if index <= count then
				pip:SetWidth(width)
				pip:SetPoint("TOPLEFT", 12 + (index - 1) * (width + gap), -26)
				pip:Show()
			else
				pip:Hide()
			end
		end
	end
	-- More spears needed than pips: each pip stands for a share of them.
	-- Coloured again only when that changes.
	local lit = fight.needed > count and math.floor(fight.hits * count / fight.needed) or fight.hits
	if lit ~= self.pipLit then
		self.pipLit = lit
		for index = 1, count do
			self.pips[index]:SetColorTexture(UI.Hex(index <= lit and PIP_ON or PIP_OFF))
		end
	end
	local left = math.max(0, fight.ends - world.time)
	self.bossTimer:SetValue(left / world.tuning.boss.limit)
	self.bossLeft:SetText(Clock(left))
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
	-- Zones follow the zone clock, which stops while a boss is out.
	local intoZone = world.course - world.zoneStart
	self.zoneBar:SetValue(intoZone / tuning.zoneLength)
	self.zone:SetText(zoneName)
	self.speed:SetText(string.format("%.1f yd/s", world.speed))
	if world:InFight() then
		self.zoneNext:SetText(string.format("Zone %d - paused", world.zoneIndex))
	else
		self.zoneNext:SetText(string.format("Zone %d - next in %s", world.zoneIndex, Clock(math.max(0, tuning.zoneLength - intoZone))))
	end
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
				item.panel:SetPoint("TOPLEFT", self.layer, "TOPLEFT", 14, POWERUPS_TOP)
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
		self.shield:SetPoint("TOPLEFT", self.layer, "TOPLEFT", 14, POWERUPS_TOP)
	end
	self.shield:SetShown(world.shield)

	-- Banner fades in and out; the boss bar shares its slot, so it shows as
	-- the banner goes.
	local alpha = 0
	if now < self.bannerUntil then
		local shown = now - self.bannerShownAt
		alpha = math.min(1, shown / 0.25, (self.bannerUntil - now) / 0.6)
	end
	self.banner:SetAlpha(alpha)
	self:UpdateBoss(world, 1 - alpha)
end
