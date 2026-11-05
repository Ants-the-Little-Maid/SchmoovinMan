local _, ns = ...

-- Drawing helpers in the classic WoW style used by Forever: dialog-box frames,
-- tooltip-edged panels, red panel buttons and the standard status bar, all
-- from the client's own art (file IDs from the community listfile). If the
-- backdrop or button templates are missing, flat panels and buttons are drawn
-- instead.
local UI = {}
ns.UI = UI

local FONT = "Fonts\\FRIZQT__.TTF"

local function Hex(hex, alpha)
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, alpha or 1
end
UI.Hex = Hex

UI.COLORS = {
	window = "1a120b",
	titleBar = "2b1d10",
	border = "8a6b2f",
	gold = "ffd100",
	text = "f2e6cc",
	subText = "e0d2b4",
	label = "c9b38a",
	white = "ffffff",
	green = "b6e07f",
	orange = "ff9b5e",
	button = "3a2814",
	buttonPrimary = "8a1d12",
	close = "5a1a12",
	divider = "5a4424",
}

-- Fill colour and accent per power-up, from the mock-up.
UI.POWERUP_STYLE = {
	windRider = { name = "Wind Rider", color = "ffcf6e", track = "3f2c0c" },
	magnet = { name = "Magnet", color = "7fd1ff", track = "12303f" },
	goldRush = { name = "Gold Rush x2", color = "ffd100", track = "3f340c" },
	stampede = { name = "Stampede", color = "ff9b5e", track = "3f1f0c" },
	shield = { name = "Thick Hide", color = "b6e07f", track = "2a3a18" },
}

function UI.Text(parent, size, color, layer, outline)
	local text = parent:CreateFontString(nil, layer or "OVERLAY")
	text:SetFont(FONT, size, outline or "")
	text:SetTextColor(Hex(color or UI.COLORS.text))
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 0.8)
	return text
end

-- One-pixel border on all four sides.
function UI.Border(frame, color, thickness)
	thickness = thickness or 1
	local r, g, b, a = Hex(color or UI.COLORS.border)
	local edges = {}
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetColorTexture(r, g, b, a)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetPoint(side .. "LEFT")
			edge:SetPoint(side .. "RIGHT")
			edge:SetHeight(thickness)
		else
			edge:SetPoint("TOP" .. side)
			edge:SetPoint("BOTTOM" .. side)
			edge:SetWidth(thickness)
		end
		edges[side] = edge
	end
	frame.borderEdges = edges
	return edges
end

local ART = {
	dialogBackground = 131071, -- interface/dialogframe/ui-dialogbox-background.blp
	dialogBorder = 131072, -- interface/dialogframe/ui-dialogbox-border.blp
	dialogHeader = 131080, -- interface/dialogframe/ui-dialogbox-header.blp
	tooltipBackground = 137056, -- interface/tooltips/ui-tooltip-background.blp
	tooltipBorder = 137057, -- interface/tooltips/ui-tooltip-border.blp
	statusBar = 137012, -- interface/targetingframe/ui-statusbar.blp
	chatBubbleBackground = 137051, -- interface/tooltips/chatbubble-background.blp
	chatBubbleBorder = 137050, -- interface/tooltips/chatbubble-backdrop.blp
	chatBubbleTail = 137052, -- interface/tooltips/chatbubble-tail.blp
}
UI.ART = ART

UI.BACKDROPS = {
	dialog = {
		bgFile = ART.dialogBackground,
		edgeFile = ART.dialogBorder,
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	},
	tooltip = {
		bgFile = ART.tooltipBackground,
		edgeFile = ART.tooltipBorder,
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	},
	bubble = {
		bgFile = ART.chatBubbleBackground,
		edgeFile = ART.chatBubbleBorder,
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 16, right = 16, top = 16, bottom = 16 },
	},
}

-- The classic tooltip edge is grey; this warm tint matches the gold text.
local EDGE_TINT = "c9a96a"

-- A frame with a backdrop, or nil when the template isn't available.
function UI.BackdropFrame(parent, kind)
	if not (BackdropTemplateMixin and UI.BACKDROPS[kind]) then
		return nil
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, "BackdropTemplate")
	if not ok or not frame or not frame.SetBackdrop then
		return nil
	end
	frame:SetBackdrop(UI.BACKDROPS[kind])
	return frame
end

