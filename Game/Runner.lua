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
	elseif self.flying then
		return nil
	elseif action == "jump" then
		if not self:IsAirborne() then
			self.vz = tuning.jumpSpeed
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

function Runner:SetFlying(flying)
	self.flying = flying
	if flying then
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
	local step = laneWidth / tuning.laneChangeTime * h
	if math.abs(targetX - self.x) <= step then
		self.x = targetX
	else
		self.x = self.x + (targetX > self.x and step or -step)
	end

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

	if self.z > 0 or self.vz > 0 then
		self.vz = self.vz - tuning.gravity * h
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
