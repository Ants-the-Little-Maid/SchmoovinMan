local _, ns = ...

-- Runs the game: window states (start, running, paused, over), the frame
-- loop, keyboard input, sounds and saving results.
local Controller = {}
ns.Controller = Controller

local FIRST_ZONE = ns.World.DEFAULT_ZONES[1]
local OVER_DELAY = 1.4
-- Seconds of 3, 2, 1 before a paused run goes on (when the setting is on).
local COUNTDOWN = 3

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
	-- Orc runs: Tauren yell as they pass, several on screen at once.
	self.taurenBubbles = {}
	for index = 1, 3 do
		self.taurenBubbles[index] = ns.Bubble.Create(frame.hudLayer)
	end
	self.screens = ns.Screens.Create(frame.screenLayer, self)
	self.options = ns.Options.Create(frame.screenLayer, self)

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

-- Quick launch from the minimap menu or /schmoove start: open the window
-- straight into a new run. A paused run is brought back rather than lost.
function Controller:QuickStart()
	self:Build()
	if not self.frame:IsShown() then
		self.frame:Show()
	end
	if self.state == "paused" or self.state == "running" then
		return
	end
	self:StartRun()
end

-- Opens the Options screen, over the start or pause screen. A live run
-- pauses first.
function Controller:OpenOptions()
	self:Build()
	if not self.frame:IsShown() then
		self.frame:Show()
	end
	if self.state == "running" and not self.overAt then
		self:Pause("")
	end
	self.options:Show()
end

-- Options closed: the start screen shows any settings changed there.
function Controller:OnOptionsClosed()
	self:RefreshStart()
end

-- Redraws the start screen after a setting changes, if it's showing.
function Controller:RefreshStart()
	if self.screens and self.state == "start" then
		self.screens:ShowStart(ns.Scores.Best(), ns.GuildBoard.TopScore())
	end
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
	self.options:Hide()
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

-- mode: nil, or "orc" for an orc run.
function Controller:PrepareScene(zoneKey, mode)
	local zone = ns.ZonesByKey[zoneKey]
	self.zoneKey = zoneKey
	self.renderer:Reset(mode)
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

-- This character's orc-run role (see Data/OrcRun.lua): "target" or nil.
-- Worked out once the character's name is known, then kept.
function Controller:OrcRole()
	if self.orcRole == nil then
		local fullName, firstName = ns.PlayerName()
		if not fullName or fullName == "" or fullName == UNKNOWNOBJECT then
			return nil
		end
		self.orcRole = ns.OrcRun.RoleFor(fullName, firstName) or false
	end
	return self.orcRole or nil
end

function Controller:StartRun()
	if InCombatLockdown() then
		ns.Print("You can't start a run in combat.")
		return
	end
	-- A run never goes on under Options, where the keys don't reach it.
	self.options:Hide()
	-- Now and then, for the right names (or when forced), an orc run.
	local mode = ns.OrcRun.Roll(self:OrcRole(), ns.OrcRun.forced, math.random())
	self.world = ns.World.New(math.floor(GetTime() * 1000) % 2147483646 + 1, RunTuning(), { mode = mode })
	self:PrepareScene(self.world.zoneKey, mode)
	self.screens:HideAll()
	self.hud:SetHint(self.world.tuning.duckEnabled, mode)
	self.hud:SetShown(true)
	if mode == "orc" then
		self.hud:ShowMessage("boss", "ORC RUN", "You're an orc!", "Schmoovers coming through: dodge them", GetTime())
	else
		self.hud:ShowBanner(ns.ZonesByKey[self.world.zoneKey].name, nil, nil, GetTime())
	end
	self.overAt = nil
	self.crashName = nil
	self:StopCountdown()
	self.nextQuip = 0
	self.nextComplaint = 0
	self.lastPassSide = nil
	self:HideBubbles()
	self.state = "running"
	self.held = {}
	ns.PlaySound("start")
end

function Controller:Pause(reason)
	if self.state ~= "running" then
		return
	end
	-- A run that has crashed is over, though it stays on screen for a moment:
	-- it ends now (and is saved) rather than pausing, where Restart or Quit
	-- would have dropped it.
	if self.overAt then
		self:EndRun()
		return
	end
	self:StopCountdown()
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
	-- The title bar's Resume can be clicked with Options open: close it, as
	-- the keys wouldn't reach the run under it.
	self.options:Hide()
	self.state = "running"
	self.held = {}
	-- A countdown first, so nothing hits you the moment the run goes on.
	if ns.db.settings.countdown ~= false then
		self.countdownUntil = GetTime() + COUNTDOWN
	end
