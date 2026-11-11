local _, ns = ...

-- The Options screen, over the start or pause screen (Esc or Done closes it).
-- Left: game settings. Right: for accessibility, the model each hazard,
-- charger, coin and gem uses in each zone, with a turning preview, so any
-- that are hard to see can be swapped (see Render/Models.lua).
local Options = {}
Options.__index = Options
ns.Options = Options

local UI = ns.UI
local FONT = "Fonts\\FRIZQT__.TTF"
-- Seconds the preview waits for a model before saying it isn't in the client.
local PREVIEW_TIMEOUT = 6
-- Preview models are fitted to this many yards tall and wide.
local PREVIEW_SIZE = 1.6
-- Longest wait for the geometry-ready signal before measuring anyway.
local GEO_WAIT = 1

local function SmallButton(parent, label, width, height)
	local button = UI.Button(parent, label, nil, width, height or 22)
	button.text:SetFont(FONT, 12, "")
	return button
end

local function SetLabel(button, text)
	button.text:SetText(text)
	button.text:SetFont(FONT, 12, "")
end

local function OnOff(value)
	return value and "On" or "Off"
end

-- The item in `list` after (step 1) or before (step -1) `current`, wrapping.
local function Step(list, current, step, same)
	for index, item in ipairs(list) do
		if same(item, current) then
			return list[(index - 1 + step) % #list + 1]
		end
	end
	return list[1]
end

function Options.Create(layer, controller)
	local self = setmetatable({}, Options)
	self.controller = controller
	local C = UI.COLORS

	local overlay = CreateFrame("Frame", nil, layer)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(layer:GetFrameLevel() + 30)
	overlay:EnableMouse(true)
	local dim = overlay:CreateTexture(nil, "BACKGROUND")
	dim:SetAllPoints()
	dim:SetColorTexture(0.047, 0.031, 0.016, 0.7)
	overlay:Hide()
	self.frame = overlay

	local box = UI.Dialog(overlay)
	box:SetPoint("CENTER")
	box:SetSize(900, 500)
	self.box = box

	local title = UI.Text(box, 24, C.gold)
	title:SetPoint("TOPLEFT", 24, -20)
	title:SetText("Options")

	local done = UI.Button(box, "Done", "primary", 130, 34)
	done:SetPoint("BOTTOMRIGHT", -20, 18)
	done:SetScript("OnClick", function()
		self:Hide()
	end)

	self:BuildGame(box)
	self:BuildModels(box)

	overlay:SetScript("OnUpdate", function(_, elapsed)
		self:UpdatePreview(elapsed)
	end)
	return self
end

-- Game settings --------------------------------------------------------------

function Options:BuildGame(box)
	local C = UI.COLORS
	local header = UI.Text(box, 15, C.gold)
	header:SetPoint("TOPLEFT", 24, -62)
	header:SetText("Game")

	local controller = self.controller
	local settings = function()
		return ns.db.settings
	end
	-- Each row: a label and a button that toggles or cycles the setting.
	local rows = {
		{
			label = "Sound",
			text = function() return OnOff(settings().sound) end,
			click = function() ns.SetSound(not settings().sound) end,
		},
		{
			label = "Ducking",
			text = function() return OnOff(settings().duck ~= false) end,
			click = function() ns.SetDuck(settings().duck == false) end,
		},
		{
			label = "Resume countdown",
			text = function() return OnOff(settings().countdown ~= false) end,
			click = function() ns.SetCountdown(settings().countdown == false) end,
		},
		{
			label = "Hazard markers",
			text = function() return OnOff(settings().markers == true) end,
			click = function() ns.SetMarkers(settings().markers ~= true) end,
		},
		{
			label = "Zone length",
			text = function()
				for _, choice in ipairs(ns.Tuning.zoneLengths) do
					if choice.seconds == ns.Tuning.zoneLength then
						return ("%d s (%s)"):format(choice.seconds, choice.name)
					end
				end
				return ""
			end,
			click = function()
				ns.CycleZoneLength()
				controller:RefreshStart()
			end,
		},
		{
			label = "Starting speed",
			text = function() return ns.StartSpeedText() end,
			click = function() ns.CycleStartSpeed() end,
		},
		{
			label = "Window size",
			text = function()
				for _, size in ipairs(ns.Window.SIZES) do
					if size.key == settings().windowSize then
						return size.name
					end
				end
				return ""
			end,
			click = function()
				local nextSize = Step(ns.Window.SIZES, settings().windowSize, 1, function(size, key)
					return size.key == key
				end)
				controller:SetWindowSize(nextSize.key)
			end,
		},
	}
	self.gameRows = {}
	for index, row in ipairs(rows) do
		local y = -92 - (index - 1) * 34
		local label = UI.Text(box, 13, C.text)
		label:SetPoint("TOPLEFT", 24, y - 4)
		label:SetText(row.label)
		local button = SmallButton(box, "", 210, 24)
		button:SetPoint("TOPLEFT", 170, y)
		button:SetScript("OnClick", function()
			row.click()
			ns.PlaySound("click")
			self:Refresh()
		end)
		row.button = button
		self.gameRows[index] = row
	end

	local note = UI.Text(box, 11, C.subText)
	note:SetPoint("TOPLEFT", 24, -92 - #rows * 34 - 6)
	note:SetWidth(360)
	note:SetJustifyH("LEFT")
	note:SetText("Ducking, zone length and starting speed apply from your next run. Slow starts score x0.75 and fast starts x1.25. The countdown gives you 3 seconds before a paused run goes on. Hazard markers put a mark on the road under each hazard: amber to jump, blue to duck, red to keep clear.")

	local line = box:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(UI.Hex(C.divider))
	line:SetWidth(1)
	line:SetPoint("TOPLEFT", 404, -60)
	line:SetPoint("BOTTOMLEFT", 404, 64)
end

-- Models -----------------------------------------------------------------------

function Options:BuildModels(box)
	local C = UI.COLORS
	local left = 424
	local header = UI.Text(box, 15, C.gold)
	header:SetPoint("TOPLEFT", left, -62)
	header:SetText("Models")
	local help = UI.Text(box, 11, C.subText)
	help:SetPoint("TOPLEFT", left, -82)
	help:SetWidth(450)
	help:SetJustifyH("LEFT")
	help:SetText("Swap any model that's hard to see, zone by zone. Your pick shows from now on; if it isn't in this client, the usual one shows instead.")

	-- Zone: < name >
	self.zoneIndex = 1
	local previous = SmallButton(box, "<", 26, 22)
	previous:SetPoint("TOPLEFT", left, -114)
	local nextZone = SmallButton(box, ">", 26, 22)
	nextZone:SetPoint("TOPLEFT", left + 254, -114)
	self.zoneName = UI.Text(box, 14, C.white)
	self.zoneName:SetPoint("CENTER", box, "TOPLEFT", left + 140, -125)
	previous:SetScript("OnClick", function()
		self.zoneIndex = (self.zoneIndex - 2) % #ns.Zones + 1
		self:Refresh()
	end)
	nextZone:SetScript("OnClick", function()
		self.zoneIndex = self.zoneIndex % #ns.Zones + 1
		self:Refresh()
	end)

	-- One row per role: label, < model name >. Clicking a row previews it.
	self.modelRows = {}
	for index, item in ipairs(ns.Models.ROLES) do
		local y = -146 - (index - 1) * 30
		local row = CreateFrame("Button", nil, box)
		row:SetPoint("TOPLEFT", left - 6, y + 3)
		row:SetSize(292, 28)
		local highlight = row:CreateTexture(nil, "BACKGROUND")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 0.82, 0, 0.12)
		highlight:Hide()
		row.highlight = highlight
		local label = UI.Text(row, 12, C.text)
		label:SetPoint("LEFT", 6, 0)
		label:SetText(item.label)
		local back = SmallButton(row, "<", 22, 20)
		back:SetPoint("LEFT", 102, 0)
		local forward = SmallButton(row, ">", 22, 20)
		forward:SetPoint("LEFT", 270, 0)
		-- Room for the longest names ("Skeletal Executioner").
		local name = UI.Text(row, 11, C.white)
		name:SetPoint("CENTER", row, "LEFT", 197, 0)
		name:SetWidth(142)
		name:SetWordWrap(false)
		row.name = name
		row.role = item.role
		row:SetScript("OnClick", function()
			self:Select(index)
		end)
		back:SetScript("OnClick", function()
			self:Cycle(index, -1)
		end)
		forward:SetScript("OnClick", function()
			self:Cycle(index, 1)
		end)
		self.modelRows[index] = row
	end
	self.selected = 1

	-- Puts back this zone's usual models.
	local reset = SmallButton(box, "Reset to Default", 292, 24)
	reset:SetPoint("TOPLEFT", left - 6, -146 - #ns.Models.ROLES * 30 - 4)
	reset:SetScript("OnClick", function()
		local zone = ns.Zones[self.zoneIndex]
		for _, item in ipairs(ns.Models.ROLES) do
			ns.Models.Pick(zone.key, item.role, nil)
		end
		ns.PlaySound("click")
		self:Refresh()
	end)

	-- Preview: the selected row's model, turning.
	local preview = CreateFrame("Frame", nil, box)
	preview:SetPoint("TOPLEFT", left + 300, -114)
	preview:SetSize(170, 230)
	local backing = preview:CreateTexture(nil, "BACKGROUND")
	backing:SetAllPoints()
	backing:SetColorTexture(0.1, 0.12, 0.1, 0.9)
	UI.Border(preview, C.divider)
	self.previewScene = ns.Scene.Create(preview)
	self.previewNote = UI.Text(preview, 11, C.subText)
	self.previewNote:SetPoint("BOTTOM", 0, 8)
	self.previewNote:SetWidth(150)
end

-- The zone shown, its choices for a role, and the one in use.
function Options:Current(role)
	local zone = ns.Zones[self.zoneIndex]
	local choices = ns.Models.Choices(zone, role)
	local picked = ns.Models.Picked(zone.key, role)
	local current = choices[1]
	for _, candidate in ipairs(choices) do
		if ns.Models.Key(candidate) == picked then
			current = candidate
		end
	end
	return zone, choices, current, picked ~= nil
end

function Options:Cycle(index, step)
	local role = self.modelRows[index].role
	local zone, choices, current = self:Current(role)
	local chosen = Step(choices, current, step, function(a, b)
		return a == b
	end)
	-- The first choice is the zone's usual model, which needs no pick.
	ns.Models.Pick(zone.key, role, chosen ~= choices[1] and ns.Models.Key(chosen) or nil)
	ns.PlaySound("click")
	self.selected = index
	self:Refresh()
end

function Options:Select(index)
	self.selected = index
	self:Refresh()
end

-- Shows a model in the preview.
function Options:ShowModel(candidate, role)
	local scene = self.previewScene
	if not self.previewActor then
		self.previewActor = scene:AcquireActor()
	end
	local actor = self.previewActor
	if not actor or self.previewCandidate == candidate then
		return
	end
	self.previewCandidate = candidate
	self.previewRole = role
	self.previewFit = nil
	self.previewSince = 0
	actor:SetAlpha(0)
	actor:ClearModel()
	local ok
	if candidate.displayID then
		ok = actor:SetModelByCreatureDisplayID(candidate.displayID)
	else
		ok = actor:SetModelByFileID(candidate.fileID)
	end
	self.previewFailed = ok == false
	self.previewNote:SetText(self.previewFailed and "Not in this client" or "Loading...")
end

-- Fits the preview model once it has loaded, then turns it.
function Options:UpdatePreview(elapsed)
	local actor = self.previewActor
	if not actor or not self.previewCandidate or self.previewFailed then
		return
	end
	self.previewSince = self.previewSince + elapsed
	local scene = self.previewScene
	-- As the main view does: until the frame is laid out, calibrating fails.
	if not scene.calibrated then
		scene:Calibrate()
	end
	if not self.previewFit then
		-- Measured once the geometry is in (or after a moment, as the renderer
		-- does: Forever can leave the signal false for props), not from a
		-- placeholder box.
		local streaming = actor.IsGeoReady and actor:IsGeoReady() == false and self.previewSince < GEO_WAIT
		if actor:IsLoaded() and not streaming then
			local minX, minY, minZ, maxX, maxY, maxZ = ns.Scene.GetActorBounds(actor, self.previewRole == "charger")
			if minX and maxZ - minZ > 0.01 then
				local size = math.max(maxX - minX, maxY - minY, maxZ - minZ)
				local scale = PREVIEW_SIZE / size
				self.previewFit = { scale = scale, z = -minZ * scale, cx = (minX + maxX) / 2, cy = (minY + maxY) / 2, height = (maxZ - minZ) * scale }
				self.previewNote:SetText("")
				scene:LookAt(0, 0, self.previewFit.height / 2, 4.2, math.rad(12))
			end
		end
		if not self.previewFit then
			if self.previewSince > PREVIEW_TIMEOUT then
				self.previewFailed = true
				self.previewNote:SetText("Not in this client")
			end
			return
		end
	end
	local fit = self.previewFit
	scene:Place(actor, 0, 0, fit.z, self.previewSince * 0.8, fit.scale, 0, 0, fit.cx, fit.cy)
	actor:SetAlpha(1)
end

-- Showing ------------------------------------------------------------------------

function Options:Refresh()
	for _, row in ipairs(self.gameRows) do
		SetLabel(row.button, row.text())
	end
	local zone = ns.Zones[self.zoneIndex]
	self.zoneName:SetText(zone.name)
	for index, row in ipairs(self.modelRows) do
		local _, _, current, picked = self:Current(row.role)
		row.name:SetText(current and (current.name or "?") or "-")
		row.name:SetTextColor(UI.Hex(picked and UI.COLORS.gold or UI.COLORS.white))
		row.highlight:SetShown(index == self.selected)
		if index == self.selected and current then
			self:ShowModel(current, row.role)
		end
	end
end

-- Opens on the zone being run (or the first) and its low hazard.
function Options:Show()
	local zoneKey = self.controller.zoneKey
	for index, zone in ipairs(ns.Zones) do
		if zone.key == zoneKey then
			self.zoneIndex = index
		end
	end
	self.frame:Show()
	if not self.previewScene.calibrated then
		self.previewScene:Calibrate()
	end
	self:Refresh()
end

function Options:Hide()
	if self.frame:IsShown() then
		self.frame:Hide()
		self.controller:OnOptionsClosed()
	end
end

function Options:IsShown()
	return self.frame:IsShown()
end
