--!strict
-- StationYard (docs/17 P1 14): the lifeboat station's compound on the south strip of the boatyard block (TownExtras
-- YARD; the boatyard shed stands north of z -92), seen from Station Hill. Tarmac hardstanding inside a galvanised
-- palisade with an open double gate east onto Quay Lane, crew car bays with three crew cars, the launch rig (the
-- coastguard 4x4 hitched to the RIB on its trailer, facing the gate), a yellow keep-clear box at the gate, a fuel
-- bowser with oil drums and a flagpole flying St Piran's flag. Placeholder Parts plus existing vehicle assets
-- (CLAUDE.md); static, no gameplay. WorldDressingService calls StationYard.place(Workspace.Dressing) once.
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))

local StationYard = {}

StationYard.RECT = { x0 = -334, z0 = -90, x1 = -248, z1 = -52 }
StationYard.GATE = { z0 = -74, z1 = -58 } -- east fence opening
local TARMAC = Color3.fromRGB(78, 80, 84)
local GALV = Color3.fromRGB(104, 107, 106) -- dull hot-dip zinc (lighter greys read sky-blue on Metal)
local PAINT_WHITE = Color3.fromRGB(226, 226, 220)
local PAINT_YELLOW = Color3.fromRGB(226, 182, 40)
local LINE_H = 0.06

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }

-- the highest terrain over the rect (the town platform meshes up to 2 studs above LandTopY)
local function groundTop(): number
	local R = StationYard.RECT
	local top = 4
	for i = 0, 6 do
		for j = 0, 4 do
			local x = R.x0 + (R.x1 - R.x0) * i / 6
			local z = R.z0 + (R.z1 - R.z0) * j / 4
			local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -100, 0), params)
			if hit then
				top = math.max(top, hit.Position.Y)
			end
		end
	end
	return top
end

