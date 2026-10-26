--!strict
-- WildlifeController (G76): ambient grey seals and herring gulls, drawn on this client only (not replicated), only
-- near the camera, no UI. Static meshes (ReplicatedStorage.WildlifeTemplates, WildlifeArtService) moved by code:
--   * seals hauled out on low rock ledges (SEAL_SITES): a slow breathing bob,
--     the head part turning and lifting now and then; one seal per haul-out bottling head-up in the swell offshore;
--   * gulls over the lagoon gliding banked circles and figure-eights (Wildlife/GullPath).
-- Heights come from raycasts at spawn (ledge hulls); a group with nothing placed is retried next check.
-- Every part is anchored with CanCollide / CanQuery / CanTouch off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GullPath = require(script.Parent:WaitForChild("Wildlife"):WaitForChild("GullPath"))
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local WildlifeController = {}

local SEAL, GULL = "M_Ani_GreySeal", "M_Ani_HerringGull"
local CHECK = 1 -- s between near / far checks
local HYSTERESIS = 80 -- studs past `near` before a group is removed
local NOSE_UP = CFrame.Angles(math.rad(70), 0, 0) -- bottling: head out of the water, body hanging below

-- spots: low rocks from map/generated/props.json, the first two dry ones are used; sea: open water the seals face, where
-- the bottling seal swims
local SEAL_SITES = {
	{
		centre = Vector3.new(1460, 0, 720),
		spots = {
			Vector3.new(1485.3, 0, 712.7),
			Vector3.new(1492.1, 0, 729.7),
			Vector3.new(1425.7, 0, 680),
		},
		sea = Vector3.new(1455, 0, 790),
	},
	{
		centre = Vector3.new(-550, 0, 35),
		spots = {
			Vector3.new(-522.7, 0, 20.5),
			Vector3.new(-579, 0, 46.6),
			Vector3.new(-538.4, 0, 22.3),
		},
		sea = Vector3.new(-550, 0, 95),
	},
}
local SEAL_NEAR = 450
local HARBOUR = Vector3.new(-40, 0, 60)
local GULL_NEAR = 600
local GULL_LOOPS: { GullPath.Loop } = {
	{
		centre = Vector3.new(-110, 34, 75),
		radius = 38,
		speed = 19,
		dir = 1,
		eight = false,
		phase = 0,
		drift = 5,
	},
	{
		centre = Vector3.new(-20, 44, 70),
		radius = 55,
		speed = 23,
		dir = -1,
		eight = false,
		phase = 2.1,
		drift = 7,
	},
	{
		centre = Vector3.new(70, 30, 70),
		radius = 48,
		speed = 18,
		dir = 1,
		eight = true,
		phase = 4,
		drift = 4,
	},
	{
		centre = Vector3.new(-160, 50, 90),
		radius = 60,
		speed = 25,
		dir = -1,
		eight = true,
		phase = 1.3,
		drift = 8,
	},
}

type Kind = "Hauled" | "Bottling" | "Glide"
type Animal = {
	kind: Kind,
	parts: { BasePart },
	rel: { CFrame }, -- each part relative to the model pivot
	minY: number, -- lowest point below the pivot
	head: number?, -- index of the head part (seal)
	neck: CFrame, -- model-space point the head turns about
	base: CFrame,
	pos: Vector3,
	loop: GullPath.Loop?,
	phase: number,
	yaw: number, -- head yaw (seal)
	pitch: number,
	goalYaw: number,
	goalPitch: number,
	nextAt: number,
}
type Group = {
	centre: Vector3,
	near: number,
	build: (Model) -> { Animal },
	model: Model?,
	animals: { Animal },
}

local templates: Folder
local holder: Folder
local groups: { Group } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function halfExtent(cf: CFrame, size: Vector3, axis: Vector3): number
	return (
		math.abs(cf.XVector:Dot(axis)) * size.X
		+ math.abs(cf.YVector:Dot(axis)) * size.Y
		+ math.abs(cf.ZVector:Dot(axis)) * size.Z
	) / 2
end

local function ground(p: Vector3): RaycastResult?
	rayParams.FilterDescendantsInstances = { holder, Players.LocalPlayer.Character or holder }
	return Workspace:Raycast(Vector3.new(p.X, 60, p.Z), Vector3.new(0, -100, 0), rayParams)
end

local function spawnAnimal(asset: string, kind: Kind, parent: Instance): Animal?
	local t = templates:FindFirstChild(asset)
	if not (t and t:IsA("Model")) then
		return nil
	end
	local m = t:Clone()
	local pivot = m:GetPivot()
	local a: Animal = {
		kind = kind,
		parts = {},
		rel = {},
		minY = math.huge,
		neck = CFrame.identity,
		base = CFrame.identity,
		pos = Vector3.zero,
		phase = math.random() * 10,
		yaw = 0,
		pitch = 0,
		goalYaw = 0,
		goalPitch = 0,
		nextAt = 0,
	}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			local rel = pivot:ToObjectSpace(d.CFrame)
			table.insert(a.parts, d)
			table.insert(a.rel, rel)
			a.minY = math.min(a.minY, rel.Y - halfExtent(rel, d.Size, Vector3.yAxis))
			if string.find(string.lower(d.Name), "head") then
				a.head = #a.parts
				-- forward is -Z: the neck is the head part's back end
				a.neck = CFrame.new(
					rel.Position + Vector3.new(0, 0, halfExtent(rel, d.Size, Vector3.zAxis))
				)
			end
		end
	end
	m.Parent = parent
	return a
