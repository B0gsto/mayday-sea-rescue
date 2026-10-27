--!strict
-- NextChip: the permanent "what to build next" chip (docs/24 E/F) in the HudLayout "chips" slot.
-- Compact: the next building's Lego icon, its 1-3 word name, a Cash bar to its price. At the price it
-- pops once (never a looping pulse: owner 2026-10-28); during a construction it shows the site's progress and time left instead. Tapping / clicking
-- (or F / gamepad Y, shown as an InputGlyph) opens the build tablet when you stand at the station,
-- else puts the guide arrow and the minimap pin on the station for a few seconds.
-- The tutorial's chip row (OnboardingController) owns this slot until the tutorial is done.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Net = require(Shared:WaitForChild("Net"))
local NextGoal = require(Shared:WaitForChild("NextGoal"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))

local UI = script.Parent
local BuildGlyph = require(UI:WaitForChild("BuildGlyph"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))
local OnboardingBeacon = require(UI:WaitForChild("OnboardingBeacon"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))

local player = Players.LocalPlayer

local NextChip = {}

local root: ImageButton? = nil
local iconWell: Frame? = nil
local nameLabel: TextLabel? = nil
local priceLabel: TextLabel? = nil
local fill: Frame? = nil
local pulseScale: UIScale? = nil
local pulsing = false

local snapshot: { [string]: any }? = nil
local beacon: OnboardingBeacon.Beacon? = nil
local pointingUntil = 0
local doneAt: number? = nil
local pointingAt: Vector3? = nil
local lastSite: NextGoal.Site? = nil
local lastSiteAt = 0

local POINT_SECONDS = 10 -- s the arrow/pin stay after a tap
local NEAR_STATION = 18 -- studs: close enough to open the tablet from the chip

local function applyData(data: any)
	if type(data) == "table" then
		snapshot = data
	end
end

local function siteState(): NextGoal.Site?
	local i = player:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	local plot = if type(i) == "number" and marina then marina:FindFirstChild(`Plot{i}`) else nil
	local key = plot and plot:GetAttribute("SiteKey")
	if type(key) ~= "string" then
		return nil
	end
	return {
		key = key,
		level = tonumber(plot:GetAttribute("SiteLevel")),
		progress = math.clamp(tonumber(plot:GetAttribute("SiteProgress")) or 0, 0, 1),
		rate = tonumber(plot:GetAttribute("SiteRate")) or 1,
	}
end

-- The station (the tablet) in the world: the same spot DockController opens by the berth frame.
local function stationPoint(): Vector3?
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return nil
	end
	return DockConfig.stationSpot(bay).Position + Vector3.new(0, 1.1, 0) -- the pad top (DockPieces.buildStation: 0.8 base + studs)
end

local function beat(): Onboarding.Beat
	local s = snapshot
	if not s then
		return "ColdOpen"
	end
	local site = siteState()
	return Onboarding.beat({
		coldOpenDone = s.coldOpenDone == true,
		totalRescues = tonumber(s.totalRescues) or 0,
		step = tonumber(s.tutorialStep),
		owned = if type(s.dockBuildings) == "table" then s.dockBuildings else {},
		constructionKey = if site then site.key else nil,
	})
end

local function clearPointing()
	pointingUntil, pointingAt = 0, nil
	if beacon then
		beacon.hide()
	end
	local map =
		require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("MapController"))
	map.SetBlips("NextGoal", nil)
end

local function pointAt(pos: Vector3)
	local b = beacon or OnboardingBeacon.start()
	beacon = b
	b.show(pos, "Place")
	pointingAt, pointingUntil = pos, os.clock() + POINT_SECONDS
	local map =
		require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("MapController"))
	map.SetBlips("NextGoal", {
		{ id = "Build", position = pos, style = "Waypoint", size = 22 },
	})
end

local function nearby(pos: Vector3): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and rootPart and rootPart:IsA("BasePart")) or hum.SeatPart then
		return false
	end
	local d = rootPart.Position - pos
	return Vector3.new(d.X, 0, d.Z).Magnitude <= NEAR_STATION
end

-- The chip's one action: open the tablet at the station, else lead there.
local function activate()
	local station = stationPoint()
	if not station then
		return
	end
	if nearby(station) then
		local dock =
			require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("DockController"))
		if dock.OpenBuild() then
			clearPointing()
			return
		end
	end
	pointAt(station)
end

