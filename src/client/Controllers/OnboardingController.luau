--!strict
-- OnboardingController: a new player's first 10 minutes (docs/16 section 4) on the client. No
-- tutorial text: the reward burst when the cold open is rescued (B1, still seated on the jet ski,
-- which stays theirs: K18), then for each tutorial call a red parachute flare over the scene and
-- one world beacon (B2): on the offer, then on the craft (on foot), the survivor and the drop-off.
-- It reads only replicated facts: the Ops signals, the PlayerDataChanged snapshot and a few
-- player attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))

local OpsController = require(script.Parent:WaitForChild("OpsController"))
local PyroController = require(script.Parent:WaitForChild("PyroController"))
local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))
local UI = script.Parent.Parent:WaitForChild("UI")
local OnboardingBeacon = require(UI:WaitForChild("OnboardingBeacon"))
local OnboardingReward = require(UI:WaitForChild("OnboardingReward"))

local OnboardingController = {}
OnboardingController.Priority = 85 -- after OpsController (80), before Radio (90)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local beacon: OnboardingBeacon.Beacon? = nil
local active = false
local endedAt = 0
local callsCompleted = 0
local offer: { [string]: any }? = nil
local inOp = false
local opStep: string? = nil -- my current step id in the running operation
local opId: string? = nil
local opPosition: Vector3? = nil
local currentGoal: string? = nil
local currentTarget: Vector3? = nil
local cash = 0
local lastAward: { [string]: any }? = nil
local rewardPending = false
local rewardShown = false
local rewardAt = math.huge
local flared: { [string]: boolean } = {}

local REWARD_DELAY = 0.6 -- s after the cold open ends: the survivor steps off, then the burst
local REWARD_HOLD = 4 -- s the reward burst keeps the debrief tablet back (OnboardingRewardBusy)

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function ownCraft(): Model?
	local folder = Workspace:FindFirstChild("Vehicles")
	for _, m in if folder then folder:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId then
			return m
		end
	end
	return nil
end

local function victimPoint(): Vector3?
	local folder = Workspace:FindFirstChild("CallProps")
	for _, m in if folder then folder:GetChildren() else {} do
		if m:IsA("Model") and m.Name == "Victim" and m:GetAttribute("CallId") == opId then
			return m:GetPivot().Position
		end
	end
	return opPosition
end

-- The drop-off the transport step lights (mirrors Mechanics/transport homePad).
local function padPoint(): Vector3?
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs")
	local dock: Vector3? = nil
	for _, pad in if folder then folder:GetChildren() else {} do
		if pad:IsA("BasePart") then
			local name = pad:GetAttribute("DropOff")
			if name == "Hospital" then
				return pad.Position
			elseif name == "Dock" then
				dock = pad.Position
			end
		end
	end
	return dock
end

-- Inside a tutorial call (SimpleSteps ids): your craft while on foot, the survivor, then the drop-off.
local function opTarget(): Vector3?
	if callsCompleted >= Onboarding.TUTORIAL_CALLS then
		return nil
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.SeatPart) then
		local craft = ownCraft()
		return if craft then craft:GetPivot().Position else nil
	end
	if opStep == "tasking" or opStep == "recovery" then
		return victimPoint()
	elseif opStep == "transport" then
		return padPoint()
	end
	return nil
end

local function applyData(data: any)
	if type(data) ~= "table" then
		return
	end
	if type(data.cash) == "number" then
		cash = data.cash
	end
	if type(data.award) == "table" then
		lastAward = data.award
	end
end

local function showReward()
	if rewardShown or not rewardPending or cash <= 0 then
		return -- cash 0: wait for the cold open's award snapshot
	end
	rewardShown = true
	rewardPending = false
	local awardCash = if lastAward and type(lastAward.cash) == "number"
		then math.max(0, lastAward.cash)
		else 0
	OnboardingReward.play(playerGui, {
		cash = cash,
		fromCash = math.max(0, cash - awardCash),
		anchor = rootPosition(),
	})
	Telemetry.once("RewardSeen") -- onboarding funnel step 10 (G64)
	task.delay(REWARD_HOLD, function()
		player:SetAttribute("OnboardingRewardBusy", nil)
	end)
end

