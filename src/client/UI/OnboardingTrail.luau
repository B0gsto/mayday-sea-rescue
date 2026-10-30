--!strict
-- OnboardingTrail: the steps from you to the beacon's goal (owner 2026-10-29: "add some nice steps of where do you
-- need to go for the tutorial"). A line of Lego chevrons (art/source/ui/trail_chevron.svg) flat on the ground,
-- tips toward the goal, along a walkable route (PathfindingService; a straight line when there is none), ending at
-- the goal. Each step is a thin raised plate (the art stacked over two darker copies: a Lego tile's edge); far steps
-- grow and tip up toward you so the trail reads to the goal. A calm pulse runs along them toward the goal (one step
-- at a time brightens toward white and grows a little), never a flash; at rest they stay saturated blue. Hidden in a vehicle, with a panel or the build tablet open, near the goal, and whenever the beacon
-- is. Client only, pooled: OnboardingBeacon owns one and steps it every frame.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
) :: any
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local OnboardingTrail = {}

export type Trail = {
	step: (goal: Vector3?, visible: boolean) -> (),
	destroy: () -> (),
}

local MAX = 24 -- pooled steps
local WIDTH = 10 -- studs across a step
local LENGTH = 13 -- studs along the path: stretched 1.3x so the V survives the low camera's foreshortening
local SPACING = 15 -- studs between step centres (x their growth): a 2 stud gap, the path reads continuous
local FIRST = 11 + LENGTH / 2 -- the first step's centre: its near edge 11 studs ahead, clear of the avatar's legs
local CLEAR = 7 -- studs: a step whose near edge comes this close to you or the camera's line to you is gone
local HALO = 0.04 -- of the screen height: a step this close on screen to your avatar fades (it read as a hat)
local GROW = 0.3 -- far steps grow up to 1.3x (more piles them into one stack at the goal) ...
local GROW_OVER = 100 -- ... over this many studs past the first
local TILT = math.rad(8) -- far steps tip up toward you by at most this (pivot on the near edge) ...
local TILT_OVER = 60 -- ... reached this many studs past the first
local LAYERS = 3 -- the art over two darker copies ...
local GAP = 0.2 -- ... this far apart: a 0.4 stud Lego plate
local EDGE = Color3.fromRGB(70, 120, 190) -- the copies' tint: the plate's dark blue edge
local REST = Color3.fromRGB(190, 218, 255) -- the top's tint at rest: the unlit art's white rim washed out at dusk
local END = 3 -- studs short of the goal: the last step
local ARRIVE = 10 -- studs from the goal: arrived, the steps go
local LIFT = 0.05 -- off the ground: never coplanar with the plate or a lot (CLAUDE.md "No z-fighting")
local PERIOD = 1.7 -- s per pulse
local WAVE = 8 * SPACING -- studs between pulses
local SHARP = 8 -- the pulse is cos^SHARP: one step or two lit at a time, the rest at rest
local REROUTE = 1 -- s: at most one route per second
local STRAY = 5 -- studs moved before a new route

-- a box's on-screen bounds (min, max viewport px), or nil when any corner is behind the camera
local function screenBox(cam: Camera, cf: CFrame, size: Vector3): (Vector2?, Vector2?)
	local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for x = -0.5, 0.5 do
		for y = -0.5, 0.5 do
			for z = -0.5, 0.5 do
				local v = cam:WorldToViewportPoint(cf * (size * Vector3.new(x, y, z)))
				if v.Z <= 0 then
					return nil, nil
				end
				lo, hi = lo:Min(Vector2.new(v.X, v.Y)), hi:Max(Vector2.new(v.X, v.Y))
			end
		end
	end
	return lo, hi
end

local function surfaceY(p: Vector3): number
	local ok, h = pcall(Weather.heightAt, p)
	return if ok and type(h) == "number" then h else -math.huge
end

-- the walkable route, or nil (no path: the goal sits on the water, the plate has not streamed in)
local function route(from: Vector3, to: Vector3): { Vector3 }?
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = SPACING,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local points = {}
	for _, wp in path:GetWaypoints() do
		table.insert(points, wp.Position)
	end
	return if #points >= 2 then points else nil
end

