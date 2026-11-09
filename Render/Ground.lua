local _, ns = ...

-- Sky, ground and lane markings, drawn behind the transparent ModelScene.
--
-- The ground is a grid of cells fixed to the world, so it scrolls as the
-- runner moves. Each cell is a texture bent into perspective with
-- SetVertexOffset (as Decor Draft's Studio/Room.lua does). Two rules keep it
-- clean:
--   * Every cell shows a part of one texture tile (tex coords stay in 0-1),
--     so nothing relies on texture wrapping, which can streak.
--   * Cells are short near the camera. A bent quad is drawn as two triangles,
--     and a tall one shows a visible diagonal crease along that split.
local Ground = {}
Ground.__index = Ground
ns.Ground = Ground

-- The road runs from NEAR_Y (behind the runner) to FAR_Y. An orc run sets a
-- nearer edge further back (SetNear), since the road behind is in view.
local NEAR_Y, FAR_Y = -6, 110
-- World size of one texture tile, in yards. Row steps must divide it.
local TILE = 8
-- Row length at y yards past the near edge's usual place: short near the
-- camera, longer further off. Measured from the near edge, so a road that
-- starts further back keeps short rows by the camera and fits in MAX_ROWS.
local function RowStep(y)
	if y < 24 then
		return 1
	elseif y < 50 then
		return 2
	elseif y < 80 then
		return 4
	end
	return 8
end
local MAX_ROWS = 64

-- Columns across the track: grass, three road lanes, grass. Built from the
-- lane positions in Tuning, so widening the lanes widens the road.
local LANE_WIDTH = ns.Tuning.lanes[2] - ns.Tuning.lanes[1]
local ROAD_HALF = LANE_WIDTH * 1.5
local COLUMNS = {
	-- The outer cells stretch far out so the ground reaches the horizon's edges.
	{ left = -200, right = -ROAD_HALF - 16, kind = "ground" },
	{ left = -ROAD_HALF - 16, right = -ROAD_HALF - 8, kind = "ground" },
	{ left = -ROAD_HALF - 8, right = -ROAD_HALF, kind = "ground" },
	{ left = -ROAD_HALF, right = -ROAD_HALF + LANE_WIDTH, kind = "road" },
	{ left = -ROAD_HALF + LANE_WIDTH, right = ROAD_HALF - LANE_WIDTH, kind = "road" },
	{ left = ROAD_HALF - LANE_WIDTH, right = ROAD_HALF, kind = "road" },
	{ left = ROAD_HALF, right = ROAD_HALF + 8, kind = "ground" },
	{ left = ROAD_HALF + 8, right = ROAD_HALF + 16, kind = "ground" },
	{ left = ROAD_HALF + 16, right = 200, kind = "ground" },
}

-- Every distinct column edge, and which edges bound each column.
local EDGE_XS = {}
do
	local seen = {}
	for _, info in ipairs(COLUMNS) do
		for _, x in ipairs({ info.left, info.right }) do
			if not seen[x] then
				seen[x] = true
				tinsert(EDGE_XS, x)
			end
		end
	end
	table.sort(EDGE_XS)
	for _, info in ipairs(COLUMNS) do
		for index, x in ipairs(EDGE_XS) do
			if x == info.left then
				info.leftEdge = index
			elseif x == info.right then
				info.rightEdge = index
			end
		end
	end
end

-- Lane markings: dashed lines between lanes, solid lines at the road's edges.
local DIVIDERS = { -LANE_WIDTH / 2, LANE_WIDTH / 2 }
local EDGES = { -ROAD_HALF, ROAD_HALF }
local DASH_LENGTH, DASH_GAP = 2.5, 2.5
local LINE_WIDTH = 0.14
local EDGE_WIDTH = 0.22
local MAX_DASHES = 60

-- Each row's far edge reaches this many pixels into the next row, hiding hairline gaps.
local ROW_OVERLAP_PX = 1
local DEFAULT_GROUND_TINT = { 0.85, 0.85, 0.85 }


local VERTEX_UPPER_LEFT, VERTEX_LOWER_LEFT, VERTEX_UPPER_RIGHT, VERTEX_LOWER_RIGHT = 1, 2, 3, 4

local function Floor(value, step)
	return math.floor(value / step) * step
end

function Ground.Create(scene, layer)
	local self = setmetatable({}, Ground)
	self.scene = scene
	self.layer = layer
	self.near = NEAR_Y

	self.sky = layer:CreateTexture(nil, "BACKGROUND", nil, -8)
	self.sky:SetColorTexture(1, 1, 1, 1)
	self.horizonFill = layer:CreateTexture(nil, "BACKGROUND", nil, -7)
	self.horizonFill:SetColorTexture(1, 1, 1, 1)

	-- Flat ground and road colour under the cells, so any gap between them
	-- shows a matching colour rather than the fog behind.
	self.groundBacking = layer:CreateTexture(nil, "BACKGROUND", nil, -7)
	self.groundBacking:SetAllPoints()
	self.groundBacking:SetColorTexture(1, 1, 1, 1)
	self.roadBacking = layer:CreateTexture(nil, "BACKGROUND", nil, -7)
	self.roadBacking:SetAllPoints()
	self.roadBacking:SetColorTexture(1, 1, 1, 1)


	-- Two reused rows of projected column edges (near and far), swapped as rows advance.
	self.rowA = { x = {}, y = {}, ok = {} }
	self.rowB = { x = {}, y = {}, ok = {} }

	self.cells = {}
	for row = 1, MAX_ROWS do
		self.cells[row] = {}
		for column = 1, #COLUMNS do
			local cell = layer:CreateTexture(nil, "BACKGROUND", nil, -6)
			cell:SetAllPoints()
			cell:Hide()
			self.cells[row][column] = cell
		end
	end

	self.dashes = {}
	for index = 1, MAX_DASHES * #DIVIDERS do
		local dash = layer:CreateTexture(nil, "BACKGROUND", nil, -4)
		dash:SetAllPoints()
		dash:SetColorTexture(1, 1, 1, 1)
		dash:Hide()
		self.dashes[index] = dash
	end
	self.edges = {}
	for index = 1, #EDGES do
		local edge = layer:CreateTexture(nil, "BACKGROUND", nil, -4)
		edge:SetAllPoints()
		edge:SetColorTexture(1, 1, 1, 1)
		edge:Hide()
		self.edges[index] = edge
	end

	-- A fog band over the horizon hides where the ground ends.
	self.fogLow = layer:CreateTexture(nil, "BACKGROUND", nil, 2)
	self.fogLow:SetColorTexture(1, 1, 1, 1)
	self.fogHigh = layer:CreateTexture(nil, "BACKGROUND", nil, 2)
	self.fogHigh:SetColorTexture(1, 1, 1, 1)
	return self
end

local function Gradient(texture, bottom, top, bottomAlpha, topAlpha)
	if CreateColor then
		texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottomAlpha or 1), CreateColor(top[1], top[2], top[3], topAlpha or 1))
	else
		texture:SetVertexColor(bottom[1], bottom[2], bottom[3], bottomAlpha or 1)
	end