end

-- The resume countdown, if one is on: true while it's still counting.
function Controller:UpdateCountdown(now)
	if not self.countdownUntil then
		return false
	end
	local left = self.countdownUntil - now
	if left > 0 then
		self.hud:ShowCountdown(math.ceil(left))
		return true
	end
	self:StopCountdown()
	return false
end

function Controller:StopCountdown()
	self.countdownUntil = nil
	if self.hud then
		self.hud:ShowCountdown(nil)
	end
end

-- The title bar's pause button works only during a run, so it's greyed out
-- on the start and game-over screens (and once the runner has crashed), and
-- reads "Resume" while paused. Checked each frame, set on a change.
function Controller:UpdatePauseButton()
	local state = (self.state == "running" and self.overAt) and "crashed" or self.state
	if state ~= self.pauseButtonState then
		self.pauseButtonState = state
		ns.Window.SetPauseButton(self.frame.pauseButton, state == "running" or state == "paused", state == "paused" and "Resume" or "Pause")
	end
end

-- The Pause button. A run that has crashed is over, though it stays on
-- screen for a moment, so it can't be paused then (nor with P or Esc).
function Controller:TogglePause()
	if self.state == "running" and not self.overAt then
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
	-- The guild badge, like the personal one, only shows for a run that counts:
	-- this character's new best, with the place it now holds on the board.
	local guildRank
	if entry == ns.GuildBoard.MyBest() then
		ns.GuildBoard.ShareBest(entry)
		guildRank = ns.GuildBoard.RankFor(world.score)
	end
	if isBest then
		ns.PlaySound("newBest")
	end
	self.hud:SetShown(false)
	self.screens:ShowGameOver(world, entry, rank, guildRank, isBest, self.crashName)
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
		elseif kind == "knock" then
			ns.PlaySound("knock")
			self:SayKnock()
		elseif kind == "bossStart" then
			ns.PlaySound("bossStart")
			self.hud:ShowMessage("boss", "BOSS", event.name, string.format("Grab %d spears to drive them off, or survive %d seconds", event.needed, event.limit), now)
			self:SayNow(ns.Assets.quips.bossStart)
		elseif kind == "spear" then
			ns.PlaySound("spear")
		elseif kind == "bossEnd" then
			local fight = world.boss
			if event.result == "driven" then
				ns.PlaySound("bossDriven")
				self.hud:ShowMessage("won", "DRIVEN OFF", event.name, string.format("+%d  -  %d spears in %.1f s", event.points, fight.hits, fight.endedAt - fight.start), now)
				self:SayNow(ns.Assets.quips.bossDriven)
			else
				ns.PlaySound("bossSurvived")
				self.hud:ShowMessage("won", "SURVIVED", event.name, string.format("Gives up and leaves  -  +%d", event.points), now)
				self:SayNow(ns.Assets.quips.bossSurvived)
			end
		elseif kind == "crash" then
			ns.PlaySound("crash")
			self:HideBubbles()
			self.overAt = now
			-- What you ran into, as it was drawn (asked now, while it's on screen).
			self.crashName = self.renderer:EntityModelName(world.crashId)
		elseif kind == "zone" then
			local zone = ns.ZonesByKey[event.key]
			self.zoneKey = event.key
			self.renderer:SetZone(zone)
			-- In an orc run, the Tauren's speed.
			local toSpeed = world:SpeedAt(world.course + world.tuning.bumpTime)
			self.hud:ShowBanner(zone.name, event.fromSpeed, toSpeed, now)
			self.flashAt = now
			self.frame.flash:SetColorTexture(zone.fog.color[1], zone.fog.color[2], zone.fog.color[3], 1)
			ns.PlaySound("zone")
		end
	end
end

function Controller:OnUpdate(elapsed)
	local now = GetTime()
	self:UpdatePauseButton()
	local world = self.world
	if not world then
		return
	end
	-- Nothing moves while the resume countdown runs.
	if self.state == "running" and not self:UpdateCountdown(now) then
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

-- Some moments always get a line from the runner (knocking an Alliance
-- jogger, a boss turning up or leaving), cutting off any chatter and any reply
-- still to come, since the runner has moved on.
function Controller:SayNow(lines)
	local world = self.world
	local quips = ns.Assets.quips
	local renderer = self.renderer
	self.pendingReply = nil
	self.replyBubble:Hide()
	self.bubble:Say(lines[math.random(#lines)], world.time + quips.duration, function()
		return renderer:RunnerHeadPoint(self.world)
	end)
	self.nextQuip = world.time + quips.duration + quips.gap
end

function Controller:SayKnock()
	self:SayNow(ns.Assets.quips.knock)
end

function Controller:HideBubbles()
	self.bubble:Hide()
	self.replyBubble:Hide()
	self.pendingReply = nil
	for _, bubble in ipairs(self.taurenBubbles) do
		bubble:Hide()
	end
	self.pendingComplaint = nil
end

-- Orc runs: each Tauren yells as it passes, over its own head, if a bubble is
-- free: half the time the side it's passing on ("... Again" when the last
-- side line was on the same side), otherwise a taurenToOrc line. Now and then
-- the orc answers over its own head, panting and complaining.
function Controller:UpdateOrcQuips(passes)
	local world = self.world
	local quips = ns.Assets.quips
	local renderer = self.renderer
	if self.state == "running" then
		for _, pass in ipairs(passes) do
			local free
			for _, bubble in ipairs(self.taurenBubbles) do
				if not bubble:IsShown() then
					free = bubble
					break
				end
			end
			if free then
				local line
				-- A side line only for a Tauren passing in another lane.
				if pass.side and math.random() < quips.sideChance then
					local again = self.lastPassSide == pass.side
					if pass.side < 0 then
						line = again and quips.passLeftAgain or quips.passLeft
					else
						line = again and quips.passRightAgain or quips.passRight
					end
					self.lastPassSide = pass.side
				else
					line = quips.taurenToOrc[math.random(#quips.taurenToOrc)]
				end
				local tauren = pass.tauren
				free:Say(line, world.time + quips.duration, function()
					return renderer:EntityHeadPoint(tauren)
				end)
				if not self.pendingComplaint and world.time >= (self.nextComplaint or 0) then
					self.pendingComplaint = world.time + quips.replyDelay
				end
			end
		end
	end

	-- The orc's answer.
	if self.pendingComplaint and world.time >= self.pendingComplaint then
		self.pendingComplaint = nil
		self.bubble:Say(quips.orcRun[math.random(#quips.orcRun)], world.time + quips.duration, function()
			return renderer:RunnerHeadPoint(self.world)
		end)
		self.nextComplaint = world.time + quips.duration + quips.complaintGap
	end

	self.bubble:Update(world.time)
	for _, bubble in ipairs(self.taurenBubbles) do
		bubble:Update(world.time)
	end
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
	if world.mode == "orc" then
		self:UpdateOrcQuips(passes)
		return
	end
	local quips = ns.Assets.quips
	local renderer = self.renderer
	-- Made once, not every frame.
	local runnerHead = self.runnerHead
	if not runnerHead then
		runnerHead = function()
			return renderer:RunnerHeadPoint(self.world)
		end
		self.runnerHead = runnerHead
	end
	local jogger = passes[1]
	local quiet = not self.bubble:IsShown() and not self.replyBubble:IsShown() and not self.pendingReply
	if self.state == "running" and jogger and quiet and world.time >= (self.nextQuip or 0) then
		local line
		if jogger.lines then
			-- A famous face: their own lines, and their own reply.
			line = jogger.lines[math.random(#jogger.lines)]
			if jogger.replies then
				self.pendingReply = { at = world.time + quips.replyDelay, jogger = jogger, lines = jogger.replies }
			end
		elseif jogger.race == "tauren" then
			line = quips.toTauren[math.random(#quips.toTauren)]
			self.pendingReply = { at = world.time + quips.replyDelay, jogger = jogger, lines = quips.taurenReply }
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

	-- The jogger's answer, if they're still in view.
	local reply = self.pendingReply
	if reply and world.time >= reply.at then
		self.pendingReply = nil
		local who = reply.jogger
		if renderer:JoggerHeadPoint(who) then
			self.replyBubble:Say(reply.lines[math.random(#reply.lines)], world.time + quips.duration, function()
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
	-- Over the Options screen, Esc closes it and nothing else is used.
	if self.options:IsShown() then
		if key == "ESCAPE" then
			self.options:Hide()
			return true
		end
		return false
	end
	local state = self.state
	if state == "running" then
		local action = RUN_KEYS[key]
		if action then
			-- Kept from the game but not used during the resume countdown.
			if not self.held[key] and not self.countdownUntil then
				self.held[key] = true
				if action ~= "duck" or self.world.tuning.duckEnabled then
					self.world:Input(action)
				end
			end
			return true
		end
		if key == "ESCAPE" or key == "P" then
			if not self.overAt then
				self:Pause("")
			end
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