-- B2: a tutorial call's offer sends a flare up over the scene (once per call).
local function flareFor(o: { [string]: any })
	local id = tostring(o.opId)
	if flared[id] or callsCompleted >= Onboarding.TUTORIAL_CALLS then
		return
	end
	if typeof(o.position) == "Vector3" then
		flared[id] = true
		PyroController.parachute(o.position + Vector3.new(0, 2, 0))
	end
end

local function update()
	if not active then
		if beacon then
			beacon.hide()
		end
		return
	end
	if rewardPending and os.clock() >= rewardAt then
		showReward()
	end
	local goal: string? = Onboarding.goal({
		coldOpenDone = true,
		callsCompleted = callsCompleted,
		offerReady = offer ~= nil,
	})
	local o = offer
	local target = if goal and o and typeof(o.position) == "Vector3" then o.position else nil
	if inOp then
		-- the step card is the objective; on the tutorial calls the beacon shows where it is
		target = opTarget()
		goal = if target then "Rescue" else nil
	end
	if not goal or not target then
		if beacon and currentGoal then
			beacon.hide()
		end
		currentGoal, currentTarget = nil, nil
		return
	end
	-- a survivor drifts: only re-place the beacon once they have moved a little
	if goal ~= currentGoal or not currentTarget or (target - currentTarget).Magnitude > 3 then
		currentGoal, currentTarget = goal, target
		if beacon then
			beacon.show(target, "Call")
		end
	end
end

function OnboardingController.Init()
	-- a returning player never sees the first-session cues
	if player:GetAttribute("ColdOpenDone") == true then
		return
	end
	beacon = OnboardingBeacon.start()

	OpsController.OnOffer:Connect(function(data: { [string]: any })
		offer = data
		if active then
			flareFor(data)
		end
	end)
	OpsController.OnState:Connect(function(s: { [string]: any })
		inOp = true
		opId = s.opId
		opPosition = if typeof(s.position) == "Vector3" then s.position else nil
		opStep = nil
		for _, c in s.current or {} do
			if c.trackId == s.myTrack then
				opStep = c.id
			end
		end
		if offer and offer.opId == s.opId then
			offer = nil
		end
	end)
	OpsController.OnDebrief:Connect(function(_: { [string]: any })
		inOp = false
	end)
	OpsController.OnClosed:Connect(function(c: { [string]: any })
		inOp = false
		if offer and offer.opId == c.opId then
			offer = nil
		end
	end)

	local function readCompleted()
		local n = player:GetAttribute("OpsCompleted")
		callsCompleted = math.max(0, (if type(n) == "number" then n else 0) - 1)
	end
	player:GetAttributeChangedSignal("OpsCompleted"):Connect(readCompleted)
	readCompleted()
	player:GetAttributeChangedSignal("ColdOpenEnded"):Connect(function()
		local reason = player:GetAttribute("ColdOpenEnded")
		if active or type(reason) ~= "string" then
			return
		end
		active = true
		endedAt = os.clock()
		rewardPending = Onboarding.rewarded(reason)
		if rewardPending then
			player:SetAttribute("OnboardingRewardBusy", true) -- OpsHud holds the debrief
		end
		rewardAt = endedAt + REWARD_DELAY
		if offer then
			flareFor(offer) -- call 2 was offered the moment the cold open ended
		end
	end)
	-- a profile that was already past the cold open on join is a returning player: no cues
	player:GetAttributeChangedSignal("ColdOpenDone"):Connect(function()
		if player:GetAttribute("ColdOpenDone") == true then
			task.delay(3, function()
				if not active and player:GetAttribute("ColdOpenEnded") == nil and beacon then
					beacon.hide()
				end
			end)
		end
	end)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(applyData)
end

function OnboardingController.Start()
	if not beacon then
		return
	end
	-- pull the first snapshot so the reward's Cash roll has both ends
	task.spawn(function()
		local net = Net.init()
		local getData = net:WaitForChild("Progression_GetData", 30)
		if getData and getData:IsA("RemoteFunction") then
			for _ = 1, 10 do
				local ok, data = pcall(function()
					return getData:InvokeServer()
				end)
				if ok and type(data) == "table" then
					applyData(data)
					return
				end
				task.wait(1)
			end
		end
	end)
	RunService.Heartbeat:Connect(update)
end

-- True while the first-session world beacon is showing a goal (G58 hides the goal chip then).
function OnboardingController.beaconActive(): boolean
	return active and currentGoal ~= nil
end

return OnboardingController
