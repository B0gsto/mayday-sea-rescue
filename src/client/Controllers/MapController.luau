--!strict
-- MapController: the GTA-style map that replaces 3D guidance arrows (docs 05 HUD style).
--
--   * Minimap (bottom-left, circular): the player at the centre, the map rotating with the camera
--     heading, a north marker on the rim, zoom from speed (close on foot, wide at speed in a boat),
--     blips (the operation's casualty / vessel pulsing, the drop-off when transporting, offers,
--     the station, Chandlery, quay desk, car park, your vehicles, other crew, storm areas, your
--     waypoint) with objective blips clamped to the rim, a dotted line to the current objective and
--     its distance. Tap / click it to open the full map.
--   * Full map (M, gamepad View/Select, the MAP button): pan (drag / left stick), zoom (wheel,
--     pinch, + / -, triggers), a legend, click / tap / A to set your own waypoint (again on it, or
--     X, clears it), close with M, Esc, Backspace, B or the close button.
--   * Hidden while LocalPlayer attribute CinematicPlaying is true.
--   * Drop-off pads (Workspace.Map.DropOffs) are hidden locally (LocalTransparencyModifier) while
--     ReplicatedStorage attribute UseMapWaypoints is true (MapService sets it on the server).
--
-- API: MapController.SetWaypoint(pos: Vector3?), GetWaypoint(), Open(), Close(), IsOpen(),
--      GetObjective(): (Vector3?, string?)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Layout = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("MapConfig"))
local Weather = require(Shared:WaitForChild("Weather"))

local MapController = {}
MapController.Priority = 120

local player = Players.LocalPlayer
local C = HudTheme.Colors
local DEEP = Color3.fromRGB(8, 38, 82)
local STUDS_PER_M = 3

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
local miniGui: ScreenGui -- the minimap, in the Layout "minimap" region (bottom left, safe area)
local mini: { [string]: any } = {}
local full: { [string]: any } = {}
local waypoint: Vector3? = nil
local viewRadius = MapConfig.Zoom.foot
local offers: { [string]: { position: Vector3, expires: number } } = {}
local closedOps: { [string]: boolean } = {}
local isOpen = false
local objective: Vector3?, objectiveLabel: string? = nil, nil

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
	for r = 1, 2 do
		for c = 1, 2 do
			local t = Instance.new("ImageLabel")
			t.Name = `Tile{r}{c}`
			t.BackgroundTransparency = 1
			t.BorderSizePixel = 0
			t.Image = MapConfig.Tiles[r][c]
			t.Size = UDim2.new(0.5, 1, 0.5, 1) -- 1 px overlap hides seams
			t.Position = UDim2.fromScale((c - 1) * 0.5, (r - 1) * 0.5)
			t.Parent = parent
		end
	end
end

-- A round badge with a glyph; casualty badges carry a pulse ring.
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

local function pulseAll(pool: Pool, t: number)
	local p = (t % 1.3) / 1.3
	for _, f in pool.items do
		local ring = f:FindFirstChild("Pulse") :: Frame?
		if ring then
			ring.Size = UDim2.fromScale(1 + 1.6 * p, 1 + 1.6 * p)
			local s = ring:FindFirstChildOfClass("UIStroke")
			if s then
				s.Transparency = p
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
	local landFolder = Workspace:FindFirstChild("LandVehicles")
	if
		model
		and (
			model:GetAttribute("LandVehicle") ~= nil
			or (landFolder and model:IsDescendantOf(landFolder))
		)
	then
		return model, "car"
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

local function nearestDropOff(from: Vector3): Vector3
	local best, bd = MapConfig.DropOffs.Dock, math.huge
	for _, p in MapConfig.DropOffs do
		local d = (p - from).Magnitude
		if d < bd then
			best, bd = p, d
		end
	end
	return best
end

