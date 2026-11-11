local _, ns = ...

-- The runner's movement. States: "run", "jump", "duck", "fly", "crash".
-- x is lateral position, z is the height of the feet.
local Runner = {}
Runner.__index = Runner
ns.Runner = Runner

function Runner.New(tuning)
	local self = setmetatable({}, Runner)
	self.tuning = tuning
	self.lane = 2
	self.x = tuning.lanes[2]
	-- x is where the lane change has got to (laneX) plus any sideways drift
	-- from a crosswind (offset). The world sets laneChangeTime, drift, gravity
	-- and jumpSpeed for the zone's twist; nil (0 for drift) otherwise.
	self.laneX = tuning.lanes[2]
	self.offset = 0
	self.drift = 0
	self.z = 0
	self.vz = 0
	self.state = "run"
	self.duckLeft = 0
	self.flying = false
	self.airborne = false
	return self
end

function Runner:Height()
	if self.state == "duck" then
		return self.tuning.duckHeight
	end
	return self.tuning.runnerHeight
end

function Runner:IsAirborne()
	return self.z > 0 or self.vz > 0
end

-- Returns an event name when the input did something.
function Runner:Input(action)
	local tuning = self.tuning
	if self.state == "crash" then
		return nil
	end
	if action == "left" or action == "right" then
		local lane = self.lane + (action == "left" and -1 or 1)
		if lane >= 1 and lane <= #tuning.lanes then
			self.lane = lane
			return "lane"
		end
	elseif self.flying or self.launch then
		-- Nothing to jump or duck on a Wind Rider or in the air off a ramp.
		return nil
	elseif action == "jump" then
		if not self:IsAirborne() then
			self.vz = self.jumpSpeed or tuning.jumpSpeed
			self.state = "jump"
			self.duckLeft = 0
			return "jump"
		end
	elseif action == "duck" and tuning.duckEnabled then
		if self:IsAirborne() then
			-- Fast fall, then duck on landing.
			self.vz = -tuning.fastFallSpeed
		end
		self.duckLeft = tuning.duckTime
		if not self:IsAirborne() then
			self.state = "duck"
		end
		return "duck"
	end
	return nil
end

-- Thrown off a ramp: an arc `height` yards high that lasts `duration`
-- seconds, whatever keys are pressed. Lanes can still be changed in the air.
function Runner:Launch(duration, height)
	self.launch = { t = 0, duration = math.max(0.2, duration), height = height }
	self.state = "jump"
	self.duckLeft = 0
end

function Runner:SetFlying(flying)
	self.flying = flying
	if flying then
		self.launch = nil
		self.state = "fly"
		self.duckLeft = 0
	end
end

function Runner:Crash()
	self.state = "crash"
end

-- Advances one fixed step. Returns "land" on touching down from a jump.
function Runner:Update(h)
	local tuning = self.tuning
	local event

	-- Lateral: move toward the chosen lane at a constant rate.
	local targetX = tuning.lanes[self.lane]
	local laneWidth = tuning.lanes[2] - tuning.lanes[1]
	local step = laneWidth / (self.laneChangeTime or tuning.laneChangeTime) * h
	local laneX = self.laneX
	if math.abs(targetX - laneX) <= step then
		laneX = targetX
	else
		laneX = laneX + (targetX > laneX and step or -step)
	end
	self.laneX = laneX

	-- A crosswind pushes you sideways while you're in the air (not on a Wind
	-- Rider); on the ground you come back to the middle of your lane.
	local want = (self.z > 0 and not self.flying and self.state ~= "crash") and (self.drift or 0) or 0
	local offset = self.offset
	if offset ~= want then
		local slide = (tuning.driftRate or 2.5) * h
		if math.abs(want - offset) <= slide then
			offset = want
		else
			offset = offset + (want > offset and slide or -slide)
		end
		self.offset = offset
	end
	self.x = laneX + offset

	if self.state == "crash" then
		return nil
	end

	if self.flying then
		local targetZ = tuning.flyHeight
		local rise = tuning.flyRiseRate * h
		if math.abs(targetZ - self.z) <= rise then
			self.z = targetZ
		else
			self.z = self.z + (targetZ > self.z and rise or -rise)
		end
		self.vz = 0
		return nil
	end

	local launch = self.launch
	if launch then
		launch.t = launch.t + h
		local progress = launch.t / launch.duration
		if progress >= 1 then
			self.launch = nil
			self.z, self.vz = 0, 0
			self.state = "run"
			return "land"
		end
		-- Never quite on the ground, and vz says whether it's rising or falling.
		self.z = math.max(0.01, 4 * launch.height * progress * (1 - progress))
		self.vz = progress < 0.5 and 1 or -1
		self.state = "jump"
		return nil
	end

	if self.z > 0 or self.vz > 0 then
		self.vz = self.vz - (self.gravity or tuning.gravity) * h
		self.z = self.z + self.vz * h
		if self.z <= 0 then
			self.z = 0
			self.vz = 0
			event = "land"
			self.state = self.duckLeft > 0 and "duck" or "run"
		elseif self.state ~= "jump" then
			self.state = "jump"
		end
	end

	if self.duckLeft > 0 then
		self.duckLeft = self.duckLeft - h
		if self.duckLeft <= 0 then
			self.duckLeft = 0
			if self.state == "duck" then
				self.state = "run"
			end
		end
	end
	return event
end
