--!strict
-- OnboardingController: the first session's world-shown tutorial (docs/16 section 4, docs/24 E) on
-- the client. No tutorial text and no choice UI: the world leads (the beacon and its ground trail).
--   docs/25 J: the guide arrow and pin go to the build stand -> the HQ card pulses -> the free Rescue Hut
--   site (the beacon over it, the camera stays free) ->
--   cold open (jet ski, first survivor, home) -> the Builder walks off the jetty -> the guide arrow
--   and minimap pin go to the build station -> the Workshop card pulses in the tablet (the server
--   tops the wallet up to its price) -> the next call is the goal while the site runs -> the finished Workshop
--   grants one spin and the arrow points at your island's prize wheel -> the permanent Next chip (UI/NextChip).
--   No chip row of beats at the top (owner 2026-10-29: "it does not make sense to have it there").
-- It reads only replicated facts: the Ops signals, the PlayerDataChanged snapshot, player and plot
-- attributes (SiteKey / SiteProgress / SiteRate) and the Progression_GetData pull.
-- Also here: the cold-open reward burst (B1, still seated on the jet ski), the seat pips and the
-- green home cue (docs/20 4, 8). No sea-blue cover any more: a new player starts on their island.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local Client = script.Parent.Parent
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local DockController = require(script.Parent:WaitForChild("DockController"))
local MapController = require(script.Parent:WaitForChild("MapController"))
local UI = Client:WaitForChild("UI")
local ColdOpenCue = require(UI:WaitForChild("ColdOpenCue"))
local Layout = require(UI:WaitForChild("Layout"))
local Menu = require(UI:WaitForChild("Menu"))
local OnboardingBeacon = require(UI:WaitForChild("OnboardingBeacon"))
local OnboardingReward = require(UI:WaitForChild("OnboardingReward"))

local OnboardingController = {}
OnboardingController.Priority = 85 -- after OpsController (80), before DockController (100)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local beacon: OnboardingBeacon.Beacon? = nil
local active = false
local cash = 0
local totalRescues = 0
local savedColdOpen = false
local tutorialStep: number? = nil
local owned: { [string]: boolean } = {}
local dataReady = false
local lastAward: { [string]: any }? = nil
local rewardPending = false
local rewardShown = false
local rewardAt = math.huge

local REWARD_DELAY = 2 -- s after the cold open ends: the survivor swims in and climbs off, then the burst
local REWARD_HOLD = 4 -- s the reward burst keeps the debrief tablet back (OnboardingRewardBusy)
local GLANCE = 1.4 -- s the camera looks at a freshly built site (beat 4 / beat 6)
-- live v24: players quit seconds after WorkshopBuilt; the 1.4 s glance cut away mid brick drop, the snap played
-- off screen and out of earshot. Now the camera stays for the drop + build snap, then shows the wheel's free spin.
local SITE_HOLD = 3.4 -- s on the finished Workshop: the last bricks land and fx1_build_snap plays (Studio 2026-10-31)
local WHEEL_HOLD = 2.4 -- s on your prize wheel while its free spin pops
local SPIN_PINK = Color3.fromRGB(255, 80, 170) -- the wheel's pink: gold confetti vanished on its yellow
local TICK = 0.5 -- s between the site timer and the tablet-open checks

local beat: Onboarding.Beat = "ColdOpen"
local guide: string? = nil
local lastTabletPulse: string? = nil
local glanceSerial = 0
local siteWatched = false -- the Workshop site ran this session: its finish gets the full beat, a rejoin does not
local tickAt = 0

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function plotModel(): Model?
	local i = player:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	local m = if type(i) == "number" and marina then marina:FindFirstChild(`Plot{i}`) else nil
	return if m and m:IsA("Model") then m else nil
end

