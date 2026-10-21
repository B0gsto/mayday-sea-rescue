--!strict
-- OnboardingController: the first 15 minutes (docs/15 section 3) on the client: the reward burst
-- when the cold open is rescued, then exactly one world beacon at a time (station, call board,
-- first station rescue, gear at about 5 min, certification exercise at about 10) and a short
-- certification and gear celebration. It reads only replicated facts: the Ops signals, the
-- PlayerDataChanged snapshot and a few player attributes. No services are edited.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local OpsController = require(script.Parent:WaitForChild("OpsController"))
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
local seconds = 0
local stationReached, boardReached = false, false
local callsCompleted = 0
local gearOwned, certEarned = false, false
local offer: { [string]: any }? = nil
local inOp = false
local opStep: string? = nil -- my current step id in the running operation
local opId: string? = nil
local opPosition: Vector3? = nil
local opHeli = false -- the casualty is a helicopter case (transport goes to the station dock)
local bays: { BasePart }? = nil
local currentGoal: string? = nil
local currentTarget: Vector3? = nil
local cash = 0
local lastAward: { [string]: any }? = nil
local rewardPending = false
local rewardShown = false
local rewardAt = math.huge
local acceptedFirst = false
local seenCerts: { [string]: boolean } = {}
local primed = false -- the first snapshot is a baseline: a returning player's gear / certs get no flare