-- Tooltip-style panel. background / border are hex colours; alpha is the fill.
function UI.Panel(parent, background, alpha, border)
	local frame = UI.BackdropFrame(parent, "tooltip")
	if frame then
		frame:SetBackdropColor(Hex(background or "0c0804", alpha or 0.8))
		frame:SetBackdropBorderColor(Hex(border or EDGE_TINT))
		return frame
	end
	frame = CreateFrame("Frame", nil, parent)
	local fill = frame:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetColorTexture(Hex(background or "0c0804", alpha or 0.72))
	frame.fill = fill
	UI.Border(frame, border)
	return frame
end

-- Dialog-box panel: the classic stone-and-gold frame used by game dialogs.
function UI.Dialog(parent, alpha)
	local frame = UI.BackdropFrame(parent, "dialog")
	if frame then
		frame:SetBackdropColor(1, 1, 1, alpha or 1)
		return frame
	end
	return UI.Panel(parent, UI.COLORS.window, alpha or 0.95)
end

function UI.SetBorderColor(frame, color, alpha)
	if frame.SetBackdropBorderColor then
		local r, g, b = Hex(color)
		frame:SetBackdropBorderColor(r, g, b, alpha or 1)
		return
	end
	for _, edge in pairs(frame.borderEdges or {}) do
		edge:SetColorTexture(Hex(color, alpha))
	end
end

local function FlatButton(parent, label, primary, width, height)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	local fill = button:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetColorTexture(Hex(primary and UI.COLORS.buttonPrimary or UI.COLORS.button))
	button.fill = fill
	UI.Border(button, primary and UI.COLORS.gold or UI.COLORS.border, primary and 2 or 1)
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)
	local text = UI.Text(button, primary and 18 or 14, primary and UI.COLORS.gold or UI.COLORS.text)
	text:SetPoint("CENTER")
	text:SetText(label)
	button.text = text
	return button
end

-- The game's red panel button (gold text), or a flat one if the template's missing.
-- style "close" gives the round close (X) button.
function UI.Button(parent, label, style, width, height)
	if style == "close" then
		local ok, close = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
		if ok and close then
			return close
		end
	end
	width, height = width or 120, height or 44
	local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok or not button then
		return FlatButton(parent, label, style == "primary", width, height)
	end
	button:SetSize(width, height)
	button:SetText(label)
	local text = button:GetFontString()
	text:SetFont(FONT, style == "primary" and 18 or 13, "")
	button.text = text
	button.templated = true
	return button
end

-- Selected tabs stay lit, with white text; others use the normal gold.
function UI.SetTabSelected(button, selected)
	if button.templated then
		if selected then
			button:LockHighlight()
			button.text:SetTextColor(1, 1, 1)
		else
			button:UnlockHighlight()
			button.text:SetTextColor(Hex(UI.COLORS.gold))
		end
		return
	end
	if selected then
		button.fill:SetColorTexture(Hex(UI.COLORS.border))
		button.text:SetTextColor(Hex(UI.COLORS.window))
		UI.SetBorderColor(button, UI.COLORS.gold)
	else
		button.fill:SetColorTexture(Hex(UI.COLORS.titleBar))
		button.text:SetTextColor(Hex(UI.COLORS.text))
		UI.SetBorderColor(button, UI.COLORS.divider)
	end
end

-- A thin progress bar: track plus fill.
function UI.Bar(parent, height, fillColor, trackColor)
	local track = parent:CreateTexture(nil, "ARTWORK")
	track:SetHeight(height)
	track:SetColorTexture(Hex(trackColor or "3a2814"))
	local fill = parent:CreateTexture(nil, "OVERLAY")
	fill:SetHeight(height)
	fill:SetPoint("TOPLEFT", track, "TOPLEFT")
	fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
	-- The game's status bar art, tinted.
	fill:SetTexture(ART.statusBar)
	fill:SetVertexColor(Hex(fillColor or UI.COLORS.gold))
	local bar = { track = track, fill = fill }
	function bar:SetValue(fraction)
		fraction = math.max(0, math.min(1, fraction))
		local width = track:GetWidth()
		if fraction <= 0 or width <= 0 then
			fill:Hide()
		else
			fill:Show()
			fill:SetWidth(width * fraction)
		end
	end
	function bar:SetColors(fillHex, trackHex)
		fill:SetVertexColor(Hex(fillHex))
		track:SetColorTexture(Hex(trackHex))
	end
	return bar
end

function UI.FormatNumber(value)
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- mm:ss.t
function UI.FormatTime(seconds)
	local tenths = math.floor(seconds * 10 + 0.5)
	local minutes = math.floor(tenths / 600)
	local rest = (tenths - minutes * 600) / 10
	return string.format("%02d:%04.1f", minutes, rest)
end