-- The island's running construction, published by DockService on the plot (docs/24 B).
local function siteState(): { key: string?, progress: number, rate: number }
	local pm = plotModel()
	local key = pm and pm:GetAttribute("SiteKey")
	return {
		key = if type(key) == "string" then key else nil,
		progress = (pm and tonumber(pm:GetAttribute("SiteProgress"))) or 0,
		rate = (pm and tonumber(pm:GetAttribute("SiteRate"))) or 1,
	}
end

-- The build station (the tablet) in the world: the same spot DockController opens by the berth frame.
local function stationPoint(): Vector3?
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return nil
	end
	return DockConfig.stationSpot(bay).Position + Vector3.new(0, 1.1, 0) -- the pad top (DockPieces.buildStation: 0.8 base + studs)
end

-- Your island's prize wheel (DockService tags it "PrizeWheel" with its Plot): the spin beat's target.
local function wheelModel(): Model?
	local i = player:GetAttribute("DockPlot")
	for _, w in CollectionService:GetTagged("PrizeWheel") do
		if w:IsA("Model") and w:GetAttribute("Plot") == i then
			return w
		end
	end
	return nil
end

local function sitePoint(key: string): Vector3?
	local pm = plotModel()
	if not pm then
		return nil
	end
	local site = pm:FindFirstChild("Site_" .. key)
	if site and site:IsA("Model") then
		return site:GetPivot().Position
	end
	local built = pm:FindFirstChild(key)
	if built and built:IsA("Model") then
		return built:GetPivot().Position
	end
	return nil
end

local function currentBeat(): Onboarding.Beat
	if not dataReady then
		return "ColdOpen"
	end
	local site = siteState()
	return Onboarding.beat({
		coldOpenDone = player:GetAttribute("ColdOpenDone") == true or savedColdOpen,
		totalRescues = totalRescues,
		step = tutorialStep,
		owned = owned,
		constructionKey = site.key,
	})
end

-- A short Scriptable look at a world spot for a beat (never while seated or under a panel). True when it plays.
local function glance(at: Vector3?, hold: number?, eye: Vector3?): boolean
	if not at or Layout.coldOpen() or player:GetAttribute("MenuOpen") == true then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and root:IsA("BasePart")) or hum.SeatPart then
		return false
	end
	if (root.Position - at).Magnitude > 220 then
		return false -- a build on your own island only: never yank the camera from across the map
	end
	local tablet = playerGui:FindFirstChild("BuildTablet")
	if tablet and tablet:IsA("ScreenGui") and tablet.Enabled then
		return false
	end
	glanceSerial += 1
	local serial = glanceSerial
	CameraController.SetOverride(CFrame.lookAt(eye or at + Vector3.new(18, 22, 18), at), 50)
	task.delay(hold or GLANCE, function()
		if serial ~= glanceSerial then
			return
		end
		local open = playerGui:FindFirstChild("BuildTablet")
		if open and open:IsA("ScreenGui") and open.Enabled then
			return
		end
		CameraController.ClearOverride()
	end)
	return true
end

-- The Workshop just finished in front of you: watch the last bricks land and the build snap, then the camera cuts
-- to your prize wheel as its free spin pops (confetti + sparkle), then hands back with the beacon on the wheel.
local function workshopDone(wheel: Model)
	if not glance(sitePoint(Onboarding.WORKSHOP), SITE_HOLD) then
		return -- seated (off on a call) or a panel open: the wheel beacon alone leads
	end
	task.delay(
		SITE_HOLD - 0.1,
		function() -- before the site glance clears: one cut, no frame of the player camera
			local root = rootPosition()
			local hub = wheel:GetBoundingBox().Position
			local side = if root then (root - hub) * Vector3.new(1, 0, 1) else Vector3.zero
			local eye = hub
				+ (if side.Magnitude > 1 then side.Unit else Vector3.zAxis) * 18
				+ Vector3.new(0, 5, 0) -- from your side (the face you walk up to), in front of the tablet
			if glance(hub, WHEEL_HOLD, eye) then
				task.delay(0.25, function()
					VFXKit.play("wheel_win", CFrame.new(hub), { color = SPIN_PINK, scale = 0.85 })
					AudioController.play("Album_Sparkle", nil, 1, 1)
				end)
			end
		end
	)