local GOLD = Color3.fromRGB(255, 208, 106)
local REWARD_HOLD = 4 -- s the reward burst keeps the debrief tablet back (OnboardingRewardBusy)
-- first station calls: steps where the beacon stands on the casualty (or on your craft if on foot)
local FIND_STEPS = { passage = true, search = true, approach = true, calm = true, recovery = true }

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function flat(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- The swap model under Workspace.Dressing (the shell sits inside it, not beside it)
local function dressingPivot(folderName: string): CFrame?
	local dressing = Workspace:FindFirstChild("Dressing")
	local folder = dressing and dressing:FindFirstChild(folderName)
	return if folder and folder:IsA("Model") then folder:GetPivot() else nil
end

local function stationPoint(): Vector3
	local pivot = dressingPivot("Station")
	if pivot then
		return pivot.Position + pivot.LookVector * 38 + Vector3.new(0, 1.5, 0)
	end
	return Vector3.new(-110, 8, -27)
end

local function boardPoint(): Vector3
	local board = Workspace:FindFirstChild("StationRescueBoard")
	if board and board:IsA("Model") and board.PrimaryPart then
		return board.PrimaryPart.Position + Vector3.new(0, 2, 0)
	end
	return stationPoint() + Vector3.new(0, 0, -14)
end

local function chandleryPoint(): Vector3
	local pivot = dressingPivot("Chandlery")
	if pivot then
		return pivot.Position + pivot.LookVector * 20 + Vector3.new(0, 1.5, 0)
	end
	return Vector3.new(-44, 8, -40)
end

local function exercisePoint(): Vector3
	local board = Workspace:FindFirstChild("StationExerciseBoard")
	if board and board:IsA("Model") and board.PrimaryPart then
		return board.PrimaryPart.Position + Vector3.new(0, 2, 0)
	end
	return boardPoint() + Vector3.new(0, 0, 6)
end

-- Your craft (docked at your bay after the cold open), else the nearest launch bay.
local function craftPoint(): Vector3?
	local folder = Workspace:FindFirstChild("Vehicles")
	for _, m in if folder then folder:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId then
			return m:GetPivot().Position
		end
	end
	if not bays then
		local found: { BasePart } = {}
		local map = Workspace:FindFirstChild("Map")
		for _, d in if map then map:GetDescendants() else {} do
			if d:IsA("BasePart") and d:GetAttribute("LaunchBay") then
				table.insert(found, d)
			end
		end
		bays = found
	end
	local rp = rootPosition()
	local best: Vector3?, bestD = nil, math.huge
	local list: { BasePart } = bays or {}
	for _, b in list do
		local d = if rp then flat(rp, b.Position) else 0
		if d < bestD then
			best, bestD = b.Position, d
		end
	end
	return best
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

-- The drop-off the transport step lights (mirrors Mechanics/transport rightPad).
local function padPoint(): Vector3?
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs")
	local want = if opHeli then "Dock" else "Hospital"
	local fallback: Vector3? = nil
	for _, pad in if folder then folder:GetChildren() else {} do
		if pad:IsA("BasePart") then
			local name = pad:GetAttribute("DropOff")
			if name == want then
				return pad.Position
			elseif name == "Dock" then
				fallback = pad.Position
			end
		end
	end
	return fallback
end

-- The beacon inside one of the first station calls: your craft (when on foot), the casualty,
-- then the drop-off.
local function opTarget(): Vector3?
	if callsCompleted >= Onboarding.FAILSAFE_CALLS then
		return nil
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seated = hum ~= nil and hum.SeatPart ~= nil
	local step = opStep or ""
	if step == "kit_launch" or step == "launch" or FIND_STEPS[step] or step == "transport" then
		if not seated then
			return craftPoint()
		end
		return if step == "transport"
			then padPoint()
			elseif step == "kit_launch" or step == "launch" then nil
			else victimPoint()
	end
	return nil
end

local function goalTarget(goal: string): Vector3
	if goal == "CallBoard" then
		return boardPoint()
	elseif goal == "Gear" then
		return chandleryPoint()
	elseif goal == "Cert" then
		return exercisePoint()
	elseif goal == "Rescue" then
		if offer and typeof(offer.position) == "Vector3" then
			return offer.position
		end
		return boardPoint()
	end
	return stationPoint()
end

-- A gold flare over the player with a one-word title (certification / gear).
local function celebrate(title: string)
	local at = rootPosition()
	if not at then
		return
	end
	local flare = Instance.new("Part")
	flare.Name = "OnboardingFlare"
	flare.Anchored, flare.CanCollide, flare.CanQuery, flare.CanTouch = true, false, false, false
	flare.Transparency = 1
	flare.Size = Vector3.new(0.4, 0.4, 0.4)
	flare.CFrame = CFrame.new(at + Vector3.new(0, 10, 0))
	flare.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Brightness = 7
	light.Range = 38
	light.Shadows = false
	light.Parent = flare
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(GOLD)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new(1.2)
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = NumberRange.new(0.7, 1.3)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -14, 0)
	sparks.Rate = 70
	sparks.Parent = flare
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(190, 44)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 400
	board.Adornee = flare
	board.Parent = flare
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 22
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.35
	label.Text = title
	label.Parent = board
	AudioController.play("Bell_Buoy")
	TweenService:Create(
		flare,
		TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(at + Vector3.new(0, 38, 0)) }
	):Play()
	TweenService:Create(light, TweenInfo.new(2.4), { Brightness = 0 }):Play()
	task.delay(2.2, function()
		sparks.Enabled = false
	end)
	task.delay(3, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			flare:Destroy()
		end)
	end)
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
	local hadGear = gearOwned
	if type(data.gear) == "table" then
		gearOwned = next(data.gear) ~= nil
	end
	if gearOwned and not hadGear and primed then
		celebrate("GEAR")
	end
	if type(data.certs) == "table" then
		certEarned = certEarned or Onboarding.certDone(data.certs)
		for _, id in ProgressionConfig.CertOrder do
			local c = data.certs[id]
			if type(c) == "table" and c.earned == true then
				certEarned = true
				if not seenCerts[id] then
					seenCerts[id] = true
					local def = ProgressionConfig.Certifications[id]
					if primed then
						celebrate(if def then def.displayName else id)
					end
				end
			end
		end
	end
	primed = true
	if type(data.certsEarned) == "table" then
		for _, id in data.certsEarned do
			if type(id) == "string" and not seenCerts[id] then
				seenCerts[id] = true
				certEarned = true
				local def = ProgressionConfig.Certifications[id]
				celebrate(if def then def.displayName else id)
			end
		end
	end
end

local function showReward()
	if rewardShown or not rewardPending then
		return
	end
	if cash <= 0 then
		return -- wait for the cold open's award snapshot
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

local function near(point: Vector3, reach: number): boolean
	local rp = rootPosition()
	return rp ~= nil and flat(rp, point) <= reach
end

