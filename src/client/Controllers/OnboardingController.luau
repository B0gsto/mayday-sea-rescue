--!strict
-- OnboardingController: a new player's first 10 minutes (docs/16 section 4) on the client. No
-- tutorial text: the reward burst when the cold open is rescued (B1, still seated on the jet ski,
-- which stays theirs: K18), then for each tutorial call a red parachute flare over the scene and
-- the world waypoint (UI/Waypoint, B2) on the offer, the survivor and the drop-off.
-- It reads only replicated facts: the Ops signals, the PlayerDataChanged snapshot and a few
-- player attributes.
-- Beats (docs/20 changes 4, 7, 8): a new player sees a sea-blue cover, not the town, until they sit on
-- the cold-open jet ski (then it fades); for everyone, a board pops the craft's seat count ("1/1", seat
-- pips, red when full) and the drop-off pulses green on the way in (ColdOpenCue.home).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))

local OpsController = require(script.Parent:WaitForChild("OpsController"))
local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))
local UI = script.Parent.Parent:WaitForChild("UI")
local ColdOpenCue = require(UI:WaitForChild("ColdOpenCue"))
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
local cash = 0
local lastAward: { [string]: any }? = nil
local rewardPending = false
local rewardShown = false
local rewardAt = math.huge

local REWARD_DELAY = 2 -- s after the cold open ends: the survivor swims in and climbs off, then the burst
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
	Telemetry.once("RewardSeen") -- onboarding funnel step 6 (G64)
	task.delay(REWARD_HOLD, function()
		player:SetAttribute("OnboardingRewardBusy", nil)
	end)
end

-- The cold-open cover (docs/20 change 7): no visible town wait. Up from Init for a player whose profile
-- has not said "done"; fades once they sit on the cold-open jet ski, as soon as the profile says they
-- are returning, or after COVER_MAX s whatever happens.
local COVER_MAX = 20
local COVER_FADE = 0.8
local function coverUntilAtSea()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ColdOpenCover"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60 -- over the HUD, the phone and Cinematic
	local sea = Instance.new("Frame")
	sea.Size = UDim2.fromScale(1, 1)
	sea.BackgroundColor3 = Color3.new(1, 1, 1)
	sea.BorderSizePixel = 0
	sea.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 120, 170), Color3.fromRGB(8, 34, 58))
	grad.Parent = sea
	gui.Parent = playerGui
	local t0 = os.clock()
	local seatedAt: number? = nil
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local atSea = player:GetAttribute("ColdOpenActive") == true
			and hum ~= nil
			and hum.SeatPart ~= nil
		seatedAt = if atSea then seatedAt or os.clock() else nil
		local returning = player:GetAttribute("ColdOpenDone") == true
			and player:GetAttribute("ColdOpenActive") ~= true
		if
			returning
			or (seatedAt and os.clock() - seatedAt > 0.3) -- the chase camera has settled on the ski
			or os.clock() - t0 > COVER_MAX
		then
			conn:Disconnect()
			TweenService:Create(sea, TweenInfo.new(COVER_FADE), { BackgroundTransparency = 1 })
				:Play()
			task.delay(COVER_FADE, gui.Destroy, gui)
		end
	end)
end

-- Seat count over your craft while you drive it with someone aboard: "n/cap" and pips, red when
-- full; it pops on every board (the survivor climbing on is the beat, this is the count).
local function seatPips(): () -> ()
	-- projected like UI/Waypoint (a ScreenGui follows the craft); a BillboardGui never showed in play
	local gui = Instance.new("ScreenGui")
	gui.Name = "SeatPips"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Size = UDim2.fromOffset(150, 60)
	box.BackgroundTransparency = 1
	box.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = box
	local function label(y: number, h: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.4
		l.Parent = box
		return l
	end
	local count = label(0, 0.6)
	local pips = label(0.6, 0.4)
	local last = 0
	local conn = RunService.Heartbeat:Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		local craft = seat and seat:FindFirstAncestorOfClass("Model")
		while craft and craft:GetAttribute("VehicleId") == nil do
			craft = craft:FindFirstAncestorOfClass("Model")
		end
		local n = craft and tonumber(craft:GetAttribute("SurvivorCount")) or 0
		local cap = craft and tonumber(craft:GetAttribute("Capacity"))
		if not (craft and cap and n > 0) then
			gui.Parent = nil
			last = 0
			return
		end
		local full = n >= cap
		count.Text = `{n}/{cap}`
		pips.Text = string.rep("●", math.min(n, cap)) .. string.rep("○", math.max(cap - n, 0))
		pips.TextColor3 = if full
			then Color3.fromRGB(240, 80, 70)
			else Color3.fromRGB(120, 235, 140)
		-- beside the rider, not over them: the chase camera looks down the line to the house pin
		local cam = Workspace.CurrentCamera
		local at, onScreen = cam:WorldToViewportPoint(
			craft:GetPivot().Position + cam.CFrame.RightVector * 4 + Vector3.yAxis * 3
		)
		box.Visible = onScreen
		box.Position = UDim2.fromOffset(at.X, at.Y)
		gui.Parent = playerGui
		if n > last then
			scale.Scale = 1.8
			TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
		end
		last = n
	end)
	return function()
		conn:Disconnect()
		gui:Destroy()
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
		currentGoal = nil
		return
	end
	-- UI/Waypoint marks every call now (one marker on screen, not two): the goal is only tracked
	currentGoal = goal
end

function OnboardingController.Init()
	-- a returning player never sees the first-session cues
	if player:GetAttribute("ColdOpenDone") == true then
		return
	end
	coverUntilAtSea()
	beacon = OnboardingBeacon.start()

	OpsController.OnOffer:Connect(function(data: { [string]: any })
		offer = data -- OpsHud sends the flare up over the scene
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
	ColdOpenCue.home() -- every delivery, for the session
	seatPips()
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
