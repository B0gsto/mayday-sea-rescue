--!strict
-- OnboardingController: the first session's world-shown tutorial (docs/16 section 4, docs/30 section 4) on
-- the client. No tutorial text and no choice UI: the world leads (the beacon and its ground trail).
--   docs/25 J: the guide arrow and pin go to the build stand -> the HQ card pulses -> the free Rescue Hut
--   site (the beacon over it, the camera stays free) ->
--   cold open (jet ski, first survivor; GoBackController's one arrow on Go back, then home, still seated) -> the green
--   arrow on the Upgrade Station's button (the first delivery paid exactly L2) -> the level-up -> out again: the bow
--   faces the sea and one arrow pops out over the water while you are home -> a trip home hands over the free spin and the
--   beacon points at your island's prize wheel while you are home -> the permanent Next chip (UI/NextChip).
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
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatLevels = require(Shared:WaitForChild("BoatLevels"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local GoBack = require(Shared:WaitForChild("Boat"):WaitForChild("GoBack"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local UpgradeStation = require(Shared:WaitForChild("UpgradeStation"))

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
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))

local OnboardingController = {}
OnboardingController.Priority = 85 -- after OpsController (80), before DockController (100)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local beacon: OnboardingBeacon.Beacon? = nil
local active = false
local cash = 0
local totalRescues = 0
local savedColdOpen = false
local boatLevel = 1
local tutorialStep: number? = nil
local owned: { [string]: boolean } = {}
local dataReady = false
local lastAward: { [string]: any }? = nil
local rewardPending = false
local rewardShown = false
local rewardAt = math.huge

local REWARD_DELAY = 2 -- s after the cold open ends: the survivor swims in and climbs off, then the burst
local REWARD_HOLD = 4 -- s the reward burst keeps the debrief tablet back (OnboardingRewardBusy)
local GLANCE = 1.4 -- s the camera looks at the wheel when its free spin waits
local TICK = 0.5 -- s between the site timer and the tablet-open checks

local beat: Onboarding.Beat = "ColdOpen"
local guide: string? = nil
local lastTabletPulse: string? = nil
local glanceSerial = 0
local upgradeArrow: BillboardGui? = nil
local seaArrow: BillboardGui? = nil
local outAgainAt: number? = nil -- when the OutAgain beat began: its arrow waits out the level-up
local SEA_ARROW_OUT = 120 -- studs past the landing -- tune
local SEA_ARROW_UP = 24 -- studs over the berth's height -- tune
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
		boatLevel = boatLevel,
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

-- The steady green build arrow (the art of UI/TabletCue): one pop and a sound, never a pulse.
local function popArrow(name: string, adornee: Instance, up: number): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Adornee = adornee
	bb.StudsOffsetWorldSpace = Vector3.new(0, up, 0)
	bb.Size = UDim2.fromOffset(84, 84)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	bb.ResetOnSpawn = false
	local art = Instance.new("ImageLabel")
	art.BackgroundTransparency = 1
	art.Image = UiImages.Markers.BuildArrow
	art.ScaleType = Enum.ScaleType.Fit
	art.Size = UDim2.fromScale(1, 1)
	art.Parent = bb
	bb.Parent = playerGui
	Style.pop(art, true)
	AudioController.play("UI_Prompt")
	return bb
end

-- OutAgain, home: the arrow over the water straight out of the bay (the berth's seaward is -Z), gone once you leave.
local function setSeaArrow(on: boolean)
	if not on then
		if seaArrow then
			(seaArrow.Adornee :: Instance):Destroy()
			seaArrow:Destroy()
			seaArrow = nil
		end
		return
	end
	local bay = player:GetAttribute("BayCFrame")
	if seaArrow or typeof(bay) ~= "CFrame" then
		return
	end
	local spot = Instance.new("Attachment")
	spot.Name = "OutToSea"
	spot.Parent = Workspace.Terrain
	spot.WorldPosition = (UpgradeStation.fromBerth(bay) * CFrame.new(0, 0, -SEA_ARROW_OUT)).Position
	seaArrow = popArrow("SeaArrow", spot, SEA_ARROW_UP)
end

-- Over the station's Upgrade button. It may not have streamed in yet: update() asks again.
local function setUpgradeArrow(on: boolean)
	if not on then
		if upgradeArrow then
			upgradeArrow:Destroy()
			upgradeArrow = nil
		end
		return
	end
	local stations = Workspace:FindFirstChild("UpgradeStations")
	local station = stations and stations:FindFirstChild(`Station{player:GetAttribute("DockPlot")}`)
	local button = station and station:FindFirstChild("Button")
	if upgradeArrow or not button then
		return
	end
	upgradeArrow = popArrow("UpgradeArrow", button, 7)
end

-- Owner 2026-10-31 (first login on a phone: the tablet filled the screen, no sea, no island): a Hut-less spawn
-- opens on a short crane down from over the island to behind the player (the tablet ahead, the cove, jetty and
-- open sea past it); any tap, click or key cuts to the end. It ends on CameraController's Foot framing (START_ZOOM
-- 19 behind the head), so the Custom camera takes over with no jump. The join reward card waits for it.
local ESTABLISH = 2.6 -- s
local SETTLE_ZOOM = 19 -- CameraController START_ZOOM
local established = false

-- The Foot framing behind `focus` looking along flat unit `ahead`: turned 14 degrees left of it (the stand and the
-- name arch share the frame, the avatar never covers the stand), 13 degrees down (the quay shows).
local function behind(focus: Vector3, ahead: Vector3): CFrame
	local look = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(14)) * CFrame.fromAxisAngle(
		ahead:Cross(Vector3.yAxis),
		math.rad(-13)
	)).Rotation * ahead
	return CFrame.lookAt(focus - look * SETTLE_ZOOM, focus)
end
local function frameSpawnBody()
	local wait0 = os.clock() -- the plot attributes replicate after the first character (the loading screen waits too)
	while
		(
			typeof(player:GetAttribute("BayCFrame")) ~= "CFrame"
			or player:GetAttribute("DockLevelHQ") == nil
		) and os.clock() - wait0 < 20
	do
		task.wait()
	end
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" or player:GetAttribute("DockLevelHQ") ~= 0 then
		return
	end
	local spawn = DockConfig.newSpawn(bay)
	local first = not established and not CameraController.Comfort.reducedMotion()
	if first then
		player:SetAttribute("Establishing", true) -- RewardController holds the join card for the shot
	end
	-- the server stands the character there a moment after the spawn (VehicleService): frame it once it has
	local root: BasePart? = nil
	local t0 = os.clock()
	while not root and os.clock() - t0 < 8 do
		task.wait(0.1)
		local char = player.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if
			r
			and r:IsA("BasePart")
			and ((r.Position - spawn.Position) * Vector3.new(1, 0, 1)).Magnitude < 6
		then
			root = r
		end
	end
	while player:GetAttribute("LoadingScreenActive") == true do
		task.wait()
	end
	if not root or Layout.coldOpen() or player:GetAttribute("CinematicPlaying") == true then
		player:SetAttribute("Establishing", nil)
		return
	end
	local ahead = (spawn.LookVector * Vector3.new(1, 0, 1)).Unit
	local focus = root.Position + Vector3.new(0, 3, 0) -- the Custom camera's subject: head offset + CameraController LIFT
	local settle = behind(focus, ahead)
	local cam = Workspace.CurrentCamera
	if not first then
		cam.CFrame = settle -- a respawn or reduced motion: the framing, no move
		return
	end
	established = true
	local fov = CameraController.Comfort.get("fov")
	local handle = CameraController.PlayCinematic({
		{
			from = CFrame.lookAt(focus - ahead * 40 + Vector3.new(0, 42, 0), focus + ahead * 80),
			to = settle,
			duration = ESTABLISH,
			fov = fov + 8,
			toFov = fov,
			handheld = 0,
		},
	}, { id = "establish", skippable = false })
	local skip = UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if
			t == Enum.UserInputType.Touch
			or t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.Keyboard
			or t.Name:sub(1, 7) == "Gamepad"
		then
			handle.stop()
		end
	end)
	while not handle.isDone() do
		task.wait()
	end
	skip:Disconnect()
	cam.CFrame = settle -- skipped mid-move: land on the framing, not where the move was cut
	player:SetAttribute("Establishing", nil)
