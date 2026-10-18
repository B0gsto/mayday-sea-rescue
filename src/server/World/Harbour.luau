--!strict
-- Harbour (RP-I1b-1): dresses the Port Haven harbour with the HP1 quay kit, pontoons and ladders and the HP2a
-- harbour props, replacing the greybox quay face, the timber Dock pier and its bay bollards. Data-driven: the
-- layout below is pure (tests/Harbour.spec.luau); Harbour.apply (called by WorldDressingService) loads the assets
-- by name through AssetLoader and places them in Workspace.Dressing as Atomic models.
--
-- Kit conventions (art/source/harbour/_hp1/kit.py, studs): pivot on the quay top / deck top at the snap origin,
-- front (sea side) = local -Z, quay pieces 9 studs along X (steps and pier head 18), footprint 9 studs behind the
-- face; quay top = map Y 4, sea level Y 0; wall foot Y -8; pontoon deck 1.5 studs above the water; the gangway
-- pitches about ATT_Hinge until its roller sits on the pontoon deck; the rock armour pivot is the seabed plane
-- (crest +12 studs at scale 1). Props (HP2a) have their pivot at the base.
--
-- Gameplay markers kept: Map.PortHaven.Dock.Bay1..Bay4 (LaunchBay) stay where they are (the stone pier replaces
-- the deck around them); the BoatDesk and the harbourmaster desk stay on the quay top; DropOff_Dock (the tow berth
-- and "alongside the pontoon") moves 10 studs west to lie alongside the new dock pontoon, DropOff_Hospital moves
-- seaward alongside the new hospital pontoon. The greybox stays when a kit piece fails to load.
-- Tide: Workspace attribute TideHeight (studs above mean sea level, default 0) re-floats the pontoons and pitches
-- the gangways. Pontoons do not bob with the waves (fixed at the tide level, server-anchored).
local Harbour = {}

export type Placement = {
	asset: string,
	cf: CFrame,
	group: string, -- Dressing child model name
	scale: number?,
	lod: string?,
	collide: boolean?,
	ground: boolean?, -- props: drop the pivot onto the surface below (raycast)
	level: number?, -- props: stacked on `level` copies of itself (ATT_Stack or the model height)
}

Harbour.QUAY_Y = 4
Harbour.SEA_Y = 0
Harbour.FREEBOARD = 1.5 -- pontoon deck above the water (waterline z -0.5 m)
Harbour.LIFT = 0.04 -- kit tops sit just above the greybox / terrain at Y 4 (no z-fighting)
Harbour.WALL_FOOT = -8
Harbour.GRID = 9
Harbour.CREST = 4 -- armour crest (quay-top level)
Harbour.QUAY_FACE_Z = 4
Harbour.QUAY_X0 = -182 -- the run is aligned to the pier: slots 8 and 9 are the pier root (x -119..-101)
Harbour.QUAY_SLOTS = 41
Harbour.PIER = { west = -119, east = -101, z0 = 4, slots = 11 } -- head centred at z 103
Harbour.DOCK_PONTOON_X = -124
Harbour.HOSPITAL_PONTOON_X = 130
Harbour.HINGE_BACK = 1.2
Harbour.TERRAIN_CUT = 0.4 -- occupancy of the Y 0..4 voxel layer under the quay kit (renders about Y 3.6) -- gangway hinge behind the coping edge

-- gangway geometry from AssetIds.Attachments (studs from the pivot)
local HINGE = Vector3.new(0, -0.06, -0.12)
local ROLLER = Vector3.new(0, -0.93, 26.25)
local SNAP_GANGWAY = 0.9 -- Straight ATT_Snap_Gangway z
local LADDER_OFFSET = Vector3.new(0, 0, 0.66) - Vector3.new(0, 0, 0.66) -- bay ATT_Ladder - ladder ATT_Ladder_Mount

