local _, ns = ...

-- A ModelScene with a fixed chase camera, adapted from Dop's Decor Draft's
-- Studio/Scene.lua (camera, projection calibration, actor pool, transforms).
local Scene = {}
Scene.__index = Scene
ns.Scene = Scene

local ACTOR_TEMPLATE = "SchmoovinManActorTemplate"
local FIELD_OF_VIEW = 0.95
Scene.FIELD_OF_VIEW = FIELD_OF_VIEW

function Scene.Create(parent)
	local self = setmetatable({}, Scene)

	local frame = CreateFrame("ModelScene", nil, parent)
	frame:SetAllPoints()
	frame:SetCameraFieldOfView(FIELD_OF_VIEW)
	frame:SetCameraNearClip(0.2)
	frame:SetCameraFarClip(400)
	frame:SetLightVisible(true)
	frame:SetLightType(Enum.ModelLightType.Directional)
	self.frame = frame

	self.freeActors = {}
	self.targetX, self.targetY, self.targetZ = 0, 8, 1.2
	self.distance = 11
	self.yaw = math.pi / 2
	self.pitch = math.rad(17)
	self.pitchSign = 1
	self.fov = FIELD_OF_VIEW
	self.xSign = 1
	self.projectionMode = "local"
	self.flipProjectedY = false

	frame:SetScript("OnSizeChanged", function()
		self:Calibrate()
	end)
	return self
end

function Scene:SetLighting(light)
	local frame = self.frame
	frame:SetLightAmbientColor(light.ambient[1], light.ambient[2], light.ambient[3])
	frame:SetLightDiffuseColor(light.diffuse[1], light.diffuse[2], light.diffuse[3])
end

-- lift: yards to push the fog back by, keeping its depth (see Renderer:UpdateFog).
function Scene:SetFog(fog, lift)
	local frame = self.frame
	if frame.SetFogColor then
		lift = lift or 0
		frame:SetFogColor(fog.color[1], fog.color[2], fog.color[3])
		frame:SetFogNear(fog.near + lift)
		frame:SetFogFar(fog.far + lift)
	end
end

-- Camera ---------------------------------------------------------------------

-- Looks at (x, y, z) in game space from behind and above.
function Scene:LookAt(x, y, z, distance, pitch)
	self.targetX, self.targetY, self.targetZ = x, y, z
	self.distance = distance or self.distance
	self.pitch = pitch or self.pitch
	self:ApplyCamera()
end

function Scene:ApplyCamera()
	local frame = self.frame
	frame:SetCameraOrientationByYawPitchRoll(self.yaw, self.pitch * self.pitchSign, 0)
	local forwardX, forwardY, forwardZ = frame:GetCameraForward()
	local tx = self.targetX * self.xSign
	frame:SetCameraPosition(tx - forwardX * self.distance, self.targetY - forwardY * self.distance, self.targetZ - forwardZ * self.distance)
	frame:SetLightDirection(forwardX * 0.6 + 0.3, forwardY, forwardZ - 0.4)
end

function Scene:SetFieldOfView(fov)
	if fov ~= self.fov then
		self.fov = fov
		self.frame:SetCameraFieldOfView(fov)
	end
end

-- Projection -----------------------------------------------------------------

-- Works out the pitch sign, which way +x appears on screen, and the units
-- Project3DPointTo2D returns, as Decor Draft does.
function Scene:Calibrate()
	local frame = self.frame
	local width, height = frame:GetSize()
	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if width <= 0 or height <= 0 or not left or not bottom then
		return false
	end

	frame:SetCameraOrientationByYawPitchRoll(self.yaw, math.abs(self.pitch), 0)
	local _, _, forwardZ = frame:GetCameraForward()
	self.pitchSign = forwardZ > 0 and -1 or 1
	self.xSign = 1
	self:ApplyCamera()

	local px, py = frame:Project3DPointTo2D(self.targetX, self.targetY, self.targetZ)
	if not px then
		return false
	end
	local scale = frame:GetEffectiveScale()
	local candidates = {
		{ mode = "local", x = width / 2, y = height / 2 },
		{ mode = "localScaled", x = width * scale / 2, y = height * scale / 2 },
		{ mode = "screen", x = left + width / 2, y = bottom + height / 2 },
		{ mode = "screenScaled", x = (left + width / 2) * scale, y = (bottom + height / 2) * scale },
		{ mode = "normalized", x = 0.5, y = 0.5 },
	}
	local best, bestError
	for _, candidate in ipairs(candidates) do
		local errorSize = math.abs(px - candidate.x) + math.abs(py - candidate.y)
		if not bestError or errorSize < bestError then
			best, bestError = candidate, errorSize
		end
	end
	self.projectionMode = best.mode
	self.flipProjectedY = false

	local centerX, centerY = self:ProjectRaw(self.targetX, self.targetY, self.targetZ)
	local rightX = self:ProjectRaw(self.targetX + 1, self.targetY, self.targetZ)
	local _, upY = self:ProjectRaw(self.targetX, self.targetY, self.targetZ + 1)
	if upY and centerY and upY < centerY then
		self.flipProjectedY = true
	end
	-- Game lanes run left to right; mirror the world if +x shows on the left.
	if rightX and centerX and rightX < centerX then
		self.xSign = -1
	end
	self:ApplyCamera()
	self.calibrated = true
	return true