end

local function ApplySurface(texture, fileID, color)
	local ok = fileID and texture:SetTexture(fileID)
	if ok == false or not fileID then
		texture:SetColorTexture(color[1], color[2], color[3], 1)
		return false
	end
	texture:SetBlendMode("DISABLE")
	texture:SetVertexColor(1, 1, 1, 1)
	return true
end

function Ground:SetZone(zone)
	self.zone = zone
	local tint = zone.groundTint or DEFAULT_GROUND_TINT
	for row = 1, MAX_ROWS do
		for column, info in ipairs(COLUMNS) do
			local cell = self.cells[row][column]
			if info.kind == "road" then
				cell.tiled = ApplySurface(cell, zone.road, zone.roadColor)
			else
				cell.tiled = ApplySurface(cell, zone.ground, zone.groundColor)
				-- Grass a shade darker than the road, so the road stands out.
				if cell.tiled then
					cell:SetVertexColor(tint[1], tint[2], tint[3], 1)
				end
			end
		end
	end
	local ground, road = zone.groundColor, zone.roadColor
	self.groundBacking:SetVertexColor(ground[1] * tint[1], ground[2] * tint[2], ground[3] * tint[3], 1)
	self.roadBacking:SetVertexColor(road[1], road[2], road[3], 1)
	Gradient(self.sky, zone.sky.bottom, zone.sky.top)
	local fog = zone.fog.color
	self.horizonFill:SetVertexColor(fog[1], fog[2], fog[3], 1)
	Gradient(self.fogLow, fog, fog, 0, 1)
	Gradient(self.fogHigh, fog, fog, 1, 0)

	-- Markings: pale on dark roads, dark on pale ones (snow, salt flats).
	local road = zone.roadColor
	local light = (road[1] + road[2] + road[3]) / 3 > 0.55
	local r, g, b, a
	if light then
		r, g, b, a = 0.25, 0.2, 0.15, 0.75
	else
		r, g, b, a = 1, 0.95, 0.8, 0.8
	end
	for _, dash in ipairs(self.dashes) do
		dash:SetVertexColor(r, g, b, a)
	end
	for _, edge in ipairs(self.edges) do
		edge:SetVertexColor(r, g, b, a)
	end