end

-- REV2: an error mid-shot must never leave Establishing set (RewardController would hold the join card all session)
local function frameSpawn()
	xpcall(frameSpawnBody, function(err)
		warn(`[OnboardingController] establishing shot failed: {err}`)
	end)
	player:SetAttribute("Establishing", nil)
end

local function buildTabletOpen(): boolean
	local gui = playerGui:FindFirstChild("BuildTablet")
	return gui ~= nil and gui:IsA("ScreenGui") and gui.Enabled
end

-- The one world guide for the beat. The call marker stays UI/Waypoint's job; this handles the build station arrow +
-- minimap pin, the Upgrade button's arrow + pin, and the arrow + pin to your island's prize wheel.
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
	-- one goal at a time: UI/Waypoint holds the call marker back while these lead (docs/24 E)
	player:SetAttribute(
		"TutorialHoldCall",
		if kind == "station" or kind == "upgrade" or kind == "spin" then true else nil
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
	elseif kind == "upgrade" then
		local i = player:GetAttribute("DockPlot")
		if type(i) ~= "number" then
			guide = nil -- the plot has not replicated yet: retry next frame
			return
		end
		local at = UpgradeStation.buttonAt(i)
		local b = beacon or OnboardingBeacon.start()
		beacon = b
		b.show(at, "Place")
		MapController.SetBlips("Tutorial", {
			{ id = "Upgrade", position = at, style = "Waypoint", size = 22 },
		})
	elseif kind == "spin" then
		local wheel = wheelModel()
		if not wheel then
			guide = nil -- the wheel has not streamed in yet: retry next frame
		else
			local at = wheel:GetPivot().Position + Vector3.new(0, 1, 0)
			glance(at)
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
	boatLevel = tonumber(data.boatLevel) or boatLevel
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

-- The cold-open jet ski while it runs and we are off it (thrown or swam away), else nil.
local function strandedFrom(): Model?
	local vehicles = Workspace:FindFirstChild("Vehicles")
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if player:GetAttribute("ColdOpenActive") ~= true or not (vehicles and hum) then
		return nil
	end
	for _, m in vehicles:GetChildren() do
		if
			m:IsA("Model")
			and m:GetAttribute("ColdOpen") == true
			and m:GetAttribute("Owner") == player.UserId
		then
			local seat = hum.SeatPart
			return if seat and seat:IsDescendantOf(m) then nil else m
		end
	end
	return nil
end

-- The spin's beacon stays home: out on a trip it must not pull you back (UpgradeService ends the beat on the next return).
local function wheelNear(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local root = rootPosition()
	return root ~= nil
		and (
			(hum ~= nil and hum.SeatPart == nil)
			or GoBack.isHome(root, player:GetAttribute("BayCFrame"))
		)
end

local function atHome(): boolean
	local root = rootPosition()
	return root ~= nil and GoBack.isHome(root, player:GetAttribute("BayCFrame"))
end

local function update()
	if rewardPending and os.clock() >= rewardAt then
		showReward()
	end
	beat = currentBeat()
	outAgainAt = if beat == "OutAgain" then outAgainAt or os.clock() else nil
	-- the Day 1 card waits for the first trip home: a new player's first screen is the game (owner 2026-11-03)
	player:SetAttribute(
		"TutorialHoldReward",
		if beat == "Done" or beat == "Spin" then nil else true
	)
	-- off the jet ski mid cold open: the edge pointer leads back to it (its craft pin marks it in view)
	local craft = strandedFrom()
	if craft then
		setGuide("craft")
		if beacon then
			beacon.show(craft:GetPivot().Position, "Call")
		end
	elseif dataReady or guide == "craft" then
		local kind = if not dataReady
			then nil
			elseif
				beat == "Upgrade"
				and player:GetAttribute("OnboardingRewardBusy") ~= true
				and BoatLevels.canBuy(boatLevel, cash)
			then "upgrade"
			elseif beat == "Spin" and wheelNear() then "spin"
			elseif
				outAgainAt
				and os.clock() - outAgainAt >= UpgradeStation.MOMENT
				and atHome()
			then "sea"
			else nil
		setGuide(kind)
	end
	-- at the stand the tablet's own cue (green arrow + Build) is the one marker on it
	local cued = DockController.TabletGoal(guide == "station")
	setUpgradeArrow(guide == "upgrade")
	setSeaArrow(guide == "sea")
	if beacon then
		-- the Upgrade button's own arrow is the marker on it; the pointer and trail still lead from the jetty
		beacon.mute(guide == "station" and cued or guide == "craft" or guide == "upgrade")
		beacon.edge(true)
	end
	-- the tablet's HQ card pulses while the tutorial points at the station
	if os.clock() >= tickAt then
		tickAt = os.clock() + TICK
		if guide == "station" then
			local key = if buildTabletOpen() then Onboarding.HQ else nil
			if key ~= lastTabletPulse then
				DockController.Pulse(key)
				lastTabletPulse = key
			end
		end
	end
end

function OnboardingController.Init()
	player:SetAttribute("TutorialHoldReward", true) -- before RewardController's first look; update() releases it
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
	player.CharacterAdded:Connect(function()
		task.spawn(frameSpawn)
	end)
	if player.Character then
		task.spawn(frameSpawn)
	end
end

return OnboardingController
