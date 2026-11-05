local _, ns = ...

-- Round minimap button, as in Dop's Decor Draft: click to open or close the
-- game, drag to move it around the minimap's edge.
local BUTTON_SIZE = 31
local RADIUS_OUTSIDE_EDGE = 5

local function Reposition(button)
	local angle = math.rad(ns.db.minimapAngle)
	local radius = Minimap:GetWidth() / 2 + RADIUS_OUTSIDE_EDGE
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor(button)
	local centerX, centerY = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	ns.db.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
	Reposition(button)
end

ns.OnLoaded(function()
	local button = CreateFrame("Button", "SchmoovinManMinimapButton", Minimap)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\Ability_Mount_Kodo_01")
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function()
		ns.Controller:Toggle()
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", FollowCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Schmoovin Man")
		GameTooltip:AddLine("Click to play. Drag to move.", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Reposition(button)
end)
