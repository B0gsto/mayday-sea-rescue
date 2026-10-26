--!strict
-- Gannet Rock (docs/21 §2.2, island 6): a bare guano-streaked stack crowned by a red-and-white lighthouse you climb.
-- Islands/init.luau calls place(base, island) with the WorldConfig.Islands row once the terrain is in.
--   * a timber landing stage from the dock (deep water) to a rock ledge at the landing;
--   * 77 granite steps cut into the west face (the terrain is carved above each tread), railed on the drop side,
--     past the stamp post's ledge, up to a walled whitewashed yard on the summit;
--   * the light (Lighthouse.luau): spiral stair inside, lantern gallery with bench and telescope (the viewpoint);
--   * the keeper's cottage (the cottage kit with its lights and chimney smoke), a gannet colony on the ledges
--     with guano splashes, gannets wheeling round the rock, surf bursting at the foot, a bell buoy off the reef.
-- The stair line was planned on the baked heightmap (tools/world/gen_terrain.py bake_island): one stud up per tread,
-- about 1.6 along, following the slope so the cut stays shallow. Re-plan it if the GannetRock polygon changes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig")) :: any
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks")) :: any
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig")) :: any
local World = script.Parent.Parent
local AssetLoader = require(World.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader")) :: any
local CottageRig = require(World:WaitForChild("CottageRig")) :: any
local Kit = require(script:WaitForChild("Kit"))
local Lighthouse = require(script:WaitForChild("Lighthouse"))

local M = {}

local STEP0_Y = 6 -- the first tread; one stud up per tread
local YARD_Y = 82 -- the summit yard, the top tread's height
local YARD_CENTRE = Vector3.new(3520, YARD_Y, 3488)
local DECK_Y = 4.2 -- the landing stage, above the swell
-- every 4th tread of the planned stair (x, z), the last one at the yard rim
local PATH = {
	{ 3416.0, 3462.0 },
	{ 3417.2, 3468.2 },
	{ 3421.8, 3471.9 },
	{ 3426.0, 3476.7 },
	{ 3430.1, 3481.7 },
	{ 3434.1, 3484.4 },
	{ 3438.3, 3479.5 },
	{ 3443.0, 3475.3 },
	{ 3448.8, 3472.5 },
	{ 3454.7, 3470.1 },
	{ 3460.6, 3467.7 },
	{ 3467.0, 3467.2 },
	{ 3473.4, 3466.6 },
	{ 3479.8, 3466.1 },
	{ 3486.1, 3465.5 },
	{ 3491.9, 3463.0 },
	{ 3496.6, 3458.7 },
	{ 3502.9, 3457.6 },
	{ 3509.2, 3457.0 },
	{ 3515.6, 3456.5 },
}

local GRANITE = Color3.fromRGB(112, 110, 104)
local STEP = Color3.fromRGB(150, 146, 136)
local WHITE = Color3.fromRGB(236, 234, 226)
local IRON = Color3.fromRGB(30, 33, 36)
local TIMBER = Color3.fromRGB(116, 88, 62)
local PILE = Color3.fromRGB(70, 58, 46)
local GUANO = Color3.fromRGB(242, 240, 230)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
terrainOnly.IgnoreWater = true

local function groundY(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), terrainOnly)
	return if hit then hit.Position.Y else fallback
end

local function carve(cf: CFrame, size: Vector3)
	Workspace.Terrain:FillBlock(cf, size, Enum.Material.Air)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function asset(name: string, cf: CFrame, parent: Instance, scale: number?): Model?
	local m = AssetLoader.cloneStatic(name, "LOD0", true)
	if not m then
		warn(`[GannetRock] {name} did not load`)
		return nil
	end
	m:PivotTo(cf)
	if scale then
		m:ScaleTo(scale)
	end
	m.Parent = parent
	return m
end