-- Every blip this frame, plus the objective (where the route line goes).
local function collect(me: Vector3, myVehicle: Model?): { BlipDraw }
	local S = MapConfig.Styles
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
	objective, objectiveLabel = nil, nil
	local s = OpsController and OpsController.GetState()
	if s and s.opId and not closedOps[s.opId] then
		local onBoard, target = false, nil :: Vector3?
		local vessel = s.kind == "DisabledVessel"
		for i, c in s.casualties or {} do
			if typeof(c.position) == "Vector3" and not c.delivered and not c.takenOver then
				if c.inWater ~= false then
					local style = if vessel then S.Vessel else S.Casualty
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
		local mech = s.current and s.current[1] and s.current[1].mechanicId
		if mech == "transport" or mech == "tow" or mech == "berth" or mech == "alongside" then
			onBoard = true
		end
		if
			(vessel or #(s.casualties or {}) == 0)
			and typeof(s.position) == "Vector3"
			and not onBoard
		then
			table.insert(list, {
				id = "OpPos",
				pos = s.position,
				style = S.Vessel,
				pulse = true,
				clamp = true,
				size = 26,
			})
			target = target or s.position
		end
		if onBoard then
			for name, p in MapConfig.DropOffs do
				table.insert(
					list,
					{ id = `Drop{name}`, pos = p, style = S.DropOff, clamp = true, size = 24 }
				)
			end
			objective, objectiveLabel = nearestDropOff(me), "Drop-off"
		elseif target then
			objective, objectiveLabel = target, if vessel then "Vessel" else "Casualty"
		end
	end
	local now = Workspace:GetServerTimeNow()
	for id, o in offers do
		if o.expires < now or (s and s.opId == id) then
			offers[id] = nil
		else
			table.insert(list, {
				id = `Offer{id}`,
				pos = o.position,
				style = S.Casualty,
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
			{ id = "Waypoint", pos = waypoint, style = S.Waypoint, clamp = true, size = 24 }
		)
		if not objective then
			objective, objectiveLabel = waypoint, "Waypoint"
		end
	end
	for _, folderName in { "Vehicles", "LandVehicles" } do
		local folder = Workspace:FindFirstChild(folderName)
		for _, m in if folder then folder:GetChildren() else {} do
			if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId and m ~= myVehicle then
				table.insert(list, {
					id = `Veh{m:GetFullName()}`,
					pos = m:GetPivot().Position,
					style = S.Vehicle,
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
				{ id = `Crew{p.UserId}`, pos = r.Position, style = S.Crew, size = 16 }
			)
		end
	end
	return list
end

-- ---------------------------------------------------------------- minimap

local function buildMinimap()
	local root = Instance.new("ImageButton")
	root.Name = "Minimap"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = C.panel
	root.BackgroundTransparency = 0.2
	root.AutoButtonColor = false
	root.Image = ""
	root.Parent = Layout.region(miniGui, "minimap")
	corner(root)
	stroke(root, Color3.fromRGB(255, 255, 255), 1, 0.7)
	mini.root = root

	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.new(1, -8, 1, -8)
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

	local pill = frame("Objective", root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(170, 30),
		BackgroundTransparency = HudTheme.PanelTransparency,
		BackgroundColor3 = C.panel,
		Visible = false,
		ZIndex = 9,
	})
	corner(pill, 10)
	stroke(pill, Color3.fromRGB(255, 255, 255), 1, 0.8)
	local pt = text("Text", pill, "", 17)
	pt.Size = UDim2.fromScale(1, 1)
	pt.ZIndex = 10
	mini.pill, mini.pillText = pill, pt

	if UserInputService.TouchEnabled then
		-- in the square's empty top-right corner, so it stays inside the minimap region
		local b = button("MapButton", root, "MAP", UDim2.fromOffset(52, 40))
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.fromScale(1, 0)
		b.TextSize = 16
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

	local fx, fz = flatYaw(cam.CFrame.LookVector)
	if not fx then
		fx, fz = flatYaw(root.CFrame.LookVector)
	end
	fx, fz = fx or 0, fz or -1
	local half = (size - 8) / 2
	local scale = half / viewRadius
	local me = root.Position
	local u, v = MapConfig.worldToUV(me.X, me.Z)
	local mapPx = MapConfig.Extent * scale
	local heading = math.deg(math.atan2(fx :: number, -(fz :: number)))
	mini.rotor.Rotation = -heading
	mini.img.Size = UDim2.fromOffset(mapPx, mapPx)
	mini.img.Position = UDim2.fromOffset(-u * mapPx, -v * mapPx)

	-- player arrow: the body's heading relative to the view
	local bodyLook = if vehicle then vehicle:GetPivot().LookVector else root.CFrame.LookVector
	local bx, bz = flatYaw(bodyLook)
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

	-- dotted route line and the distance pill
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
		local metres = (Vector3.new(d.X, 0, d.Z)).Magnitude / STUDS_PER_M
		mini.pillText.Text = if metres >= 1000
			then string.format("%s  %.1f km", objectiveLabel or "", metres / 1000)
			else string.format(
				"%s  %d m",
				objectiveLabel or "",
				math.floor(metres / 10 + 0.5) * 10
			)
		mini.pill.Visible = true
	else
		for _, dot in dots:GetChildren() do
			(dot :: Frame).Visible = false
		end
		mini.pill.Visible = false
	end
end

-- ---------------------------------------------------------------- full map

local function legendRow(parent: Instance, style: Style, order: number)
	local row = frame("Row", parent, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order })
	local b = badge(style, 22, false)
	b.Position = UDim2.fromOffset(13, 15)
	b.Parent = row
	local t = text("Label", row, style.label, 17)
	t.Font = HudTheme.BodyFont
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Position = UDim2.fromOffset(32, 0)
	t.Size = UDim2.new(1, -32, 1, 0)
	t.TextTruncate = Enum.TextTruncate.AtEnd
end

local function buildFullMap()
	local root = frame("FullMap", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = DEEP,
		Visible = false,
		ZIndex = 20,
	})
	full.root = root
	local canvas = frame("Canvas", root, { Size = UDim2.fromScale(1, 1), ClipsDescendants = true })
	local img = frame("Map", canvas)
	makeTiles(img)
	full.img = img
	full.areas = frame("Areas", canvas, { Size = UDim2.fromScale(1, 1) })
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Modal = true -- frees the mouse in first person while the map is open
	hit.Parent = canvas
	full.hit = hit
	full.blips = frame("Blips", canvas, { Size = UDim2.fromScale(1, 1) })
	full.pool = poolNew(full.blips)
	local me = text("Player", canvas, "▲", 28, Color3.fromRGB(255, 255, 255))
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Size = UDim2.fromOffset(30, 30)
	me.TextStrokeTransparency = 0.1
	full.me = me
	local cross = text("Cross", canvas, "+", 34, Color3.fromRGB(255, 255, 255))
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Size = UDim2.fromOffset(34, 34)
	cross.TextStrokeTransparency = 0.3
	cross.Visible = false
	full.cross = cross

	-- header and buttons
	local title = HudTheme.panel("Title", UDim2.fromOffset(300, 52), root)
	title.Position = UDim2.fromOffset(16, 16)
	local tt = text("Text", title, "GALE ISLES", 26)
	tt.Font = HudTheme.HeaderFont
	tt.Size = UDim2.fromScale(1, 1)
	local close = button("Close", root, "X", UDim2.fromOffset(56, 56))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 16)
	close.Activated:Connect(function()
		MapController.Close()
	end)
	local zin = button("ZoomIn", root, "+", UDim2.fromOffset(56, 56))
	zin.AnchorPoint = Vector2.new(0, 1)
	zin.Position = UDim2.new(0, 16, 1, -212)
	local zout = button("ZoomOut", root, "-", UDim2.fromOffset(56, 56))
	zout.AnchorPoint = Vector2.new(0, 1)
	zout.Position = UDim2.new(0, 16, 1, -148)
	zin.Activated:Connect(function()
		full.radius = math.max(MapConfig.FullMap.minRadius, full.radius * 0.7)
	end)
	zout.Activated:Connect(function()
		full.radius = math.min(MapConfig.FullMap.maxRadius, full.radius / 0.7)
	end)
	local clear = button("ClearWaypoint", root, "Clear waypoint", UDim2.fromOffset(190, 52))
	clear.AnchorPoint = Vector2.new(0, 1)
	clear.Position = UDim2.new(0, 16, 1, -20)
	clear.TextSize = 20
	clear.Activated:Connect(function()
		MapController.SetWaypoint(nil)
	end)
	full.clear = clear
	local recentre = button("Recentre", root, "Me", UDim2.fromOffset(56, 56))
	recentre.AnchorPoint = Vector2.new(0, 1)
	recentre.Position = UDim2.new(0, 16, 1, -84)
	recentre.TextSize = 20
	recentre.Activated:Connect(function()
		local r = rootPart()
		if r then
			full.center = Vector2.new(r.Position.X, r.Position.Z)
		end
	end)

	-- legend
	local legend = HudTheme.panel("Legend", UDim2.fromOffset(250, 0), root)
	legend.AnchorPoint = Vector2.new(1, 0)
	legend.Position = UDim2.new(1, -16, 0, 84)
	legend.AutomaticSize = Enum.AutomaticSize.Y
	HudTheme.padding(legend, 10)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = legend
	local head = text("Head", legend, "LEGEND", 18, C.gold)
	head.Font = HudTheme.HeaderFont
	head.Size = UDim2.new(1, 0, 0, 26)
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.LayoutOrder = 0
	local order = 1
	for _, key in { "Casualty", "Vessel", "DropOff", "Waypoint", "Vehicle", "Crew", "Storm" } do
		legendRow(legend, MapConfig.Styles[key], order)
		order += 1
	end
	for _, b in MapConfig.Blips do
		if b.legend then
			legendRow(legend, b :: any, order)
			order += 1
		end
	end
	local hint = text("Hint", legend, "", 14, C.textDim)
	hint.Font = HudTheme.BodyFont
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Size = UDim2.new(1, 0, 0, 52)
	hint.LayoutOrder = 99
	full.hint = hint
	-- the legend collapses on small (phone) screens
	full.legend = legend

	full.radius = MapConfig.FullMap.startRadius
	full.center = Vector2.new(0, 200)
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