end

function Scene:ProjectRaw(x, y, z)
	local frame = self.frame
	local px, py, depth = frame:Project3DPointTo2D(x, y, z)
	if not px then
		return nil
	end
	local mode = self.projectionMode
	if mode == "localScaled" then
		local scale = frame:GetEffectiveScale()
		px, py = px / scale, py / scale
	elseif mode == "screen" then
		px, py = px - frame:GetLeft(), py - frame:GetBottom()
	elseif mode == "screenScaled" then
		local scale = frame:GetEffectiveScale()
		px, py = px / scale - frame:GetLeft(), py / scale - frame:GetBottom()
	elseif mode == "normalized" then
		px, py = px * frame:GetWidth(), py * frame:GetHeight()
	end
	if self.flipProjectedY then
		py = frame:GetHeight() - py
	end
	return px, py, depth
end

-- Game-space point to frame-local UI units (bottom-left origin).
function Scene:Project(x, y, z)
	return self:ProjectRaw(x * self.xSign, y, z)
end

-- Distance of a game-space point in front of the camera.
function Scene:Depth(x, y, z)
	local frame = self.frame
	local cx, cy, cz = frame:GetCameraPosition()
	local fx, fy, fz = frame:GetCameraForward()
	return (x * self.xSign - cx) * fx + (y - cy) * fy + (z - cz) * fz
end

-- Actors ---------------------------------------------------------------------

local unpack = unpack or table.unpack

local function ReadBox(minX, minY, minZ, maxX, maxY, maxZ)
	if type(minX) == "table" then
		local low, high = minX, minY
		return low.x, low.y, low.z, high.x, high.y, high.z
	end
	if minX and minY and minZ and maxX and maxY and maxZ then
		return minX, minY, minZ, maxX, maxY, maxZ
	end
	return nil
end

-- The model's unscaled box as six numbers, or nil. Uses the larger of the
-- active and max boxes: for some doodads the active box covers only part of
-- the mesh, which made them scale up far too big.
-- activeOnly: use just the active box. For characters the max box can
-- include room for every animation and attachment, making them far too small.
function Scene.GetActorBounds(actor, activeOnly)
	local a = { ReadBox(actor:GetActiveBoundingBox()) }
	local b = (not activeOnly and actor.GetMaxBoundingBox) and { ReadBox(actor:GetMaxBoundingBox()) } or {}
	if not a[1] and not b[1] then
		return nil
	end
	if not b[1] then
		return unpack(a)
	end
	if not a[1] then
		return unpack(b)
	end
	return math.min(a[1], b[1]), math.min(a[2], b[2]), math.min(a[3], b[3]),
		math.max(a[4], b[4]), math.max(a[5], b[5]), math.max(a[6], b[6])
end

function Scene:AcquireActor()
	local actor = tremove(self.freeActors)
	if not actor then
		actor = self.frame:CreateActor(nil, ACTOR_TEMPLATE)
	end
	if actor then
		actor:SetAlpha(1)
		actor:Show()
	end
	return actor
end

function Scene:ReleaseActor(actor)
	actor:ClearModel()
	actor:Hide()
	tinsert(self.freeActors, actor)
end

-- Places an actor at a game-space point. The game multiplies an actor's
-- position by its scale, so this divides first.
-- centerX / centerY: the model's own box centre (unscaled). When given, the
-- model is shifted so that centre, not its pivot, lands on (x, y).
function Scene:Place(actor, x, y, z, yaw, scale, pitch, roll, centerX, centerY)
	scale = scale or 1
	yaw = yaw or 0
	local renderX = x * self.xSign
	if centerX then
		local c, s = math.cos(yaw), math.sin(yaw)
		renderX = renderX - (centerX * c - centerY * s) * scale
		y = y - (centerX * s + centerY * c) * scale
	end
	actor:SetScale(scale)
	actor:SetPosition(renderX / scale, y / scale, z / scale)
	actor:SetYaw(yaw or 0)
	actor:SetPitch(pitch or 0)
	actor:SetRoll(roll or 0)
end
