local _, ns = ...

-- Round minimap button, as in Dop's Decor Draft. Left-click opens or closes
-- the game, right-click opens a quick-start and settings menu, and dragging
-- moves it around the minimap's edge.
local BUTTON_SIZE = 31

-- Right-click menu: quick launch into a run, then the main settings. Uses the
-- game's own menu system (Blizzard_Menu, which Forever loads with its own skin).
local function BuildMenu(owner, root)
	local controller = ns.Controller
	local settings = ns.db.settings
	root:CreateTitle("Schmoovin Man")
	root:CreateButton("Start a run", function()
		controller:QuickStart()
	end)
	local shown = controller.frame and controller.frame:IsShown()
	root:CreateButton(shown and "Close game" or "Open game", function()
		controller:Toggle()
	end)
	root:CreateDivider()

	local zones = root:CreateButton("Zone length")
	for _, choice in ipairs(ns.Tuning.zoneLengths) do
		zones:CreateRadio(("%d s (%s)"):format(choice.seconds, choice.name), function()
			return ns.Tuning.zoneLength == choice.seconds
		end, function()
			ns.ChooseZoneLength(choice.seconds)
		end)
	end

	local speeds = root:CreateButton("Starting speed")
	for _, choice in ipairs(ns.Tuning.startSpeeds) do
		speeds:CreateRadio(ns.StartSpeedText(choice), function()
			return ns.Tuning.baseSpeed == choice.speed
		end, function()
			ns.ChooseStartSpeed(choice.speed)
		end)
	end

	local sizes = root:CreateButton("Window size")
	for _, size in ipairs(ns.Window.SIZES) do
		sizes:CreateRadio(size.name, function()
			return (settings.windowSize or "medium") == size.key
		end, function()
			controller:Build()
			controller:SetWindowSize(size.key)
		end)
	end

	root:CreateCheckbox("Ducking", function()
		return settings.duck ~= false
	end, function()
		ns.SetDuck(settings.duck == false)
	end)
	root:CreateCheckbox("Sound", function()
		return settings.sound
	end, function()
		ns.SetSound(not settings.sound)
	end)
	root:CreateDivider()
	root:CreateButton("Options...", function()
		controller:OpenOptions()
	end)
end

local function OpenMenu(button)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(button, BuildMenu)
	else
		-- No menu system: right-click still launches straight into a run.
		ns.Controller:QuickStart()
	end
end

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
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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

	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			GameTooltip:Hide()
			OpenMenu(self)
		else
			ns.Controller:Toggle()
		end
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
		GameTooltip:AddLine("Left-click: open or close", 1, 1, 1)
		GameTooltip:AddLine("Right-click: quick start and settings", 1, 1, 1)
		GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Reposition(button)
end)