end

-- Where the road starts, in yards from the runner (negative is behind); nil
-- for the usual place.
function Ground:SetNear(y)
	self.near = y or NEAR_Y
end

-- Corners in order: far-left, near-left, near-right, far-right, as frame
-- coordinates. Plain numbers, so drawing makes no tables.
function Ground:SetQuad(texture, flx, fly, nlx, nly, nrx, nry, frx, fry)
	local width, height = self.layer:GetSize()
	texture:SetVertexOffset(VERTEX_UPPER_LEFT, flx, fly - height)
	texture:SetVertexOffset(VERTEX_LOWER_LEFT, nlx, nly)
	texture:SetVertexOffset(VERTEX_LOWER_RIGHT, nrx - width, nry)
	texture:SetVertexOffset(VERTEX_UPPER_RIGHT, frx - width, fry - height)
	texture:Show()
end

-- A flat strip on the ground from x1 to x2 and y1 (near) to y2 (far).
function Ground:Strip(texture, x1, x2, y1, y2)
	local scene = self.scene
	local flx, fly = scene:Project(x1, y2, 0)
	local nlx, nly = scene:Project(x1, y1, 0)
	local nrx, nry = scene:Project(x2, y1, 0)
	local frx, fry = scene:Project(x2, y2, 0)
	if flx and nlx and nrx and frx then
		self:SetQuad(texture, flx, fly, nlx, nly, nrx, nry, frx, fry)
		return true
	end
	texture:Hide()
	return false
end

-- Projects every column edge at ground distance y into reused arrays.
function Ground:ProjectRow(y, xs, ys, ok)
	local scene = self.scene
	for index, x in ipairs(EDGE_XS) do
		local px, py = scene:Project(x, y, 0)
		ok[index] = px ~= nil
		xs[index], ys[index] = px or 0, py or 0
	end
end

function Ground:DrawSky()
	local width, height = self.layer:GetSize()
	local _, horizonY = self.scene:Project(0, FAR_Y, 0)
	horizonY = math.max(0, math.min(height, horizonY or height * 0.6))

	self.sky:ClearAllPoints()
	self.sky:SetPoint("TOPLEFT", self.layer, "TOPLEFT", 0, 0)
	self.sky:SetPoint("BOTTOMRIGHT", self.layer, "BOTTOMRIGHT", 0, horizonY)
	self.horizonFill:ClearAllPoints()
	self.horizonFill:SetPoint("TOPLEFT", self.layer, "BOTTOMLEFT", 0, horizonY)
	self.horizonFill:SetPoint("BOTTOMRIGHT", self.layer, "BOTTOMRIGHT", 0, 0)
	local fogSize = height * 0.07
	self.fogLow:ClearAllPoints()
	self.fogLow:SetPoint("BOTTOMLEFT", self.layer, "BOTTOMLEFT", 0, horizonY - fogSize)
	self.fogLow:SetPoint("TOPRIGHT", self.layer, "BOTTOMRIGHT", 0, horizonY)
	self.fogHigh:ClearAllPoints()
	self.fogHigh:SetPoint("BOTTOMLEFT", self.layer, "BOTTOMLEFT", 0, horizonY)
	self.fogHigh:SetPoint("TOPRIGHT", self.layer, "BOTTOMRIGHT", 0, horizonY + fogSize)
end

