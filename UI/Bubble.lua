local _, ns = ...

-- A speech bubble drawn with the game's own chat-bubble art (dark fill, light
-- edge, tail underneath), so it looks like a /say bubble. It can follow any
-- point on screen: the runner's head or a jogger's.
local Bubble = {}
Bubble.__index = Bubble
ns.Bubble = Bubble

local UI = ns.UI
local PADDING_X, PADDING_Y = 16, 12
local MAX_TEXT_WIDTH = 220

function Bubble.Create(layer)
	local self = setmetatable({}, Bubble)
	self.layer = layer

	local frame = UI.BackdropFrame(layer, "bubble")
	if frame then
		frame:SetBackdropColor(1, 1, 1, 1)
		frame:SetBackdropBorderColor(1, 1, 1, 1)
	else
		frame = UI.Panel(layer, "000000", 0.75, "ffffff")
	end
	frame:SetFrameLevel(layer:GetFrameLevel() + 5)
	frame:Hide()
	self.frame = frame

	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetPoint("CENTER")
	text:SetJustifyH("CENTER")
	text:SetWordWrap(true)
	self.text = text

	-- The chat bubble's tail, pointing down at the speaker.
	local tail = frame:CreateTexture(nil, "OVERLAY")
	tail:SetTexture(UI.ART.chatBubbleTail)
	tail:SetSize(16, 16)
	tail:SetPoint("TOP", frame, "BOTTOM", 0, 5)
	self.tail = tail
	return self
end

-- Shows text until untilTime, following whatever `anchor` returns (x, y in the
-- layer's units) each frame.
function Bubble:Say(text, untilTime, anchor)
	self.text:SetWidth(MAX_TEXT_WIDTH)
	self.text:SetText(text)
	local width = math.min(MAX_TEXT_WIDTH, self.text:GetStringWidth())
	self.text:SetWidth(width + 2)
	self.frame:SetSize(math.max(width + PADDING_X * 2, 48), self.text:GetStringHeight() + PADDING_Y * 2)
	self.untilTime = untilTime
	self.anchor = anchor
	self.frame:Show()
end

function Bubble:IsShown()
	return self.frame:IsShown()
end

function Bubble:Hide()
	self.untilTime = nil
	self.anchor = nil
	self.frame:Hide()
end

-- Keeps the bubble over its speaker; hides it when time is up or the speaker
-- has gone off screen.
function Bubble:Update(now)
	if not self.untilTime then
		return
	end
	local x, y
	if self.anchor then
		x, y = self.anchor()
	end
	if now >= self.untilTime or not x then
		self:Hide()
		return
	end
	self.frame:ClearAllPoints()
	self.frame:SetPoint("BOTTOM", self.layer, "BOTTOMLEFT", x, y + 14)
	-- Fade out over the last quarter second.
	self.frame:SetAlpha(math.min(1, (self.untilTime - now) / 0.25))
end