function OnboardingTrail.start(parent: Instance): Trail
	local player = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "Trail"
	folder.Parent = parent

	-- layers[LAYERS] is the top (art + glow); the ones under it are the plate's darker edge
	type Tile =
		{ layers: { Part }, arts: { ImageLabel }, glow: ImageLabel, s: number, tail: number }
	local tiles: { Tile } = {}
	for i = 1, MAX do
		local layers, arts = {}, {}
		for k = 1, LAYERS do
			local part = Instance.new("Part")
			part.Name = "Step"
			part.Size = Vector3.new(LENGTH, 0.05, WIDTH) -- X along the path: a Top-face canvas's up runs along -X
			part.Transparency = 1
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
			part.Parent = folder
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.LightInfluence = 0 -- unlit: reads at night
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 32
			gui.Enabled = false
			gui.Parent = part
			-- the art is two 520x676 frames side by side: the sky-blue step, then the same step brightened toward white
			local art = Instance.new("ImageLabel")
			art.AnchorPoint = Vector2.new(0.5, 0.5)
			art.Position = UDim2.fromScale(0.5, 0.5)
			art.Size = UDim2.fromScale(0.86, 0.86)
			art.BackgroundTransparency = 1
			art.Image = UiImages.Markers.TrailChevron
			art.ImageRectSize = Vector2.new(520, 676)
			art.ImageColor3 = if k < LAYERS then EDGE else REST
			art.ScaleType = Enum.ScaleType.Fit
			art.Parent = gui
			layers[k], arts[k] = part, art
		end
		local glow = arts[LAYERS]:Clone()
		glow.AnchorPoint = Vector2.zero
		glow.Position = UDim2.new()
		glow.Size = UDim2.fromScale(1, 1)
		glow.ImageRectOffset = Vector2.new(520, 0)
		glow.ImageColor3 = Color3.new(1, 1, 1)
		glow.Parent = arts[LAYERS]
		tiles[i] = { layers = layers, arts = arts, glow = glow, s = 0, tail = 1 }
	end

	local placed = 0 -- steps in use
	local shown = false
	local goalAt: Vector3? = nil
	local routedFrom: Vector3? = nil
	local routedAt = -math.huge
	local token = 0

	local function refresh()
		for i, t in tiles do
			for _, art in t.arts do
				(art.Parent :: SurfaceGui).Enabled = shown and i <= placed
			end
		end
	end
	local function setShown(on: boolean)
		if on ~= shown then
			shown = on
			refresh()
		end
	end

	-- lays the steps along `points` (from you to the goal), each on the ground under it
	local function lay(points: { Vector3 }, goal: Vector3)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { parent, player.Character :: Instance }
		params.IgnoreWater = true
		local n, s, seg, segStart = 0, FIRST, 1, 0
		while n < MAX and seg < #points do
			local a, b = points[seg], points[seg + 1]
			local len = (b - a).Magnitude
			if s > segStart + len then
				seg, segStart = seg + 1, segStart + len
				continue
			end
			local p = a:Lerp(b, if len > 0 then (s - segStart) / len else 0)
			local flat = Vector3.new(goal.X - p.X, 0, goal.Z - p.Z)
			if flat.Magnitude < END then
				break
			end
			local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			dir = if dir.Magnitude > 0.1 then dir.Unit else flat.Unit
			local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
			-- shortcut: a step over the water sits at the sea level when laid, not on each wave; fine for the
			-- dock-side goals, per-frame heights if a trail ever runs across open water
			local y = math.max(if hit then hit.Position.Y else -math.huge, surfaceY(p))
			if y == -math.huge then
				y = p.Y
			end
			n += 1
			local t = tiles[n]
			local past = s - FIRST
			local grow = 1 + GROW * math.clamp(past / GROW_OVER, 0, 1)
			local tilt = TILT * math.clamp(past / TILT_OVER, 0, 1)
			local half = LENGTH * grow / 2
			local at = Vector3.new(p.X, y + LIFT, p.Z)
			-- -X = dir: the art's tip; then tip up about the near (+X) edge
			local base = CFrame.lookAt(at, at + dir)
				* CFrame.Angles(0, -math.pi / 2, 0)
				* CFrame.new(half, 0, 0)
				* CFrame.Angles(0, 0, -tilt)
				* CFrame.new(-half, 0, 0)
			for k, part in t.layers do
				part.Size = Vector3.new(LENGTH * grow, 0.05, WIDTH * grow)
				part.CFrame = base * CFrame.new(0, (k - 1) * GAP, 0)
			end
			t.s, t.tail = s, 1
			s += SPACING * grow
		end
		-- out of steps short of the goal: the last three fade out instead of stopping dead (the beacon marks the rest)
		local last = if n == MAX then tiles[MAX].layers[1].Position else nil
		if last and Vector3.new(goal.X - last.X, 0, goal.Z - last.Z).Magnitude > 2 * SPACING then
			for k = 1, 3 do
				tiles[MAX - 3 + k].tail = 1 - k / 4
			end
		end
		placed = n
		refresh()
	end

	local function reroute(from: Vector3, goal: Vector3)
		token += 1
		local mine = token
		routedFrom, routedAt = from, os.clock()
		task.spawn(function()
			local points = route(from, goal) or { from, goal }
			if mine == token then -- a newer route (or a new goal) replaced this one while it computed
				lay(points, goal)
			end
		end)
	end

	local self: any = {}

	function self.step(goal: Vector3?, visible: boolean)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local gui = player:FindFirstChildOfClass("PlayerGui")
		local tablet = gui and gui:FindFirstChild("BuildTablet")
		local on = visible
			and goal ~= nil
			and root ~= nil
			and not (hum and hum.SeatPart) -- in a boat the ring and the edge pointer guide; steps would sink in the waves
			and player:GetAttribute("MenuOpen") ~= true
			and not (tablet and tablet:IsA("ScreenGui") and tablet.Enabled)
		if on and goal and root then
			local d = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Magnitude
			on = d > ARRIVE
		end
		if not on or not goal or not root then
			setShown(false)
			if not goal then
				goalAt, placed = nil, 0
				token += 1
			end
			return
		end
		local here = root.Position
		local moved = goalAt == nil or (goalAt :: Vector3 - goal).Magnitude > 1
		if moved then
			goalAt = goal
			placed = 0
			refresh()
			reroute(here, goal)
		elseif
			os.clock() - routedAt >= REROUTE
			and (routedFrom == nil or (here - routedFrom :: Vector3).Magnitude > STRAY)
		then
			reroute(here, goal)
		end
		setShown(true)
		local now = os.clock()
		-- the camera's line to you, flat: steps on it or near you would sit round the avatar's legs
		local cam = Workspace.CurrentCamera
		local eye = if cam then cam.CFrame.Position else here
		local line = Vector3.new(here.X - eye.X, 0, here.Z - eye.Z)
		local lineLen = line.Magnitude
		-- your avatar's on-screen box: a step drawn over or just past it reads as a hat or a halo
		local charLo, charHi
		if cam and char then
			local cf, size = (char :: Model):GetBoundingBox()
			charLo, charHi = screenBox(cam, cf, size)
		end
		local halo = if cam then HALO * cam.ViewportSize.Y else 1
		for i = 1, placed do
			local t = tiles[i]
			-- 0..1, one narrow crest travelling toward the goal: a smooth cosine power, never on/off
			local pulse = math.max(0, math.cos(2 * math.pi * (now / PERIOD - t.s / WAVE))) ^ SHARP
			local top = t.layers[LAYERS]
			local pos = top.Position
			local off = Vector3.new(pos.X - eye.X, 0, pos.Z - eye.Z)
			local along = if lineLen > 0.1
				then math.clamp(off:Dot(line) / lineLen, 0, lineLen) / lineLen
				else 1
			local gap = (off - line * along).Magnitude - top.Size.X / 2
			local alpha = math.clamp((gap - CLEAR) / 4, 0, 1) * t.tail
			local lo, hi
			if cam and charLo then
				lo, hi = screenBox(cam, top.CFrame, top.Size)
			end
			if lo and hi and charLo and charHi then
				-- the screen gap between the two boxes (negative when they overlap)
				local d =
					math.max(lo.X - charHi.X, charLo.X - hi.X, lo.Y - charHi.Y, charLo.Y - hi.Y)
				alpha *= math.clamp(d / halo, 0, 1)
			end
			for _, art in t.arts do
				art.ImageTransparency = 1 - alpha
			end
			t.glow.ImageTransparency = 1 - alpha * 0.8 * pulse
			local size = 0.86 + 0.12 * pulse
			t.arts[LAYERS].Size = UDim2.fromScale(size, size)
			t.arts[LAYERS].ImageColor3 = REST:Lerp(Color3.new(1, 1, 1), pulse)
		end
	end

	function self.destroy()
		token += 1
		folder:Destroy()
	end

	return self :: Trail
end

return OnboardingTrail
