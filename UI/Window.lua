local _, ns = ...

-- The 960 x 600 game window from the mock-up: title bar, then the 3D view
-- with the ground behind the model scene and the HUD and screens on top.
local Window = {}
ns.Window = Window

local UI = ns.UI
local WIDTH, HEIGHT, TITLE_HEIGHT = 960, 600, 30
-- The title bar's small buttons.
local BUTTON_FONT, BUTTON_FONT_SIZE = "Fonts\\FRIZQT__.TTF", 11

-- Window sizes, as a scale on the 960 x 600 layout so everything grows together.
Window.SIZES = {
	{ key = "small", label = "S", name = "Small", scale = 0.75 },
	{ key = "medium", label = "M", name = "Medium", scale = 1.0 },
	{ key = "large", label = "L", name = "Large", scale = 1.3 },
	{ key = "huge", label = "XL", name = "Extra large", scale = 1.6 },
}

function Window.ApplySize(frame, key)
	local chosen = Window.SIZES[2]
	for _, size in ipairs(Window.SIZES) do
		if size.key == key then
			chosen = size
		end
	end
	-- Never bigger than the screen.
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local fit = math.min(screenWidth / WIDTH, screenHeight / HEIGHT) * 0.98
	local scale = math.min(chosen.scale, fit > 0 and fit or chosen.scale)
	frame:SetScale(scale)
	for sizeKey, button in pairs(frame.sizeButtons) do
		UI.SetTabSelected(button, sizeKey == chosen.key)
	end
	return chosen.key
end

-- Enables or greys out the Pause button and sets its label. The button
-- template swaps font objects when it's enabled or disabled, so the small
-- font goes back on after.
function Window.SetPauseButton(button, enabled, label)
	button:SetEnabled(enabled)
	button.text:SetText(label)
	button.text:SetFont(BUTTON_FONT, BUTTON_FONT_SIZE, "")
end

function Window.Create(controller)
	local frame = CreateFrame("Frame", "SchmoovinManFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	tinsert(UISpecialFrames, "SchmoovinManFrame")

	-- The classic dialog-box frame, with flat colours if backdrops aren't available.
	local inset = 2
	if frame.SetBackdrop then
		frame:SetBackdrop(UI.BACKDROPS.dialog)
		inset = 12
	else
		local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		background:SetAllPoints()
		background:SetColorTexture(UI.Hex(UI.COLORS.window))
		UI.Border(frame, UI.COLORS.border, 2)
	end

	-- Title bar: drag to move.
	local titleBar = CreateFrame("Frame", nil, frame)
	titleBar:SetPoint("TOPLEFT", inset, -inset)
	titleBar:SetPoint("TOPRIGHT", -inset, -inset)
	titleBar:SetHeight(TITLE_HEIGHT)
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	titleBar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
	end)
	local titleLine = titleBar:CreateTexture(nil, "BORDER")
	titleLine:SetPoint("BOTTOMLEFT")
	titleLine:SetPoint("BOTTOMRIGHT")
	titleLine:SetHeight(1)
	titleLine:SetColorTexture(UI.Hex(UI.COLORS.border, 0.6))

	-- Title on the classic header plate that sits over the top edge.
	local header = frame:CreateTexture(nil, "ARTWORK")
	header:SetTexture(UI.ART.dialogHeader)
	header:SetSize(320, 64)
	header:SetPoint("TOP", 0, 12)
	local title = UI.Text(frame, 14, UI.COLORS.gold)
	title:SetPoint("TOP", header, "TOP", 0, -14)
	title:SetText("Schmoovin Man")

	-- The round close button sits in the frame's corner, as on game dialogs.
	local close = UI.Button(frame, "X", "close", 26, 22)
	close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Pause sits at the left end, away from the size and close buttons; it
	-- reads "Resume" while paused.
	local pause = UI.Button(titleBar, "Pause", nil, 70, 22)
	pause.text:SetFont(BUTTON_FONT, BUTTON_FONT_SIZE, "")
	pause:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
	-- Greyed out outside a run (see Controller:UpdatePauseButton), with a
	-- tooltip that still says why.
	local function ShowPauseTip(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		if controller.state == "paused" then
			GameTooltip:SetText("Resume (P)")
		elseif controller.state == "running" and not controller.overAt then
			GameTooltip:SetText("Pause (Esc or P)")
		else
			GameTooltip:SetText("Pause: only during a run")
		end
		GameTooltip:Show()
	end
	pause:SetScript("OnClick", function(self)
		controller:TogglePause()
		-- The tooltip under the cursor follows the change.
		if GameTooltip:IsOwned(self) then
			ShowPauseTip(self)
		end
	end)
	pause:SetMotionScriptsWhileDisabled(true)
	pause:SetScript("OnEnter", ShowPauseTip)
	pause:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	frame.pauseButton = pause

	-- Window size choices, right to left so Small sits leftmost, clear of the
	-- close button in the corner.
	frame.sizeButtons = {}
	local anchor
	for index = #Window.SIZES, 1, -1 do
		local size = Window.SIZES[index]
		local button = UI.Button(titleBar, size.label, nil, 30, 22)
		button.text:SetFont(BUTTON_FONT, BUTTON_FONT_SIZE, "")
		if anchor then
			button:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
		else
			button:SetPoint("RIGHT", titleBar, "RIGHT", -34, 0)
		end
		button:SetScript("OnClick", function()
			controller:SetWindowSize(size.key)
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(size.name .. " window")
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		frame.sizeButtons[size.key] = button
		anchor = button
	end
	local sizeLabel = UI.Text(titleBar, 11, UI.COLORS.label)
	sizeLabel:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
	sizeLabel:SetText("Size")

	-- The view: ground layer, model scene, then HUD and screens.
	local view = CreateFrame("Frame", nil, frame)
	view:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
	view:SetPoint("BOTTOMRIGHT", -inset, inset)
	view:SetClipsChildren(true)
	frame.view = view

	local groundLayer = CreateFrame("Frame", nil, view)
	groundLayer:SetAllPoints()
	groundLayer:SetFrameLevel(view:GetFrameLevel() + 1)
	frame.groundLayer = groundLayer

	local sceneHolder = CreateFrame("Frame", nil, view)
	sceneHolder:SetAllPoints()
	sceneHolder:SetFrameLevel(view:GetFrameLevel() + 2)
	frame.sceneHolder = sceneHolder

	local hud = CreateFrame("Frame", nil, view)
	hud:SetAllPoints()
	hud:SetFrameLevel(view:GetFrameLevel() + 10)
	frame.hudLayer = hud

	local screens = CreateFrame("Frame", nil, view)
	screens:SetAllPoints()
	screens:SetFrameLevel(view:GetFrameLevel() + 20)
	frame.screenLayer = screens

	-- Brief fog-coloured flash that covers the swap on a zone change.
	local flash = hud:CreateTexture(nil, "BACKGROUND")
	flash:SetAllPoints()
	flash:SetColorTexture(1, 1, 1, 1)
	flash:SetAlpha(0)
	frame.flash = flash

	frame:SetScript("OnHide", function()
		controller:OnWindowHidden()
	end)
	frame:SetScript("OnShow", function()
		controller:OnWindowShown()
	end)
	return frame
end