local function update(dt: number)
	if not active then
		if beacon then
			beacon.hide()
		end
		return
	end
	seconds += dt
	-- reward burst
	if rewardPending and os.clock() >= rewardAt then
		showReward()
	end
	-- reaching the station opens the call-board goal (the board is inside the hall)
	local sp = stationPoint()
	if not stationReached and (near(sp, Onboarding.REACH.Station) or near(boardPoint(), 22)) then
		stationReached = true
		Telemetry.once("StationReached") -- onboarding funnel step 11 (G64)
	end
	local bp = boardPoint()
	if not boardReached and near(bp, Onboarding.REACH.CallBoard) then
		boardReached = true
	end
	-- the call board is the in-world way to take the first tasking
	if
		not acceptedFirst
		and callsCompleted == 0
		and not inOp
		and offer
		and near(bp, Onboarding.REACH.CallBoard + 18)
	then
		acceptedFirst = true
		-- accepting from the edge of the board ring counts as reaching it, else the goal never
		-- leaves CallBoard and the gear / certification beacons never come
		boardReached, stationReached = true, true
		OpsController.Accept(tostring(offer.opId))
	end
	local goal: Onboarding.Goal? = Onboarding.goal({
		coldOpenDone = true,
		stationReached = stationReached,
		boardReached = boardReached,
		callsCompleted = callsCompleted,
		offerReady = offer ~= nil,
		gearOwned = gearOwned,
		certEarned = certEarned,
		seconds = seconds,
	})
	local kind = if goal then Onboarding.goalKind(goal) else "Place"
	local target = if goal then goalTarget(goal) else nil
	if inOp then
		-- the step card is the objective; on the first calls the beacon shows where it is
		target = opTarget()
		kind = "Call"
		goal = if target then "Rescue" else nil
	end
	if not goal or not target then
		if beacon then
			beacon.hide()
		end
		currentGoal = nil
		currentTarget = nil
		return
	end
	if goal ~= currentGoal or target ~= currentTarget then
		currentGoal = goal
		currentTarget = target
		if beacon then
			beacon.show(target, kind)
		end
	end
end

function OnboardingController.Init()
	if player:GetAttribute("ColdOpenDone") ~= true then
		beacon = OnboardingBeacon.start()
	end
	-- a returning player never sees the first-session goals
	if player:GetAttribute("ColdOpenDone") == true then
		return
	end

	OpsController.OnOffer:Connect(function(data: { [string]: any })
		offer = data
		acceptedFirst = false
	end)
	OpsController.OnState:Connect(function(s: { [string]: any })
		inOp = true
		opId = s.opId
		opPosition = if typeof(s.position) == "Vector3" then s.position else nil
		local was = opStep
		opStep = nil
		for _, c in s.current or {} do
			if c.trackId == s.myTrack then
				opStep = c.id
			end
		end
		if opStep == "transport" and was ~= "transport" then
			-- the pad is chosen when the step starts (as Mechanics/transport lights it)
			local c1 = s.casualties and s.casualties[1]
			opHeli = type(c1) == "table" and (c1.band == "Critical" or c1.band == "Serious")
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

	player:GetAttributeChangedSignal("OpsCompleted"):Connect(function()
		local n = player:GetAttribute("OpsCompleted")
		callsCompleted = math.max(0, (if type(n) == "number" then n else 0) - 1)
	end)
	local done = player:GetAttribute("OpsCompleted")
	callsCompleted = math.max(0, (if type(done) == "number" then done else 0) - 1)
	player:GetAttributeChangedSignal("ColdOpenEnded"):Connect(function()
		local reason = player:GetAttribute("ColdOpenEnded")
		if active or type(reason) ~= "string" then
			return
		end
		active = true
		endedAt = os.clock()
		seconds = 0
		rewardPending = Onboarding.rewarded(reason)
		if rewardPending then
			player:SetAttribute("OnboardingRewardBusy", true) -- OpsHud holds the debrief
		end
		rewardAt = endedAt + 0.5
		if player:GetAttribute("ColdOpenHandover") == "Ride" then
			rewardAt = math.huge -- play it when the arrival shot has handed back control
		end
	end)
	player:GetAttributeChangedSignal("ArrivalOnFoot"):Connect(function()
		if player:GetAttribute("ArrivalOnFoot") == true and rewardPending then
			rewardAt = math.min(rewardAt, os.clock() + 0.4)
		end
	end)
	-- a profile that was already past the cold open on join is a returning player: no beacons
	player:GetAttributeChangedSignal("ColdOpenDone"):Connect(function()
		if player:GetAttribute("ColdOpenDone") == true then
			task.delay(3, function()
				if not active and player:GetAttribute("ColdOpenEnded") == nil then
					if beacon then
						beacon.hide()
					end
				end
			end)
		end
	end)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(applyData)
end

function OnboardingController.Start()
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
	local last = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = math.min(now - last, 0.5)
		last = now
		if rewardPending and not rewardShown and rewardAt == math.huge and now - endedAt > 30 then
			rewardAt = now -- the arrival shot never came: do not lose the moment
		end
		update(dt)
	end)
end

-- True while the first-session world beacon is showing a goal (G58 hides the goal chip then).
function OnboardingController.beaconActive(): boolean
	return active and currentGoal ~= nil
end

return OnboardingController
