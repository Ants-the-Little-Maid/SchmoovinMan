local _, ns = ...

-- Runs the game: window states (start, running, paused, over), the frame
-- loop, keyboard input, sounds and saving results.
local Controller = {}
ns.Controller = Controller

local Rules = ns.Rules
local FIRST_ZONE = ns.World.DEFAULT_ZONES[1]
local OVER_DELAY = 1.4

Controller.state = "closed"

-- Keys while running. Anything else reaches the game as normal.
local RUN_KEYS = {
	A = "left", LEFT = "left",
	D = "right", RIGHT = "right",
	W = "jump", UP = "jump", SPACE = "jump",
	S = "duck", DOWN = "duck",
}

function Controller:Build()
	if self.frame then
		return
	end
	local frame = ns.Window.Create(self)
	self.frame = frame
	self.scene = ns.Scene.Create(frame.sceneHolder)
	self.ground = ns.Ground.Create(self.scene, frame.groundLayer)
	self.renderer = ns.Renderer.Create(self.scene, self.ground)
	self.hud = ns.Hud.Create(frame.hudLayer)
	self.bubble = ns.Bubble.Create(frame.hudLayer)
	-- A second bubble, for a Tauren jogger's reply.
	self.replyBubble = ns.Bubble.Create(frame.hudLayer)
	self.screens = ns.Screens.Create(frame.screenLayer, self)

	-- Keyboard: only keys the game uses are kept from the rest of WoW.
	local keys = CreateFrame("Frame", nil, frame)
	keys:SetAllPoints()
	self.keys = keys
	self.held = {}
	if not InCombatLockdown() then
		keys:SetPropagateKeyboardInput(true)
	end
	keys:SetScript("OnKeyDown", function(_, key)
		if InCombatLockdown() then
			return
		end
		keys:SetPropagateKeyboardInput(not self:HandleKey(key))
	end)
	keys:SetScript("OnKeyUp", function(_, key)
		self.held[key] = nil
		if not InCombatLockdown() then
			keys:SetPropagateKeyboardInput(true)
		end
	end)

	frame:SetScript("OnUpdate", function(_, elapsed)
		self:OnUpdate(elapsed)
	end)
	ns.Window.ApplySize(frame, ns.db.settings.windowSize)
	-- The screen-fit limit depends on the screen, so recheck it when that changes.
	local function Refit()
		self:SetWindowSize(ns.db.settings.windowSize)
	end
	ns.RegisterEvent("DISPLAY_SIZE_CHANGED", Refit)
	ns.RegisterEvent("UI_SCALE_CHANGED", Refit)

	ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
		if self.state == "running" then
			self:Pause("You entered combat, so the run paused.")
		end
		if not InCombatLockdown() then
			keys:SetPropagateKeyboardInput(true)
		end
		keys:EnableKeyboard(false)
	end)
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
		keys:EnableKeyboard(frame:IsShown())
	end)
end

-- Window --------------------------------------------------------------------------

function Controller:Toggle()
	self:Build()
	if self.frame:IsShown() then
		self:Close()
	else
		self.frame:Show()
	end
end

function Controller:SetWindowSize(key)
	ns.db.settings.windowSize = ns.Window.ApplySize(self.frame, key)
	-- Projection depends on the window's scale, so measure it again.
	self.scene.calibrated = false
	self.scene:Calibrate()
end

function Controller:Close()
	if self.frame then
		self.frame:Hide()
	end
end

function Controller:OnWindowShown()
	self.keys:EnableKeyboard(not InCombatLockdown())
	if self.state == "closed" or self.state == "over" then
		self:ShowStart()
	elseif self.state == "paused" then
		self.screens.paused:Show()
	end
end

function Controller:OnWindowHidden()
	if self.state == "running" then
		self:Pause("Paused while the window was closed.")
	end
	self.held = {}
	if not InCombatLockdown() then
		self.keys:SetPropagateKeyboardInput(true)
	end
	self.keys:EnableKeyboard(false)
	if self.state ~= "paused" then
		self.state = "closed"
	end
end

