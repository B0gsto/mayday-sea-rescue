--!strict
-- WildlifeController (G76): ambient grey seals and herring gulls, drawn on this client only (not replicated), only
-- near the camera, no UI. Static meshes (ReplicatedStorage.WildlifeTemplates, WildlifeArtService) moved by code:
--   * seals hauled out on low rock ledges (SEAL_SITES): a slow breathing bob,
--     the head part turning and lifting now and then; one seal per haul-out bottling head-up in the swell offshore;
--   * gulls over the lagoon gliding banked circles and figure-eights (Wildlife/GullPath).
--   * near the player (life1, Wildlife/NearLife): two gulls that find a boat at sea and trail it overhead, calling
--     (they fall behind a boat at full speed and leave); gulls standing on piles, bollards and posts that lift off
--     calling as you pass close or race by; a seal that bobs up to look at a slow boat and dives (splash) when it
--     speeds up or comes too close. At most PERCH_MAX perched (1 on Low), two trailing, one seal.
-- Heights come from raycasts at spawn (ledge hulls); a group with nothing placed is retried next check.
-- Every part is anchored with CanCollide / CanQuery / CanTouch off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local GullPath = require(script.Parent:WaitForChild("Wildlife"):WaitForChild("GullPath"))
local NearLife = require(script.Parent:WaitForChild("Wildlife"):WaitForChild("NearLife"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local Weather = require(Shared:WaitForChild("Weather"))

local WildlifeController = {}

local SEAL, GULL, STANDING_GULL = "M_Ani_GreySeal", "M_Ani_HerringGull", "M_Ani_Gull"
local CHECK = 1 -- s between near / far checks
local HYSTERESIS = 80 -- studs past `near` before a group is removed
local NOSE_UP = CFrame.Angles(math.rad(70), 0, 0) -- bottling: head out of the water, body hanging below

type SealSite = { centre: Vector3, spots: { Vector3 }, sea: Vector3 }
-- spots: low rock ledges, the first two dry ones are used; sea: open water the seals face, where the bottling seal
-- swims. Empty since the ring cut: the hub-era sites lay on Plot4's plate and in open sea (no rocks there now).
local SEAL_SITES: { SealSite } = {}
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

local PERCH_MAX = 3
local PERCH_NEAR, PERCH_FAR = 160, 220 -- perched gulls appear inside, go past
local PERCH_REST = 90 -- s before a post that lost its gull gets another
local SCARE, SCARE_FAST = 14, 45 -- studs: a gull lifts off from someone this close, or a fast boat
local ESCORT_REST, SEAL_REST = 30, 45
local CALL_NEAR = 220
local me = NearLife.me

type Kind = "Hauled" | "Bottling" | "Glide" | "Escort" | "Flee"
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
	model: Model?,
	born: number,
	anchor: Vector3?, -- Escort: where its loop is centred
	goneAt: number?, -- Escort leaving / Bottling diving
	perch: BasePart?, -- Hauled on a post
	dir: Vector3?, -- Flee heading
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
local near: { Animal } = {} -- the life round the player
local perches: { [BasePart]: boolean } = {}
local perchRest: { [BasePart]: number } = {}
local escortRest, sealRest = 0, 0
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
		model = m,
		born = os.clock(),
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

local function buildSeals(site: SealSite, model: Model): { Animal }
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
		swell -= if a.goneAt then 3 * math.min(1, (t - a.goneAt) / 1.5) else 0 -- diving
		root = CFrame.new(a.pos + Vector3.new(0, swell, 0))
			* CFrame.Angles(0, a.phase + 0.6 * math.sin(t * 0.05 + a.phase), 0)
			* NOSE_UP
	elseif a.kind == "Escort" then
		root = CFrame.new(a.anchor :: Vector3) * GullPath.at(a.loop :: GullPath.Loop, t)
	elseif a.kind == "Flee" then
		local age, d = t - a.born, a.dir :: Vector3
		local p = a.pos + d * 24 * age + Vector3.new(0, 4 * age + 2 * age * age, 0) -- climbing away
		root = CFrame.lookAt(p, p + d + Vector3.new(0, 0.3, 0))
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

---------------------------------------------------------------- near the player

local function drop(a: Animal)
	if a.model then
		a.model:Destroy()
	end
	table.remove(near, table.find(near, a) :: number)
end

local function call(at: Vector3)
	local cam = Workspace.CurrentCamera
	if cam and (cam.CFrame.Position - at).Magnitude < CALL_NEAR then
		AudioController.play(if math.random() < 0.5 then "Gull_Call_1" else "Gull_Call_2", at, 0.5)
	end
end

local function countKind(kind: Kind): number
	local n = 0
	for _, a in near do
		n += if a.kind == kind then 1 else 0
	end
	return n
end

-- Gulls on posts appear out of sight; two gulls find a boat at sea; a seal surfaces by a slow boat.
local function nearCheck()
	local cam = Workspace.CurrentCamera
	if not (cam and me.ok) then
		return
	end
	local t = os.clock()
	local c = cam.CFrame.Position
	local open = CallLogic.isWater(me.pos, "Open")
	local max = if OceanQuality.current().name == "Low" then 1 else PERCH_MAX
	local taken: { [BasePart]: boolean } = {}
	for _, a in near do
		if a.perch then
			taken[a.perch] = true
		end
	end
	if countKind("Hauled") < max then
		local options = {}
		for p in perches do
			local d = (p.Position - c).Magnitude
			local _, onScreen = cam:WorldToViewportPoint(p.Position)
			if
				not taken[p]
				and d < PERCH_NEAR
				and (d > 100 or not onScreen)
				and (p.Position - me.pos).Magnitude > SCARE * 2
				and t >= (perchRest[p] or 0)
			then
				table.insert(options, p)
			end
		end
		local p = options[math.random(math.max(1, #options))]
		local top = p and NearLife.perchTop(p.Name, p.CFrame, p.Size)
		rayParams.FilterDescendantsInstances = { holder, Players.LocalPlayer.Character or holder }
		-- open sky over it, not a pile under a deck
		if
			p
			and top
			and not Workspace:Raycast(top + Vector3.new(0, 0.3, 0), Vector3.new(0, 4, 0), rayParams)
		then
			perchRest[p] = t + 5 -- a failed spawn is not retried every second
			local a = spawnAnimal(STANDING_GULL, "Hauled", holder)
			if a then
				a.perch = p
				a.base = CFrame.new(top)
					* CFrame.Angles(0, math.random() * 2 * math.pi, 0)
					* CFrame.new(0, -a.minY + 0.05, 0)
				table.insert(near, a)
			end
		end
	end
	if me.boat and open and t >= escortRest and countKind("Escort") == 0 then
		escortRest = math.huge
		local from = NearLife.around(me.pos, me.dir, math.random() * 2 * math.pi, 200)
		for i = 1, 2 do
			local a = spawnAnimal(GULL, "Escort", holder)
			if a then
				a.anchor = from
				a.loop = {
					centre = Vector3.new(0, 24 + 8 * i, 0),
					radius = 18 + 8 * i,
					speed = 18,
					dir = if i == 1 then 1 else -1,
					eight = false,
					phase = math.random() * 6,
					drift = 4,
				}
				a.nextAt = t + 2 + math.random() * 6
				table.insert(near, a)
			end
		end
	end
	if me.boat and open and me.speed < NearLife.SLOW and t >= sealRest and math.random() < 0.08 then
		local p = NearLife.around(
			me.pos,
			me.dir,
			(0.5 + math.random() * 0.9) * (if math.random() < 0.5 then 1 else -1),
			22 + math.random() * 12
		)
		if CallLogic.isWater(p, "Open") then
			local a = spawnAnimal(SEAL, "Bottling", holder)
			if a then
				sealRest = math.huge
				local d = me.pos - p
				a.phase = math.atan2(-d.X, -d.Z) -- looking at the boat
				a.pos = Vector3.new(p.X, 0.3 - (NOSE_UP * a.rel[a.head or 1]).Y, p.Z)
				a.nextAt = t + 1
				table.insert(near, a)
				VFXKit.play(
					"dolphin_leap",
					CFrame.new(p.X, Weather.heightAt(p), p.Z),
					{ still = true, scale = 0.35 }
				)
				AudioController.play("Pet_Seal", p, 0.4)
			end
		end
	end
end

-- Every frame: trailing gulls follow, perched gulls lift off from someone close, the seal dives; each leaves.
local function nearFrame(t: number, dt: number)
	local cam = Workspace.CurrentCamera
	local c = if cam then cam.CFrame.Position else me.pos
	for i = #near, 1, -1 do
		local a = near[i]
		local flat = Vector3.new(a.pos.X, 0, a.pos.Z)
		if a.kind == "Hauled" then
			local at = a.base.Position
			local d = (at - me.pos).Magnitude
			if not (a.perch and a.perch.Parent) or (at - c).Magnitude > PERCH_FAR then
				drop(a)
			elseif
				me.ok and (d < SCARE or (me.boat and me.speed > NearLife.FAST and d < SCARE_FAST))
			then
				perchRest[a.perch :: BasePart] = t + PERCH_REST
				drop(a)
				local f = spawnAnimal(GULL, "Flee", holder)
				if f then
					local away = Vector3.new(at.X - me.pos.X, 0, at.Z - me.pos.Z)
					f.pos = at + Vector3.new(0, 1, 0)
					f.dir = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
					f.nextAt = math.huge -- no head turns in flight
					table.insert(near, f)
				end
				call(at)
			end
		elseif a.kind == "Flee" then
			if t - a.born > 6 then
				drop(a)
			end
		elseif a.kind == "Escort" then
			local anchor = a.anchor :: Vector3
			local open = me.ok and me.boat and CallLogic.isWater(me.pos, "Open")
			local far = (Vector3.new(me.pos.X, 0, me.pos.Z) - anchor).Magnitude
			if not a.goneAt and (not open or far > 300) then
				a.goneAt = t
			end
			local goal = if a.goneAt
				then anchor + NearLife.around(Vector3.zero, anchor - me.pos, 0, 500)
				else Vector3.new(me.pos.X, 0, me.pos.Z)
			a.anchor = NearLife.toward(anchor, goal, 55 * dt)
			if a.goneAt and far > 350 then
				drop(a)
				escortRest = t + ESCORT_REST
			elseif t >= a.nextAt then
				a.nextAt = t + 8 + math.random() * 10
				call(anchor + (a.loop :: GullPath.Loop).centre)
			end
		elseif a.kind == "Bottling" then
			local d = (flat - Vector3.new(me.pos.X, 0, me.pos.Z)).Magnitude
			if
				not a.goneAt
				and (
					not me.ok
					or me.speed > NearLife.FAST * 0.6
					or d < 9
					or d > 150
					or t - a.born > 30
				)
			then
				a.goneAt = t
				VFXKit.play(
					"dolphin_leap",
					CFrame.new(flat.X, Weather.heightAt(flat), flat.Z),
					{ still = true, scale = 0.5 }
				)
			elseif a.goneAt and t - a.goneAt > 1.6 then
				drop(a)
				sealRest = t + SEAL_REST
			end
		end
	end
end

local function watchPerch(d: Instance)
	if d:IsA("BasePart") and NearLife.perchName(d.Name) and not d:IsDescendantOf(holder) then
		perches[d] = true
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

-- Feel review 15: a small flock lifts off `at` (an island's landmark on your first landfall), climbing steeply,
-- fanning out and curving away, then gone in ~4 s. Client only, never replicated.
function WildlifeController.Flock(at: Vector3)
	local t = templates and holder and templates:FindFirstChild(GULL)
	if not (t and t:IsA("Model")) then
		return
	end
	local n = 6
	local birds = {}
	for i = 1, n do
		local m = t:Clone()
		local parts = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
				table.insert(parts, d)
			end
		end
		local a = i / n * math.pi * 2 + math.random() * 0.5
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local start = at + dir * (2 + math.random() * 4) + Vector3.new(0, 1 + math.random() * 2, 0)
		m:PivotTo(CFrame.lookAt(start, start + dir + Vector3.yAxis))
		m.Parent = holder
		table.insert(birds, {
			m = m,
			parts = parts,
			start = start,
			dir = dir,
			rise = 18 + math.random() * 10,
			out = 30 + math.random() * 20,
			delay = math.random() * 0.4,
			curve = (math.random() * 2 - 1) * 0.7,
		})
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		if e > 4 then
			conn:Disconnect()
			for _, b in birds do
				b.m:Destroy()
			end
			return
		end
		for _, b in birds do
			local k = math.clamp((e - b.delay) / 3.6, 0, 1)
			-- climbs steeply first (rise eases out), then speeds away (out eases in) on a curve
			local dir = CFrame.Angles(0, b.curve * k, 0):VectorToWorldSpace(b.dir)
			local pos = b.start
				+ dir * (b.out * k * k)
				+ Vector3.new(0, b.rise * (1 - (1 - k) ^ 2), 0)
			local vel = dir * (2 * b.out * k + 0.5) + Vector3.new(0, 2 * b.rise * (1 - k), 0)
			b.m:PivotTo(CFrame.lookAt(pos, pos + vel) * CFrame.Angles(0, 0, -b.curve * 0.6))
			local fade = math.clamp((e - 3.5) / 0.5, 0, 1)
			for _, p in b.parts do
				p.LocalTransparencyModifier = fade
			end
		end
	end)
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
	Workspace.DescendantAdded:Connect(watchPerch)
	Workspace.DescendantRemoving:Connect(function(d)
		perches[d :: BasePart] = nil
		perchRest[d :: BasePart] = nil
	end)
	task.spawn(function() -- the posts already there, a slice at a time (phones)
		for i, d in Workspace:GetDescendants() do
			watchPerch(d)
			if i % 4000 == 0 then
				task.wait()
			end
		end
	end)

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		NearLife.update()
		nearFrame(t, dt)
		table.clear(parts)
		table.clear(cfs)
		for _, g in groups do
			for _, a in g.animals do
				step(a, t, dt, parts, cfs)
			end
		end
		for _, a in near do
			step(a, t, dt, parts, cfs)
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
	while true do
		check()
		nearCheck()
		task.wait(CHECK)
	end
end

return WildlifeController
