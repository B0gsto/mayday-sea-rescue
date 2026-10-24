--!strict
-- AmbientController (RP-NPC1, docs/14 section 5): a living Port Haven, drawn on this client only (not replicated,
-- not streamed). Plan and rules: Shared/Ambient/AmbientPlan.
--   * people: residents at their doors, fishermen on the quay, shoppers in the Chandlery, families on Haven Sands,
--     tourists at the Harbour Light (static spots, stock Roblox idle / wave), plus walkers and dog walkers
--     on the pavements (stock R15 walk, played at the ground speed); traffic on the road lanes (the parked-car
--     meshes from ReplicatedStorage.TrafficTemplates, wheels turning; part cars until those load; headlamps at night).
--   * only near the player (AmbientPlan.CAPS[tier].radius), capped per quality tier (same tier pick as
--     ScatterController: the "scatterQuality" override, else SavedQualityLevel; touch-only devices max medium).
--   * routines: AmbientPlan.routine(Weather state, night) thins the street, empties the beach and the quay in storms.
--   * rigs: clones of ReplicatedStorage.AmbientNpcTemplates (R15 Models built by the server with NpcFactory, attribute
--     NpcRole) when that folder exists; else a block-person greybox. Every part is anchored at the root, CanCollide /
--     CanTouch / CanQuery off, so nobody blocks a road, the slipway or a ladder. Car bodies and cabins do collide
--     (locally: the player and the car they drive bump into them); a car waits for the player in its lane ahead.
-- Workspace.AmbientLocal attributes: AmbientTier, AmbientPeople, AmbientCars.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local NpcOutfits = require(Shared:WaitForChild("Config"):WaitForChild("NpcOutfits"))
local Plan = require(Shared:WaitForChild("Ambient"):WaitForChild("AmbientPlan"))
local RoadNet = require(Shared:WaitForChild("RoadNet"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))
local junctions = RoadNet.junctions(WorldConfig.Roads)
local Weather = require(Shared:WaitForChild("Weather"))

local AmbientController = {}