-- the rock stair: tread k (0..76) at y = STEP0_Y + k, walked between the PATH points
type Tread = { pos: Vector3, dir: Vector3, ground: number }
local function treads(): { Tread }
	local out = {}
	local last = #PATH
	for k = 0, (last - 1) * 4 do
		local i = math.min(k // 4 + 1, last - 1)
		local a = Vector3.new(PATH[i][1], 0, PATH[i][2])
		local b = Vector3.new(PATH[i + 1][1], 0, PATH[i + 1][2])
		local t = (k - (i - 1) * 4) / 4
		local p = a:Lerp(b, t)
		table.insert(out, {
			pos = Vector3.new(p.X, STEP0_Y + k, p.Z),
			dir = (b - a).Unit,
			ground = groundY(p.X, p.Z, STEP0_Y + k - 2),
		})
	end
	return out
end

local function stair(m: Model, list: { Tread })
	for _, s in list do -- carve first: the treads are measured on the uncut rock
		carve(Kit.facing(s.pos + Vector3.new(0, 4.6, 0), s.dir), Vector3.new(2.6, 9, 6.6))
	end
	local prevTop: Vector3? = nil
	for k, s in list do
		local turn = k > 1 and k < #list and list[k - 1].dir:Dot(list[k + 1].dir) < 0.75
		local h = math.clamp(s.pos.Y - s.ground + 2.5, 1.6, 18)
		local size = if turn then Vector3.new(6.4, h, 6.4) else Vector3.new(2.2, h, 5)
		Kit.part(
			m,
			`Tread{k}`,
			size,
			Kit.facing(s.pos - Vector3.new(0, h / 2, 0), s.dir),
			STEP,
			Enum.Material.Granite
		)
		if (k - 1) % 4 == 0 then
			if s.ground < s.pos.Y + 0.5 then -- an iron stanchion on the drop side where the tread is not cut in deep
				local side = Vector3.new(-s.dir.Z, 0, s.dir.X)
				local l = groundY(s.pos.X + side.X * 6, s.pos.Z + side.Z * 6, 0)
				local r = groundY(s.pos.X - side.X * 6, s.pos.Z - side.Z * 6, 0)
				local p = s.pos + side * (if l < r then 2.3 else -2.3)
				Kit.part(
					m,
					"Stanchion",
					Vector3.new(0.3, 3.4, 0.3),
					CFrame.new(p + Vector3.new(0, 1.7, 0)),
					IRON,
					Enum.Material.Metal
				)
				local top = p + Vector3.new(0, 3.3, 0)
				if prevTop and (prevTop - top).Magnitude < 9 then
					Kit.beam(m, "HandRail", prevTop, top, 0.22, IRON, Enum.Material.Metal)
				end
				prevTop = top
			else
				prevTop = nil
			end
		end
	end
end

-- the landing stage: plank deck on piles from the dock out in deep water to a granite ledge at the landing
local function landing(m: Model, island: any, firstTread: Vector3)
	local dock = flat(island.dock)
	local land = flat(island.landing)
	local ledgeTop = STEP0_Y - 1
	local ledge = land + (land - dock).Unit * 1.5
	Kit.part(
		m,
		"LandingLedge",
		Vector3.new(11, 9, 10),
		Kit.facing(Vector3.new(ledge.X, ledgeTop - 4.5, ledge.Z), firstTread - ledge),
		GRANITE,
		Enum.Material.Granite
	)
	carve(CFrame.new(ledge.X, ledgeTop + 5, ledge.Z), Vector3.new(12, 10, 12))
	local u = (land - dock).Unit
	local side = Vector3.new(-u.Z, 0, u.X)
	local length = (land - dock).Magnitude - 4
	local deck = Instance.new("Model")
	deck.Name = "LandingStage"
	deck.Parent = m
	local head = 12 -- the wide stage at the seaward end
	for along = 0, length - 0.01, 12 do
		local len = math.min(12, length - along)
		local width = if along < head then 12 else 7
		for b = 0, math.floor(width) - 1 do
			local off = -width / 2 + 0.5 + b
			local c = dock + u * (along + len / 2) + side * off
			local tone = 0.92 + 0.08 * math.noise(b * 0.7, along * 0.13)
			Kit.part(
				deck,
				"Board",
				Vector3.new(len - 0.05, 0.4, 0.92),
				Kit.facing(Vector3.new(c.X, DECK_Y - 0.2, c.Z), u),
				Color3.new(TIMBER.R * tone, TIMBER.G * tone, TIMBER.B * tone),
				Enum.Material.Wood
			)
		end
	end
	for along = 0, length, 6 do
		local width = if along < head - 0.01 then 12 else 7
		local beamC = dock + u * along
		Kit.part(
			deck,
			"Headstock",
			Vector3.new(0.9, 0.8, width + 0.6),
			Kit.facing(Vector3.new(beamC.X, DECK_Y - 0.8, beamC.Z), u),
			PILE,
			Enum.Material.Wood
		)
		for _, s in { -1, 1 } do
			local p = beamC + side * (s * (width / 2 + 0.1))
			local bed = groundY(p.X, p.Z, -20)
			Kit.cyl(
				deck,
				"Pile",
				p,
				0.5,
				bed - 1,
				DECK_Y + (if along < head - 0.01 then 1.2 else -0.4),
				PILE,
				Enum.Material.Wood
			)
		end
	end
	for _, s in { -1, 1 } do -- kerbs along the narrow walk
		local a = dock + u * head + side * (s * 3.3)
		local b = dock + u * length + side * (s * 3.3)
		Kit.beam(
			deck,
			"Kerb",
			Vector3.new(a.X, DECK_Y + 0.25, a.Z),
			Vector3.new(b.X, DECK_Y + 0.25, b.Z),
			0.5,
			PILE,
			Enum.Material.Wood
		)
	end
	-- dressing on the stage
	local function on(along: number, off: number, yaw: number): CFrame
		local p = dock + u * along + side * off
		return CFrame.lookAt(Vector3.new(p.X, DECK_Y, p.Z), Vector3.new(p.X, DECK_Y, p.Z) + u)
			* CFrame.Angles(0, yaw, 0)
	end
	asset("M_Hbr_Bollard_01", on(1.5, -4.8, 0), deck)
	asset("M_Hbr_Bollard_01", on(1.5, 4.8, 0), deck)
	asset("M_Hbr_Bollard_02", on(12.5, -5, 0), deck)
	asset("M_Hbr_Ladder", on(-0.3, 0, 0), deck)
	asset("M_Hbr_LifebuoyStation", on(16, 3.0, -math.pi / 2), deck)
	asset("M_Hbr_LobsterPot_01", on(9, 4.2, 0.4), deck)
	asset("M_Hbr_LobsterPot_02", on(10.4, 4.6, 1.3), deck)
	asset("M_Hbr_Rope_Coil", on(6, -4.3, 0), deck)
	asset("M_Hbr_FishBox_01", on(10, -3.8, 0.2), deck)
	for _, off in { -3, 3 } do
		local p = dock + side * off - u * 0.15
		asset(
			"M_Hbr_Fender_Tyre",
			CFrame.lookAt(
				Vector3.new(p.X, DECK_Y - 4.3, p.Z),
				Vector3.new(p.X, DECK_Y - 4.3, p.Z) - u
			),
			deck
		)
	end
	-- a lamp post at the stage head
	local lp = dock + u * 3 + side * 5.2
	Kit.cyl(deck, "LampPost", lp, 0.22, DECK_Y, DECK_Y + 9, IRON, Enum.Material.Metal)
	local lantern = Kit.part(
		deck,
		"Lantern",
		Vector3.new(1, 1.3, 1),
		CFrame.new(lp.X, DECK_Y + 9.6, lp.Z),
		Color3.fromRGB(255, 226, 170),
		Enum.Material.Neon
	)
	Kit.part(
		deck,
		"LanternCap",
		Vector3.new(1.4, 0.3, 1.4),
		CFrame.new(lp.X, DECK_Y + 10.4, lp.Z),
		IRON,
		Enum.Material.Metal
	)
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = lantern
end

-- the summit yard: a granite drum flush with the top tread, whitewashed wall with a gap where the stair comes in
local function yard(m: Model, entry: Vector3): number
	local r = (flat(entry) - flat(YARD_CENTRE)).Magnitude - 0.4
	Workspace.Terrain:FillCylinder(
		CFrame.new(YARD_CENTRE + Vector3.new(0, 14, 0)),
		28,
		r + 2.5,
		Enum.Material.Air
	)
	Kit.cyl(m, "Yard", YARD_CENTRE, r, YARD_Y - 22, YARD_Y, GRANITE, Enum.Material.Granite)
	Kit.cyl(
		m,
		"Flags",
		YARD_CENTRE,
		r - 1.4,
		YARD_Y,
		YARD_Y + 0.12,
		Color3.fromRGB(150, 146, 138),
		Enum.Material.Granite
	)
	local n = 40
	local ea = math.atan2(entry.Z - YARD_CENTRE.Z, entry.X - YARD_CENTRE.X)
	local function gap(i: number): boolean
		local a = i * 2 * math.pi / n
		return math.abs(math.atan2(math.sin(a - ea), math.cos(a - ea))) < 0.2
	end
	Kit.ring(
		m,
		"YardWall",
		YARD_CENTRE,
		n,
		r - 1.2,
		r,
		YARD_Y,
		YARD_Y + 3.2,
		WHITE,
		Enum.Material.Plaster,
		0,
		gap
	)
	Kit.ring(
		m,
		"Coping",
		YARD_CENTRE,
		n,
		r - 1.4,
		r + 0.2,
		YARD_Y + 3.2,
		YARD_Y + 3.6,
		Color3.fromRGB(176, 172, 162),
		Enum.Material.Granite,
		0,
		gap
	)
	return r
end

local function keeperCottage(m: Model, at: Vector3, face: Vector3)
	local shell = asset("M_Bld_Cottage_02", CFrame.lookAt(at, at + face), m, 0.65)
	if shell then
		shell.Name = "KeepersCottage"
		local ok, err = pcall(CottageRig.apply, shell)
		if not ok then
			warn(`[GannetRock] cottage rig: {err}`)
		end
	end
end

local function stampPost(m: Model, island: any, list: { Tread })
	local s = island.stamp
	local best = list[1]
	for _, t in list do
		if (flat(t.pos) - flat(s)).Magnitude < (flat(best.pos) - flat(s)).Magnitude then
			best = t
		end
	end
	local y = best.pos.Y
	local bottom = math.min(groundY(s.X, s.Z, y), y) - 3
	carve(CFrame.new(s.X, y + 5, s.Z), Vector3.new(7, 10, 7))
	Kit.part(
		m,
		"StampLedge",
		Vector3.new(7, y - bottom, 7),
		CFrame.new(s.X, (y + bottom) / 2, s.Z),
		STEP,
		Enum.Material.Granite
	)
	local post = Instance.new("Model")
	post.Name = "StampPost"
	post:SetAttribute("IslandId", island.id)
	Kit.part(
		post,
		"Post",
		Vector3.new(0.7, 4, 0.7),
		CFrame.new(s.X, y + 2, s.Z),
		Color3.fromRGB(96, 72, 50),
		Enum.Material.Wood
	)
	Kit.part(
		post,
		"Box",
		Vector3.new(1.8, 1.4, 1.4),
		CFrame.new(s.X, y + 4.5, s.Z),
		Color3.fromRGB(176, 38, 34),
		Enum.Material.Metal
	)
	Kit.part(
		post,
		"Lid",
		Vector3.new(2.1, 0.25, 1.7),
		CFrame.new(s.X, y + 5.3, s.Z),
		IRON,
		Enum.Material.Metal
	)
	post.PrimaryPart = post:FindFirstChild("Post") :: BasePart
	CollectionService:AddTag(post, "StampPost")
	post.Parent = m
end

local GANNET = {
	Body = Color3.fromRGB(246, 246, 242),
	Belly = Color3.fromRGB(252, 252, 250),
	Head = Color3.fromRGB(236, 212, 150), -- the buff-yellow head
	Beak = Color3.fromRGB(164, 176, 186),
	Wing = Color3.fromRGB(240, 240, 236),
	Tail = Color3.fromRGB(34, 34, 38), -- black wingtips crossed over the tail
	Foot = Color3.fromRGB(60, 66, 70),
	Leg = Color3.fromRGB(60, 66, 70),
}

local function perched(parent: Instance, cf: CFrame)
	local bird = WildlifeRig.build("Gull", false)
	if not bird then
		return
	end
	bird.Name = "Gannet"
	WildlifeRig.scale(bird, 1.2)
	for _, p in bird:GetDescendants() do
		local c = GANNET[p.Name]
		if c and p:IsA("BasePart") then
			p.Color = c
		end
	end
	bird.Parent = parent
	WildlifeRig.setCFrame(bird, cf)
end

-- the colony: gannets on the flatter ledges of the faces, each with its guano splash and a streak down the rock
local function colony(m: Model, island: any, list: { Tread }, yardR: number): number
	local folder = Instance.new("Model")
	folder.Name = "Colony"
	folder.Parent = m
	local rng = Random.new(3500)
	local c = flat(island.center)
	local n = 0
	for _ = 1, 400 do
		if n >= 30 then
			break
		end
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(25, 80)
		local x, z = c.X + math.cos(a) * r, c.Z + math.sin(a) * r
		local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), terrainOnly)
		local clear = hit ~= nil
			and hit.Position.Y > 10
			and hit.Normal.Y > 0.72
			and hit.Material ~= Enum.Material.Water
		if hit and clear and (flat(hit.Position) - flat(YARD_CENTRE)).Magnitude > yardR + 3 then
			for _, t in list do
				if (t.pos - hit.Position).Magnitude < 9 then
					clear = false
					break
				end
			end
		end
		if hit and clear then
			local p = hit.Position
			local out = flat(p - island.center).Unit
			perched(
				folder,
				CFrame.lookAt(p, p + out) * CFrame.Angles(0, rng:NextNumber(-0.8, 0.8), 0)
			)
			local normal = hit.Normal
			local out2 = if flat(normal).Magnitude > 0.05 then flat(normal) else out
			local down = (out2 - normal * normal:Dot(out2)).Unit -- downhill along the surface
			Kit.part(
				folder,
				"Guano",
				Vector3.new(0.1, 2.6, 2.6),
				CFrame.fromMatrix(p + normal * 0.05, normal, down),
				GUANO,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			).CanCollide =
				false
			local streak = Kit.part(
				folder,
				"Streak",
				Vector3.new(rng:NextNumber(4, 9), 0.08, rng:NextNumber(0.6, 1.2)),
				CFrame.fromMatrix(p + down * 3 + normal * 0.06, down, normal),
				GUANO,
				Enum.Material.SmoothPlastic
			)
			streak.CanCollide = false
			streak.Transparency = 0.12
			n += 1
		end
	end
	-- a few on the yard wall coping
	for i = 0, 5 do
		local a = 0.6 + i * 0.9
		local p = YARD_CENTRE + Kit.dir(a) * (yardR - 0.6) + Vector3.new(0, 3.6, 0)
		perched(folder, CFrame.lookAt(p, p + Kit.dir(a)))
		n += 1
	end
	return n