function StationYard.place(base: Instance)
	local R = StationYard.RECT
	local model = Instance.new("Model")
	model.Name = "StationYard"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local y = groundTop() + 0.1 -- the hardstanding's top
	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		colour: Color3,
		mat: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanTouch = false
		p.CanCollide = collide ~= false
		p.CanQuery = collide ~= false
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local function line(name: string, a: Vector3, b: Vector3, w: number, colour: Color3)
		local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local mid = (a + b) / 2
		local p = part(
			name,
			Vector3.new(w, LINE_H, d.Magnitude),
			CFrame.lookAt(
				Vector3.new(mid.X, y + LINE_H / 2, mid.Z),
				Vector3.new(b.X, y + LINE_H / 2, b.Z)
			),
			colour,
			Enum.Material.SmoothPlastic,
			false
		)
		p.CastShadow = false
	end
	local function xz(x: number, z: number): Vector3
		return Vector3.new(x, y, z)
	end

	-- hardstanding: a 3-stud slab so no uneven terrain edge shows under it
	part(
		"Hardstanding",
		Vector3.new(R.x1 - R.x0, 3, R.z1 - R.z0),
		CFrame.new((R.x0 + R.x1) / 2, y - 1.5, (R.z0 + R.z1) / 2),
		TARMAC,
		Enum.Material.Granite
	)

	-- crew bays along the north fence (nose in), 6 wide, 12 deep
	local bayZ0, bayZ1 = R.z0 + 1.5, R.z0 + 13.5
	for k = 0, 7 do
		local x = R.x0 + 2 + 6 * k
		line("BayLine", xz(x, bayZ0), xz(x, bayZ1), 0.25, PAINT_WHITE)
	end
	line("BayFront", xz(R.x0 + 2, bayZ1), xz(R.x0 + 44, bayZ1), 0.25, PAINT_WHITE)

	-- keep-clear box inside the gate: yellow outline and diagonal hatching
	local G = StationYard.GATE
	local hx0, hx1 = R.x1 - 14, R.x1 - 1.5
	for _, e in
		{
			{ xz(hx0, G.z0), xz(hx1, G.z0) },
			{ xz(hx0, G.z1), xz(hx1, G.z1) },
			{ xz(hx0, G.z0), xz(hx0, G.z1) },
			{ xz(hx1, G.z0), xz(hx1, G.z1) },
		}
	do
		line("KeepClear", e[1], e[2], 0.35, PAINT_YELLOW)
	end
	for k = 1, 4 do
		local z = G.z0 + (G.z1 - G.z0) * k / 5
		line("KeepClearHatch", xz(hx0 + 0.6, z - 2.5), xz(hx1 - 0.6, z + 2.5), 0.3, PAINT_YELLOW)
	end

	-- galvanised palisade: posts every 3 studs, two rails, pales every stud; the gate gap on the east side
	local H = 6
	local function fence(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local frame = CFrame.lookAt(a, b)
		for _, ry in { 1.2, H - 0.6 } do
			part(
				"Rail",
				Vector3.new(0.18, 0.3, len),
				frame * CFrame.new(0, ry, -len / 2),
				GALV,
				Enum.Material.Metal
			)
		end
		local posts = math.max(1, math.floor(len / 3 + 0.5))
		for k = 0, posts do
			local d = len * k / posts
			part(
				"Post",
				Vector3.new(0.35, H + 0.3, 0.35),
				frame * CFrame.new(0, (H + 0.3) / 2, -d),
				GALV,
				Enum.Material.Metal
			)
		end
		local pales = math.floor(len)
		for k = 1, pales - 1 do
			local d = len * k / pales
			-- pales stand a little proud of the rails, alternately 0.3 higher (the triple-point tops read at range)
			part(
				"Pale",
				Vector3.new(0.12, H + 0.3 * (k % 2), 0.22),
				frame * CFrame.new(0.15, (H + 0.3 * (k % 2)) / 2, -d),
				GALV,
				Enum.Material.Metal,
				false
			)
		end
	end
	local c00, c10, c11, c01 = xz(R.x0, R.z0), xz(R.x1, R.z0), xz(R.x1, R.z1), xz(R.x0, R.z1)
	fence(c00, c10) -- north
	fence(c01, c00) -- west
	fence(c11, c01) -- south
	fence(c10, xz(R.x1, G.z0)) -- east, north of the gate
	fence(xz(R.x1, G.z1), c11) -- east, south of the gate
	-- the gate leaves stand open, swung in against the hatching
	for _, z in { G.z0 + 0.4, G.z1 - 0.4 } do
		local a, b = xz(R.x1 - 0.4, z), xz(R.x1 - 7.6, z)
		local len = (b - a).Magnitude
		local frame = CFrame.lookAt(a, b)
		for _, ry in { 0.8, 3, H - 0.4 } do
			part(
				"Gate",
				Vector3.new(0.2, 0.25, len),
				frame * CFrame.new(0, ry, -len / 2),
				GALV,
				Enum.Material.Metal
			)
		end
		for k = 0, 7 do
			part(
				"Gate",
				Vector3.new(0.12, H - 0.4, 0.2),
				frame * CFrame.new(0, (H - 0.4) / 2 + 0.4, -len * k / 7),
				GALV,
				Enum.Material.Metal
			)
		end
	end

	-- the flagpole in the north-east corner: white mast, gilt truck, St Piran's flag (white cross on black)
	local fp = xz(R.x1 - 5, R.z0 + 5)
	part(
		"FlagBase",
		Vector3.new(2, 0.6, 2),
		CFrame.new(fp + Vector3.new(0, 0.3, 0)),
		Color3.fromRGB(120, 118, 112),
		Enum.Material.Granite
	)
	local mast = part(
		"FlagMast",
		Vector3.new(26, 0.5, 0.5),
		CFrame.new(fp + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(236, 236, 232),
		Enum.Material.SmoothPlastic
	)
	mast.Shape = Enum.PartType.Cylinder
	local truck = part(
		"FlagTruck",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(fp + Vector3.new(0, 26.3, 0)),
		Color3.fromRGB(212, 170, 60),
		Enum.Material.Metal
	)
	truck.Shape = Enum.PartType.Ball
	do
		-- 7 x 4.5 flag flying west (down the prevailing south-westerly), three panels with a slight wave
		local top = fp + Vector3.new(0, 25.6, 0)
		local fw, fh, n = 7, 4.5, 3
		for k = 1, n do
			local x0 = (k - 1) * fw / n
			local wave = math.sin(k * 1.7) * 0.35
			local frame = CFrame.new(top + Vector3.new(-(x0 + fw / n / 2) - 0.25, -fh / 2, wave))
				* CFrame.Angles(0, (k % 2 - 0.5) * 0.25, 0)
			part(
				"Flag",
				Vector3.new(fw / n + 0.02, fh, 0.05),
				frame,
				Color3.fromRGB(16, 16, 18),
				Enum.Material.Fabric,
				false
			)
			part(
				"FlagCross",
				Vector3.new(fw / n + 0.03, 0.8, 0.07),
				frame,
				PAINT_WHITE,
				Enum.Material.Fabric,
				false
			)
			if k == 2 then
				part(
					"FlagCross",
					Vector3.new(0.8, fh + 0.01, 0.07),
					frame,
					PAINT_WHITE,
					Enum.Material.Fabric,
					false
				)
			end
		end
	end

	-- fuel bowser (a green tank on a two-wheel chassis, hazard diamond) and oil drums by the west fence
	do
		local at = CFrame.new(xz(R.x0 + 12, R.z1 - 8)) -- tank along X
		local green = Color3.fromRGB(38, 74, 54)
		part(
			"BowserChassis",
			Vector3.new(9, 0.5, 3.2),
			at * CFrame.new(0, 1.2, 0),
			Color3.fromRGB(40, 42, 44),
			Enum.Material.Metal
		)
		local tank = part(
			"BowserTank",
			Vector3.new(8.6, 3.6, 3.6),
			at * CFrame.new(0, 3.3, 0),
			green,
			Enum.Material.Metal
		)
		tank.Shape = Enum.PartType.Cylinder
		for _, s in { -1, 1 } do
			local wheel = part(
				"BowserWheel",
				Vector3.new(0.6, 2, 2),
				at * CFrame.new(0.6, 1, s * 1.85) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(24, 24, 26),
				Enum.Material.Rubber
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
		part(
			"BowserDrawbar",
			Vector3.new(4, 0.35, 0.35),
			at * CFrame.new(6.3, 1.1, 0),
			Color3.fromRGB(40, 42, 44),
			Enum.Material.Metal
		)
		part(
			"BowserJack",
			Vector3.new(0.3, 1.1, 0.3),
			at * CFrame.new(7.9, 0.55, 0),
			Color3.fromRGB(40, 42, 44),
			Enum.Material.Metal
		)
		part(
			"BowserHatch",
			Vector3.new(1.4, 0.4, 1.4),
			at * CFrame.new(-1.5, 5.25, 0),
			Color3.fromRGB(40, 42, 44),
			Enum.Material.Metal
		)
		part(
			"BowserReel",
			Vector3.new(0.9, 1.4, 1.4),
			at * CFrame.new(-4.6, 2.2, 0),
			Color3.fromRGB(196, 40, 34),
			Enum.Material.Metal
		)
		part(
			"BowserHazard",
			Vector3.new(1.2, 1.2, 0.05),
			at * CFrame.new(1.5, 3.4, 1.82) * CFrame.Angles(0, 0, math.pi / 4),
			Color3.fromRGB(232, 120, 30),
			Enum.Material.SmoothPlastic,
			false
		)
		for k, c in
			{
				Color3.fromRGB(32, 64, 128),
				Color3.fromRGB(176, 40, 32),
				Color3.fromRGB(32, 64, 128),
			}
		do
			local drum = part(
				"Drum",
				Vector3.new(2.6, 1.8, 1.8),
				CFrame.new(xz(R.x0 + 3 + (k - 1) * 2, R.z1 - 3))
					* CFrame.new(0, 1.3, 0)
					* CFrame.Angles(0, 0, math.pi / 2),
				c,
				Enum.Material.Metal
			)
			drum.Shape = Enum.PartType.Cylinder
		end
	end

	model.Parent = base

	-- the vehicles (existing assets, static): pivots are at the wheels' ground contact
	local function vehicle(asset: string, cf: CFrame): Model?
		local m = AssetLoader.cloneStatic(asset, "LOD0", true)
		if not m then
			warn(`[StationYard] {asset} did not load`)
			return nil
		end
		m:PivotTo(cf)
		m.Parent = model
		return m
	end
	for _, asset in
		{
			"M_Road_ParkedCar_01",
			"M_Road_ParkedCar_02",
			"M_Road_ParkedCar_03",
			"M_Veh_Coastguard4x4",
			"M_Veh_BoatTrailer_RIB",
			"M_Veh_RIB",
		}
	do
		task.spawn(AssetLoader.getTemplate, asset, "LOD0")
	end
	local crew =
		{ [1] = "M_Road_ParkedCar_02", [2] = "M_Road_ParkedCar_01", [4] = "M_Road_ParkedCar_03" }
	for bay, asset in crew do
		local x = R.x0 + 2 + 6 * bay + 3
		local z = (bayZ0 + bayZ1) / 2 + (bay % 2) * 0.6
		vehicle(asset, CFrame.lookAt(xz(x, z), xz(x + (bay - 2) * 0.15, z - 10)))
	end
	-- the launch rig facing the gate: trailer coupler (ATT_Coupler z -14.06) on the 4x4's tow hitch (rear, ~z +7.6)
	local rigZ = (G.z0 + G.z1) / 2
	local trailerX = R.x0 + 38
	local east = Vector3.new(1, 0, 0)
	local trailer = vehicle(
		"M_Veh_BoatTrailer_RIB",
		CFrame.lookAt(xz(trailerX, rigZ), xz(trailerX, rigZ) + east)
	)
	if trailer then
		vehicle("M_Veh_RIB", trailer:GetPivot() * CFrame.new(0, 2.905, 6.2)) -- StationRig HALL_BOAT
	end
	local towX = trailerX + 14.06 + 7.9
	vehicle("M_Veh_Coastguard4x4", CFrame.lookAt(xz(towX, rigZ), xz(towX, rigZ) + east))
	print(`[StationYard] placed at Y {math.floor(y * 10) / 10}`)
end

return StationYard