local TICK = 0.5
local SPAWNS_PER_TICK = 2
local TEMPLATES = "AmbientNpcTemplates"
-- stock Roblox R15 animations (the default Animate script's ids)
local ANIM = {
	Idle = "rbxassetid://507766666",
	Wave = "rbxassetid://507770239",
	Sit = "rbxassetid://2506281703",
	Walk = "rbxassetid://507777826",
}
local WALK_SPEED, CAR_SPEED = 6, 26 -- studs/s (tune)
local WALKER_GAP = 6 -- studs between a new walker and anyone already out (docs/22: two spawned inside each other)
local BRAKE = 14 -- studs/s^2: 26 studs/s stops in 24 studs, inside RoadNet.stopFor's 40 look-ahead
local UTURN = 12 -- studs: a dead-end turn-round starts this far before the road end (stays on the road)
-- the stock walk clip covers 6.4 studs/s at 1x for a HipHeight 2 rig (the default Animate script's walk rate)
local WALK_CLIP_SPEED = 6.4
local CAR_COLORS = { "#2B3A55", "#8C1C13", "#E8E4D8", "#3D5A40", "#5B5F66", "#C9A227", "#1E1E22" }
local DOG_COLORS = { "#6B4A2B", "#1F1B18", "#C99A5B", "#E9E1D2" }
local SHIRT_COLORS = { "#2F4A6D", "#7A2E2E", "#3E5F3A", "#C7B48A", "#4A4A52" }

type Agent = {
	model: Model,
	root: BasePart,
	height: number,
	spot: number?,
	route: Plan.Route?,
	lane: number?,
	join: Plan.Exit?, -- set while a car is on a turn path: the lane it joins at the end
	s: number,
	dir: number,
	speed: number,
	dog: BasePart?,
	groundY: number?,
	wheels: { Weld }?, -- mesh traffic: wheel welds turned as it rolls
	wheelR: number?,
	spin: number?,
}

local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true

-- shortcut: the same tier rule as ScatterController.pickTier (a local there), move it to a shared helper if a third
-- controller needs it
local function pickTier(): string
	local override = Comfort.get("scatterQuality")
	if override == "High" or override == "Medium" or override == "Low" then
		return string.lower(override)
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	local n = if ok and type(level) == "number" then level else 0
	local name = if n == 0
		then "medium"
		elseif n <= 3 then "low"
		elseif n <= 7 then "medium"
		else "high"
	if
		UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and name == "high"
	then
		name = "medium"
	end
	return name
end

local function isNight(): boolean
	return Lighting:GetAttribute("WeatherBase") == "Night" or Lighting:GetSunDirection().Y < -0.05
end

-- ground under p (searching `up` studs above), nil over the sea or when the ground has not streamed in
local function ground(p: Vector3, up: number): Vector3?
	local hit = Workspace:Raycast(p + Vector3.new(0, up, 0), Vector3.new(0, -up - 40, 0), rayParams)
	if hit and hit.Position.Y > 0.3 then
		return hit.Position
	end
	return nil
end

local animations: { [string]: Animation } = {}
local function play(model: Model, name: string, speed: number?)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local id = (ANIM :: any)[name]
	if not (hum and id) then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local made = Instance.new("Animator")
		made.Parent = hum
		animator = made
	end
	local anim = animations[name]
	if not anim then
		local made = Instance.new("Animation")
		made.AnimationId = id
		animations[name] = made
		anim = made
	end
	pcall(function()
		local track = (animator :: Animator):LoadAnimation(anim)
		track.Looped = true
		track:Play(0.2)
		if speed then
			track:AdjustSpeed(speed)
		end
	end)
end

local function weld(root: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, p
	w.Parent = p
end

local function box(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- the block-person fallback (as NpcFactory.greybox), feet at y 0
local function greybox(role: string, seed: number): Model
	local outfit = NpcOutfits.pick(role, seed, false)
	local skin = Color3.fromHex(outfit.skin or NpcOutfits.SKIN_TONES[2])
	local shirt = Color3.fromHex(SHIRT_COLORS[seed % #SHIRT_COLORS + 1])
	local m = Instance.new("Model")
	local root = box(m, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), skin)
	root.Transparency = 1
	box(m, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.8, 0), shirt)
	box(m, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 5.4, 0), skin)
	for side = -1, 1, 2 do
		box(
			m,
			"Leg",
			Vector3.new(0.8, 2.8, 0.8),
			CFrame.new(side * 0.5, 1.4, 0),
			Color3.fromRGB(35, 35, 45)
		)
		box(m, "Arm", Vector3.new(0.6, 2, 0.6), CFrame.new(side * 1.3, 3.8, 0), skin)
	end
	m.PrimaryPart = root
	return m
end

local function person(role: string, seed: number, kid: boolean?): Agent?
	local m: Model? = nil
	local templates = ReplicatedStorage:FindFirstChild(TEMPLATES)
	if templates then
		local list = {}
		for _, t in templates:GetChildren() do
			if t:IsA("Model") and t:GetAttribute("NpcRole") == role then
				table.insert(list, t)
			end
		end
		if #list > 0 then
			m = list[seed % #list + 1]:Clone()
		end
	end
	local model = m or greybox(role, seed)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	model:PivotTo(CFrame.new(0, 1000, 0))
	if kid then
		model:ScaleTo(0.65)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			d.Anchored = d == root
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	if m == nil then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p ~= root then
				weld(root, p)
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	local height = root.Position.Y - (cf.Y - size.Y / 2)
	model.Name = role
	model.Parent = folder
	return { model = model, root = root, height = height, s = 0, dir = 1, speed = 0 }
end

-- a simple few-part dog (body anchored, the rest welded) on a rope leash to the owner
local function dog(owner: Agent, seed: number): BasePart
	local m = Instance.new("Model")
	m.Name = "Dog"
	local c = Color3.fromHex(DOG_COLORS[seed % #DOG_COLORS + 1])
	local body = box(m, "Body", Vector3.new(1.1, 1, 2.4), CFrame.new(0, 1.4, 0), c)
	local head = box(m, "Head", Vector3.new(0.9, 0.9, 1), CFrame.new(0, 2.1, -1.5), c)
	box(m, "Snout", Vector3.new(0.5, 0.4, 0.6), CFrame.new(0, 1.9, -2.2), c)
	box(
		m,
		"Tail",
		Vector3.new(0.2, 0.2, 0.9),
		CFrame.new(0, 1.9, 1.5) * CFrame.Angles(0.6, 0, 0),
		c
	)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			box(m, "Leg", Vector3.new(0.3, 0.9, 0.3), CFrame.new(x * 0.35, 0.45, z * 0.85), c)
		end
	end
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.Anchored = p == body
			if p ~= body then
				weld(body, p)
			end
		end
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = head
	local hand = owner.model:FindFirstChild("RightHand")
	a1.Parent = if hand and hand:IsA("BasePart") then hand else owner.root
	local leash = Instance.new("RopeConstraint")
	leash.Attachment0, leash.Attachment1 = a0, a1
	leash.Length, leash.Visible, leash.Thickness = 5, true, 0.08
	leash.Color = BrickColor.new("Really red")
	leash.Parent = body
	m.PrimaryPart = body
	m.Parent = owner.model
	return body
end

-- a parked-car mesh from ReplicatedStorage.TrafficTemplates (TrafficArtService), nil until one is fully replicated.
-- The pivot (bottom centre, forward -Z) is an invisible anchored Root; the _COL hull (body and cabin) is the only
-- solid part; wheels hang on Welds that the Heartbeat turns. The paint is baked into the mesh: no CAR_COLORS tint.
local function meshCar(seed: number): Agent?
	local f = ReplicatedStorage:FindFirstChild("TrafficTemplates")
	local list = if f then f:GetChildren() else {}
	local t = list[seed % math.max(1, #list) + 1]
	if not (t and t:IsA("Model")) then
		return nil
	end
	local n = 0
	for _, d in t:GetDescendants() do
		n += if d:IsA("BasePart") then 1 else 0
	end
	if n < ((t:GetAttribute("Parts") :: number?) or 1) then
		return nil
	end
	local m = t:Clone()
	m.Name = "Car"
	local root: BasePart = Instance.new("Part")
	root.Name = "Root"
	root.Size, root.CFrame, root.Transparency = Vector3.one, m:GetPivot(), 1
	root.CanCollide, root.CanTouch, root.CanQuery, root.Anchored = false, false, false, true
	root.Parent = m
	local wheels = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			local solid = p:HasTag("AssetCollision")
			p.CanCollide, p.CanTouch, p.CanQuery = solid, false, solid
			p.Anchored = false
			if string.find(p.Name, "_Wheel", 1, true) then
				local hub = CFrame.new(root.CFrame:PointToObjectSpace(p.Position)) -- the tyre's box centre is the hub
				local w = Instance.new("Weld")
				w.Part0, w.Part1, w.C0, w.C1 =
					root, p, hub, p.CFrame:ToObjectSpace(root.CFrame * hub)
				w.Parent = p
				table.insert(wheels, w)
			else
				weld(root, p)
			end
		end
	end
	local _, size = m:GetBoundingBox()
	for x = -1, 1, 2 do -- unseen lamp holders for the night beams (the lenses are in the mesh)
		local head = box(
			m,
			"Headlamp",
			Vector3.new(0.6, 0.4, 0.2),
			root.CFrame * CFrame.new(x * size.X * 0.32, 2.2, -size.Z / 2),
			Color3.new(1, 1, 0.9)
		)
		head.Transparency, head.CanCollide, head.CanTouch, head.CanQuery = 1, false, false, false
		local light = Instance.new("SpotLight")
		light.Face, light.Range, light.Angle, light.Brightness = Enum.NormalId.Front, 40, 60, 2
		light.Parent = head
		weld(root, head)
	end
	m.PrimaryPart = root
	m.Parent = folder
	local r = if #wheels > 0 then wheels[1].C0.Y else 1
	return {
		model = m,
		root = root,
		height = 0,
		s = 0,
		dir = 1,
		speed = CAR_SPEED,
		wheels = wheels,
		wheelR = r,
		spin = 0,
	}
end

local function car(seed: number): Agent
	local mesh = meshCar(seed)
	if mesh then
		return mesh
	end
	local m = Instance.new("Model")
	m.Name = "Car"
	local paint = Color3.fromHex(CAR_COLORS[seed % #CAR_COLORS + 1])
	local body = box(m, "Body", Vector3.new(6.2, 2.2, 13.5), CFrame.new(0, 2.1, 0), paint)
	box(m, "Cabin", Vector3.new(5.8, 2, 7), CFrame.new(0, 4.2, 0.8), Color3.fromRGB(45, 60, 72)).Material =
		Enum.Material.Glass
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local w = box(
				m,
				"Wheel",
				Vector3.new(0.9, 2.4, 2.4),
				CFrame.new(x * 2.75, 1.2, z * 4.4), -- a Cylinder's axis is its local X: already the axle
				Color3.fromRGB(26, 26, 28)
			)
			w.Shape = Enum.PartType.Cylinder
		end
		local head = box(
			m,
			"Headlamp",
			Vector3.new(1.2, 0.6, 0.2),
			CFrame.new(x * 2.2, 2.5, -6.8),
			Color3.new(1, 1, 0.9)
		)
		local light = Instance.new("SpotLight")
		light.Face, light.Range, light.Angle, light.Brightness = Enum.NormalId.Front, 40, 60, 2
		light.Parent = head
		box(
			m,
			"TailLamp",
			Vector3.new(1.2, 0.6, 0.2),
			CFrame.new(x * 2.2, 2.5, 6.8),
			Color3.fromRGB(150, 20, 20)
		)
	end
	-- Body and cabin are solid so the local character and the car this client drives (it owns that car's physics)
	-- bump into them. shortcut: traffic is client-only, so other players' cars and characters pass through it on
	-- this screen and the server never sees it; move traffic to the server if cars must block for everyone.
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local solid = p == body or p.Name == "Cabin"
			p.CanCollide, p.CanTouch, p.CanQuery = solid, false, solid
			p.Anchored = p == body
			if p ~= body then
				weld(body, p)
			end
		end
	end
	m.PrimaryPart = body
	m.Parent = folder
	return { model = m, root = body, height = 2.1, s = 0, dir = 1, speed = CAR_SPEED }
end

local function setLamps(a: Agent, on: boolean)
	for _, p in a.model:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Headlamp" or p.Name == "TailLamp") then
			p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local l = p:FindFirstChildOfClass("SpotLight")
			if l then
				l.Enabled = on
			end
		end
	end
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- a random point of `routes` between minD and maxD of `center`, nil if none
local function pickOnRoutes(
	routes: { Plan.Route },
	center: Vector3,
	minD: number,
	maxD: number
): (number?, number)
	local cands = {}
	for i, r in routes do
		for s = 0, r.length, 12 do
			local d = flatDist((Plan.sample(r, s)), center)
			if d >= minD and d <= maxD then
				table.insert(cands, { i, s })
			end
		end
	end
	if #cands == 0 then
		return nil, 0
	end
	local c = cands[math.random(1, #cands)]
	return c[1], c[2]
end

function AmbientController.Init() end

function AmbientController.Start()
	local f = Instance.new("Folder")
	f.Name = "AmbientLocal"
	f.Parent = Workspace
	folder = f

	local spots = Plan.spots()
	local pavements, lanes = {}, {}
	for _, r in Plan.routes() do
		table.insert(if r.kind == "lane" then lanes else pavements, r)
	end
	local stops = Plan.junctionStops(lanes, junctions)
	local nextLanes = {}
	for i in lanes do
		nextLanes[i] = Plan.nextLane(lanes, i)
	end
	local statics: { [number]: Agent } = {}
	local movers: { Agent } = {}
	local cars: { Agent } = {}
	local tier = pickTier()
	local night = isNight()
	local seed = 0

	local function release(a: Agent)
		a.model:Destroy()
	end

	local function center(): Vector3
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp.Position
		end
		local cam = Workspace.CurrentCamera
		return if cam then cam.Focus.Position else Vector3.zero
	end

	local function think()
		local char = Players.LocalPlayer.Character
		rayParams.FilterDescendantsInstances = if char then { folder, char } else { folder }
		tier = pickTier()
		local nowNight = isNight()
		local cap = Plan.CAPS[tier] or Plan.CAPS.medium
		local share = Plan.routine(Weather.getState(), nowNight)
		local c = center()
		local budget = SPAWNS_PER_TICK

		-- static spots: nearest wanted first, at most 60% of the people cap
		local wanted = {}
		for i, s in spots do
			local d = flatDist(s.pos, c)
			local keep = Plan.keep(i, (share :: any)[s.zone] or 1)
			if keep and (d < cap.radius or (statics[i] and d < cap.radius + 40)) then
				table.insert(wanted, { i = i, d = d })
			end
		end
		table.sort(wanted, function(a, b)
			return a.d < b.d
		end)
		local staticCap = math.ceil(cap.people * 0.6)
		local want: { [number]: boolean } = {}
		for k = 1, math.min(#wanted, staticCap) do
			want[wanted[k].i] = true
		end
		local nStatic = 0
		for i, a in statics do
			if want[i] then
				nStatic += 1
			else
				release(a)
				statics[i] = nil
			end
		end
		for i in want do
			if not statics[i] and budget > 0 then
				local s = spots[i]
				-- indoors: not the upper floor; the beach hint is the waterline height
				local g = ground(
					s.pos,
					if s.zone == "indoor" then 2 elseif s.zone == "beach" then 15 else 6
				)
				if g then
					budget -= 1
					local a = person(s.role, i * 7919, s.kid)
					if a then
						a.spot = i
						a.root.CFrame = CFrame.new(g + Vector3.new(0, a.height, 0))
							* CFrame.Angles(0, s.yaw, 0)
						play(a.model, s.pose)
						statics[i] = a
						nStatic += 1
					end
				end
			end
		end

		-- walkers and dog walkers: drop the farthest beyond the ring or the routine's share
		local moverCap =
			math.min(cap.people - nStatic, math.floor(cap.people * 0.5 * share.street + 0.5))
		table.sort(movers, function(a, b)
			return flatDist(a.root.Position, c) < flatDist(b.root.Position, c)
		end)
		for k = #movers, 1, -1 do
			if k > moverCap or flatDist(movers[k].root.Position, c) > cap.radius + 40 then
				release(table.remove(movers, k) :: Agent)
			end
		end
		while #movers < moverCap and budget > 0 do
			budget -= 1
			-- a pavement point that has no dry ground under it (a sea cliff, a missing tile) is skipped
			local ri, s, g
			for _ = 1, 4 do
				-- walkers spawn from close by: the promenade outside the station is never empty
				ri, s = pickOnRoutes(pavements, c, cap.radius * 0.15, cap.radius)
				if not ri then
					break
				end
				g = ground(Plan.sample(pavements[ri], s), 8)
				-- never inside another person: walkers and static spots both count
				for _, other in movers do
					g = if g and flatDist(other.root.Position, g) > WALKER_GAP then g else nil
				end
				for _, other in statics do
					g = if g and flatDist(other.root.Position, g) > WALKER_GAP then g else nil
				end
				if g then
					break
				end
			end
			if not (ri and g) then
				break
			end
			seed += 1
			local roll = math.random()
			local a = person("Passenger", seed)
			if a then
				a.route, a.s, a.dir = pavements[ri], s, if math.random() < 0.5 then 1 else -1
				a.groundY = g.Y
				a.speed = WALK_SPEED * (0.85 + 0.3 * math.random())
				local hum = a.model:FindFirstChildOfClass("Humanoid")
				local hip = if hum and hum.HipHeight > 0 then hum.HipHeight else 2
				-- stride matches ground speed: no foot sliding (taller rigs step slower)
				play(a.model, "Walk", a.speed / WALK_CLIP_SPEED * 2 / hip)
				-- the first walker on screen always has a dog: the town reads alive at a glance
				if #movers == 0 or roll > 0.8 then
					a.dog = dog(a, seed)
				end
				table.insert(movers, a)
			end
		end

		-- traffic
		local laneStuds = 0
		for _, r in lanes do
			for s = 0, r.length, 12 do
				if flatDist((Plan.sample(r, s)), c) <= cap.radius then
					laneStuds += 12
				end
			end
		end
		local carCap = Plan.carCap(cap, laneStuds, share.cars)
		for k = #cars, 1, -1 do
			if k > carCap or flatDist(cars[k].root.Position, c) > cap.radius + 60 then
				release(table.remove(cars, k) :: Agent)
			end
		end
		for _ = 1, math.min(carCap - #cars, SPAWNS_PER_TICK) do
			local li, s = pickOnRoutes(lanes, c, cap.radius * 0.25, cap.radius)
			local clear = li ~= nil
			if li then
				local p = Plan.sample(lanes[li], s)
				for _, other in cars do
					clear = clear and flatDist(other.root.Position, p) > 40
				end
			end
			if li and clear then
				seed += 1
				local a = car(seed)
				a.lane, a.route, a.s = li, lanes[li], s
				setLamps(a, nowNight)
				table.insert(cars, a)
			end
		end
		if nowNight ~= night then
			night = nowNight
			for _, a in cars do
				setLamps(a, night)
			end
		end

		folder:SetAttribute("AmbientTier", tier)
		folder:SetAttribute("AmbientPeople", nStatic + #movers)
		folder:SetAttribute("AmbientCars", #cars)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		for _, a in movers do
			local r = a.route :: Plan.Route
			a.s += a.dir * a.speed * dt
			if a.s > r.length or a.s < 0 then
				a.dir = -a.dir -- turn back at the end of the pavement
				a.s = math.clamp(a.s, 0, r.length)
			end
			local p, d = Plan.sample(r, a.s)
			local g = ground(p, 8)
			local baseY = if g then g.Y else (a.groundY or p.Y)
			local at = Vector3.new(p.X, baseY, p.Z) + Vector3.new(0, a.height, 0)
			a.root.CFrame = CFrame.lookAt(at, at + d * a.dir)
			if a.dog then
				local bob = math.abs(math.sin(a.s * 1.4)) * 0.15
				-- trailing on the pavement, not out in the road; paws on the ground
				local cf = a.root.CFrame * CFrame.new(0.9, 1.4 - a.height + bob, 1.6)
				local dg = ground(cf.Position, 3)
				if dg then
					cf = CFrame.new(cf.Position.X, dg.Y + 1.4, cf.Position.Z) * cf.Rotation
				end
				a.dog.CFrame = cf
			end
		end
		local hrp = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local hum = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		local reach = if hum and hum.SeatPart then 7 else 5 -- a driven vehicle is wider than a person
		local now = Workspace:GetServerTimeNow()
		for _, a in cars do
			local r = a.route :: Plan.Route
			local p, d = Plan.sample(r, a.s)
			-- wait for the player (on foot or driving) in the lane ahead: the body is solid, it must not shove them
			local target = CAR_SPEED
			if hrp and hrp:IsA("BasePart") then
				local rel = (hrp.Position - p) * Vector3.new(1, 0, 1) -- flat: the lane line sits below the deck and the HRP
				local ahead = rel:Dot(d)
				if ahead > 0 and ahead < 22 and (rel - d * ahead).Magnitude < reach then
					target = 0
				end
			end
			-- stop at a red (or catchable amber) traffic light, and queue behind the car ahead (by position, so it holds
			-- through turns; cars heading across or the other way are not followed)
			local stop = RoadNet.stopFor(junctions, r.road, p, d, now)
			stop = stop and stop - 7 -- the front bumper (half the 13.5 body) on the line, not the middle
			for _, b in cars do
				if b ~= a then
					local rel = b.root.Position - p
					rel = Vector3.new(rel.X, 0, rel.Z)
					local ahead = rel:Dot(d)
					if
						ahead > 0
						and ahead < 40
						and (rel - d * ahead).Magnitude < 4
						and b.root.CFrame.LookVector:Dot(d) > 0.3
					then
						stop = math.min(stop or math.huge, ahead - 17)
					end
				end
			end
			if stop then -- the speed from which BRAKE stops the car on the line
				target = math.min(target, math.sqrt(2 * BRAKE * math.max(0, stop)))
			end
			if target < a.speed then -- hard braking is capped; a late amber is run, as people do
				a.speed = math.max(target, a.speed - 2 * BRAKE * dt)
			else
				a.speed += (target - a.speed) * math.min(1, dt * 2)
			end
			local old = a.s
			a.s += a.speed * dt
			local join = a.join
			if join then
				if a.s >= r.length then -- turn done: on to the new lane
					a.lane, a.route, a.s, a.join =
						join.lane, lanes[join.lane], join.s + a.s - r.length, nil
				end
			else
				local i = a.lane :: number
				local from, exit = nil, nil
				for _, st in stops[i] do
					if old < st.at and a.s >= st.at then -- past the stop line: a random way on, never back
						from, exit = st.at, st.exits[math.random(1, #st.exits)]
						break
					end
				end
				local k = nextLanes[i]
				local u = math.min(UTURN, r.length / 2)
				if not exit and lanes[k].road == r.road and a.s >= r.length - u then
					from, exit = r.length - u, { lane = k, s = u } -- dead end: loop round onto the other lane
				elseif not exit and a.s > r.length then
					a.lane, a.route, a.s = k, lanes[k], a.s - r.length -- the road carries on
				end
				if from and exit then
					local over = a.s - from
					a.route, a.s, a.join = Plan.turn(r, from, lanes[exit.lane], exit.s), over, exit
				end
			end
			r = a.route :: Plan.Route
			p, d = Plan.sample(r, a.s)
			local g = ground(p, 8)
			local lift = if g then g.Y - p.Y else 0
			local front = Plan.sample(r, a.s + 6)
			local at = p + Vector3.new(0, lift + a.height, 0)
			local look = front + Vector3.new(0, lift + a.height, 0)
			if (look - at).Magnitude < 0.1 then
				look = at + d
			end
			a.root.CFrame = CFrame.lookAt(at, look)
			local wheels = a.wheels
			if wheels then
				local spin = ((a.spin :: number) + a.speed * dt / (a.wheelR :: number))
					% (2 * math.pi)
				a.spin = spin
				for _, w in wheels do -- rolling forward (-Z): the tyre top turns toward -Z
					w.C0 = CFrame.new(w.C0.Position) * CFrame.Angles(-spin, 0, 0)
				end
			end
		end
	end)

	while folder.Parent do
		local ok, err = pcall(think :: any)
		if not ok then
			warn(`[Ambient] {err}`)
		end
		task.wait(TICK)
	end
end

return AmbientController
