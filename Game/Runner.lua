local _, ns = ...

-- The runner's movement. States: "run", "jump", "duck", "fly", "crash".
-- x is lateral position, z is the height of the feet.
local Runner = {}
Runner.__index = Runner
ns.Runner = Runner

-- `from`, moved toward `to` by at most `most`.
local function Toward(from, to, most)
	if math.abs(to - from) <= most then
		return to
	end
	return from + (to > from and most or -most)
end

function Runner.New(tuning)
	local self = setmetatable({}, Runner)
	self.tuning = tuning
	self.lane = 2
	self.x = tuning.lanes[2]
	-- x is where the lane change has got to (laneX) plus how far a crosswind
	-- has carried you (offset) and how far you've slid past your lane on ice
	-- (slide). The world sets laneChangeTime, skid, skidBack, wind, gravity
	-- and jumpSpeed for the zone's twist; nil otherwise.
	self.laneX = tuning.lanes[2]
	self.offset = 0
	-- slideAt: seconds since you arrived in the lane you're sliding past, and
	-- slideWay the way you came in, 1 (right) or -1; nil when not sliding.
	-- slideLength and slideBack: how far this slide goes and how long it takes
	-- to come back. run: how far the lane change has come the same way
	-- (runWay) without stopping, which settles them.
	self.slide = 0
	self.slideAt = nil
	self.slideWay = nil
	self.run = 0
	self.runWay = nil
	-- Sideways speed in yards a second, for drawing (the lean, the spray on ice).
	self.vx = 0
	-- wind: which way a crosswind blows now, 1 (right) or -1, or nil. blow:
	-- the way it blew when you left the ground, while you're in the air.
	self.wind = nil
	self.blow = nil
	self.inAir = false
	self.airTime = 0
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

-- The lane a crosswind is carrying you to in the air: the next one over the
-- way it blew when you left the ground, if the road goes that far, else your
-- own. You come down there unless the jump is cut short.
function Runner:LandingLane()
	local blow = self.blow
	if blow and self.tuning.lanes[self.lane + blow] then
		return self.lane + blow
	end
	return self.lane
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
	self.vx = 0
end

-- Advances one fixed step. Returns "land" on touching down from a jump.
function Runner:Update(h)
	local tuning = self.tuning
	local event

	local lanes = tuning.lanes
	local laneWidth = lanes[2] - lanes[1]

	-- A crosswind carries you while you're in the air (a jump, a ramp's throw
	-- or the drop after a Wind Rider, but not on one), the way it blew when
	-- you left the ground. Coming down more than half a lane across puts you
	-- in the next lane; less, and you come back to your own.
	local airborne = self.z > 0 and not self.flying and self.state ~= "crash"
	if airborne and not self.inAir then
		self.inAir, self.airTime, self.blow = true, 0, self.wind
	elseif not airborne and self.inAir then
		self.inAir = false
		local blow, to = self.blow, self:LandingLane()
		if to ~= self.lane and math.abs(self.offset) >= laneWidth / 2 then
			-- Where you are stays put: only which lane it's counted from changes.
			self.lane = to
			self.laneX = self.laneX + blow * laneWidth
			self.offset = self.offset - blow * laneWidth
		end
		self.blow = nil
	end

	-- Lateral: move toward the chosen lane at a constant rate.
	local targetX = lanes[self.lane]
	local laneRate = laneWidth / (self.laneChangeTime or tuning.laneChangeTime)
	local step = laneRate * h
	local from = self.laneX
	local laneX = Toward(from, targetX, step)
	local way = laneX > from and 1 or laneX < from and -1 or 0
	self.laneX = laneX
	-- How far it has come the same way without stopping.
	if way ~= 0 and way == self.runWay then
		self.run = self.run + math.abs(laneX - from)
	else
		self.runWay, self.run = way ~= 0 and way or nil, math.abs(laneX - from)
	end

	-- On ice (a zone's twist): arriving in a lane on the ground, you slide
	-- past its middle and come back (Rules.Skid): the whole skid after a whole
	-- lane or more, and less after less, so turning back at once is only a
	-- wobble. It never takes you out of reach of what's in your lane or into
	-- reach of what's in the next. A new lane change ends it, and what's left
	-- of it goes as fast as the change does: turning back you're where you'd
	-- be without it by the time it's gone, and going on you hold still until
	-- the change catches up.
	local slideTo = 0
	if laneX ~= targetX or not self.skid then
		self.slideAt = nil
	elseif way ~= 0 then
		if self.z <= 0 and not self.flying then
			local share = math.min(1, self.run / laneWidth)
			self.slideAt, self.slideWay = 0, way
			self.slideLength, self.slideBack = self.skid * share, self.skidBack and self.skidBack * share
		end
	elseif self.slideAt then
		self.slideAt = self.slideAt + h
		local slid = ns.Rules.Skid(self.slideLength, laneRate, self.slideBack, self.slideAt)
		if slid then
			slideTo = self.slideWay * slid
		else
			self.slideAt = nil
		end
	end
	-- (A slide is never faster than the lane change before it, so this keeps
	-- to its curve exactly.)
	local slide = Toward(self.slide, slideTo, step)
	self.slide = slide

	-- How far the wind has carried you: a lane by the end of a jump, slowly
	-- at first (Rules.Blown), and never past the road's edge. Lane changes
	-- still work in the air, on top of it. On the ground what's left of it
	-- goes as fast as a lane change.
	local want = 0
	local rate = laneRate
	if self.inAir then
		self.airTime = self.airTime + h
		if self:LandingLane() ~= self.lane then
			want = self.blow * ns.Rules.Blown(tuning, self.airTime)
		end
		-- The fastest the wind's curve moves, so it's followed exactly, and
		-- eased back along if a lane change leaves no lane to be blown to.
		rate = 2 * laneWidth / ns.Rules.BlowTime(tuning)
	end
	local offset = Toward(self.offset, want, rate * h)
	self.offset = offset
	local x = math.max(lanes[1], math.min(lanes[#lanes], laneX + offset)) + slide
	self.vx = (x - self.x) / h
	self.x = x

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