local function updateFullMap(now: number)
	local scale, size = fullScale()
	local mapPx = MapConfig.Extent * scale
	local c = full.center :: Vector2
	local u, v = MapConfig.worldToUV(c.X, c.Y)
	full.img.Size = UDim2.fromOffset(mapPx, mapPx)
	full.img.Position = UDim2.fromOffset(size.X / 2 - u * mapPx, size.Y / 2 - v * mapPx)
	local function at(p: Vector3): (number, number)
		return size.X / 2 + (p.X - c.X) * scale, size.Y / 2 + (p.Z - c.Y) * scale
	end
	local root = rootPart()
	local vehicle = seatModel()
	local me = if root then root.Position else Vector3.new(c.X, 0, c.Y)
	if root then
		local x, y = at(me)
		full.me.Position = UDim2.fromOffset(x, y)
		local bx, bz =
			flatYaw(if vehicle then vehicle:GetPivot().LookVector else root.CFrame.LookVector)
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
	for _, b in collect(me, vehicle) do
		local x, y = at(b.pos)
		local f = poolGet(pool, b.id, b.style, math.floor((b.size or 20) * 1.15), b.pulse)
		f.Position = UDim2.fromOffset(x, y)
	end
	poolFlush(pool)
	pulseAll(pool, now)
	full.clear.Visible = waypoint ~= nil
	full.legend.Visible = size.X >= 700
	local pad = UserInputService.GamepadEnabled and not UserInputService.MouseEnabled
	full.cross.Visible = pad
	full.hint.Text = if pad
		then "Left stick: pan. Triggers: zoom. A: set waypoint. X: clear. B: close."
		elseif
			UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		then "Drag to pan, pinch to zoom, tap to set a waypoint."
		else "Drag to pan, wheel to zoom, click to set a waypoint. M or Esc closes."
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

function MapController.GetWaypoint(): Vector3?
	return waypoint
end

function MapController.GetObjective(): (Vector3?, string?)
	return objective, objectiveLabel
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
	full.root.Visible = true
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
	gui.DisplayOrder = 16
	player:SetAttribute("MapOpen", false)
	ContextActionService:UnbindAction("MapFullPad")
end

-- ---------------------------------------------------------------- lifecycle

local function hidePads()
	local use = ReplicatedStorage:GetAttribute("UseMapWaypoints") == true
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs")
	for _, p in if folder then folder:GetDescendants() else {} do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if use then 1 else 0
		end
	end
end

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
	ReplicatedStorage:GetAttributeChangedSignal("UseMapWaypoints"):Connect(hidePads)
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 30)
		local folder = map and map:WaitForChild("DropOffs", 30)
		if folder then
			folder.DescendantAdded:Connect(hidePads)
		end
		hidePads()
	end)
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