end

local function buildSeals(site: typeof(SEAL_SITES[1]), model: Model): { Animal }
	local out = {}
	for i, spot in site.spots do
		if #out >= 2 then
			break -- two hauled out per site; later spots are fallbacks
		end
		local c = ground(spot)
		if not (c and c.Position.Y > 0.3) then
			continue -- no ledge here (yet), or awash
		end
		local d = site.sea - spot
		d = CFrame.Angles(0, if i % 2 == 0 then 0.5 else -0.4, 0)
			:VectorToWorldSpace(Vector3.new(d.X, 0, d.Z).Unit)
		local h, b = ground(spot + d * 3), ground(spot - d * 3)
		local hy = if h then h.Position.Y else c.Position.Y
		local by = if b then b.Position.Y else c.Position.Y
		local a = spawnAnimal(SEAL, "Hauled", model)
		if a then
			a.base = CFrame.new(spot.X, c.Position.Y, spot.Z)
				* CFrame.Angles(0, math.atan2(-d.X, -d.Z), 0)
				* CFrame.Angles(math.clamp(math.atan2(hy - by, 6), -0.3, 0.3), 0, 0)
				* CFrame.new(0, -a.minY - 0.1, 0) -- belly settled into the rock
			table.insert(out, a)
		end
	end
	local sea = ground(site.sea)
	if #out > 0 and not (sea and sea.Position.Y > -1.5) then
		local a = spawnAnimal(SEAL, "Bottling", model)
		if a then
			-- pivot height that puts the head centre 0.3 studs above the water
			a.pos = Vector3.new(site.sea.X, 0.3 - (NOSE_UP * a.rel[a.head or 1]).Y, site.sea.Z)
			table.insert(out, a)
		end
	end
	return out
end

local function buildGulls(model: Model): { Animal }
	local out = {}
	for _, loop in GULL_LOOPS do
		local a = spawnAnimal(GULL, "Glide", model)
		if a then
			a.loop = loop
			a.nextAt = math.huge
			table.insert(out, a)
		end
	end
	return out
end

local function step(a: Animal, t: number, dt: number, parts: { BasePart }, cfs: { CFrame })
	if t >= a.nextAt then
		a.goalYaw = if math.random() < 0.35 then 0 else (math.random() * 2 - 1) * 0.45
		a.goalPitch = if math.random() < 0.3 then 0.18 else 0
		a.nextAt = t + 3 + math.random() * 6
	end
	local k = math.min(1, dt * 1.5)
	a.yaw += (a.goalYaw - a.yaw) * k
	a.pitch += (a.goalPitch - a.pitch) * k
	local root: CFrame
	if a.kind == "Hauled" then
		root = a.base * CFrame.new(0, 0.06 * math.sin(t * 1.4 + a.phase), 0) -- breathing, ~4.5 s
	elseif a.kind == "Bottling" then
		local swell = Weather.heightAt(a.pos) + 0.12 * math.sin(t * 1.1 + a.phase)
		root = CFrame.new(a.pos + Vector3.new(0, swell, 0))
			* CFrame.Angles(0, a.phase + 0.6 * math.sin(t * 0.05 + a.phase), 0)
			* NOSE_UP
	else
		root = GullPath.at(a.loop :: GullPath.Loop, t)
	end
	for i, p in a.parts do
		table.insert(parts, p)
		table.insert(
			cfs,
			if i == a.head
				then root * a.neck * CFrame.Angles(a.pitch, a.yaw, 0) * a.neck:Inverse() * a.rel[i]
				else root * a.rel[i]
		)
	end
end

local function check()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local p = cam.CFrame.Position
	for _, g in groups do
		local dist = (Vector3.new(p.X, 0, p.Z) - g.centre).Magnitude
		if g.model and dist > g.near + HYSTERESIS then
			g.model:Destroy()
			g.model = nil
			g.animals = {}
		elseif not g.model and dist < g.near then
			local m = Instance.new("Model")
			m.Name = "Wildlife"
			g.animals = g.build(m)
			if #g.animals > 0 then
				m.Parent = holder
				g.model = m
			else
				m:Destroy()
			end
		end
	end
end

function WildlifeController.Start()
	local f = ReplicatedStorage:WaitForChild("WildlifeTemplates", 120)
	if not (f and f:IsA("Folder")) then
		warn("[Wildlife] WildlifeTemplates missing; no seals or gulls")
		return
	end
	templates = f
	for _, m in f:GetChildren() do -- wait for every part to replicate
		local function count(): number
			local n = 0
			for _, d in m:GetDescendants() do
				n += if d:IsA("BasePart") then 1 else 0
			end
			return n
		end
		local t0 = os.clock()
		while count() < ((m:GetAttribute("Parts") :: number?) or 0) and os.clock() - t0 < 30 do
			task.wait(0.2)
		end
	end
	local h = Instance.new("Folder")
	h.Name = "WildlifeLocal"
	h.Parent = Workspace
	holder = h
	for _, site in SEAL_SITES do
		table.insert(groups, {
			centre = site.centre,
			near = SEAL_NEAR,
			build = function(m: Model)
				return buildSeals(site, m)
			end,
			animals = {},
		})
	end
	table.insert(groups, { centre = HARBOUR, near = GULL_NEAR, build = buildGulls, animals = {} })

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		table.clear(parts)
		table.clear(cfs)
		for _, g in groups do
			for _, a in g.animals do
				step(a, t, dt, parts, cfs)
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
	while true do
		check()
		task.wait(CHECK)
	end
end

return WildlifeController