end

-- a gannet in flight: white body, buff head, long black-tipped wings, faces -Z
local function flyer(parent: Instance, cf: CFrame): { Part }
	local parts = {}
	local function add(
		name: string,
		size: Vector3,
		off: CFrame,
		color: Color3,
		shape: Enum.PartType?
	)
		local p = Kit.part(parent, name, size, cf * off, color, Enum.Material.SmoothPlastic, shape)
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		table.insert(parts, p)
	end
	add("Body", Vector3.new(0.9, 0.85, 2.8), CFrame.new(), GANNET.Body)
	add(
		"Head",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(0, 0.15, -1.6),
		GANNET.Head,
		Enum.PartType.Ball
	)
	add("Beak", Vector3.new(0.22, 0.22, 0.9), CFrame.new(0, 0.1, -2.3), GANNET.Beak)
	add("Tail", Vector3.new(0.5, 0.12, 1.1), CFrame.new(0, 0.1, 1.8), GANNET.Body)
	for _, s in { -1, 1 } do
		add(
			"Wing",
			Vector3.new(3.2, 0.12, 0.95),
			CFrame.new(s * 1.9, 0.25, -0.1) * CFrame.Angles(0, 0, s * 0.12),
			GANNET.Wing
		)
		add(
			"WingTip",
			Vector3.new(1.4, 0.1, 0.7),
			CFrame.new(s * 4.1, 0.5, 0.05) * CFrame.Angles(0, s * 0.15, s * 0.12),
			GANNET.Tail
		)
	end
	return parts