end

-- The first delivery (OperationService lets the rider off and docks the jet ski): stand on the jetty head in front
-- of the build tablet, facing it, so the reward burst and the station beacon play there. Live v21: 11 of 19 new
-- players quit still seated at sea after it, the station on land behind them.
local function stepToStation()
	local bay = player:GetAttribute("BayCFrame")
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if typeof(bay) ~= "CFrame" or not (char and hum and root and root:IsA("BasePart")) then
		return
	end
	local t0 = os.clock()
	while hum.SeatPart and os.clock() - t0 < 2 do
		hum.Sit = false
		task.wait()
	end
	if hum.SeatPart then
		return -- still welded: never drag the hull along
	end
	local station = DockConfig.stationSpot(bay)
	local at = (station * CFrame.new(0, 0, 8)).Position -- the deck in front of the tablet, inside its open range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(at + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), params)
	local feet = (if hit then hit.Position else at)
		+ Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.2, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local face = Vector3.new(station.X, feet.Y, station.Z)
	char:PivotTo(CFrame.lookAt(feet, face))
	-- the Foot camera keeps the ride's heading: turn it to look over the shoulder at the tablet
	task.wait()
	local cam = Workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(
		feet + (feet - face).Unit * 16 + Vector3.new(0, 7, 0),
		face + Vector3.new(0, 3, 0)
	)
end

local function buildTabletOpen(): boolean
	local gui = playerGui:FindFirstChild("BuildTablet")
	return gui ~= nil and gui:IsA("ScreenGui") and gui.Enabled
end

