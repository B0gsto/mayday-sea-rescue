--!strict
-- MapController: the GTA-style map that replaces 3D guidance arrows (docs 05 HUD style).
--
--   * Minimap (bottom left, top left on touch, Layout region): the player at the centre, the map
--     heading-up (the bow while seated, else the camera), a north marker on the rim, zoom from speed (close on foot,
--     wide at speed in a boat),
--     blips (the operation's casualty / vessel pulsing, the drop-off when transporting, offers,
--     the station, quay desk, your vehicles, other crew, storm areas, your
--     waypoint) with objective blips clamped to the rim, a dotted line to the current objective (its
--     distance lives on UI/Waypoint's marker and the strip, one readout: playtest 2). Tap / click it to open the full map.
--   * Full map (M, gamepad View/Select, the MAP button): a kit Panel window. Pan (drag / left stick),
--     zoom (wheel, pinch, + / -, triggers), click / tap / A to set your own waypoint (again on it,
--     or X, clears it), close with M, Esc, Backspace, B or the panel's X. Zoom / Me / Clear sit bottom
--     left and a small collapsible legend (tap its header, or gamepad Y) bottom right. Place names
--     (MapConfig.Places) are live labels at a fixed screen size; one that would touch a control or a
--     name drawn before it is skipped. Fog (DiscoveryConfig) covers the unexplored map.
--   * Hidden while LocalPlayer attribute CinematicPlaying is true.
--
-- API: MapController.SetWaypoint(pos: Vector3?), GetWaypoint(), Open(), Close(), IsOpen(),
--      GetObjective(): (Vector3?, label?, routeStuds?), the one goal (by boat: its next sea leg round the islands,
--      RingLayout.seaRoute, and the route's length): "Craft" | "Casualty" | "Drop-off" | "Quest" | "Mayday" |
--      "Waypoint". Order (docs/20 rule 1): your accepted call, then your quest (QuestService's QuestTarget
--      attribute), then a call offer, then your own waypoint. An offer never takes the pin from a quest.
--      GetTargets(): { Vector3 }
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DiscoveryConfig = require(Shared:WaitForChild("Config"):WaitForChild("DiscoveryConfig"))
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("MapConfig"))
local RingLayout = require(Shared:WaitForChild("Config"):WaitForChild("RingLayout"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local Weather = require(Shared:WaitForChild("Weather"))
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = UI:WaitForChild("Kit")
local DiscoveryController = require(script.Parent:WaitForChild("DiscoveryController"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local Layout = require(UI:WaitForChild("Layout"))
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local MapController = {}
MapController.Priority = 120

local player = Players.LocalPlayer
local C = HudTheme.Colors
local DEEP = Color3.fromRGB(8, 38, 82)

type Style = { label: string, glyph: string, color: Color3 }
type BlipDraw = {
	id: string,
	pos: Vector3,
	style: Style,
	pulse: boolean?,
	clamp: boolean?,
	size: number?,
	minimap: boolean?,
}
type Pool = { parent: GuiObject, items: { [string]: Frame }, used: { [string]: boolean } }

local OpsController: any = nil
local gui: ScreenGui -- the full map (whole screen)
local miniGui: ScreenGui -- the minimap, in the Layout "minimap" region (safe area)
local mini: { [string]: any } = {}
local full: { [string]: any } = {}
local waypoint: Vector3? = nil
local viewRadius = MapConfig.Zoom.foot
local offers: { [string]: { position: Vector3, expires: number } } = {}
local closedOps: { [string]: boolean } = {}
local isOpen = false
local objective: Vector3?, objectiveLabel: string? = nil, nil
local objectiveRoute: number? = nil -- by boat: the sea route's length (objective is then its next leg)
local targets: { Vector3 } = {} -- the pulsing call blips (survivors, vessels, offers) last frame
-- extra static blips other systems hand in (SetBlips), keyed by group: the seamarks
local extraBlips: { [string]: { BlipDraw } } = {}
local RING = 1.08 -- bezel size / minimap square
local MAP_HALF = 0.395 -- map canvas radius / square side (just past the bezel hole, RING * 0.72 / 2)
local S = Theme.Size

-- the map fog grid (DiscoveryConfig)
local FOG = DiscoveryConfig.Fog
local FOG_COLOR = Color3.fromRGB(7, 18, 34)

-- ---------------------------------------------------------------- small UI helpers

local function corner(o: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if r then UDim.new(0, r) else UDim.new(0.5, 0)
	c.Parent = o
end

local function stroke(o: GuiObject, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
end

local function frame(name: string, parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in (props or {}) :: { [string]: any } do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function text(
	name: string,
	parent: Instance,
	str: string,
	size: number,
	color: Color3?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Text = str
	t.TextSize = size
	t.Font = HudTheme.BoldFont
	t.TextColor3 = color or C.text
	t.Parent = parent
	return t
end

local function button(name: string, parent: Instance, str: string, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.BackgroundColor3 = C.panel
	b.BackgroundTransparency = HudTheme.PanelTransparency
	b.Text = str
	b.TextSize = 24
	b.Font = HudTheme.HeaderFont
	b.TextColor3 = C.text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 12)
	stroke(b, C.accent, 2)
	return b
end

local function makeTiles(parent: Instance)
	local n = #MapConfig.Tiles -- n x n tiles, row-major from the north-west
	for r = 1, n do
		for c = 1, n do
			local t = Instance.new("ImageLabel")
			t.Name = `Tile{r}{c}`
			t.BackgroundTransparency = 1
			t.BorderSizePixel = 0
			t.Image = MapConfig.Tiles[r][c]
			t.Size = UDim2.new(1 / n, 1, 1 / n, 1) -- 1 px overlap hides seams
			t.Position = UDim2.fromScale((c - 1) / n, (r - 1) / n)
			t.Parent = parent
		end
	end
end

-- A round badge with a glyph; casualty badges carry a soft halo ring.
local function badge(style: Style, size: number, pulse: boolean?): Frame
	local f = frame("Blip", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 0,
		BackgroundColor3 = style.color,
		ZIndex = 5,
	})
	corner(f)
	stroke(f, Color3.fromRGB(12, 20, 28), 2)
	if pulse then
		local ring = frame("Pulse", f, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		})
		corner(ring)
		stroke(ring, style.color, 3)
	end
	local g = text("Glyph", f, style.glyph, math.floor(size * 0.62), Color3.fromRGB(12, 20, 28))
	g.Size = UDim2.fromScale(1, 1)
	g.ZIndex = 6
	return f
end

local function poolNew(parent: GuiObject): Pool
	return { parent = parent, items = {}, used = {} }
end

local function poolGet(pool: Pool, key: string, style: Style, size: number, pulse: boolean?): Frame
	local found: Frame? = pool.items[key]
	if not found then
		local nf = badge(style, size, pulse)
		nf.Parent = pool.parent
		pool.items[key] = nf
		found = nf
	end
	local f = found :: Frame
	pool.used[key] = true
	f.Visible = true
	return f
end

local function poolFlush(pool: Pool)
	for key, f in pool.items do
		if not pool.used[key] then
			f:Destroy()
			pool.items[key] = nil
		end
	end
	table.clear(pool.used)
end

-- the halo breathes slowly and never flashes or pings (owner, 2026-10-28)
local function pulseAll(pool: Pool, t: number)
	local k = 1.45 + 0.1 * math.sin(t * 1.6)
	for _, f in pool.items do
		local ring = f:FindFirstChild("Pulse") :: Frame?
		if ring then
			ring.Size = UDim2.fromScale(k, k)
			local s = ring:FindFirstChildOfClass("UIStroke")
			if s then
				s.Transparency = 0.35
			end
		end
	end
end

-- ---------------------------------------------------------------- world state

local function rootPart(): BasePart?
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function seatModel(): (Model?, string)
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat then
		return nil, "foot"
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	while model and model.Parent and model.Parent:IsA("Model") do
		model = model.Parent :: Model
	end
	return model, "boat"
end

local function flatYaw(v: Vector3): (number?, number?)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil, nil
	end
	f = f.Unit
	return f.X, f.Z
end

local function stormActive(): boolean
	local ok, s = pcall(Weather.getState)
	return ok and (s == "Warning" or s == "Storm" or s == "Clearing")
end

local function stormAreas(): { { center: Vector3, radius: number } }
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local c = folder and folder:GetAttribute("StormCenter")
	local r = folder and folder:GetAttribute("StormRadius")
	if typeof(c) == "Vector3" and type(r) == "number" then
		return { { center = c, radius = r } }
	end
	return MapConfig.StormAreas
end

-- The drop-off is your own berth (BayCFrame, docs/23 (k)); nil until the server hands you one.
local function myBerth(): Vector3?
	local bay = player:GetAttribute("BayCFrame")
	return if typeof(bay) == "CFrame" then bay.Position else nil
end

-- Your own boat in Workspace.Vehicles (VehicleService sets Owner = UserId).
local function ownCraft(): Model?
	local folder = Workspace:FindFirstChild("Vehicles")
	for _, m in if folder then folder:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId then
			return m
		end
	end
	return nil
end

-- Every blip this frame, plus the objective (where the route line goes).
local function collect(me: Vector3, myVehicle: Model?): { BlipDraw }
	local St = MapConfig.Styles
	local list: { BlipDraw } = {}
	for _, b in MapConfig.Blips do
		if b.position then
			table.insert(list, {
				id = b.id,
				pos = b.position,
				style = b :: any,
				clamp = b.id == "Station",
				minimap = b.minimap ~= false,
				size = 22,
			})
		end
	end
	for _, group in extraBlips do
		for _, b in group do
			table.insert(list, b)
		end
	end
	-- the one goal (docs/20 rule 1): the strip, the world pin and the route line all read it. Order:
	-- off your craft -> your craft; nobody aboard -> the nearest survivor; anyone aboard -> home; no call -> the offer
	objective, objectiveLabel = nil, nil
	local s = OpsController and OpsController.GetState()
	local active = s ~= nil and s.opId ~= nil and not closedOps[s.opId]
	if active then
		local onBoard, target = false, nil :: Vector3?
		for i, c in s.casualties or {} do
			if typeof(c.position) == "Vector3" and not c.delivered and not c.takenOver then
				if c.inWater ~= false then
					local style = St.Casualty
					table.insert(list, {
						id = `Cas{i}`,
						pos = c.position,
						style = style,
						pulse = true,
						clamp = true,
						size = 26,
					})
					if not target or (c.position - me).Magnitude < (target - me).Magnitude then
						target = c.position
					end
				else
					onBoard = true
				end
			end
		end
		-- my step says it first (the strip reads the same step): on the ride home, home is the goal
		for _, cur in s.current or {} do
			if (cur.trackId == s.myTrack or #s.current == 1) and cur.mechanicId == "transport" then
				onBoard = true
			end
		end
		if #(s.casualties or {}) == 0 and typeof(s.position) == "Vector3" and not onBoard then
			table.insert(list, {
				id = "OpPos",
				pos = s.position,
				style = St.Vessel,
				pulse = true,
				clamp = true,
				size = 26,
			})
			target = target or s.position
		end
		local berth = myBerth()
		if onBoard and berth then -- the cold open too: its home is your berth (ColdOpen.SHORE)
			table.insert(
				list,
				{ id = "DropMyDock", pos = berth, style = St.DropOff, clamp = true, size = 24 }
			)
			objective, objectiveLabel = berth, "Drop-off"
		elseif target then
			-- from the moment you take it (playtest: the distance vanished on accept)
			objective, objectiveLabel = target, "Casualty"
		end
		local craft = ownCraft()
		local bay = player:GetAttribute("BayCFrame")
		if select(2, seatModel()) ~= "boat" then
			if craft then
				objective, objectiveLabel = craft:GetPivot().Position, "Craft"
			elseif typeof(bay) == "CFrame" then -- no craft out (wrong-medium / idle despawn): the bay makes one
				objective, objectiveLabel = bay.Position, "Craft"
			end
		end
	end
	local quest = player:GetAttribute("QuestTarget") -- WP-21b: the thing, then the giver
	if typeof(quest) == "Vector3" then
		table.insert(list, { id = "Quest", pos = quest, style = St.Quest, clamp = true, size = 24 })
		if not objective then
			objective, objectiveLabel = quest, "Quest"
		end
	end
	local now = Workspace:GetServerTimeNow()
	for id, o in offers do
		if o.expires < now or (s and s.opId == id) then
			offers[id] = nil
		elseif not active then -- an offer never takes the pin from your own call
			table.insert(list, {
				id = `Offer{id}`,
				pos = o.position,
				style = St.Casualty,
				pulse = true,
				clamp = true,
				size = 24,
			})
			if not objective then
				objective, objectiveLabel = o.position, "Mayday"
			end
		end
	end
	if waypoint then
		table.insert(
			list,
			{ id = "Waypoint", pos = waypoint, style = St.Waypoint, clamp = true, size = 24 }
		)
		if not objective then
			objective, objectiveLabel = waypoint, "Waypoint"
		end
	end
	-- by boat, round the islands (playtest 2026-10-26: straight at the berth beached you on the plate): the pin and
	-- the line point at the next sea leg, the cove mouth before the berth; a heli (high) flies straight
	objectiveRoute = nil
	if objective and objectiveLabel ~= "Craft" and myVehicle and me.Y < 20 then
		objective, objectiveRoute = RingLayout.seaRoute(me, objective)
	end
	local home = player:GetAttribute("BayCFrame") -- your dock at the marina (docs/23)
	if typeof(home) == "CFrame" then
		table.insert(
			list,
			{ id = "Home", pos = home.Position, style = St.Home, clamp = true, size = 20 }
		)
	end
	for _, folderName in { "Vehicles" } do
		local folder = Workspace:FindFirstChild(folderName)
		for _, m in if folder then folder:GetChildren() else {} do
			if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId and m ~= myVehicle then
				table.insert(list, {
					id = `Veh{m:GetFullName()}`,
					pos = m:GetPivot().Position,
					style = St.Vehicle,
					clamp = true,
					size = 20,
				})
			end
		end
	end
	for _, p in Players:GetPlayers() do
		local r = p ~= player
			and p.Character
			and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			table.insert(
				list,
				{ id = `Crew{p.UserId}`, pos = r.Position, style = St.Crew, size = 16 }
			)
		end
	end
	table.clear(targets)
	for _, b in list do
		if b.pulse then
			table.insert(targets, b.pos)
		end
	end
	return list
end

-- ---------------------------------------------------------------- minimap

local function buildMinimap()
	local root = Instance.new("ImageButton")
	root.Name = "Minimap"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.AutoButtonColor = false
	root.Image = ""
	root.Parent = Layout.region(miniGui, "minimap")
	corner(root)
	mini.root = root
	-- the brass bezel (assets/ui/hud/minimap_ring_thin.png, hole 72%): 4% past the square so its
	-- hole (RING * 0.72) just covers the canvas edge
	local ring = Instance.new("ImageLabel")
	ring.Name = "Bezel"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(RING, RING)
	ring.BackgroundTransparency = 1
	ring.Image = UiImages.Hud.MinimapRing
	ring.ZIndex = 7
	ring.Parent = root

	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(2 * MAP_HALF, 2 * MAP_HALF)
	canvas.BackgroundColor3 = DEEP
	canvas.BorderSizePixel = 0
	canvas.Parent = root
	corner(canvas)
	mini.canvas = canvas

	local rotor = frame(
		"Rotor",
		canvas,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }
	)
	mini.rotor = rotor
	local img = frame("Map", rotor)
	makeTiles(img)
	mini.img = img
	mini.areas = frame("Areas", rotor)
	mini.dots = frame("Route", canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	-- soft inner shade so blips read against bright sand
	local vignette = frame("Vignette", canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	corner(vignette)
	stroke(vignette, Color3.fromRGB(4, 16, 30), 10, 0.55)

	mini.overlay = frame("Blips", root, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	mini.pool = poolNew(mini.overlay)

	local arrow = text("Player", root, "▲", 22, Color3.fromRGB(255, 255, 255))
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(24, 24)
	arrow.TextStrokeTransparency = 0.2
	arrow.ZIndex = 8
	mini.arrow = arrow

	local north = frame("North", root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.panel,
		ZIndex = 9,
	})
	corner(north)
	stroke(north, C.text, 2)
	text("N", north, "N", 15).Size = UDim2.fromScale(1, 1)
	mini.north = north

	if UserInputService.TouchEnabled then
		-- in the square's empty top-right corner, so it stays inside the minimap region
		local b = button("MapButton", root, "MAP", UDim2.fromOffset(52, 40))
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.fromScale(1, 0)
		b.TextSize = 16
		b.ZIndex = 10
		b.Activated:Connect(function()
			MapController.Open()
		end)
	end
	root.Activated:Connect(function()
		MapController.Open()
	end)
end

local function updateMinimap(dt: number, now: number)
	local root = rootPart()
	local cam = Workspace.CurrentCamera
	if not root or not cam then
		mini.root.Visible = false
		return
	end
	mini.root.Visible = true
	-- size and place come from UI/Layout (design units inside the region's UIScale)
	local size = Layout.current().side

	local vehicle, mode = seatModel()
	local vel = root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local want = MapConfig.zoomFor(mode, speed)
	viewRadius += (want - viewRadius) * math.clamp(dt / MapConfig.Zoom.easeSeconds, 0, 1)

	-- heading-up like a chart plotter (the bezel's lubber mark sits at the top): the bow while
	-- seated, the camera on foot. Following the chase camera's lag and free look swung the call
	-- blip round the rim while turning (playtest 2026-10-23).
	local fx, fz = flatYaw(if vehicle then root.CFrame.LookVector else cam.CFrame.LookVector)
	if not fx then
		fx, fz = flatYaw(root.CFrame.LookVector)
	end
	fx, fz = fx or 0, fz or -1
	local half = size * MAP_HALF
	local scale = half / viewRadius
	local me = root.Position
	local u, v = MapConfig.worldToUV(me.X, me.Z)
	local mapPx = MapConfig.Extent * scale
	local heading = math.deg(math.atan2(fx :: number, -(fz :: number)))
	mini.rotor.Rotation = -heading
	mini.img.Size = UDim2.fromOffset(mapPx, mapPx)
	mini.img.Position = UDim2.fromOffset(-u * mapPx, -v * mapPx)

	-- player arrow: the body's heading relative to the view (seated, the body faces the bow; a
	-- model's pivot need not)
	local bx, bz = flatYaw(root.CFrame.LookVector)
	if bx then
		mini.arrow.Rotation = math.deg(math.atan2(bx :: number, -(bz :: number))) - heading
	end
	local nx, ny = MapConfig.toView(0, -1, fx :: number, fz :: number)
	mini.north.Position = UDim2.new(0.5, nx * (half - 10), 0.5, ny * (half - 10))

	-- storm areas (world-aligned, in the rotor)
	local areas = mini.areas :: Frame
	areas:ClearAllChildren()
	if stormActive() then
		for _, a in stormAreas() do
			local f = frame("Storm", areas, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(
					(a.center.X - me.X) * scale,
					(a.center.Z - me.Z) * scale
				),
				Size = UDim2.fromOffset(a.radius * 2 * scale, a.radius * 2 * scale),
				BackgroundTransparency = 0.62,
				BackgroundColor3 = MapConfig.Styles.Storm.color,
			})
			corner(f)
			stroke(f, MapConfig.Styles.Storm.color, 2)
		end
	end

	-- blips
	local pool = mini.pool :: Pool
	local list = collect(me, vehicle)
	for _, b in list do
		if b.minimap ~= false then
			local x, y =
				MapConfig.toView(b.pos.X - me.X, b.pos.Z - me.Z, fx :: number, fz :: number)
			x, y = x * scale, y * scale
			local r = half - 9
			local cx, cy, clamped = MapConfig.clampToRim(x, y, r)
			if not clamped or b.clamp then
				local f = poolGet(pool, b.id, b.style, b.size or 20, b.pulse)
				f.Position = UDim2.new(0.5, cx, 0.5, cy)
				f.BackgroundTransparency = if clamped then 0.15 else 0
			end
		end
	end
	poolFlush(pool)
	pulseAll(pool, now)

	-- dotted route line (the distance is on the world marker and the strip: UI/Waypoint)
	local dots = mini.dots :: Frame
	if objective then
		local d = objective - me
		local x, y = MapConfig.toView(d.X, d.Z, fx :: number, fz :: number)
		x, y = x * scale, y * scale
		local len = math.min(math.sqrt(x * x + y * y), half - 12)
		local n = math.max(0, math.floor((len - 14) / 11))
		local kids = dots:GetChildren()
		for i = 1, math.max(n, #kids) do
			local dot = (kids[i] :: any) :: Frame?
			if i <= n then
				if not dot then
					local nd = frame("Dot", dots, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(5, 5),
						BackgroundTransparency = 0.05,
						BackgroundColor3 = Color3.fromRGB(255, 214, 10),
					})
					corner(nd)
					dot = nd
				end
				local t = (14 + (i - 1) * 11) / math.max(1, math.sqrt(x * x + y * y));
				(dot :: Frame).Position = UDim2.new(0.5, x * t, 0.5, y * t);
				(dot :: Frame).Visible = true
			elseif dot then
				dot.Visible = false
			end
		end
	else
		for _, dot in dots:GetChildren() do
			(dot :: Frame).Visible = false
		end
	end
end

-- ---------------------------------------------------------------- full map

local LEGEND_WIDTH = 210
local LEGEND_HEAD = 34 -- collapsed height
local LEGEND_ROW = 24
local PLACE_STYLE: { [string]: { size: number, color: Color3, halo: Color3 } } = {
	region = { size = 24, color = Color3.fromRGB(235, 240, 220), halo = Color3.fromRGB(10, 25, 45) },
	isle = { size = 24, color = Color3.fromRGB(255, 248, 232), halo = Color3.fromRGB(10, 25, 45) },
	place = { size = 19, color = Color3.fromRGB(238, 232, 214), halo = Color3.fromRGB(10, 25, 45) },
	water = { size = 19, color = Color3.fromRGB(196, 236, 246), halo = Color3.fromRGB(8, 34, 64) },
	street = { size = 16, color = Color3.fromRGB(255, 250, 238), halo = Color3.fromRGB(10, 25, 45) },
}

local function legendRow(parent: Instance, style: Style, order: number)
	local row = frame("Row", parent, { Size = UDim2.new(1, 0, 0, LEGEND_ROW), LayoutOrder = order })
	local b = badge(style, 18, false)
	b.Position = UDim2.fromOffset(10, LEGEND_ROW / 2)
	b.Parent = row
	local t = text("Label", row, style.label, 15)
	t.Font = HudTheme.BodyFont
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Position = UDim2.fromOffset(26, 0)
	t.Size = UDim2.new(1, -26, 1, 0)
	t.TextTruncate = Enum.TextTruncate.AtEnd
end

local function kitButton(
	parent: Instance,
	name: string,
	str: string,
	size: UDim2,
	grad: string,
	onActivate: (() -> ())?
): ImageButton
	local b = Style.button(parent, size)
	b.Name = name
	local _, face = Style.block(b, Style.grad(grad), { radius = S.cornerSmall, lip = 4 })
	local l = Style.label(face, str, Theme.Text.small, true)
	l.TextWrapped = false
	l.TextXAlignment = Enum.TextXAlignment.Center
	if onActivate then
		Style.press(b, onActivate, S.cornerSmall)
	end
	return b
end

local function buildFullMap()
	local mapCanvas = Style.canvas(gui)
	full.canvas = mapCanvas
	local panel = Panel.new(mapCanvas, {
		title = "Map",
		icon = "map",
		size = Vector2.new(1160, 640),
		wide = true, -- the map keeps its size (kit panels cap at half the desktop width)
		onClose = function()
			if isOpen then
				MapController.Close()
			end
		end,
	})
	full.panel = panel
	panel.body.Visible = false

	local root = frame("View", panel.root, {
		-- below the whole title bar (over its lower half it clipped the title)
		Position = UDim2.fromOffset(S.pad, S.titleBar + 6),
		Size = UDim2.new(1, -2 * S.pad, 1, -(S.titleBar + 6 + S.pad)),
		BackgroundColor3 = DEEP,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 6,
	})
	Style.corner(root, S.corner + 2)
	Style.stroke(root, S.border, true)
	full.root = root

	local canvas = frame("Canvas", root, {
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 1,
	})
	local img = frame("Map", canvas, { ZIndex = 1 })
	makeTiles(img)
	full.img = img

	full.fog = frame("Fog", canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })

	full.areas = frame("Areas", canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Modal = true -- frees the mouse in first person while the map is open
	hit.ZIndex = 9
	hit.Parent = canvas
	full.hit = hit
	full.blips = frame("Blips", canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
	full.pool = poolNew(full.blips)

	-- you: a big white arrow on a blue disc, outlined, turned to your heading
	local me = text("Player", canvas, "▲", 34, Color3.fromRGB(255, 255, 255))
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Size = UDim2.fromOffset(44, 44)
	me.BackgroundTransparency = 0.1
	me.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
	me.ZIndex = 8
	corner(me)
	stroke(me, Color3.fromRGB(255, 255, 255), 3)
	me.TextStrokeTransparency = 0.2
	full.me = me
	local cross = text("Cross", canvas, "+", 34, Color3.fromRGB(255, 255, 255))
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Size = UDim2.fromOffset(34, 34)
	cross.TextStrokeTransparency = 0.3
	cross.Visible = false
	cross.ZIndex = 8
	full.cross = cross

	-- place names: live labels under the blips (MapConfig.Places)
	local names = frame("Places", canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })
	full.places = {}
	for i, pl in MapConfig.Places do
		local st = PLACE_STYLE[pl.kind] or PLACE_STYLE.place
		local str = if pl.kind == "region" then string.gsub(pl.text, "(.)", "%1 ") else pl.text
		local t = text("Place" .. i, names, string.gsub(str, " $", ""), st.size, st.color)
		t.FontFace = Font.new(
			"rbxasset://fonts/families/BuilderSans.json",
			if pl.kind == "isle" or pl.kind == "region"
				then Enum.FontWeight.Bold
				else Enum.FontWeight.SemiBold,
			if pl.kind == "water" then Enum.FontStyle.Italic else Enum.FontStyle.Normal
		)
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.AnchorPoint = Vector2.new(if pl.left then 0 else 0.5, 0.5)
		t.Visible = false
		t.ZIndex = 7
		local halo = Instance.new("UIStroke")
		halo.Color = st.halo
		halo.Thickness = 3 -- thick enough to read over the baked road lines
		halo.Transparency = 0
		halo.Parent = t
		if pl.kind == "street" then -- a dark plate: a street name sits on its road
			t.BackgroundColor3 = st.halo
			t.BackgroundTransparency = 0.3
			corner(t, 6)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
			pad.Parent = t
		end
		table.insert(full.places, { label = t, x = pl.x, z = pl.z, kind = pl.kind, left = pl.left })
	end

	-- controls, inside the map view (the panel already sits in the safe area)
	local safe = root
	full.safe = safe

	local zin = kitButton(safe, "ZoomIn", "+", UDim2.fromOffset(52, 52), "blue", function()
		full.radius = math.max(MapConfig.FullMap.minRadius, full.radius * 0.7)
	end)
	zin.AnchorPoint = Vector2.new(0, 1)
	zin.Position = UDim2.new(0, 12, 1, -200)
	local zout = kitButton(safe, "ZoomOut", "-", UDim2.fromOffset(52, 52), "blue", function()
		full.radius = math.min(MapConfig.FullMap.maxRadius, full.radius / 0.7)
	end)
	zout.AnchorPoint = Vector2.new(0, 1)
	zout.Position = UDim2.new(0, 12, 1, -140)
	local clear = kitButton(
		safe,
		"ClearWaypoint",
		"Clear waypoint",
		UDim2.fromOffset(190, 48),
		"orange",
		function()
			MapController.SetWaypoint(nil)
		end
	)
	clear.AnchorPoint = Vector2.new(0, 1)
	clear.Position = UDim2.new(0, 12, 1, -12)
	full.clear = clear
	local recentre = kitButton(safe, "Recentre", "Me", UDim2.fromOffset(52, 52), "blue", function()
		local r = rootPart()
		if r then
			full.center = Vector2.new(r.Position.X, r.Position.Z)
		end
	end)
	recentre.AnchorPoint = Vector2.new(0, 1)
	recentre.Position = UDim2.new(0, 12, 1, -80)
	full.controls = { zin, zout, recentre }

	-- legend: a small collapsible kit panel, bottom right (collapsed: just its header)
	local legend = Style.button(safe, UDim2.fromOffset(LEGEND_WIDTH, LEGEND_HEAD)) :: any
	legend.Name = "Legend"
	legend.AnchorPoint = Vector2.new(1, 1)
	legend.Position = UDim2.new(1, -12, 1, -12)
	legend.ClipsDescendants = true
	legend.ZIndex = 10
	local _, legendFace =
		Style.block(legend, Style.grad("ink"), { radius = S.cornerSmall, lip = 4 })
	legendFace.ZIndex = 1
	local head = Instance.new("TextButton")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.AutoButtonColor = false
	head.Size = UDim2.new(1, 0, 0, LEGEND_HEAD)
	head.FontFace = Font.new(Theme.FONT, Enum.FontWeight.Regular)
	head.Text = "LEGEND  ▸"
	head.TextSize = 20
	head.TextColor3 = Color3.fromRGB(255, 248, 232)
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.ZIndex = 2
	head.Parent = legend
	local headPad = Instance.new("UIPadding")
	headPad.PaddingLeft = UDim.new(0, 12)
	headPad.Parent = head
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, LEGEND_HEAD)
	body.Size = UDim2.new(1, 0, 1, -LEGEND_HEAD)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 4
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ZIndex = 2
	body.Parent = legend
	HudTheme.padding(body, 8)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)
	layout.Parent = body
	local order = 1
	for _, key in
		{ "Casualty", "Vessel", "DropOff", "Waypoint", "Vehicle", "Home", "Crew", "Storm" }
	do
		legendRow(body, MapConfig.Styles[key], order)
		order += 1
	end
	for _, b in MapConfig.Blips do
		if b.legend then
			legendRow(body, b :: any, order)
			order += 1
		end
	end
	full.legendRows = order - 1
	full.legend, full.legendHead = legend, head
	full.legendOpen = false
	head.Activated:Connect(function()
		full.legendOpen = not full.legendOpen
	end)

	-- the controls hint: one dim line, bottom centre
	local hint = text("Hint", safe, "", 15, C.textDim)
	hint.Font = HudTheme.BodyFont
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -16)
	hint.Size = UDim2.fromOffset(420, 20)
	hint.TextStrokeTransparency = 0.5
	hint.ZIndex = 10
	full.hint = hint

	full.radius = MapConfig.FullMap.startRadius
	full.center = Vector2.new(0, 200)
end

local function fogRun(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = FOG_COLOR
	f.BackgroundTransparency = 0.08
	f.Parent = parent
	return f
end

local function rebuildRuns(
	layer: Frame,
	originX: number,
	originZ: number,
	cell: number,
	count: number,
	revealed: (number) -> boolean
): { { f: Frame, x: number, z: number, w: number, h: number } }
	layer:ClearAllChildren()
	local runs = {}
	for iz = 0, count - 1 do
		local ix = 0
		while ix < count do
			if not revealed(iz * count + ix + 1) then
				local j = ix
				while j + 1 < count and not revealed(iz * count + j + 2) do
					j += 1
				end
				table.insert(runs, {
					f = fogRun(layer),
					x = originX + ix * cell,
					z = originZ + iz * cell,
					w = (j - ix + 1) * cell,
					h = cell,
				})
				ix = j + 1
			else
				ix += 1
			end
		end
	end
	return runs
end

local function refreshFog()
	if not full.fog then
		return
	end
	full.fogRuns = rebuildRuns(
		full.fog,
		FOG.origin,
		FOG.origin,
		FOG.cell,
		FOG.count,
		DiscoveryController.IsRevealed
	)
end

local function placeFog(scale: number, size: Vector2, c: Vector2)
	for _, r in full.fogRuns or {} do
		local f = r.f
		f.Position =
			UDim2.fromOffset(size.X / 2 + (r.x - c.X) * scale, size.Y / 2 + (r.z - c.Y) * scale)
		f.Size = UDim2.fromOffset(r.w * scale + 1, r.h * scale + 1)
	end
end

local function fullScale(): (number, Vector2)
	local size = full.root.AbsoluteSize
	return math.min(size.X, size.Y) / 2 / full.radius, size
end

local function screenToWorld(p: Vector2): Vector2
	local scale, size = fullScale()
	local origin = full.root.AbsolutePosition
	local local_ = p - origin - size / 2
	return full.center + local_ / scale
end

local function placeWaypointAt(screen: Vector2)
	local w = screenToWorld(screen)
	if waypoint then
		local scale = fullScale()
		local d = (Vector2.new(waypoint.X, waypoint.Z) - w).Magnitude * scale
		if d < 22 then
			MapController.SetWaypoint(nil)
			return
		end
	end
	MapController.SetWaypoint(Vector3.new(w.X, 0, w.Y))
end

-- The legend's size (collapsed: its header; open: as many rows as fit, the rest scroll).
local function layoutLegend(size: Vector2)
	local open = full.legendOpen == true
	local rowsH = full.legendRows * LEGEND_ROW + 16
	local room = math.max(size.Y - 24 - LEGEND_HEAD, LEGEND_ROW * 3)
	local h = if open then LEGEND_HEAD + math.min(rowsH, room) else LEGEND_HEAD
	full.legend.Size = UDim2.fromOffset(LEGEND_WIDTH, h)
	full.legendHead.Text = if open then "LEGEND  ▾" else "LEGEND  ▸"
	full.hint.Visible = size.X - 2 * (LEGEND_WIDTH + 32) >= 300
end

local MARK_GAP = 6 -- px of clear map kept between a place name and any marker

local function rectsTouch(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2): boolean
	return a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y
end

-- Place names at a fixed screen size; a name is drawn only where it touches no control or a name
-- placed before it (MapConfig.Places order = priority). Region names show zoomed out, minor
-- places zoomed in.
local function placeNames(c: Vector2, scale: number, size: Vector2, marks: { { Vector2 } })
	local origin = full.root.AbsolutePosition
	local blocked: { { Vector2 } } = {}
	local panels: { GuiObject } = { full.legend, full.clear, full.hint }
	for _, g in full.controls do
		table.insert(panels, g)
	end
	for _, o in panels do
		if o.Visible then
			local p = o.AbsolutePosition - origin
			table.insert(blocked, { p - Vector2.new(6, 6), p + o.AbsoluteSize + Vector2.new(6, 6) })
		end
	end
	local r = full.radius :: number
	for _, pl in full.places do
		local t = pl.label :: TextLabel
		local show = (pl.kind ~= "region" or r >= 700)
			and (pl.kind ~= "place" or r <= 1600)
			and (pl.kind ~= "street" or r <= 700)
		if show then
			local x, y = size.X / 2 + (pl.x - c.X) * scale, size.Y / 2 + (pl.z - c.Y) * scale
			if pl.left then
				x += 10 -- clear of the landmark's dot baked into the map art
			end
			local wh = t.TextBounds
			if wh.X < 1 then
				wh = Vector2.new(#t.Text * t.TextSize * 0.55, t.TextSize)
			end
			wh += Vector2.new(6, 6) -- the 3 px halo each side
			local x0 = if pl.left then x else x - wh.X / 2
			-- a name under a map marker slides below it, else above it (one or two steps); a name with
			-- no clear spot is dropped, never drawn over a marker
			local covered = true
			local step = wh.Y / 2 + 18
			for _, dy in { 0, step, -step, 2 * step, -2 * step } do
				local clear = true
				for _, m in marks do
					local b0, b1 =
						Vector2.new(x0 - MARK_GAP, y + dy - wh.Y / 2 - MARK_GAP),
						Vector2.new(x0 + wh.X + MARK_GAP, y + dy + wh.Y / 2 + MARK_GAP)
					if rectsTouch(b0, b1, m[1], m[2]) then
						clear = false
						break
					end
				end
				if clear then
					y += dy
					covered = false
					break
				end
			end
			local a0, a1 = Vector2.new(x0, y - wh.Y / 2), Vector2.new(x0 + wh.X, y + wh.Y / 2)
			show = not covered and a1.X > 0 and a0.X < size.X and a1.Y > 0 and a0.Y < size.Y
			for _, b in blocked do
				if show and rectsTouch(a0, a1, b[1], b[2]) then
					show = false
				end
			end
			if show then
				t.Position = UDim2.fromOffset(x, y)
				table.insert(blocked, { a0, a1 })
			end
		end
		t.Visible = show
	end
end

local function updateFullMap(now: number)
	local scale, size = fullScale()
	local mapPx = MapConfig.Extent * scale
	local c = full.center :: Vector2
	local u, v = MapConfig.worldToUV(c.X, c.Y)
	full.img.Size = UDim2.fromOffset(mapPx, mapPx)
	full.img.Position = UDim2.fromOffset(size.X / 2 - u * mapPx, size.Y / 2 - v * mapPx)
	placeFog(scale, size, c)
	local function at(p: Vector3): (number, number)
		return size.X / 2 + (p.X - c.X) * scale, size.Y / 2 + (p.Z - c.Y) * scale
	end
	local root = rootPart()
	local vehicle = seatModel()
	local me = if root then root.Position else Vector3.new(c.X, 0, c.Y)
	if root then
		local x, y = at(me)
		full.me.Position = UDim2.fromOffset(x, y)
		local bx, bz = flatYaw(root.CFrame.LookVector)
		if bx then
			full.me.Rotation = math.deg(math.atan2(bx :: number, -(bz :: number)))
		end
	end
	local areas = full.areas :: Frame
	areas:ClearAllChildren()
	if stormActive() then
		for _, a in stormAreas() do
			local x, y = at(a.center)
			local f = frame("Storm", areas, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(a.radius * 2 * scale, a.radius * 2 * scale),
				BackgroundTransparency = 0.65,
				BackgroundColor3 = MapConfig.Styles.Storm.color,
			})
			corner(f)
			stroke(f, MapConfig.Styles.Storm.color, 2)
		end
	end
	local pool = full.pool :: Pool
	local marks: { { Vector2 } } = {}
	if root then -- blips stack off your arrow, never under it
		local x, y = at(me)
		table.insert(marks, { Vector2.new(x - 24, y - 24), Vector2.new(x + 24, y + 24) })
	end
	for _, b in collect(me, vehicle) do
		local x, y = at(b.pos)
		local px = math.floor((b.size or 20) * 1.15)
		local f = poolGet(pool, b.id, b.style, px, b.pulse)
		-- a blip that would overlap one drawn before it steps out round a ring (8 slots, then wider)
		local half = Vector2.new(px, px) / 2 + Vector2.new(3, 3)
		local p = Vector2.new(x, y)
		for k = 0, 16 do
			local q = if k == 0
				then p
				else p
					+ Vector2.new(math.cos(k * math.pi / 4), math.sin(k * math.pi / 4))
						* (px + 4)
						* (1 + math.floor((k - 1) / 8))
			local clear = true
			for _, m in marks do
				if rectsTouch(q - half, q + half, m[1], m[2]) then
					clear = false
					break
				end
			end
			if clear then
				p = q
				break
			end
		end
		f.Position = UDim2.fromOffset(p.X, p.Y)
		table.insert(marks, { p - half, p + half })
	end
	poolFlush(pool)
	pulseAll(pool, now)
	full.clear.Visible = waypoint ~= nil
	layoutLegend(size)
	placeNames(c, scale, size, marks)
	local pad = UserInputService.GamepadEnabled and not UserInputService.MouseEnabled
	full.cross.Visible = pad
	full.hint.Text = if pad
		then "LS Pan · RT Zoom · A Point · X Clear · Y Legend · B Close"
		elseif
			UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		then "Drag Pan · Pinch Zoom · Tap Point"
		else "Drag Pan · Wheel Zoom · Click Point · M Close"
end

-- ---------------------------------------------------------------- input

local drag: { start: Vector2, center: Vector2, moved: boolean, input: InputObject }? = nil
local pinchStart: number? = nil
local padPan = Vector2.zero
local padZoom = 0

local function bindFullMapInput()
	full.hit.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			if drag == nil then
				drag = {
					start = Vector2.new(input.Position.X, input.Position.Y),
					center = full.center,
					moved = false,
					input = input,
				}
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not isOpen then
			return
		end
		local t = input.UserInputType
		if
			drag
			and (
				t == Enum.UserInputType.MouseMovement
				or (t == Enum.UserInputType.Touch and input == drag.input)
			)
		then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local delta = p - drag.start
			if delta.Magnitude > 8 then
				drag.moved = true
			end
			if drag.moved then
				local scale = fullScale()
				full.center = drag.center - delta / scale
			end
		elseif t == Enum.UserInputType.MouseWheel then
			local before = screenToWorld(
				Vector2.new(input.Position.X, input.Position.Y) + full.root.AbsolutePosition
			)
			full.radius = math.clamp(
				full.radius * 0.85 ^ input.Position.Z,
				MapConfig.FullMap.minRadius,
				MapConfig.FullMap.maxRadius
			)
			local after = screenToWorld(
				Vector2.new(input.Position.X, input.Position.Y) + full.root.AbsolutePosition
			)
			full.center += before - after
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if
			drag
			and (
				t == Enum.UserInputType.MouseButton1
				or (t == Enum.UserInputType.Touch and input == drag.input)
			)
		then
			local d = drag
			drag = nil
			if isOpen and not d.moved and pinchStart == nil then
				placeWaypointAt(Vector2.new(input.Position.X, input.Position.Y))
			end
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale: number, _, state: Enum.UserInputState)
		if not isOpen then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchStart = full.radius
			drag = nil
		elseif state == Enum.UserInputState.Change and pinchStart then
			full.radius = math.clamp(
				pinchStart / math.max(scale, 0.05),
				MapConfig.FullMap.minRadius,
				MapConfig.FullMap.maxRadius
			)
		else
			pinchStart = nil
		end
	end)
end

local function onPad(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	local k = input.KeyCode
	if k == Enum.KeyCode.Thumbstick1 then
		local p = Vector2.new(input.Position.X, -input.Position.Y)
		padPan = if p.Magnitude > 0.15 then p else Vector2.zero
	elseif k == Enum.KeyCode.ButtonR2 or k == Enum.KeyCode.ButtonL2 then
		local z = if state == Enum.UserInputState.End then 0 else input.Position.Z
		padZoom = if k == Enum.KeyCode.ButtonR2 then -z else z
	elseif state == Enum.UserInputState.Begin then
		if k == Enum.KeyCode.ButtonA then
			local size = full.root.AbsoluteSize
			placeWaypointAt(full.root.AbsolutePosition + size / 2)
		elseif k == Enum.KeyCode.ButtonX then
			MapController.SetWaypoint(nil)
		elseif k == Enum.KeyCode.ButtonB then
			MapController.Close()
		elseif k == Enum.KeyCode.ButtonY then
			full.legendOpen = not full.legendOpen
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onToggle(
	_: string,
	state: Enum.UserInputState,
	_: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if isOpen then
			MapController.Close()
		else
			MapController.Open()
		end
	end
	return Enum.ContextActionResult.Sink
end

-- ---------------------------------------------------------------- API

function MapController.SetWaypoint(pos: Vector3?)
	waypoint = pos
	player:SetAttribute("MapWaypoint", pos)
end

-- Static blips from another system, replaced per group (nil clears it). Each item: a unique id,
-- a position and a MapConfig.Styles key. Used by SeamarkController.
function MapController.SetBlips(
	group: string,
	items: {
		{
			id: string,
			position: Vector3,
			style: string,
			minimap: boolean?,
			size: number?,
		}
	}?
)
	if not items then
		extraBlips[group] = nil
		return
	end
	local list: { BlipDraw } = {}
	for _, b in items do
		table.insert(list, {
			id = `{group}_{b.id}`,
			pos = b.position,
			style = MapConfig.Styles[b.style],
			minimap = b.minimap ~= false,
			size = b.size or 18,
		})
	end
	extraBlips[group] = list
end

function MapController.GetObjective(): (Vector3?, string?, number?)
	return objective, objectiveLabel, objectiveRoute
end

-- Where the call blips pulse (survivors, vessels, offered calls), as of the last map frame.
function MapController.GetTargets(): { Vector3 }
	return targets
end

function MapController.IsOpen(): boolean
	return isOpen
end

function MapController.Open()
	if isOpen or player:GetAttribute("CinematicPlaying") == true then
		return
	end
	isOpen = true
	local r = rootPart()
	if r then
		full.center = Vector2.new(r.Position.X, r.Position.Z)
	end
	refreshFog()
	full.root.Visible = true
	full.panel.open()
	mini.root.Visible = false
	gui.DisplayOrder = 40 -- above the Ops cards while the full map is up
	player:SetAttribute("MapOpen", true)
	ContextActionService:BindActionAtPriority(
		"MapFullPad",
		onPad,
		false,
		3000,
		Enum.KeyCode.Thumbstick1,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.ButtonX,
		Enum.KeyCode.ButtonY,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonL2
	)
end

function MapController.Close()
	if not isOpen then
		return
	end
	isOpen = false
	drag, pinchStart, padPan, padZoom = nil, nil, Vector2.zero, 0
	full.root.Visible = false
	full.panel.close()
	gui.DisplayOrder = 16
	player:SetAttribute("MapOpen", false)
	ContextActionService:UnbindAction("MapFullPad")
end

-- ---------------------------------------------------------------- lifecycle

function MapController.Init()
	local ok, ops = pcall(require, script.Parent:WaitForChild("OpsController") :: any)
	if ok then
		OpsController = ops
		ops.OnOffer:Connect(function(o: any)
			if type(o) == "table" and o.opId and typeof(o.position) == "Vector3" then
				offers[o.opId] = {
					position = o.position,
					expires = tonumber(o.offerExpiresAt) or (Workspace:GetServerTimeNow() + 30),
				}
			end
		end)
		ops.OnClosed:Connect(function(c: any)
			if type(c) == "table" and c.opId then
				closedOps[c.opId] = true
				offers[c.opId] = nil
			end
		end)
		ops.OnState:Connect(function(s: any)
			if type(s) == "table" and s.opId then
				closedOps[s.opId] = nil
				offers[s.opId] = nil
			end
		end)
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MapHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 16
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("CinematicKeep", true) -- MapController hides itself on CinematicPlaying
	miniGui = Instance.new("ScreenGui")
	miniGui.Name = "MiniMapHud"
	miniGui.ResetOnSpawn = false
	miniGui.DisplayOrder = 16
	miniGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	miniGui:SetAttribute("CinematicKeep", true)
	Layout.prepare(miniGui)
	miniGui.Parent = player:WaitForChild("PlayerGui")
	buildMinimap()
	buildFullMap()
	refreshFog()
	DiscoveryController.Changed:Connect(function()
		if full.fog then
			refreshFog()
		end
	end)
	bindFullMapInput()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function MapController.Start()
	ContextActionService:BindAction(
		"MapToggle",
		onToggle,
		false,
		Enum.KeyCode.M,
		Enum.KeyCode.ButtonSelect
	)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if
			isOpen
			and (
				input.KeyCode == Enum.KeyCode.Escape
				or (input.KeyCode == Enum.KeyCode.Backspace and not processed)
			)
		then
			MapController.Close()
		end
	end)
	local function cinematic()
		local on = player:GetAttribute("CinematicPlaying") == true
		gui.Enabled = not on
		miniGui.Enabled = not on
		if on then
			MapController.Close()
		end
	end
	player:GetAttributeChangedSignal("CinematicPlaying"):Connect(cinematic)
	cinematic()
	RunService.RenderStepped:Connect(function(dt: number)
		if not gui.Enabled then
			return
		end
		local now = os.clock()
		if isOpen then
			if padPan.Magnitude > 0 then
				full.center += padPan * full.radius * 1.2 * dt
			end
			if padZoom ~= 0 then
				full.radius = math.clamp(
					full.radius * (1 + padZoom * 1.5 * dt),
					MapConfig.FullMap.minRadius,
					MapConfig.FullMap.maxRadius
				)
			end
			updateFullMap(now)
		else
			updateMinimap(dt, now)
		end
	end)
end

return MapController