end

-- gannets wheeling round the rock: birds welded to an unanchored arm that a hinge motor turns about a fixed hub
-- (one physics assembly per ring instead of a per-frame server loop)
local function wheel(m: Model, centre: Vector3, y: number, speed: number, birds: { { number } })
	local hub = Kit.part(
		m,
		"WheelHub",
		Vector3.new(1, 1, 1),
		CFrame.new(centre.X, y, centre.Z),
		WHITE,
		Enum.Material.SmoothPlastic
	)
	hub.Transparency = 1
	hub.CanCollide = false
	hub.CanQuery = false
	local arm = Kit.part(
		m,
		"WheelArm",
		Vector3.new(1, 1, 1),
		hub.CFrame,
		WHITE,
		Enum.Material.SmoothPlastic
	)
	arm.Transparency = 1
	arm.CanCollide = false
	arm.CanQuery = false
	local axis = CFrame.Angles(0, 0, math.pi / 2) -- the hinge axis (attachment X) points up
	local a0 = Instance.new("Attachment")
	a0.CFrame = axis
	a0.Parent = hub
	local a1 = Instance.new("Attachment")
	a1.CFrame = axis
	a1.Parent = arm
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = speed
	hinge.MotorMaxTorque = math.huge
	hinge.MotorMaxAcceleration = math.huge
	hinge.Parent = arm
	local sign = if speed > 0 then 1 else -1
	for _, b in birds do -- { angle, radius, height offset, bank }
		local a, r = b[1], b[2]
		local p = Vector3.new(centre.X, y + b[3], centre.Z) + Kit.dir(a) * r
		local heading = Kit.dir(a - sign * math.pi / 2) -- a +Y motor turns +X towards -Z
		local cf = CFrame.lookAt(p, p + heading) * CFrame.Angles(0, 0, sign * b[4])
		for _, part in flyer(m, cf) do
			local w = Instance.new("WeldConstraint")
			w.Part0 = arm
			w.Part1 = part
			w.Parent = part
			part.Anchored = false
		end
	end
	arm.Anchored = false
	pcall(function()
		arm:SetNetworkOwner(nil)
	end)