local function startPulse(on: boolean)
	local scale = pulseScale
	if not scale or pulsing == on then
		return
	end
	pulsing = on
	if not on then
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
		return
	end
	-- one gentle pop as it becomes affordable, then it rests
	scale.Scale = 1.1
	TweenService:Create(
		scale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function refresh()
	local r = root
	local s = snapshot
	local done = s ~= nil and beat() == "Done"
	if not done then
		doneAt = nil
	end
	if done and s and doneAt == nil then
		doneAt = os.clock() + Onboarding.DONE_HOLD + 0.5 -- the tutorial's ticked Spin chip keeps the slot first
	end
	if not (r and s and done and doneAt and os.clock() >= doneAt) then
		if r then
			r.Visible = false
		end
		startPulse(false)
		return
	end
	local levels = if type(s.dock) == "table" and type(s.dock.levels) == "table"
		then s.dock.levels
		else {}
	-- a running site owns the chip: a frame without SiteKey (playtest 2026-10-26, not reproduced) must not flip
	-- it to the next buy. shortcut: a 3 s hold, until the server's site state is found to drop out
	local site = siteState()
	if site then
		lastSite, lastSiteAt = site, os.clock()
	elseif
		lastSite
		and os.clock() - lastSiteAt < 3
		and (tonumber(levels[lastSite.key]) or 0) < (lastSite.level or 1)
	then
		site = lastSite
	end
	local g = NextGoal.next({
		cash = tonumber(s.cash) or 0,
		levels = levels,
		construction = site,
	})
	if not g then
		r.Visible = false
		startPulse(false)
		clearPointing()
		return
	end
	r.Visible = true
	local art = iconWell :: Frame
	art:ClearAllChildren()
	if DockConfig.Buildings[g.key] then
		BuildGlyph(art, { kind = "Building", key = g.key })
	else
		BuildGlyph(art, { kind = "Decor", key = g.key })
	end
	local name = nameLabel :: TextLabel
	name.Text = if g.level > 1 then `{g.name} Lv{g.level}` else g.name
	local fillFrame = fill :: Frame
	local price = priceLabel :: TextLabel
	fillFrame.Size = UDim2.fromScale(g.progress, 1)
	fillFrame.BackgroundColor3 = if g.kind == "Site"
		then HudTheme.Colors.ready
		else HudTheme.Colors.gold
	if g.kind == "Site" then
		price.Text = BuildTimer.text(g.timeLeft or 0)
		price.TextColor3 = HudTheme.Colors.ready
	else
		price.Text = HudTheme.formatNumber(g.price)
		price.TextColor3 = HudTheme.Colors.gold
	end
	startPulse(g.kind == "Build" and g.progress >= 1)
end

local function tick()
	-- hide under panels, cinematics and the cold open; the chip is part of the gameplay HUD
	local r = root
	if not r then
		return
	end
	local hidden = Layout.coldOpen()
		or player:GetAttribute("MenuOpen") == true
		or player:GetAttribute("MapOpen") == true
		or player:GetAttribute("CinematicPlaying") == true
	if hidden then
		r.Visible = false
	else
		refresh()
	end
	if pointingAt then
		local station = stationPoint()
		if
			os.clock() > pointingUntil
			or (station and nearby(station))
			or player:GetAttribute("MenuOpen") == true
		then
			clearPointing()
		end
	end
end

function NextChip.mount(region: Frame)
	if root then
		return
	end
	local r = Style.button(region, UDim2.fromScale(1, 1))
	r.Name = "NextChip"
	r.Visible = false
	root = r
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BorderSizePixel = 0
	panel.Parent = r
	-- the UI kit look, like the tutorial chips it replaces (playtest 2026-10-26: slate read faint)
	Style.corner(panel, 10)
	Style.gradient(panel, Style.grad("ink"))
	Style.stroke(panel, 3, true)

	local well = Instance.new("Frame")
	well.Name = "Icon"
	well.BackgroundColor3 = HudTheme.Colors.panelLight
	well.BackgroundTransparency = 0.1
	well.Position = UDim2.fromOffset(6, 6)
	well.Size = UDim2.fromOffset(36, 36)
	well.Parent = panel
	HudTheme.corner(well, 5)
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.74, 0.74)
	art.Parent = well
	iconWell = art

	local name = Style.label(panel, "", 20)
	name.Name = "Name"
	name.Size = UDim2.new(1, -150, 0, 26)
	name.Position = UDim2.fromOffset(50, 2)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel = name
	local price = Style.label(panel, "", 20)
	price.Name = "Price"
	price.Size = UDim2.fromOffset(80, 26)
	price.Position = UDim2.new(1, -124, 0, 2)
	price.TextXAlignment = Enum.TextXAlignment.Right
	price.TextColor3 = HudTheme.Colors.gold
	priceLabel = price

	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.BackgroundColor3 = HudTheme.Colors.locked
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Position = UDim2.fromOffset(50, 32)
	back.Size = UDim2.new(1, -94, 0, 8)
	back.Parent = panel
	HudTheme.corner(back, 3)
	local f = Instance.new("Frame")
	f.Name = "Fill"
	f.BackgroundColor3 = HudTheme.Colors.gold
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(0, 1)
	f.Parent = back
	HudTheme.corner(f, 3)
	fill = f

	local slot = Instance.new("Frame")
	slot.Name = "Key"
	slot.BackgroundTransparency = 1
	slot.AnchorPoint = Vector2.new(1, 0)
	slot.Position = UDim2.new(1, -4, 0, 4)
	slot.Size = UDim2.fromOffset(38, 36)
	slot.Parent = panel
	InputGlyph.chip(slot, Enum.KeyCode.F, Enum.KeyCode.ButtonY)

	local pulse = Instance.new("UIScale")
	pulse.Name = "NextPulse"
	pulse.Parent = r
	pulseScale = pulse

	Style.press(r, activate, HudTheme.Corner)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(applyData)
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30) :: RemoteFunction?
		local ok, data = pcall(function()
			return getData and getData:InvokeServer()
		end)
		if ok then
			applyData(data)
		end
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.25)
		end
	end)
	ContextActionService:BindActionAtPriority("NextGoal_Key", function(_, state, _input)
		if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if not root or not root.Visible then
			return Enum.ContextActionResult.Pass
		end
		activate()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Medium.Value - 1, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
end

return NextChip