-- Start screen with the runner jogging in Mulgore behind it.
function Controller:ShowStart()
	self.state = "start"
	self.world = ns.World.New(1, ns.Tuning)
	self:PrepareScene(FIRST_ZONE)
	self.hud:SetShown(false)
	self.screens:HideAll()
	local guildTop = ns.GuildBoard.TopScore()
	self.screens:ShowStart(ns.Scores.Best(), guildTop)
end

function Controller:PrepareScene(zoneKey)
	local zone = ns.ZonesByKey[zoneKey]
	self.zoneKey = zoneKey
	self.renderer:Reset()
	self.renderer:SetZone(zone)
	if not self.scene.calibrated then
		self.scene:Calibrate()
	end
	self.renderer:FillScenery(self.world, zone)
end

-- Runs ----------------------------------------------------------------------------

-- Each run gets its own copy of the tuning, taken at the start. Settings
-- changed during a run (/schmoove duck, /schmoove zones) then wait for the
-- next run, so a row already on the track can't become impossible mid-run.
local function RunTuning()
	local copy = {}
	for key, value in pairs(ns.Tuning) do
		copy[key] = value
	end
	return copy
end

function Controller:StartRun()
	if InCombatLockdown() then
		ns.Print("You can't start a run in combat.")
		return
	end
	self.world = ns.World.New(math.floor(GetTime() * 1000) % 2147483646 + 1, RunTuning())
	self:PrepareScene(self.world.zoneKey)
	self.screens:HideAll()
	self.hud:SetHint(self.world.tuning.duckEnabled)
	self.hud:SetShown(true)
	self.hud:ShowBanner(ns.ZonesByKey[self.world.zoneKey].name, nil, nil, GetTime())
	self.overAt = nil
	self.nextQuip = 0
	self:HideBubbles()
	self.state = "running"
	self.held = {}
	ns.PlaySound("start")
end

function Controller:Pause(reason)
	if self.state ~= "running" then
		return
	end
	self.state = "paused"
	self.screens:ShowPaused(self.world, reason)
end

function Controller:Resume()
	if self.state ~= "paused" then
		return
	end
	if InCombatLockdown() then
		ns.Print("You can't resume during combat.")
		return
	end
	self.screens.paused:Hide()
	self.state = "running"
	self.held = {}
end

function Controller:TogglePause()
	if self.state == "running" then
		self:Pause("")
	elseif self.state == "paused" then
		self:Resume()
	end
end

function Controller:QuitRun()
	self:ShowStart()
end