end

-- surf bursting where the swell meets the foot of the rock, and foam spreading on the water
local function surf(m: Model, island: any)
	local holder = Kit.part(
		m,
		"Surf",
		Vector3.new(1, 1, 1),
		CFrame.new(island.center),
		WHITE,
		Enum.Material.SmoothPlastic
	)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	local c = flat(island.center)
	local land = flat(island.landing)
	local n = 0
	for i = 0, 17 do
		local a = i * math.pi / 9 + 0.1
		local from = c + Kit.dir(a) * 220 + Vector3.new(0, 0.8, 0)
		local hit = Workspace:Raycast(from, (c + Vector3.new(0, 0.8, 0) - from), terrainOnly)
		if hit and (flat(hit.Position) - land).Magnitude > 22 then
			local att = Instance.new("Attachment")
			att.Name = "Surf"
			att.Parent = holder -- WorldPosition needs the parent first
			att.WorldPosition = Vector3.new(hit.Position.X, 0.4, hit.Position.Z) + Kit.dir(a) * 2
			local burst = Instance.new("ParticleEmitter")
			burst.Name = "Burst"
			Flipbooks.apply(burst, "FX_Spray_SlamBurst")
			burst.Rate = 0.45
			burst.Lifetime = NumberRange.new(1.6, 2.4)
			burst.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 5),
				NumberSequenceKeypoint.new(0.4, 13),
				NumberSequenceKeypoint.new(1, 18),
			})
			burst.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.6, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			burst.Speed = NumberRange.new(9, 17)
			burst.SpreadAngle = Vector2.new(22, 22)
			burst.Acceleration = Vector3.new(0, -16, 0)
			burst.Drag = 0.8
			burst.Rotation = NumberRange.new(0, 360)
			burst.RotSpeed = NumberRange.new(-20, 20)
			burst.Color = ColorSequence.new(Color3.fromRGB(246, 250, 252))
			burst.Parent = att
			local foam = Instance.new("ParticleEmitter")
			foam.Name = "Foam"
			Flipbooks.apply(foam, "FX_Foam_Swash")
			foam.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			foam.EmissionDirection = Enum.NormalId.Top
			foam.Rate = 0.5
			foam.Lifetime = NumberRange.new(5, 7)
			foam.Speed = NumberRange.new(0.2, 0.4)
			foam.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 8),
				NumberSequenceKeypoint.new(1, 18),
			})
			foam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			})
			foam.Rotation = NumberRange.new(0, 360)
			foam.Color = ColorSequence.new(Color3.fromRGB(240, 246, 248))
			foam.Parent = att
			n += 1
		end
	end
	return n