-- hanging fenders: ATT_Line height above the pivot (the bottom) and the radius, studs
local FENDER: { [string]: { line: number, r: number } } = {
	M_Hbr_Fender_Cyl_01 = { line = 2.47, r = 0.3 },
	M_Hbr_Fender_Cyl_02 = { line = 3.04, r = 0.38 },
	M_Hbr_Fender_Cyl_03 = { line = 3.61, r = 0.45 },
	M_Hbr_Fender_Ball = { line = 2.7, r = 0.9 },
}

local WIDTH: { [string]: number } = {
	Straight = 9,
	LadderBay = 9,
	Steps = 18,
}

-- yaw for a piece whose local -Z (front) faces `normal`
function Harbour.yawFacing(normal: Vector3): number
	return math.atan2(-normal.X, -normal.Z)
end

local function at(x: number, y: number, z: number, yaw: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
end

-- Quay slot kinds: "S" straight, "L" ladder bay, "T" steps (two slots, second "-"). Index 1 = x -182..-173.
-- Pier root 8-9, dock gangway 7, slipway 1-3 (the ramp lies in front of the wall), steps 13-14 by the spawn,
-- ladders every 54 studs or so, hospital gangway 35.
Harbour.QUAY = "SSSSLSSSSSLSTSSSLSSSSSLSSSSSLSSSSSSSSSLSS"

function Harbour.quaySlotX(i: number): number
	return Harbour.QUAY_X0 + Harbour.GRID * (i - 0.5)
end

-- the quay face run, the pier sides and head, and the ladders (one per ladder bay)
function Harbour.kitLayout(): { Placement }
	local out: { Placement } = {}
	local y = Harbour.QUAY_Y + Harbour.LIFT
	local function add(kind: string, cf: CFrame, group: string)
		table.insert(out, { asset = `M_Hbr_QuayKit_{kind}`, cf = cf, group = group })
		if kind == "LadderBay" then
			table.insert(
				out,
				{ asset = "M_Hbr_Ladder", cf = cf * CFrame.new(LADDER_OFFSET), group = group }
			)
		end
	end
	local yawQuay = Harbour.yawFacing(Vector3.new(0, 0, 1))
	local i = 1
	while i <= #Harbour.QUAY do
		local c = string.sub(Harbour.QUAY, i, i)
		local kind = if c == "L" then "LadderBay" elseif c == "T" then "Steps" else "Straight"
		local w = WIDTH[kind]
		local x = Harbour.QUAY_X0 + Harbour.GRID * (i - 1) + w / 2
		add(kind, at(x, y, Harbour.QUAY_FACE_Z, yawQuay), "Harbour_Quay")
		i += w // Harbour.GRID
	end
	-- the stone pier around the launch bays: two runs facing out, ladders on the bay side between the bays
	local P = Harbour.PIER
	local eastLadders = { [3] = true, [6] = true, [8] = true }
	for s = 1, P.slots do
		local z = P.z0 + Harbour.GRID * (s - 0.5)
		add("Straight", at(P.west, y, z, Harbour.yawFacing(Vector3.new(-1, 0, 0))), "Harbour_Pier")
		local kind = if eastLadders[s] then "LadderBay" else "Straight"
		add(kind, at(P.east, y, z, Harbour.yawFacing(Vector3.new(1, 0, 0))), "Harbour_Pier")
	end
	local headZ = P.z0 + Harbour.GRID * P.slots
	add("Head", at((P.west + P.east) / 2, y, headZ, yawQuay), "Harbour_Pier")
	return out
end

-- Gangway pitch (radians, + = the far end down) so the roller, hinge-relative (py, pz) in the gangway frame, sits
-- `drop` studs below the hinge; also the roller's horizontal reach from the hinge.
function Harbour.gangwayPitch(drop: number): (number, number)
	local d = ROLLER - HINGE
	local py, pz = d.Y, d.Z
	local r = math.sqrt(py * py + pz * pz)
	local phi = math.atan2(pz, py)
	local a = math.acos(math.clamp(-drop / r, -1, 1)) - phi
	local reach = py * math.sin(a) + pz * math.cos(a)
	return a, reach
end

-- a gangway hinged on the quay at (x, quay top, face - HINGE_BACK) heading +Z down to a deck at deckY:
-- the gangway pivot CFrame and the z of the roller on the deck
function Harbour.gangway(x: number, deckY: number): (CFrame, number)
	local hinge =
		Vector3.new(x, Harbour.QUAY_Y + Harbour.LIFT, Harbour.QUAY_FACE_Z - Harbour.HINGE_BACK)
	local a, reach = Harbour.gangwayPitch(hinge.Y - deckY)
	return CFrame.new(hinge) * CFrame.Angles(a, 0, 0) * CFrame.new(-HINGE), hinge.Z + reach
end

export type Float = { name: string, gangway: CFrame, pieces: { Placement } }

-- The two floating berths at tide `tide` (studs). Pontoon pieces are placed relative to the deck; fenders hang
-- from the deck edge at the berth side.
function Harbour.floats(tide: number): { Float }
	local deck = Harbour.SEA_Y + tide + Harbour.FREEBOARD
	local out: { Float } = {}
	-- dock pontoon: along the pier's west face, the tow berth (DropOff_Dock) alongside its west side
	do
		local x = Harbour.DOCK_PONTOON_X
		local g, rollerZ = Harbour.gangway(x, deck)
		local z0 = rollerZ - SNAP_GANGWAY
		local p: { Placement } = {}
		local grp = "Harbour_DockPontoon"
		table.insert(
			p,
			{ asset = "M_Hbr_Pontoon_Straight12", cf = at(x, deck, z0, 0), group = grp }
		)
		table.insert(
			p,
			{ asset = "M_Hbr_Pontoon_Straight12", cf = at(x, deck, z0 + 36, 0), group = grp }
		)
		for _, fz in { 13.5, 22.5 } do -- fingers on the first section, west side
			table.insert(p, {
				asset = "M_Hbr_Pontoon_Finger",
				cf = at(x - 3.81, deck, z0 + fz, -math.pi / 2),
				group = grp,
			})
		end
		local fenders = { "M_Hbr_Fender_Cyl_01", "M_Hbr_Fender_Cyl_02", "M_Hbr_Fender_Cyl_01" }
		for k, fz in { 55, 66, 77 } do -- the tow berth on the second section, hung from the deck edge
			local f = fenders[k]
			table.insert(p, {
				asset = f,
				cf = CFrame.new(x - 3.9 - FENDER[f].r, deck + 0.25 - FENDER[f].line, z0 + fz),
				group = grp,
				collide = false,
			})
		end
		table.insert(p, {
			asset = "M_Hbr_LifebuoyStation",
			cf = at(x + 2.6, deck, z0 + 6, -math.pi / 2),
			group = grp,
		})
		table.insert(p, {
			asset = "M_Hbr_Rope_Coil",
			cf = at(x + 1.8, deck, z0 + 48, 0.6),
			group = grp,
			collide = false,
		})
		table.insert(out, { name = "DockGangway", gangway = g, pieces = p })
	end
	-- hospital pontoon: a T off the quay, parallel to it, the ambulance berth on its seaward side
	do
		local x = Harbour.HOSPITAL_PONTOON_X
		local g, rollerZ = Harbour.gangway(x, deck)
		local z0 = rollerZ - SNAP_GANGWAY
		local zc = z0 + 3.6
		local p: { Placement } = {}
		local grp = "Harbour_HospitalPontoon"
		table.insert(p, { asset = "M_Hbr_Pontoon_Corner", cf = at(x, deck, z0, 0), group = grp })
		table.insert(p, {
			asset = "M_Hbr_Pontoon_Straight12",
			cf = at(x + 3.6, deck, zc, math.pi / 2),
			group = grp,
		})
		table.insert(p, {
			asset = "M_Hbr_Pontoon_Straight12",
			cf = at(x - 3.6, deck, zc, -math.pi / 2),
			group = grp,
		})
		for k, fx in { -24, -12, 12, 24 } do
			local f = if k % 2 == 0 then "M_Hbr_Fender_Ball" else "M_Hbr_Fender_Cyl_03"
			table.insert(p, {
				asset = f,
				cf = CFrame.new(x + fx, deck + 0.25 - FENDER[f].line, zc + 3.9 + FENDER[f].r),
				group = grp,
				collide = false,
			})
		end
		table.insert(p, {
			asset = "M_Hbr_LifebuoyStation",
			cf = at(x + 9, deck, zc - 2.6, 0),
			group = grp,
		})
		table.insert(out, { name = "HospitalGangway", gangway = g, pieces = p })
	end
	return out
end

-- the pads the berthing / delivery mechanics read, alongside the pontoons' berth sides (centre, size)
function Harbour.padFrames(tide: number): { [string]: { cf: CFrame, size: Vector3 } }
	local deck = Harbour.SEA_Y + tide + Harbour.FREEBOARD
	local _, hospRoller = Harbour.gangway(Harbour.HOSPITAL_PONTOON_X, deck)
	local hz0 = hospRoller - SNAP_GANGWAY
	return {
		-- 12 x 20 along Z (unchanged size and z), its east edge 0.6 studs off the pontoon's west D-fenders
		DropOff_Dock = {
			cf = CFrame.new(Harbour.DOCK_PONTOON_X - 3.9 - 0.6 - 6, 0.2, 92),
			size = Vector3.new(12, 0.4, 20),
		},
		-- 24 x 16 along X (unchanged size and x), its north edge 0.6 studs off the pontoon's seaward edge
		DropOff_Hospital = {
			cf = CFrame.new(Harbour.HOSPITAL_PONTOON_X, 0.2, hz0 + 7.2 + 0.6 + 8),
			size = Vector3.new(24, 0.4, 16),
		},
	}
end

-- Rock armour along a breakwater face: pieces scaled so the crest reaches CREST from the seabed below
-- (`bed(x, z)` -> seabed Y), stepped by their scaled width with a 15 % overlap; shallow stretches are skipped.
export type Run = { from: Vector3, to: Vector3, normal: Vector3, group: string }
function Harbour.armourRun(run: Run, bed: (number, number) -> number?): { Placement }
	local out: { Placement } = {}
	local span = run.to - run.from
	local len = span.Magnitude
	local dir = span.Unit
	local yaw = Harbour.yawFacing(run.normal)
	local d = 0
	while d < len do
		local guess = 2
		local base = run.from + dir * (d + 4.5 * guess)
		local lowest: number? = nil
		for _, out_ in { 3, 10, 18 } do
			local p = base + run.normal * out_ * guess
			local y = bed(p.X, p.Z)
			if y and (not lowest or y < lowest) then
				lowest = y
			end
		end
		local s = if lowest then (Harbour.CREST - lowest) / 12 else 0
		if s < 0.7 then
			d += Harbour.GRID
		else
			s = math.min(s, 3)
			local w = Harbour.GRID * s
			local c = run.from + dir * (d + w / 2)
			table.insert(out, {
				asset = "M_Hbr_QuayKit_Armour",
				cf = at(c.X, Harbour.CREST - 12 * s, c.Z, yaw),
				group = run.group,
				scale = s,
				lod = "LOD1",
			})
			d += w * 0.85
		end
	end
	return out
end

-- seaward faces of the breakwater arms and heads (Build.luau buildBreakwater: arms x +-320 width 16, z -20..368,
-- heads z 352..368 from the 60-stud mouth) and the harbour side of the arms
Harbour.ARMOUR_RUNS = {
	{
		from = Vector3.new(-328, 0, -20),
		to = Vector3.new(-328, 0, 368),
		normal = Vector3.new(-1, 0, 0),
		group = "Harbour_ArmourWest",
	},
	{
		from = Vector3.new(-328, 0, 368),
		to = Vector3.new(-34, 0, 368),
		normal = Vector3.new(0, 0, 1),
		group = "Harbour_ArmourWest",
	},
	{
		from = Vector3.new(-312, 0, -20),
		to = Vector3.new(-312, 0, 352),
		normal = Vector3.new(1, 0, 0),
		group = "Harbour_ArmourWestIn",
	},
	{
		from = Vector3.new(328, 0, -20),
		to = Vector3.new(328, 0, 368),
		normal = Vector3.new(1, 0, 0),
		group = "Harbour_ArmourEast",
	},
	{
		from = Vector3.new(328, 0, 368),
		to = Vector3.new(34, 0, 368),
		normal = Vector3.new(0, 0, 1),
		group = "Harbour_ArmourEast",
	},
	{
		from = Vector3.new(312, 0, -20),
		to = Vector3.new(312, 0, 352),
		normal = Vector3.new(-1, 0, 0),
		group = "Harbour_ArmourEastIn",
	},
} :: { Run }

-- Quay furniture: bollards on the coping at the mooring points, lifebuoy stations about every 40 m, the fish quay
-- (pots, boxes, nets) east of the steps, rope coils and flakes by the bollards. y comes from a raycast (ground).
function Harbour.propLayout(): { Placement }
	local out: { Placement } = {}
	local function prop(
		asset: string,
		x: number,
		z: number,
		yaw: number,
		group: string,
		extra: { [string]: any }?
	)
		local p: Placement =
			{ asset = asset, cf = at(x, Harbour.QUAY_Y, z, yaw), group = group, ground = true }
		if extra then
			for k, v in extra do
				(p :: any)[k] = v
			end
		end
		table.insert(out, p)
	end
	local edge = Harbour.QUAY_FACE_Z - 1.6
	local skip = { [7] = true, [8] = true, [9] = true, [13] = true, [14] = true, [35] = true }
	local bollards = { "M_Hbr_Bollard_01", "M_Hbr_Bollard_02", "M_Hbr_Bollard_01" }
	for i = 2, Harbour.QUAY_SLOTS, 2 do
		local c = string.sub(Harbour.QUAY, i, i)
		if not skip[i] and c == "S" then
			local x = Harbour.quaySlotX(i)
			prop(bollards[(i // 2) % 3 + 1], x, edge, (i * 0.7) % 1.2, "Harbour_Quay")
			if i % 6 == 0 then
				prop(
					"M_Hbr_Rope_Coil",
					x + 2.6,
					edge - 1.4,
					i * 0.9,
					"Harbour_Quay",
					{ collide = false }
				)
			end
		end
	end
	-- lifebuoy stations: quay every ~120 studs (40 m), facing the walkway
	for _, x in { -150.5, -40, 74, 165.5 } do
		prop("M_Hbr_LifebuoyStation", x, Harbour.QUAY_FACE_Z - 2.4, math.pi, "Harbour_Quay")
	end
	-- pier: a bollard at each launch bay (where the greybox Bay{i}Bollard stood), more on the west face,
	-- cannon bollards on the head, a lifebuoy between bays 2 and 3, chain and flaked rope near the head
	local P = Harbour.PIER
	for i = 1, 4 do
		local z = 4 + i * 22 - 8
		prop(
			if i % 2 == 0 then "M_Hbr_Bollard_02" else "M_Hbr_Bollard_01",
			P.east - 1.6,
			z,
			0,
			"Harbour_Pier"
		)
	end
	for _, z in { 22, 58, 94 } do
		prop("M_Hbr_Bollard_01", P.west + 1.6, z, 0.4, "Harbour_Pier")
	end
	local headZ = P.z0 + Harbour.GRID * P.slots
	local hx = (P.west + P.east) / 2
	for _, ang in { -0.8, 0, 0.8 } do
		prop(
			"M_Hbr_Bollard_03",
			hx + math.sin(ang) * 7.2,
			headZ + math.cos(ang) * 7.2,
			ang,
			"Harbour_Pier"
		)
	end
	prop("M_Hbr_LifebuoyStation", P.east - 2.4, 51, -math.pi / 2, "Harbour_Pier")
	prop("M_Hbr_Rope_Chain", hx - 3, headZ - 4, 1.1, "Harbour_Pier", { collide = false })
	prop("M_Hbr_Rope_Flaked", P.west + 3.2, 40, 0.1, "Harbour_Pier", { collide = false })
	prop("M_Hbr_Rope_Coil", P.east - 3.4, 73, 2.2, "Harbour_Pier", { collide = false })
	-- the fish quay (x 25..97): creels and pots stacked two high, fish-box stacks, a trawl net, ropes
	local g = "Harbour_FishQuay"
	for k, spot in { { 30, -1.5 }, { 33, -1.4 }, { 36.2, -1.6 }, { 31.5, -4.2 }, { 34.8, -4.0 } } do
		local pot = if k % 2 == 0 then "M_Hbr_LobsterPot_02" else "M_Hbr_LobsterPot_01"
		prop(pot, spot[1], spot[2], k * 0.35, g)
		if k <= 3 then
			prop(pot, spot[1] + 0.1, spot[2], k * 0.35 + 0.1, g, { level = 1 })
		end
	end
	for k, spot in { { 52, -2.0, 4 }, { 55, -2.2, 3 }, { 53.5, -4.6, 2 }, { 84, -3, 3 } } do
		local box = if k % 2 == 0 then "M_Hbr_FishBox_02" else "M_Hbr_FishBox_01"
		for lv = 0, spot[3] - 1 do
			prop(box, spot[1], spot[2], (k + lv) % 2 * 0.06, g, { level = lv })
		end
	end
	prop("M_Hbr_NetPile", 64, -4.5, 0.25, g, { collide = false })
	prop("M_Hbr_Rope_Flaked", 70, -2.2, 1.5, g, { collide = false })
	prop("M_Hbr_Rope_Coil", 44, -1.8, 0.8, g, { collide = false })
	prop("M_Hbr_LobsterPot_02", 88, -6.5, 0.2, g)
	prop("M_Hbr_LobsterPot_01", 90.6, -6.3, 1.0, g)
	return out
end

-------------------------------------------------------------------------------- run time

local function groupModel(base: Instance, name: string): Model
	local m = base:FindFirstChild(name)
	if m and m:IsA("Model") then
		return m
	end
	local g = Instance.new("Model")
	g.Name = name
	g.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	g.Parent = base
	return g
end

-- Places everything; returns the number of placed models. `base` is Workspace.Dressing.
function Harbour.apply(base: Instance): number
	local Workspace = game:GetService("Workspace")
	local AssetLoader = (require :: any)(
		script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader")
	)
	local terrain = Workspace.Terrain
	local map = Workspace:FindFirstChild("Map")
	local tide = (Workspace:GetAttribute("TideHeight") :: number?) or 0

	-- 1. the kit: everything loads first; any miss keeps the greybox untouched
	local kit = Harbour.kitLayout()
	local floats = Harbour.floats(tide)
	local needed: { [string]: string } =
		{ M_Hbr_Pontoon_Gangway = "LOD0", M_Hbr_QuayKit_Armour = "LOD1" }
	for _, p in kit do
		needed[p.asset] = "LOD0"
	end
	for _, f in floats do
		for _, p in f.pieces do
			needed[p.asset] = "LOD0"
		end
	end
	local props = Harbour.propLayout()
	for _, p in props do
		needed[p.asset] = "LOD0"
	end
	for asset, lod in needed do
		task.spawn(AssetLoader.getTemplate, asset, lod)
	end
	for asset, lod in needed do
		local essential = string.find(asset, "QuayKit_") and asset ~= "M_Hbr_QuayKit_Armour"
			or string.find(asset, "Pontoon_")
		if essential and not AssetLoader.getTemplate(asset, lod) then
			warn(`[Harbour] {asset} did not load; keeping the greybox harbour`)
			return 0
		end
	end

	local placed = 0
	local function place(p: Placement, parent: Instance): Model?
		local m = AssetLoader.cloneStatic(p.asset, p.lod or "LOD0", p.collide ~= false)
		if not m then
			return nil
		end
		if p.scale and math.abs(p.scale - 1) > 1e-3 then
			m:ScaleTo(p.scale)
		end
		m:PivotTo(p.cf)
		m.Parent = parent
		placed += 1
		return m
	end

	-- terrain: a rubble footing under the pier and along the quay toe so the wall feet (Y -8) bed in
	local tOk, tErr = pcall(function()
		local foot = Harbour.WALL_FOOT + 0.3
		local P = Harbour.PIER
		local pierLen = Harbour.GRID * P.slots + 10
		terrain:FillBlock(
			CFrame.new((P.west + P.east) / 2, (foot - 30) / 2, P.z0 + pierLen / 2),
			Vector3.new(P.east - P.west + 4, foot + 30, pierLen),
			Enum.Material.Rock
		)
		local x0, x1 = Harbour.QUAY_X0, Harbour.QUAY_X0 + Harbour.GRID * Harbour.QUAY_SLOTS
		terrain:FillBlock(
			CFrame.new((x0 + x1) / 2, (foot - 16) / 2, Harbour.QUAY_FACE_Z + 1.5),
			Vector3.new(x1 - x0, foot + 16, 5),
			Enum.Material.Rock
		)
		-- smooth terrain meshes an empty-over-full voxel boundary 2 studs high, so the baked town ground (voxels full
		-- to Y 4) renders at Y 6 and buried the setts: under the kit footprint (z -8..4) the top layer (Y 0..4) is cut
		-- to occupancy CUT (surface about Y 2 + 4 * CUT = 3.6, under the setts) in Cobblestone, and Y 4..8 emptied
		local region = Region3.new(
			Vector3.new(x0, 0, Harbour.QUAY_FACE_Z - 12),
			Vector3.new(x1, 8, Harbour.QUAY_FACE_Z)
		):ExpandToGrid(4)
		local mats, occ = terrain:ReadVoxels(region, 4)
		local n = occ.Size
		for ix = 1, n.X do
			for iz = 1, n.Z do
				for iy = 1, n.Y do
					local cap = if iy == 1 then Harbour.TERRAIN_CUT else 0
					if occ[ix][iy][iz] > cap then
						occ[ix][iy][iz] = cap
						mats[ix][iy][iz] = if cap > 0
							then Enum.Material.Cobblestone
							else Enum.Material.Air
					end
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occ)
	end)
	if not tOk then
		warn(`[Harbour] terrain footing / carve failed: {tErr}`)
	end

	for _, p in kit do
		place(p, groupModel(base, p.group))
	end

	-- 2. the floating berths (re-posed on TideHeight changes)
	local floatModels: { [string]: { gangway: Model?, pieces: { { m: Model, p: Placement } } } } =
		{}
	for _, f in floats do
		local grp = groupModel(base, f.pieces[1].group)
		local g = place({ asset = "M_Hbr_Pontoon_Gangway", cf = f.gangway, group = grp.Name }, grp)
		local list = {}
		for _, p in f.pieces do
			local m = place(p, grp)
			if m then
				table.insert(list, { m = m, p = p })
			end
		end
		floatModels[f.name] = { gangway = g, pieces = list }
	end
	Workspace:GetAttributeChangedSignal("TideHeight"):Connect(function()
		local t = (Workspace:GetAttribute("TideHeight") :: number?) or 0
		for _, f in Harbour.floats(t) do
			local fm = floatModels[f.name]
			if fm then
				if fm.gangway then
					fm.gangway:PivotTo(f.gangway)
				end
				for k, e in fm.pieces do
					local p = f.pieces[k]
					if p then
						e.m:PivotTo(p.cf)
					end
				end
			end
		end
		local pads = map and map:FindFirstChild("DropOffs")
		for name, frame in Harbour.padFrames(t) do
			local pad = pads and pads:FindFirstChild(name)
			if pad and pad:IsA("BasePart") then
				pad.CFrame = frame.cf + Vector3.new(0, t, 0)
			end
		end
	end)

	-- 3. breakwater armour on the terrain seabed
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local function bed(x: number, z: number): number?
		local hit = Workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -200, 0), params)
		return if hit then hit.Position.Y else nil
	end
	for _, run in Harbour.ARMOUR_RUNS do
		for _, p in Harbour.armourRun(run, bed) do
			place(p, groupModel(base, p.group))
		end
	end

	-- 4. props, dropped onto the quay / pier / pontoon surface
	local surface = RaycastParams.new()
	surface.FilterType = Enum.RaycastFilterType.Include
	local solids: { Instance } = { terrain }
	for _, c in base:GetChildren() do
		if string.sub(c.Name, 1, 8) == "Harbour_" then
			table.insert(solids, c)
		end
	end
	local quay = map
		and map:FindFirstChild("PortHaven")
		and (map :: any).PortHaven:FindFirstChild("Quay")
	if quay then
		table.insert(solids, quay)
	end
	surface.FilterDescendantsInstances = solids
	local heights: { [string]: number } = {}
	local function heightOf(asset: string): number
		if heights[asset] then
			return heights[asset]
		end
		local t = AssetLoader.getTemplate(asset, "LOD0")
		local h = 1
		if t then
			local stack = t:FindFirstChild("ATT_Stack", true)
			if stack and stack:IsA("Attachment") then
				h = (t.WorldPivot:PointToObjectSpace(stack.WorldPosition)).Y
			else
				h = t:GetExtentsSize().Y * 0.92 -- nested a little into the one below
			end
		end
		heights[asset] = h
		return h
	end
	for _, p in props do
		local cf = p.cf
		if p.ground then
			local pos = cf.Position
			local hit =
				Workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0), surface)
			local y = if hit then hit.Position.Y else Harbour.QUAY_Y + Harbour.LIFT
			cf = cf + Vector3.new(0, y + (p.level or 0) * heightOf(p.asset) - pos.Y, 0)
		end
		local q = table.clone(p)
		q.cf = cf
		place(q, groupModel(base, p.group))
	end

	-- 5. greybox: the quay box backs off behind the kit's setts, the Dock deck / pilings / bay bollards go
	-- (Bay1..Bay4 stay), the pads move alongside the pontoons
	local town = map and map:FindFirstChild("PortHaven")
	if quay and quay:IsA("BasePart") then
		local back = Harbour.QUAY_FACE_Z - 12 -- the carved band (z -8..4) shows terrain, not the greybox top
		local minZ = quay.Position.Z - quay.Size.Z / 2
		quay.Size = Vector3.new(quay.Size.X, quay.Size.Y, back - minZ)
		quay.CFrame = CFrame.new(quay.Position.X, quay.Position.Y, (minZ + back) / 2)
		quay:SetAttribute("TrimmedBy", "Harbour")
	end
	local dock = town and town:FindFirstChild("Dock")
	if dock then
		for _, c in dock:GetChildren() do
			if c:IsA("BasePart") and not c:GetAttribute("LaunchBay") then
				c:Destroy()
			end
		end
		dock:RemoveTag("GREYBOX")
		dock:SetAttribute("SwappedTo", "Harbour_Pier")
	end
	local pads = map and map:FindFirstChild("DropOffs")
	for name, frame in Harbour.padFrames(tide) do
		local pad = pads and pads:FindFirstChild(name)
		if pad and pad:IsA("BasePart") then
			pad.Size = frame.size
			pad.CFrame = frame.cf + Vector3.new(0, tide, 0)
		end
	end
	print(`[Harbour] placed {placed} harbour models`)
	return placed
end

return Harbour