-- docs/24 E: the one world guide for the beat. The call marker stays UI/Waypoint's job; this handles
-- the build station arrow + minimap pin, and the arrow + pin to your island's prize wheel.
local function setGuide(kind: string?)
	if kind == guide then
		return
	end
	if beacon then
		beacon.hide()
	end
	MapController.SetBlips("Tutorial", nil)
	Menu.pulse(nil)
	if lastTabletPulse ~= nil then
		DockController.Pulse(nil)
		lastTabletPulse = nil
	end
	guide = kind
	-- one goal at a time: UI/Waypoint holds the call marker back on the station and spin beats (docs/24 E)
	player:SetAttribute(
		"TutorialHoldCall",
		if kind == "station" or kind == "spin" then true else nil
	)
	if kind == "hqsite" then
		-- the Hut rises: a beacon over the site, the camera stays the player's (docs/25 J)
		local at = sitePoint(Onboarding.HQ)
		if not at then
			guide = nil -- the site has not streamed in yet: retry next frame
			return
		end
		local b = beacon or OnboardingBeacon.start()
		beacon = b
		b.show(at, "Place")
	elseif kind == "station" then
		local at = stationPoint()
		if not at then
			guide = nil -- the berth frame has not replicated yet: retry next frame
			return
		end
		local b = beacon or OnboardingBeacon.start()
		beacon = b
		b.show(at, "Place")
		MapController.SetBlips("Tutorial", {
			{ id = "Build", position = at, style = "Waypoint", size = 22 },
		})
	elseif kind == "site" then
		siteWatched = true
		glance(sitePoint(Onboarding.WORKSHOP))
	elseif kind == "spin" then
		local wheel = wheelModel()
		if not wheel then
			guide = nil -- the wheel has not streamed in yet: retry next frame
		else
			local at = wheel:GetPivot().Position + Vector3.new(0, 1, 0)
			if siteWatched then
				siteWatched = false
				workshopDone(wheel)
			else
				glance(at)
			end
			local b = beacon or OnboardingBeacon.start()
			beacon = b
			b.show(at, "Place")
			MapController.SetBlips("Tutorial", {
				{ id = "Spin", position = at, style = "Waypoint", size = 22 },
			})
		end
	end
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
	if type(data.totalRescues) == "number" then
		totalRescues = data.totalRescues
	end
	savedColdOpen = data.coldOpenDone == true
	if type(data.dockBuildings) == "table" then
		owned = data.dockBuildings
	end
	tutorialStep = if type(data.tutorialStep) == "number" then data.tutorialStep else nil
	dataReady = true
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
	task.delay(REWARD_HOLD, function()
		player:SetAttribute("OnboardingRewardBusy", nil)
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
	box.Size = UDim2.fromOffset(300, 76)
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
		l.TextStrokeColor3 = Color3.fromHex("14121C")
		l.TextStrokeTransparency = 0
		l.Parent = box
		return l
	end
	local count = label(0, 0.5)
	-- one Lego stud per seat (tools/ui-art/stickers.py): green filled, grey empty, all red when full
	local pips = Instance.new("Frame")
	pips.BackgroundTransparency = 1
	pips.Position = UDim2.fromScale(0, 0.5)
	pips.Size = UDim2.fromScale(1, 0.5)
	pips.Parent = box
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = pips
	local last = 0
	local shown = ""
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
		if count.Text ~= shown then
			shown = count.Text
			for _, old in pips:GetChildren() do
				if old:IsA("ImageLabel") then
					old:Destroy()
				end
			end
			local px = if cap <= 4 then 36 else 30
			for i = 1, cap do
				local pip = Instance.new("ImageLabel")
				pip.BackgroundTransparency = 1
				pip.Size = UDim2.fromOffset(px, px)
				pip.ScaleType = Enum.ScaleType.Fit
				pip.LayoutOrder = i
				pip.Image = if i > n
					then UiImages.Badges.PipOff
					elseif full then UiImages.Badges.PipFull
					else UiImages.Badges.PipOn
				pip.Parent = pips
			end
		end
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
	if rewardPending and os.clock() >= rewardAt then
		showReward()
	end
	beat = currentBeat()
	if dataReady then
		local kind = if beat == "BuildStation" or beat == "BuildHQ"
			then "station"
			elseif beat == "HQSite" then "hqsite"
			elseif beat == "Build" then "site"
			elseif beat == "Spin" then "spin"
			else nil
		setGuide(kind)
	end
	-- the tablet's HQ / Workshop card pulses while the tutorial points at the station
	if os.clock() >= tickAt then
		tickAt = os.clock() + TICK
		if guide == "station" then
			local want = if beat == "BuildHQ" then Onboarding.HQ else Onboarding.WORKSHOP
			local key = if buildTabletOpen() then want else nil
			if key ~= lastTabletPulse then
				DockController.Pulse(key)
				lastTabletPulse = key
			end
		end
	end
end

function OnboardingController.Init()
	beacon = OnboardingBeacon.start()

	-- a delivery sets Rescued before the next snapshot
	local function readRescued()
		local n = player:GetAttribute("Rescued")
		if type(n) == "number" then
			totalRescues = math.max(totalRescues, n)
		end
	end
	player:GetAttributeChangedSignal("Rescued"):Connect(readRescued)
	readRescued()
	player:GetAttributeChangedSignal("ColdOpenEnded"):Connect(function()
		local reason = player:GetAttribute("ColdOpenEnded")
		if active or type(reason) ~= "string" then
			return
		end
		active = true
		rewardPending = Onboarding.rewarded(reason)
		if rewardPending then
			player:SetAttribute("OnboardingRewardBusy", true) -- OpsHud holds the debrief
		end
		rewardAt = os.clock() + REWARD_DELAY
		if rewardPending and player:GetAttribute("ColdOpenHandover") == "Ride" then
			task.spawn(stepToStation)
		end
	end)
	player:GetAttributeChangedSignal("ColdOpenDone"):Connect(function()
		if player:GetAttribute("ColdOpenDone") == true and not active then
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
	-- pull the first snapshot: the beat and the reward's Cash roll read it
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

return OnboardingController
