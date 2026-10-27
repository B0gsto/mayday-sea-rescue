--!strict
-- OnboardingController: the first session's world-shown tutorial (docs/16 section 4, docs/24 E) on
-- the client. No tutorial text and no choice UI: the world leads, a chip row counts the beats.
--   docs/25 J: the guide arrow and pin go to the build stand -> the HQ card pulses -> the free Rescue Hut
--   site (the beacon over it, the camera stays free) ->
--   cold open (jet ski, first survivor, home) -> the Builder walks off the jetty -> the guide arrow
--   and minimap pin go to the build station -> the Workshop card pulses in the tablet (the server
--   tops the wallet up to its price) -> the chip row shows the site's timer while the next call is
--   the goal -> the finished Workshop grants one spin and the arrow points at your island's prize wheel -> the chip row
--   gives way to the permanent Next chip (UI/NextChip).
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
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))

local Client = script.Parent.Parent
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local DockController = require(script.Parent:WaitForChild("DockController"))
local MapController = require(script.Parent:WaitForChild("MapController"))
local Telemetry = require(Client:WaitForChild("Telemetry"))
local UI = Client:WaitForChild("UI")
local BuildGlyph = require(UI:WaitForChild("BuildGlyph"))
local ColdOpenCue = require(UI:WaitForChild("ColdOpenCue"))
local Glyph = require(UI:WaitForChild("Glyph"))
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
local TICK = 0.5 -- s between the site timer and the tablet-open checks

local chipsGui: ScreenGui? = nil
local chipViews: { [string]: { root: Frame, label: TextLabel, tick: Frame, stroke: UIStroke } } = {}
local beat: Onboarding.Beat = "ColdOpen"
local guide: string? = nil
local lastTabletPulse: string? = nil
local glanceSerial = 0
local tickAt = 0
local doneAt: number? = nil
local holdingTick = false

local CHIPS: { { id: string, label: string, icon: string? } } = {
	{ id = "HQ", label = "Hut" },
	{ id = "Rescue", label = "Rescue", icon = "lifebuoy" },
	{ id = "Workshop", label = "Workshop" },
	{ id = "Spin", label = "Spin", icon = "spin" },
}

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
local function wheelPoint(): Vector3?
	local i = player:GetAttribute("DockPlot")
	for _, w in CollectionService:GetTagged("PrizeWheel") do
		if w:IsA("Model") and w:GetAttribute("Plot") == i then
			return w:GetPivot().Position + Vector3.new(0, 1, 0)
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

-- A short Scriptable look at a world spot for a beat (never while seated or under a panel).
local function glance(at: Vector3?)
	if not at or Layout.coldOpen() or player:GetAttribute("MenuOpen") == true then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and root:IsA("BasePart")) or hum.SeatPart then
		return
	end
	if (root.Position - at).Magnitude > 220 then
		return -- a build on your own island only: never yank the camera from across the map
	end
	local tablet = playerGui:FindFirstChild("BuildTablet")
	if tablet and tablet:IsA("ScreenGui") and tablet.Enabled then
		return
	end
	glanceSerial += 1
	local serial = glanceSerial
	CameraController.SetOverride(CFrame.lookAt(at + Vector3.new(18, 22, 18), at), 50)
	task.delay(GLANCE, function()
		if serial ~= glanceSerial then
			return
		end
		local open = playerGui:FindFirstChild("BuildTablet")
		if open and open:IsA("ScreenGui") and open.Enabled then
			return
		end
		CameraController.ClearOverride()
	end)
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
		glance(sitePoint(Onboarding.WORKSHOP))
	elseif kind == "spin" then
		local at = wheelPoint()
		if not at then
			guide = nil -- the wheel has not streamed in yet: retry next frame
		else
			glance(sitePoint(Onboarding.WORKSHOP))
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
	Telemetry.once("RewardSeen") -- onboarding funnel step 6 (G64)
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

