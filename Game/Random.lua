local _, ns = ...

-- Park-Miller generator. Every product fits a Lua double exactly, so a seed
-- gives the same run on any machine.
local Random = {}
Random.__index = Random
ns.Random = Random

local MODULUS = 2147483647
local MULTIPLIER = 16807

function Random.New(seed)
	local self = setmetatable({}, Random)
	seed = math.floor(math.abs(seed or 1)) % MODULUS
	if seed == 0 then
		seed = 1
	end
	self.state = seed
	return self
end

-- A number in [0, 1).
function Random:Next()
	self.state = (self.state * MULTIPLIER) % MODULUS
	return (self.state - 1) / (MODULUS - 1)
end

-- An integer in [low, high].
function Random:Int(low, high)
	return low + math.floor(self:Next() * (high - low + 1))
end

function Random:Pick(list)
	return list[self:Int(1, #list)]
end

function Random:Shuffle(list)
	for index = #list, 2, -1 do
		local other = self:Int(1, index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end
