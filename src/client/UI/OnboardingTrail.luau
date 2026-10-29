--!strict
-- OnboardingTrail: the steps from you to the beacon's goal (owner 2026-10-29: "add some nice steps of where do you
-- need to go for the tutorial"). A line of Lego chevrons (art/source/ui/trail_chevron.svg) flat on the ground,
-- tips toward the goal, along a walkable route (PathfindingService; a straight line when there is none), ending at
-- the goal. A calm wave runs along them toward the goal (each step brightens and grows a little in turn),
-- never a flash. Hidden in a vehicle, with a panel or the build tablet open, near the goal, and whenever the beacon
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
local SPACING = 7 -- studs between steps
local TILE = 6 -- studs across a step
local FIRST = 5 -- studs ahead of you to the first step
local END = 3 -- studs short of the goal: the last step
local ARRIVE = 10 -- studs from the goal: arrived, the steps go
local LIFT = 0.05 -- off the ground: never coplanar with the plate or a lot (CLAUDE.md "No z-fighting")
local PERIOD = 1.7 -- s per wave
local WAVE = 6 * SPACING -- studs between crests
local REROUTE = 1 -- s: at most one route per second
local STRAY = 5 -- studs moved before a new route

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

	type Tile = { part: Part, art: ImageLabel, s: number }
	local tiles: { Tile } = {}
	for i = 1, MAX do
		local part = Instance.new("Part")
		part.Name = "Step"
		part.Size = Vector3.new(TILE, 0.05, TILE)
		part.Transparency = 1
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.CastShadow = false
		part.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0 -- unlit: reads at night
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Enabled = false
		gui.Parent = part
		local art = Instance.new("ImageLabel")
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromScale(0.9, 0.9)
		art.BackgroundTransparency = 1
		art.Image = UiImages.Markers.TrailChevron
		art.ScaleType = Enum.ScaleType.Fit
		art.Parent = gui
		tiles[i] = { part = part, art = art, s = 0 }
	end

	local placed = 0 -- steps in use
	local shown = false
	local goalAt: Vector3? = nil
	local routedFrom: Vector3? = nil
	local routedAt = -math.huge
	local token = 0

	local function refresh()
		for i, t in tiles do
			(t.art.Parent :: SurfaceGui).Enabled = shown and i <= placed
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
			local at = Vector3.new(p.X, y + LIFT, p.Z)
			t.part.CFrame = CFrame.lookAt(at, at + dir)
			t.s = s
			s += SPACING
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
		for i = 1, placed do
			local t = tiles[i]
			-- 0..1, cresting in turn toward the goal: a smooth cosine, never on/off
			local wave = 0.5 + 0.5 * math.cos(2 * math.pi * (now / PERIOD - t.s / WAVE))
			local pos = t.part.Position
			local near = math.clamp(
				(Vector3.new(pos.X - here.X, 0, pos.Z - here.Z).Magnitude - 1.5) / 4,
				0,
				1
			)
			t.art.ImageTransparency = 1 - near * (0.7 + 0.3 * wave)
			local size = 0.86 + 0.14 * wave
			t.art.Size = UDim2.fromScale(size, size)
		end
	end

	function self.destroy()
		token += 1
		folder:Destroy()
	end

	return self :: Trail
end

return OnboardingTrail
