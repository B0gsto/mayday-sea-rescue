--!strict
-- SeaLifeController (sea1, owner 2026-10-29: "more content on the sea, it looks too empty"): the ambient sea life and
-- things to see from Shared.SeaLife, drawn on this client only (not replicated, nothing to stream), no UI.
--   * fishing boats (WildlifeTemplates M_Veh_MooredBoat_02/_03 LOD1) on lazy loops, riding the swell, a low engine
--     putter, two herring gulls trailing each with a call now and then;
--   * Lego dolphin pods porpoising along a loop; near the camera one leaps now and then (VFX dolphin_leap + splash);
--   * a Lego whale far out showing its back, breaching every BREACH_EVERY s while in range (VFX whale_breach);
--   * Lego sandbars (no collision: shallows) with isolated-danger buoys; Gull Bank's beached Lego wreck and gulls;
--   * Lego wreck buoys over the Morwenna; drifting flotsam (crates, a barrel, planks).
-- Each group is built when the camera comes within its draw distance (SeaLife.NEAR x the ocean quality scale)
-- and destroyed past it; Low quality skips the flotsam. Every part is anchored, CanCollide / CanQuery / CanTouch
-- off, moved with one BulkMoveTo a frame. Workspace.SeaLifeLocal attribute Parts: parts drawn now (perf runs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local GullPath = require(script.Parent:WaitForChild("Wildlife"):WaitForChild("GullPath"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local SeaLife = require(Shared:WaitForChild("SeaLife"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local Weather = require(Shared:WaitForChild("Weather"))

local SeaLifeController = {}

local GULL = "M_Ani_HerringGull"
local CHECK = 1 -- s between near / far checks
local HYSTERESIS = 100
local STUDS = "rbxassetid://18878365966" -- a white 4 x 4 stud tile (IslandPlates)
local QUALITY = { High = 1, Medium = 0.75, Low = 0.5 }
local LEAP_NEAR = 300 -- dolphins leap only this close to the camera
local LEAP_TIME = 1.2
local BREACH_TIME = 3.2
local CALL_NEAR = 220 -- gull calls this close

local SAND = Color3.fromRGB(226, 201, 140)
local SAND_TOP = Color3.fromRGB(236, 214, 160)
local RED = Color3.fromRGB(196, 40, 28)
local BLACK = Color3.fromRGB(27, 42, 53)
local BLUE = Color3.fromRGB(13, 105, 172)
local YELLOW = Color3.fromRGB(245, 205, 48)
local BROWN = Color3.fromRGB(124, 92, 70)
local DARK_BROWN = Color3.fromRGB(88, 64, 50)
local DOLPHIN = Color3.fromRGB(110, 140, 170)
local WHALE = Color3.fromRGB(52, 66, 92)
local BELLY = Color3.fromRGB(226, 228, 230)

-- One moving thing: its parts relative to its root, and how the root moves.
type Thing = {
	parts: { BasePart },
	rel: { CFrame },
	root: (t: number, clock: number) -> CFrame,
}
type Group = {
	centre: (t: number) -> Vector3,
	near: number,
	build: (Model) -> { Thing },
	model: Model?,
	things: { Thing },
	lowSkip: boolean?,
}

local templates: Folder? = nil
local holder: Folder
local groups: { Group } = {}

local function part(
	parent: Instance,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	studs: boolean?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if studs then
		local tex = Instance.new("Texture")
		tex.Face = Enum.NormalId.Top
		tex.Texture = STUDS
		tex.StudsPerTileU, tex.StudsPerTileV = 4, 4
		tex.Color3 = color:Lerp(Color3.new(0, 0, 0), 0.12)
		tex.Transparency = 0.15
		tex.Parent = p
	end
	p.Parent = parent
	return p
end

-- A thing from parts laid out round a local origin: { part, CFrame relative to the root }.
local function thing(list: { { any } }, root: (number, number) -> CFrame): Thing
	local th: Thing = { parts = {}, rel = {}, root = root }
	for _, e in list do
		table.insert(th.parts, e[1])
		table.insert(th.rel, e[2])
	end
	return th
end

local function surface(p: Vector3): number
	return Weather.heightAt(p)
end

-- A copy of a WildlifeTemplates model as a thing (parts relative to its pivot, turned so the bow is -Z).
local function meshThing(asset: string, parent: Instance, root: (number, number) -> CFrame): Thing?
	local tmpl = templates and templates:FindFirstChild(asset)
	if not (tmpl and tmpl:IsA("Model")) then
		return nil
	end
	local m = tmpl:Clone()
	local pivot = m:GetPivot()
	local bow = m:FindFirstChild("ATT_Moor_Bow", true)
	local turn = CFrame.identity
	if bow and bow:IsA("Attachment") then
		local d = pivot:PointToObjectSpace(bow.WorldPosition)
		turn = CFrame.Angles(0, -math.atan2(-d.X, -d.Z), 0) -- the bow onto -Z
	end
	local th: Thing = { parts = {}, rel = {}, root = root }
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			table.insert(th.parts, d)
			table.insert(th.rel, turn * pivot:ToObjectSpace(d.CFrame))
		end
	end
	m.Parent = parent
	return th
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- A gull circling `centre(t)` (studs above it on a GullPath loop), calling now and then near the camera.
local function gull(parent: Instance, centre: (number) -> Vector3, loop: GullPath.Loop): Thing?
	local nextCall = os.clock() + math.random() * 10
	return meshThing(GULL, parent, function(t, clock)
		local cf = CFrame.new(centre(t)) * GullPath.at(loop, t)
		if clock >= nextCall then
			nextCall = clock + 8 + math.random() * 10
			local cam = Workspace.CurrentCamera
			if cam and (cam.CFrame.Position - cf.Position).Magnitude < CALL_NEAR then
				AudioController.play(
					if math.random() < 0.5 then "Gull_Call_1" else "Gull_Call_2",
					cf.Position,
					0.5
				)
			end
		end
		return cf
	end)
end

local function gullLoop(radius: number, height: number, phase: number, dir: number): GullPath.Loop
	return {
		centre = Vector3.new(0, height, 0),
		radius = radius,
		speed = 18,
		dir = dir,
		eight = false,
		phase = phase,
		drift = 4,
	}
end

---------------------------------------------------------------- boats

local function buildBoat(b: typeof(SeaLife.Boats[1]), model: Model): { Thing }
	local out = {}
	local function centre(t: number): Vector3
		return (SeaLife.at(b.loop, t))
	end
	local boat = meshThing(b.asset, model, function(t, clock)
		local p, dir = SeaLife.at(b.loop, t)
		local y = surface(p)
		return CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + dir)
			* CFrame.Angles(
				0.03 * math.sin(clock * 0.9 + b.loop.phase),
				0,
				0.05 * math.sin(clock * 0.7)
			)
	end)
	if boat then
		table.insert(out, boat)
		local engine = AudioController.newSound("Eng_RIB_Idle", boat.parts[1], true)
		engine.Volume, engine.PlaybackSpeed = 0.18, 0.55 -- a slow diesel putter
		engine.RollOffMaxDistance = 160
		engine:Play()
	end
	for i = 1, 2 do
		local g =
			gull(model, centre, gullLoop(14 + 8 * i, 18 + 6 * i, i * 2.4, if i == 1 then 1 else -1))
		if g then
			table.insert(out, g)
		end
	end
	return out
end

---------------------------------------------------------------- dolphins and the whale

local function dolphinParts(model: Model): { { any } }
	return {
		{ part(model, Vector3.new(2, 1.6, 7), DOLPHIN, nil, true), CFrame.identity },
		{ part(model, Vector3.new(1.8, 0.5, 5), BELLY), CFrame.new(0, -0.6, 0.2) },
		{ part(model, Vector3.new(0.8, 0.6, 1.8), DOLPHIN), CFrame.new(0, -0.3, -4.2) }, -- beak
		{
			part(model, Vector3.new(0.4, 1.4, 1.6), DOLPHIN),
			CFrame.new(0, 1.3, 0.6) * CFrame.Angles(-0.5, 0, 0),
		},
		{ part(model, Vector3.new(3.6, 0.3, 1.2), DOLPHIN), CFrame.new(0, 0, 4.15) }, -- flukes
	}
end

local function buildPod(pod: typeof(SeaLife.Pods[1]), model: Model): { Thing }
	local out = {}
	for i = 1, pod.size do
		local side = (i - (pod.size + 1) / 2) * 7
		local back = (i % 2) * 6
		local leapAt, nextLeap = -math.huge, os.clock() + 2 + math.random() * 6
		table.insert(
			out,
			thing(dolphinParts(model), function(t, clock)
				local p, dir = SeaLife.at(pod.loop, t)
				local right = dir:Cross(Vector3.yAxis)
				p += right * side - dir * back
				local y = surface(p) - 0.9 + 0.35 * math.sin(clock * 2.2 + i) -- the back and fin break the surface
				local pitch = 0.12 * math.cos(clock * 2.2 + i)
				local u = (clock - leapAt) / LEAP_TIME
				if u >= 0 and u < 1 then
					local h, a = SeaLife.leap(u, 6)
					y += h + 0.9
					pitch = a
				elseif u >= 1 and leapAt > -math.huge then
					leapAt = -math.huge
					VFXKit.play("dolphin_leap", CFrame.new(p.X, surface(p), p.Z), { still = true })
				elseif clock >= nextLeap then
					nextLeap = clock + 4 + math.random() * 7
					local cam = Workspace.CurrentCamera
					if cam and (cam.CFrame.Position - p).Magnitude < LEAP_NEAR then
						leapAt = clock
					end
				end
				return CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + dir)
					* CFrame.Angles(pitch, 0, 0)
			end)
		)
	end
	return out
end

local function buildWhale(model: Model): { Thing }
	local list: { { any } } = {
		{ part(model, Vector3.new(9, 7, 26), WHALE, nil, true), CFrame.identity },
		{ part(model, Vector3.new(8, 2, 20), BELLY), CFrame.new(0, -3.4, -1) },
		{ part(model, Vector3.new(7, 5.5, 6), WHALE), CFrame.new(0, -0.5, -15) }, -- head
		{ part(model, Vector3.new(4, 4, 8), WHALE), CFrame.new(0, 0.4, 16) }, -- tail stock
		{ part(model, Vector3.new(12, 0.8, 3.5), WHALE), CFrame.new(0, 0.4, 21) }, -- flukes
		{
			part(model, Vector3.new(7, 0.6, 2.6), WHALE),
			CFrame.new(-6.5, -2, -6) * CFrame.Angles(0, 0, 0.4),
		},
		{
			part(model, Vector3.new(7, 0.6, 2.6), WHALE),
			CFrame.new(6.5, -2, -6) * CFrame.Angles(0, 0, -0.4),
		},
	}
	local at, nextAt = -math.huge, os.clock() + 8
	return {
		thing(list, function(t, clock)
			local p, dir = SeaLife.at(SeaLife.Whale, t)
			local y = surface(p) - 3.6 + 0.4 * math.sin(clock * 0.6) -- the back just awash
			local pitch, roll = 0, 0
			local u = (clock - at) / BREACH_TIME
			if u >= 0 and u < 1 then
				local h = SeaLife.leap(u, 16)
				y += h
				pitch = 1.1 * (1 - 2 * u) -- nose up out of the sea, then over
				roll = u * math.pi * 0.5 -- lands on its side
			elseif u >= 1 and at > -math.huge then
				at = -math.huge
				VFXKit.play("whale_breach", CFrame.new(p.X, surface(p), p.Z), { still = true })
			elseif clock >= nextAt then
				local e = SeaLife.BREACH_EVERY
				nextAt = clock + e[1] + math.random() * (e[2] - e[1])
				at = clock
				VFXKit.play(
					"dolphin_leap",
					CFrame.new(p.X, surface(p), p.Z),
					{ still = true, scale = 2.5 }
				)
			end
			return CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + dir)
				* CFrame.Angles(pitch, 0, roll)
		end),
	}
end

---------------------------------------------------------------- marks, sandbars, flotsam

-- A Lego buoy riding the swell at `at`: bands bottom up, then a pole and a top mark.
local function buoy(
	model: Model,
	at: Vector3,
	bands: { Color3 },
	top: { { any } },
	phase: number
): Thing
	local list: { { any } } = {}
	for i, c in bands do
		local band: { any } = {
			part(model, Vector3.new(1.4, 3.2, 3.2), c, Enum.PartType.Cylinder),
			CFrame.new(0, -0.6 + (i - 1) * 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
		}
		table.insert(list, band)
	end
	local poleY = -0.6 + #bands * 1.4
	local pole: { any } =
		{ part(model, Vector3.new(0.5, 3, 0.5), bands[#bands]), CFrame.new(0, poleY + 1.3, 0) }
	table.insert(list, pole)
	for _, e in top do
		table.insert(list, { e[1], CFrame.new(0, poleY + 3, 0) * e[2] })
	end
	return thing(list, function(_t, clock)
		local y = surface(at)
		return CFrame.new(at.X, y, at.Z)
			* CFrame.Angles(
				0.12 * math.sin(clock * 1.1 + phase),
				0,
				0.12 * math.sin(clock * 0.8 + phase * 2)
			)
	end)
end

local function dangerBuoy(model: Model, at: Vector3, phase: number): Thing
	return buoy(model, at, { RED, BLACK, RED }, {
		{
			part(model, Vector3.new(1.1, 1.1, 1.1), BLACK, Enum.PartType.Ball),
			CFrame.new(0, 0.5, 0),
		},
		{
			part(model, Vector3.new(1.1, 1.1, 1.1), BLACK, Enum.PartType.Ball),
			CFrame.new(0, 1.7, 0),
		},
	}, phase)
end

local function wreckBuoy(model: Model, at: Vector3, phase: number): Thing
	return buoy(model, at, { BLUE, YELLOW, BLUE, YELLOW }, {
		{ part(model, Vector3.new(0.4, 2, 0.4), YELLOW), CFrame.new(0, 1, 0) },
		{ part(model, Vector3.new(1.6, 0.4, 0.4), YELLOW), CFrame.new(0, 1.2, 0) }, -- the yellow cross
	}, phase)
end

local function buildSandbar(s: typeof(SeaLife.Sandbars[1]), model: Model): { Thing }
	local cf = CFrame.new(s.at) * CFrame.Angles(0, math.rad(s.yaw), 0)
	-- two stacked Lego plates (tops 0.7 and 1.15 above the still sea; the upper one inset, no shared faces)
	local base = part(model, Vector3.new(s.size.X, 3, s.size.Y), SAND, nil, true)
	base.CFrame = cf * CFrame.new(0, 0.7 - 1.5, 0)
	local upper = part(model, Vector3.new(s.size.X * 0.55, 1, s.size.Y * 0.5), SAND_TOP, nil, true)
	upper.CFrame = cf * CFrame.new(-s.size.X * 0.08, 1.15 - 0.5, 0)
	local out: { Thing } = {}
	for i, x in { -1, 1 } do
		table.insert(
			out,
			dangerBuoy(model, cf:PointToWorldSpace(Vector3.new(x * (s.size.X / 2 + 22), 0, 0)), i)
		)
	end
	if s.wreck then
		-- a small Lego fishing boat run aground on the upper plate, listing, her mast snapped
		local w = cf * CFrame.new(s.size.X * 0.12, 1.15, 4) * CFrame.Angles(0, 0.5, 0.28)
		for _, e in
			{
				{ Vector3.new(7, 2, 18), BROWN, CFrame.new(0, 1, 0) },
				{ Vector3.new(1, 2.4, 18), RED, CFrame.new(-3.5 - 0.55, 1.4, 0) },
				{ Vector3.new(1, 2.4, 14), RED, CFrame.new(3.5 + 0.55, 1.4, -2) }, -- the stbd side stove in aft
				{ Vector3.new(5, 0.4, 6), DARK_BROWN, CFrame.new(0, 2.25, -5) },
				{ Vector3.new(4, 3, 4), BELLY, CFrame.new(0, 3.55, 2) }, -- wheelhouse
				{
					Vector3.new(0.8, 6, 0.8),
					DARK_BROWN,
					CFrame.new(0, 5, -4) * CFrame.Angles(0, 0, 0.5),
				},
				{
					Vector3.new(0.6, 0.4, 5),
					BROWN,
					CFrame.new(5, -0.2, 8) * CFrame.Angles(0, 0.6, 0),
				}, -- loose planks
				{
					Vector3.new(0.6, 0.4, 4),
					BROWN,
					CFrame.new(-6, -0.2, 9) * CFrame.Angles(0, -0.3, 0),
				},
			} :: { { any } }
		do
			part(model, e[1], e[2], nil, e[1].X > 3).CFrame = w * e[3]
		end
		local over = cf.Position
		for i = 1, 2 do
			local g = gull(model, function()
				return over
			end, gullLoop(22 + 10 * i, 26 + 8 * i, i * 3, if i == 1 then 1 else -1))
			if g then
				table.insert(out, g)
			end
		end
	end
	return out
end

local function buildFlotsam(at: Vector3, model: Model, seed: number): { Thing }
	local out = {}
	for i, e in
		{
			{ Vector3.new(2.4, 2.4, 2.4), BROWN, Enum.PartType.Block, Vector3.new(0, 0, 0) },
			{ Vector3.new(2, 2, 2), DARK_BROWN, Enum.PartType.Block, Vector3.new(5, 0, 3) },
			{ Vector3.new(3, 2.2, 2.2), BLUE, Enum.PartType.Cylinder, Vector3.new(-4, 0, 4) }, -- a barrel on its side
			{ Vector3.new(0.6, 0.4, 6), BROWN, Enum.PartType.Block, Vector3.new(2, 0, -5) },
		} :: { { any } }
	do
		local p = part(model, e[1], e[2], e[3], e[3] == Enum.PartType.Block and e[1].X > 1)
		local phase = seed + i * 1.7
		table.insert(
			out,
			thing({ { p, CFrame.identity } }, function(t, clock)
				local off = e[4]
					+ Vector3.new(math.sin(t * 0.05 + phase) * 3, 0, math.cos(t * 0.04 + phase) * 3)
				local q = at + off
				return CFrame.new(q.X, surface(q) + e[1].Y * 0.15, q.Z)
					* CFrame.Angles(
						0.15 * math.sin(clock * 1.3 + phase),
						t * 0.05 + phase,
						0.15 * math.sin(clock + phase)
					)
			end)
		)
	end
	return out
end

---------------------------------------------------------------- groups

local function fixed(p: Vector3): (number) -> Vector3
	return function()
		return p
	end
end

local function addGroups()
	local N = SeaLife.NEAR
	for _, b in SeaLife.Boats do
		table.insert(groups, {
			centre = function(t)
				return (SeaLife.at(b.loop, t))
			end,
			near = N.boat,
			build = function(m)
				return buildBoat(b, m)
			end,
			things = {},
		})
	end
	for _, pod in SeaLife.Pods do
		table.insert(groups, {
			centre = function(t)
				return (SeaLife.at(pod.loop, t))
			end,
			near = N.pod,
			build = function(m)
				return buildPod(pod, m)
			end,
			things = {},
		})
	end
	table.insert(groups, {
		centre = function(t)
			return (SeaLife.at(SeaLife.Whale, t))
		end,
		near = N.whale,
		build = buildWhale,
		things = {},
	})
	for _, s in SeaLife.Sandbars do
		table.insert(groups, {
			centre = fixed(s.at),
			near = N.sandbar,
			build = function(m)
				return buildSandbar(s, m)
			end,
			things = {},
		})
	end
	local marks = SeaLife.WreckMarks
	table.insert(groups, {
		centre = fixed((marks[1] + marks[2]) / 2),
		near = N.sandbar,
		build = function(m)
			return { wreckBuoy(m, marks[1], 0), wreckBuoy(m, marks[2], 1.3) }
		end,
		things = {},
	})
	for i, at in SeaLife.Flotsam do
		table.insert(groups, {
			centre = fixed(at),
			near = N.flotsam,
			build = function(m)
				return buildFlotsam(at, m, i * 2.3)
			end,
			things = {},
			lowSkip = true,
		})
	end
end

local function check()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local tier = OceanQuality.current().name
	local q = QUALITY[tier] or 1
	local p = cam.CFrame.Position
	local t = now()
	for _, g in groups do
		local c = g.centre(t)
		local dist = (Vector3.new(p.X, 0, p.Z) - c).Magnitude
		local near = if g.lowSkip and tier == "Low" then -1 else g.near * q
		if g.model and dist > near + HYSTERESIS then
			g.model:Destroy()
			g.model = nil
			g.things = {}
		elseif not g.model and dist < near then
			local m = Instance.new("Model")
			m.Name = "SeaLife"
			g.things = g.build(m)
			m.Parent = holder
			g.model = m
		end
	end
	local parts = 0
	for _, d in holder:GetDescendants() do
		parts += if d:IsA("BasePart") then 1 else 0
	end
	holder:SetAttribute("Parts", parts)
end

function SeaLifeController.Start()
	local f = ReplicatedStorage:WaitForChild("WildlifeTemplates", 120)
	if f and f:IsA("Folder") then
		templates = f -- WildlifeController waits for the parts to replicate; a missing mesh is skipped
	else
		warn("[SeaLife] WildlifeTemplates missing; no fishing boats or gulls")
	end
	local h = Instance.new("Folder")
	h.Name = "SeaLifeLocal"
	h.Parent = Workspace
	holder = h
	addGroups()

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local t, clock = now(), os.clock()
		table.clear(parts)
		table.clear(cfs)
		for _, g in groups do
			for _, th in g.things do
				local root = th.root(t, clock)
				for i, p in th.parts do
					table.insert(parts, p)
					table.insert(cfs, root * th.rel[i])
				end
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
	task.wait(5) -- let WildlifeController's replication wait settle first
	while true do
		check()
		task.wait(CHECK)
	end
end

return SeaLifeController