function Controller:EndRun()
	local world = self.world
	local entry, rank, isBest = ns.Scores.Add(world)
	-- Shared with the guild when it's this character's best, even if another
	-- character holds the account's best.
	if entry == ns.GuildBoard.MyBest() then
		ns.GuildBoard.ShareBest(entry)
	end
	if isBest then
		ns.PlaySound("newBest")
	end
	local guildRank = ns.GuildBoard.RankFor(world.score)
	self.hud:SetShown(false)
	self.screens:ShowGameOver(world, entry, rank, guildRank, isBest)
	self.state = "over"

	local failures = self.renderer:TakeFailures()
	if #failures > 0 then
		ns.Print(("%d model(s) didn't load in this client and were swapped for backups: %s"):format(#failures, table.concat(failures, ", ")))
	end
end

-- Events from the simulation.
function Controller:HandleEvents(now)
	local world = self.world
	for _, event in ipairs(world:DrainEvents()) do
		local kind = event.type
		if kind == "collect" then
			ns.PlaySound(event.role == "gem" and "gem" or "coin")
		elseif kind == "powerup" then
			ns.PlaySound("powerup")
		elseif kind == "shieldBreak" then
			ns.PlaySound("shieldBreak")
		elseif kind == "crash" then
			ns.PlaySound("crash")
			self:HideBubbles()
			self.overAt = now
		elseif kind == "zone" then
			local zone = ns.ZonesByKey[event.key]
			self.zoneKey = event.key
			self.renderer:SetZone(zone)
			local toSpeed = Rules.Speed(world.tuning, world.time + world.tuning.bumpTime)
			self.hud:ShowBanner(zone.name, event.fromSpeed, toSpeed, now)
			self.flashAt = now
			self.frame.flash:SetColorTexture(zone.fog.color[1], zone.fog.color[2], zone.fog.color[3], 1)
			ns.PlaySound("zone")
		end
	end
end

function Controller:OnUpdate(elapsed)
	local now = GetTime()
	local world = self.world
	if not world then
		return
	end
	if self.state == "running" then
		world:Step(elapsed)
		self:HandleEvents(now)
		if self.overAt and now - self.overAt > OVER_DELAY then
			self.renderer:Update(world, now)
			self:EndRun()
			return
		end
	end
	self.renderer:Update(world, now)
	self:UpdateQuips()
	if self.state == "running" or self.state == "paused" then
		local zone = ns.ZonesByKey[self.zoneKey]
		self.hud:Update(world, ns.Scores.Best() and ns.Scores.Best().score or 0, zone.name, now)
	end
	-- Zone change flash fades over 0.8 seconds.
	if self.flashAt then
		local alpha = 1 - (now - self.flashAt) / 0.8
		if alpha <= 0 then
			self.flashAt = nil
			alpha = 0
		end
		self.frame.flash:SetAlpha(alpha * 0.85)
	end
end

-- Speech bubble ------------------------------------------------------------------

function Controller:HideBubbles()
	self.bubble:Hide()
	self.replyBubble:Hide()
	self.pendingReply = nil
end

-- On overtaking a jogger something gets said, always by the runner first:
-- * Orcs and trolls: a side or general line over the runner's head.
-- * Tauren: the runner compliments them, then they reply over their own head.
-- Bubble time follows the run's clock, so it holds still while paused.
function Controller:UpdateQuips()
	local world = self.world
	local passes = self.renderer:TakePasses()
	if self.state ~= "running" and self.state ~= "paused" then
		self:HideBubbles()
		return
	end
	local quips = ns.Assets.quips
	local renderer = self.renderer
	local runnerHead = function()
		return renderer:RunnerHeadPoint(self.world)
	end
	local jogger = passes[1]
	local quiet = not self.bubble:IsShown() and not self.replyBubble:IsShown() and not self.pendingReply
	if self.state == "running" and jogger and quiet and world.time >= (self.nextQuip or 0) then
		local line
		if jogger.race == "tauren" then
			line = quips.toTauren[math.random(#quips.toTauren)]
			self.pendingReply = { at = world.time + quips.replyDelay, jogger = jogger }
		elseif math.random() < quips.sideChance then
			-- A jogger on the left edge is passed on their right, and vice versa.
			line = jogger.side < 0 and quips.passRight or quips.passLeft
		else
			line = quips.general[math.random(#quips.general)]
		end
		self.bubble:Say(line, world.time + quips.duration, runnerHead)
		local talkTime = quips.duration + (self.pendingReply and quips.replyDelay or 0)
		self.nextQuip = world.time + talkTime + quips.gap
	end

	-- The Tauren's answer, if they're still in view.
	local reply = self.pendingReply
	if reply and world.time >= reply.at then
		self.pendingReply = nil
		local who = reply.jogger
		if renderer:JoggerHeadPoint(who) then
			self.replyBubble:Say(quips.taurenReply[math.random(#quips.taurenReply)], world.time + quips.duration, function()
				return renderer:JoggerHeadPoint(who)
			end)
		end
	end

	self.bubble:Update(world.time)
	self.replyBubble:Update(world.time)
end

-- Keyboard ------------------------------------------------------------------------

-- Returns true when the key was used, so it doesn't reach the game.
function Controller:HandleKey(key)
	local state = self.state
	if state == "running" then
		local action = RUN_KEYS[key]
		if action then
			if not self.held[key] then
				self.held[key] = true
				if action ~= "duck" or self.world.tuning.duckEnabled then
					self.world:Input(action)
				end
			end
			return true
		end
		if key == "ESCAPE" or key == "P" then
			self:Pause("")
			return true
		end
		return false
	elseif state == "paused" then
		if key == "P" then
			self:Resume()
			return true
		end
		return false
	elseif state == "start" or state == "over" then
		if key == "ENTER" or key == "R" or (state == "start" and key == "SPACE") then
			self:StartRun()
			return true
		end
		return false
	end
	return false
end