function Ground:DrawCells(distance)
	-- Row edges sit on world positions (y + distance) aligned to their step,
	-- so no row crosses a tile boundary. Each edge is projected once and
	-- shared by the rows either side of it.
	local near, far = self.rowA, self.rowB
	local nearY = self.near
	self:ProjectRow(nearY, near.x, near.y, near.ok)
	local row = 0
	local world = nearY + distance
	local y = nearY
	while y < FAR_Y and row < MAX_ROWS do
		local step = RowStep(y - nearY + NEAR_Y)
		local nextWorld = Floor(world, step) + step
		local nextY = nextWorld - distance
		row = row + 1
		self:ProjectRow(nextY, far.x, far.y, far.ok)
		local vNear = (world % TILE) / TILE
		local vFar = vNear + (nextWorld - world) / TILE
		for column, info in ipairs(COLUMNS) do
			local cell = self.cells[row][column]
			local l, r = info.leftEdge, info.rightEdge
			if near.ok[l] and near.ok[r] and far.ok[l] and far.ok[r] then
				-- The far edge reaches ROW_OVERLAP_PX up into the next row, hiding hairline gaps.
				self:SetQuad(cell, far.x[l], far.y[l] + ROW_OVERLAP_PX, near.x[l], near.y[l], near.x[r], near.y[r], far.x[r], far.y[r] + ROW_OVERLAP_PX)
				if cell.tiled then
					-- Road lanes share one tile across; each grass cell shows a whole tile.
					local uLeft, uRight = 0, 1
					if info.kind == "road" then
						uLeft = (info.left + ROAD_HALF) / TILE
						uRight = uLeft + (info.right - info.left) / TILE
					end
					-- Texture v runs top to bottom; the far edge is the top.
					cell:SetTexCoord(uLeft, 1 - vFar, uLeft, 1 - vNear, uRight, 1 - vFar, uRight, 1 - vNear)
				end
			else
				cell:Hide()
			end
		end
		near, far = far, near
		world, y = nextWorld, nextY
	end
	for unused = row + 1, MAX_ROWS do
		for column = 1, #COLUMNS do
			self.cells[unused][column]:Hide()
		end
	end
end

function Ground:DrawMarkings(distance)
	-- Dashes are fixed to the world, so they stream toward the runner.
	local period = DASH_LENGTH + DASH_GAP
	local nearY = self.near
	local used = 0
	for _, x in ipairs(DIVIDERS) do
		local start = Floor(nearY + distance, period) - distance
		local y = start
		while y < FAR_Y * 0.8 and used < #self.dashes do
			local y1, y2 = math.max(y, nearY), y + DASH_LENGTH
			if y2 > nearY then
				used = used + 1
				self:Strip(self.dashes[used], x - LINE_WIDTH, x + LINE_WIDTH, y1, y2)
			end
			y = y + period
		end
	end
	for unused = used + 1, #self.dashes do
		self.dashes[unused]:Hide()
	end
	-- Edges are flat colour, so one long strip shows no crease.
	for index, x in ipairs(EDGES) do
		self:Strip(self.edges[index], x - EDGE_WIDTH, x + EDGE_WIDTH, nearY, FAR_Y * 0.8)
	end
end

-- Red marks where a boss's throws will land: markers = { count, [i] = { x, y,
-- halfWidth, halfDepth, alpha } }. Drawn over the road, under the models.
function Ground:DrawMarkers(markers)
	self.markers = self.markers or {}
	local textures = self.markers
	local drawable = self.scene.calibrated
	for index = 1, markers.count do
		local marker = markers[index]
		local texture = textures[index]
		if not texture then
			texture = self.layer:CreateTexture(nil, "BACKGROUND", nil, -3)
			texture:SetAllPoints()
			texture:SetColorTexture(1, 1, 1, 1)
			textures[index] = texture
		end
		if not drawable then
			texture:Hide()
		elseif self:Strip(texture, marker.x - marker.halfWidth, marker.x + marker.halfWidth, marker.y - marker.halfDepth, marker.y + marker.halfDepth) then
			texture:SetVertexColor(0.88, 0.21, 0.16, marker.alpha)
		end
	end
	for index = markers.count + 1, #textures do
		textures[index]:Hide()
	end
end

function Ground:Draw(distance)
	local width, height = self.layer:GetSize()
	if width <= 0 or height <= 0 or not self.scene.calibrated then
		return
	end
	self:DrawSky()
	self:Strip(self.groundBacking, -200, 200, self.near, FAR_Y)
	self:Strip(self.roadBacking, -ROAD_HALF, ROAD_HALF, self.near, FAR_Y)
	self:DrawCells(distance)
	self:DrawMarkings(distance)
end