end

local function sound(parent: BasePart, clip: any, maxDistance: number)
	if not clip then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = clip.id
	s.Volume = clip.volume
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 25
	s.RollOffMaxDistance = maxDistance
	s.Parent = parent
	s:Play()
end

function M.place(base: Instance, island: any)
	local m = Instance.new("Model")
	m.Name = "GannetRock"
	m:SetAttribute("IslandId", island.id)
	m.Parent = base
	local list = treads()
	stair(m, list)
	landing(m, island, list[1].pos)
	stampPost(m, island, list)
	local yardR = yard(m, list[#list].pos)

	local light = flat(island.landmark)
	local entry = flat(list[#list].pos)
	local doorAngle = math.atan2(entry.Z - light.Z, entry.X - light.X)
	local home = math.atan2(-light.Z, -light.X) -- the gallery looks home, to the ring of islands
	local lighthouse, galleryY =
		Lighthouse.build(m, Vector3.new(light.X, YARD_Y, light.Z), doorAngle, home)
	m:SetAttribute("GalleryY", galleryY)

	keeperCottage(m, Vector3.new(light.X + 21, YARD_Y, light.Z), Vector3.new(-1, 0, 0)) -- east of the tower, facing it
	local birds = colony(m, island, list, yardR)
	wheel(
		m,
		island.center,
		96,
		0.22,
		{ { 0, 62, 0, 0.25 }, { 0.5, 70, 8, 0.25 }, { 2.4, 80, -6, 0.2 }, { 4.1, 66, 14, 0.25 } }
	)
	wheel(
		m,
		island.center,
		70,
		-0.17,
		{ { 1.2, 96, 0, 0.18 }, { 3.3, 104, 10, 0.2 }, { 5.2, 90, -4, 0.18 } }
	)
	local bursts = surf(m, island)

	local bell =
		asset("M_Hbr_NavMark_Bell", CFrame.new(3398, 0, 3606) * CFrame.Angles(0, 0.6, 0), m)
	local clips = AudioConfig.Clips
	local bellPart = bell and bell:FindFirstChildWhichIsA("BasePart", true)
	if bellPart then
		sound(bellPart, clips.Bell_Buoy, 260)
	end
	local surfPart = m:FindFirstChild("Surf") :: BasePart?
	if surfPart then
		sound(surfPart, clips.Wave_OpenSwell, 240)
	end
	local yardPart = m:FindFirstChild("Yard") :: BasePart?
	if yardPart then
		sound(yardPart, clips.Gull_Flock, 200)
	end

	local parts = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	m:SetAttribute("Parts", parts)
	m:SetAttribute("Placed", true)
	print(
		`[GannetRock] {#list} treads, {birds} gannets, {bursts} surf spots, {parts} parts ({lighthouse.Name})`
	)
end

return M