-- The tutorial's top row of goal chips (docs/24 E): icon + 1-3 words + a tick when the beat is done.
local function makeChip(
	bar: Frame,
	info: { id: string, label: string, icon: string? },
	index: number
): Frame
	-- the UI kit look (playtest 2026-10-26: the slate chips were small and faint): gradient blocks, ink outlines, FredokaOne
	local root = Instance.new("Frame")
	root.Name = "Chip_" .. info.id
	root.Position = UDim2.new((index - 1) / #CHIPS, 3, 0, 0)
	root.Size = UDim2.new(1 / #CHIPS, -6, 1, 0)
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.BorderSizePixel = 0
	root.Parent = bar
	Style.corner(root, 10)
	Style.gradient(root, Style.grad("ink"))
	local stroke = Style.stroke(root, 3, true)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 6, 0.5, 0)
	icon.Size = UDim2.fromOffset(30, 30)
	icon.Parent = root
	if info.id == "Workshop" or info.id == "HQ" then
		BuildGlyph(icon, { kind = "Building", key = info.id :: string })
	else
		Style.icon(icon, info.icon or "build")
	end
	local label = Style.label(root, info.label, 20)
	label.Position = UDim2.fromOffset(40, 0)
	label.Size = UDim2.new(1, -44, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 22
	fit.Parent = label
	-- the tick: a badge on the icon's corner, so the word keeps the chip's width
	local tick = Instance.new("Frame")
	tick.Name = "Tick"
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromOffset(34, 10)
	tick.Size = UDim2.fromOffset(18, 18)
	tick.BackgroundColor3 = Color3.new(1, 1, 1)
	tick.BorderSizePixel = 0
	tick.Visible = false
	tick.ZIndex = 3
	tick.Parent = root
	Style.corner(tick, 9)
	Style.gradient(tick, Style.grad("buy"))
	Style.stroke(tick, 2, true)
	Glyph.draw("check", tick, Color3.new(1, 1, 1))
	chipViews[info.id] = { root = root, label = label, tick = tick, stroke = stroke }
	return root
end

local function mountChips()
	if chipsGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialChips"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 17 -- over the HUD, under the menu panels
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = playerGui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromScale(1, 1)
	bar.Parent = Layout.region(gui, "chips")
	chipsGui = gui
	for i, info in CHIPS do
		makeChip(bar, info, i)
	end
end

local function renderChips()
	local gui = chipsGui
	if not gui then
		return
	end
	local shown = dataReady
		and beat ~= "ColdOpen"
		and (beat ~= "Done" or holdingTick)
		and not Layout.coldOpen()
		and player:GetAttribute("MenuOpen") ~= true
		and player:GetAttribute("CinematicPlaying") ~= true
	gui.Enabled = shown
	if not shown then
		return
	end
	local site = siteState()
	-- the Hut's or the Workshop's chip shows its site's timer (both are Lv1 builds)
	local digging = if site.key == Onboarding.HQ or site.key == Onboarding.WORKSHOP
		then site.key
		else nil
	local work = if digging
		then BuildTimer.work(DockConfig.Buildings[digging].levels[1].cash)
		else 0
	local left = if digging then BuildTimer.timeLeft(site.progress, site.rate, work) else 0
	local done = {
		HQ = owned[Onboarding.HQ] == true,
		Rescue = totalRescues >= 1,
		Workshop = owned[Onboarding.WORKSHOP] == true,
		Spin = (tutorialStep or 0) >= Onboarding.STEP_DONE,
	}
	local here: { [string]: boolean } = {
		HQ = beat == "BuildHQ" or beat == "HQSite",
		Rescue = beat == "Rescue",
		Workshop = beat == "BuildStation" or beat == "Build",
		Spin = beat == "Spin",
	}
	for _, info in CHIPS do
		local view = chipViews[info.id]
		if view then
			local complete = done[info.id] == true
			local current = here[info.id] == true
			view.tick.Visible = complete
			Style.gradient(
				view.root,
				Style.grad(if current then "orange" elseif complete then "green" else "ink")
			)
			view.stroke.Color = if current then Color3.new(1, 1, 1) else Color3.fromHex("14121C")
			if info.id == digging and not complete then
				view.label.Text = BuildTimer.text(left)
			else
				view.label.Text = info.label
			end
		end
	end
end

local function update()
	if rewardPending and os.clock() >= rewardAt then
		showReward()
	end
	beat = currentBeat()
	-- the Spin chip ticks for a moment after the first spin before the Next chip takes the slot
	if beat == "Done" and tutorialStep and tutorialStep >= Onboarding.STEP_DONE then
		doneAt = doneAt or os.clock() + Onboarding.DONE_HOLD
	else
		doneAt = nil
	end
	holdingTick = beat == "Done" and doneAt ~= nil and os.clock() < doneAt
	if dataReady then
		local kind = if beat == "BuildStation" or beat == "BuildHQ"
			then "station"
			elseif beat == "HQSite" then "hqsite"
			elseif beat == "Build" then "site"
			elseif beat == "Spin" then "spin"
			else nil
		setGuide(kind)
	end
	renderChips()
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

	-- a delivery sets Rescued before the next snapshot (the cold open's rescue is the first chip's tick)
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
	mountChips()
	-- pull the first snapshot: the beat, the reward's Cash roll and the chip row all read it
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
