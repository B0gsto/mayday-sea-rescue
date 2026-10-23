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
Harbour.YARD_QUAY = { x0 = -317, kinds = "SSSSSSS..SSSSSS" } -- 15 slots to x -182; slots 8-9 the yard slipway
-- map/Build.luau buildBreakwater: arms at x +-320 (16 wide, z -20..368), heads z 352..368 from the 60-stud mouth.
-- Map polish (docs/17 P0 7): the outer third dog-legs inward, so each arm runs root -> knee (x +-320, z `knee`)
-- -> head (x +-`head`, z `far`) -> the mouth; the mouth, the Harbour Light and the basin inside stay. CallTypes
-- Areas.Inside.elbow mirrors knee / head (tests/Harbour.spec.luau checks they match).
Harbour.BREAKWATER = { x = 320, w = 16, far = 360, mouth = 30, root = -20, knee = 250, head = 140 }
Harbour.BREAKWATER_LAMP = 40 -- lamp spacing along the arms
Harbour.BREAKWATER_LADDER = 5 -- a ladder bay every 5th harbour-face slot (45 studs)
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

-- The centreline of one breakwater (side -1 west, +1 east): root, knee, head, mouth end (Y 0).
function Harbour.breakwaterLine(side: number): { Vector3 }
	local B = Harbour.BREAKWATER
	return {
		Vector3.new(side * B.x, 0, B.root),
		Vector3.new(side * B.x, 0, B.knee),
		Vector3.new(side * B.head, 0, B.far),
		Vector3.new(side * B.mouth, 0, B.far),
	}
end

-- unit normal of the leg a -> b pointing into the basin
local BASIN = Vector3.new(0, 0, 180)
local function inward(a: Vector3, b: Vector3): Vector3
	local d = (b - a).Unit
	local n = Vector3.new(-d.Z, 0, d.X)
	return if (BASIN - (a + b) / 2):Dot(n) < 0 then -n else n
end
Harbour.inward = inward

-- The line `dist` studs off the centreline toward the basin (negative: seaward), mitred at the bends.
function Harbour.breakwaterOffset(side: number, dist: number): { Vector3 }
	local P = Harbour.breakwaterLine(side)
	local out = { P[1] + inward(P[1], P[2]) * dist }
	for k = 2, #P - 1 do
		local n1, n2 = inward(P[k - 1], P[k]), inward(P[k], P[k + 1])
		local m = (n1 + n2).Unit -- the bisector, lengthened so both offset lines pass through it
		table.insert(out, P[k] + m * (dist / m:Dot(n1)))
	end
	table.insert(out, P[#P] + inward(P[#P - 1], P[#P]) * dist)
	return out
end

export type Slot = { cf: CFrame, kind: string, k: number }

-- The 9-stud kit slots of one breakwater's harbour face: the arm from the quay line, then the dog-leg and the head
-- (each centred between its mitres) to 3 studs short of the mouth. cf: the face at quay top, front to the basin.
function Harbour.breakwaterSlots(side: number): { Slot }
	local Q = Harbour.breakwaterOffset(side, Harbour.BREAKWATER.w / 2)
	Q[1] = Vector3.new(Q[1].X, 0, Harbour.QUAY_FACE_Z)
	Q[#Q] -= (Q[#Q] - Q[#Q - 1]).Unit * 3
	local y = Harbour.QUAY_Y + Harbour.LIFT
	local out: { Slot } = {}
	for i = 1, #Q - 1 do
		local a, b = Q[i], Q[i + 1]
		local len = (b - a).Magnitude
		local n = math.floor(len / Harbour.GRID)
		local pad = if i == 1 then 0 else (len - n * Harbour.GRID) / 2
		local yaw = Harbour.yawFacing(inward(a, b))
		for s = 1, n do
			local k = #out + 1
			local p = a + (b - a).Unit * (pad + Harbour.GRID * (s - 0.5))
			table.insert(out, {
				cf = at(p.X, y, p.Z, yaw),
				kind = if k % Harbour.BREAKWATER_LADDER == 3 then "LadderBay" else "Straight",
				k = k,
			})
		end
	end
	return out
end

-- Points every `step` studs along a polyline, starting `step / 2` in and stopping `stop` short of the end.
local function along(Q: { Vector3 }, step: number, stop: number): { { pos: Vector3, dir: Vector3 } }
	local out = {}
	local total = 0
	for i = 1, #Q - 1 do
		total += (Q[i + 1] - Q[i]).Magnitude
	end
	local s, i, s0 = step / 2, 1, 0
	while s < total - stop do
		while s > s0 + (Q[i + 1] - Q[i]).Magnitude do
			s0 += (Q[i + 1] - Q[i]).Magnitude
			i += 1
		end
		local dir = (Q[i + 1] - Q[i]).Unit
		table.insert(out, { pos = Q[i] + dir * (s - s0), dir = dir })
		s += step
	end
	return out
end

-- Lamp standards along the deck behind the seaward parapet, clear of the pierhead light.
function Harbour.breakwaterLamps(side: number): { { pos: Vector3, dir: Vector3 } }
	local B = Harbour.BREAKWATER
	return along(Harbour.breakwaterOffset(side, -(B.w / 2 - 4.2)), Harbour.BREAKWATER_LAMP, 14)
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
	-- the boatyard frontage west of the quay run, up to the west breakwater root ("." = the yard slipway)
	local Y = Harbour.YARD_QUAY
	for k = 1, #Y.kinds do
		if string.sub(Y.kinds, k, k) == "S" then
			add(
				"Straight",
				at(Y.x0 + Harbour.GRID * (k - 0.5), y, Harbour.QUAY_FACE_Z, yawQuay),
				"Harbour_YardQuay"
			)
		end
	end
	-- the breakwaters' harbour faces: the arm, the dog-leg and the head
	for _, side in { -1, 1 } do
		local grp = if side < 0 then "Harbour_BreakwaterWest" else "Harbour_BreakwaterEast"
		for _, s in Harbour.breakwaterSlots(side) do
			add(s.kind, s.cf, grp)
		end
	end
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

-- seaward faces of the dog-legged breakwaters, stopping 4 studs short of the mouth; the harbour side is a coursed
-- quay wall (the breakwaterSlots kit runs)
function Harbour.armourRuns(): { Run }
	local out: { Run } = {}
	for _, side in { -1, 1 } do
		local Q = Harbour.breakwaterOffset(side, -Harbour.BREAKWATER.w / 2)
		Q[#Q] -= (Q[#Q] - Q[#Q - 1]).Unit * 4
		for i = 1, #Q - 1 do
			table.insert(out, {
				from = Q[i],
				to = Q[i + 1],
				normal = -inward(Q[i], Q[i + 1]),
				group = if side < 0 then "Harbour_ArmourWest" else "Harbour_ArmourEast",
			})
		end
	end
	return out
end

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
	-- lifebuoy stations: quay every ~120 studs (40 m), facing the walkway; the west one sits by the ladder bay,
	-- clear of the lifeboat crewman NpcService stands 4.5 studs east of the station slipway (x -150.5)
	for _, x in { -145.5, -40, 74, 165.5 } do
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
	-- breakwater arms: a bollard behind every sixth slot of the harbour face, between the ladders
	for _, side in { -1, 1 } do
		local grp = if side < 0 then "Harbour_BreakwaterWest" else "Harbour_BreakwaterEast"
		for _, s in Harbour.breakwaterSlots(side) do
			if s.k % 6 == 0 and s.kind == "Straight" then
				local p = (s.cf * CFrame.new(0, 0, 1.6)).Position
				prop("M_Hbr_Bollard_01", p.X, p.Z, s.k * 0.7, grp)
			end
		end
	end
	return out
end

-------------------------------------------------------------------------------- run time

-- Station frontage rail (r2 playtest: a player backing away from the station walked off the quay into
-- the harbour). Waist high, so a deliberate jump still clears it. Open at the slipway, the dock gangway,
-- the pier root and the steps, with a gap at each ladder top so the ladders still lead in and out.
Harbour.RAIL =
	{ first = 4, last = 12, z = Harbour.QUAY_FACE_Z - 0.6, height = 3.2, gap = 3, post = 3 }

function Harbour.railRuns(): { { x0: number, x1: number } }
	local R = Harbour.RAIL
	local open = { [7] = true, [8] = true, [9] = true } -- gangway, pier root
	local out: { { x0: number, x1: number } } = {}
	local function add(x0: number, x1: number)
		local last = out[#out]
		if last and math.abs(last.x1 - x0) < 1e-6 then
			last.x1 = x1
		else
			table.insert(out, { x0 = x0, x1 = x1 })
		end
	end
	for i = R.first, R.last do
		local c = string.sub(Harbour.QUAY, i, i)
		if not open[i] and c ~= "T" then
			local x0 = Harbour.QUAY_X0 + Harbour.GRID * (i - 1)
			local x1 = x0 + Harbour.GRID
			if c == "L" then
				local mid = (x0 + x1) / 2
				add(x0, mid - R.gap / 2)
				table.insert(out, { x0 = mid + R.gap / 2, x1 = x1 })
			else
				add(x0, x1)
			end
		end
	end
	return out
end

-- Code-built (placeholder until a kit rail lands): hot-dip galvanised posts and rails (docs/17 P2 19: not toy colours).
local function buildRail(base: Instance)
	local R = Harbour.RAIL
	local y0 = Harbour.QUAY_Y + Harbour.LIFT
	local model = Instance.new("Model")
	model.Name = "Harbour_Rail"
	local function bar(size: Vector3, pos: Vector3, colour: Color3)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.Position = pos
		p.Color = colour
		p.Material = Enum.Material.Metal
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
	end
	local steel, top = Color3.fromRGB(104, 107, 106), Color3.fromRGB(116, 119, 118) -- lighter reads sky-blue
	for _, run in Harbour.railRuns() do
		local len = run.x1 - run.x0
		local mid = (run.x0 + run.x1) / 2
		bar(Vector3.new(len, 0.3, 0.3), Vector3.new(mid, y0 + R.height, R.z), top)
		bar(Vector3.new(len, 0.2, 0.2), Vector3.new(mid, y0 + R.height * 0.5, R.z), steel)
		local posts = math.max(1, math.ceil(len / R.post))
		for k = 0, posts do
			local x = run.x0 + 0.15 + (len - 0.3) * k / posts
			bar(Vector3.new(0.3, R.height, 0.3), Vector3.new(x, y0 + R.height / 2, R.z), steel)
		end
	end
	model.Parent = base
end

-- Breakwaters (code-built granite until a kit lands): the greybox arm / head boxes become the granite core of the
-- dog-legged arm (arm, a new <Side>Elbow box, head), their top dropped under the kit setts (Y 4) and their harbour
-- side tucked behind the kit wall face; a coursed parapet with a coping and piers at the bends runs along the
-- seaward edge, cast-iron lamp standards every 40 studs behind it; the west pierhead gets a red light tower (IALA A
-- port hand; the east pierhead has the Harbour Light).
local GRANITE = {
	Color3.fromRGB(150, 146, 138),
	Color3.fromRGB(138, 134, 127),
	Color3.fromRGB(162, 157, 147),
	Color3.fromRGB(128, 125, 120),
}
local IRON = Color3.fromRGB(32, 36, 38)
local LAMP_GLOW = Color3.fromRGB(255, 214, 150)
local function buildBreakwater(base: Instance, map: Instance?)
	local B = Harbour.BREAKWATER
	local wall = map and map:FindFirstChild("Breakwater")
	if not wall then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Harbour_BreakwaterDress"
	local rng = Random.new(1871)
	local function block(size: Vector3, cf: CFrame, colour: Color3, mat: Enum.Material?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = mat or Enum.Material.Granite
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local function cylinder(
		len: number,
		dia: number,
		at_: Vector3,
		colour: Color3,
		mat: Enum.Material
	)
		local p = block(
			Vector3.new(len, dia, dia),
			CFrame.new(at_) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			mat
		)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local top = Harbour.QUAY_Y - 0.05
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "West" else "East"
		local arm, head = wall:FindFirstChild(`{tag}Arm`), wall:FindFirstChild(`{tag}Head`)
		if not (arm and arm:IsA("BasePart") and head and head:IsA("BasePart")) then
			continue
		end
		local floor = arm.Position.Y - arm.Size.Y / 2
		local elbow = arm:Clone()
		elbow.Name = `{tag}Elbow`
		elbow.Parent = wall
		local P = Harbour.breakwaterLine(side)
		for i, part in { arm, elbow, head } :: { BasePart } do
			local a, b = P[i], P[i + 1]
			local dir = (b - a).Unit
			-- overlap the bends by half a width (closes the outer corner); root and mouth ends stay put
			local a2 = if i == 1 then a else a - dir * B.w / 2
			local b2 = if i == 3 then b else b + dir * B.w / 2
			local mid = (a2 + b2) / 2 - inward(a, b) * 0.25 -- harbour side 0.5 behind the kit face
			local y = (top + floor) / 2
			part.Size = Vector3.new(B.w - 0.5, top - floor, (b2 - a2).Magnitude)
			part.CFrame = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(b2.X, y, b2.Z))
			part.Material = Enum.Material.Granite
			part.Color = GRANITE[1]
		end
		-- the parapet along the seaward edge: two staggered courses of dressed blocks, a coping, a pier at each bend
		local L = Harbour.breakwaterOffset(side, -(B.w / 2 - 1.5))
		for i = 1, #L - 1 do
			local a = Vector3.new(L[i].X, top, L[i].Z)
			local b = Vector3.new(L[i + 1].X, top, L[i + 1].Z)
			local len = (b - a).Magnitude
			local frame = CFrame.lookAt(a, b) -- local -Z along the run
			for course = 0, 1 do
				local d = if course == 1 then -2.25 else 0
				while d < len do
					local s0 = math.max(d, 0)
					local l = math.min(4.5, len - s0, d + 4.5 - s0)
					if l > 0.2 then
						block(
							Vector3.new(2.9, 1.48, l - 0.12),
							frame * CFrame.new(0, 0.75 + course * 1.5, -(s0 + l / 2)),
							GRANITE[rng:NextInteger(1, #GRANITE)]
						)
					end
					d += 4.5
				end
			end
			block(Vector3.new(3.4, 0.5, len), frame * CFrame.new(0, 3.25, -len / 2), GRANITE[3])
			if i > 1 then
				block(Vector3.new(3.8, 3.9, 3.8), frame * CFrame.new(0, 1.95, 0), GRANITE[4])
				block(Vector3.new(4.2, 0.5, 4.2), frame * CFrame.new(0, 4.1, 0), GRANITE[3])
			end
		end
		-- lamp standards: a granite plinth, an iron column and a lantern, lit (shadowless) day and night
		for _, l in Harbour.breakwaterLamps(side) do
			local p = Vector3.new(l.pos.X, top, l.pos.Z)
			block(Vector3.new(1.6, 0.8, 1.6), CFrame.new(p + Vector3.new(0, 0.4, 0)), GRANITE[2])
			cylinder(9, 0.45, p + Vector3.new(0, 5.3, 0), IRON, Enum.Material.Metal)
			block(
				Vector3.new(0.9, 0.3, 0.9),
				CFrame.new(p + Vector3.new(0, 9.85, 0)),
				IRON,
				Enum.Material.Metal
			)
			local glass = block(
				Vector3.new(1.1, 1.5, 1.1),
				CFrame.new(p + Vector3.new(0, 10.75, 0)),
				LAMP_GLOW,
				Enum.Material.Glass
			)
			glass.CanCollide = false
			glass.CastShadow = false
			block(
				Vector3.new(1.5, 0.3, 1.5),
				CFrame.new(p + Vector3.new(0, 11.65, 0)),
				IRON,
				Enum.Material.Metal
			)
			local light = Instance.new("PointLight")
			light.Color = LAMP_GLOW
			light.Range = 18
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = glass
		end
	end
	-- the west pierhead light: a white granite tower with a red band, an iron gallery and a red lantern
	local lx, lz = -(B.mouth + 6), B.far
	local p = Vector3.new(lx, top, lz)
	block(Vector3.new(6.4, 1, 6.4), CFrame.new(p + Vector3.new(0, 0.5, 0)), GRANITE[2])
	cylinder(
		10,
		4.6,
		p + Vector3.new(0, 6, 0),
		Color3.fromRGB(236, 234, 228),
		Enum.Material.Plaster
	)
	cylinder(
		2.2,
		4.7,
		p + Vector3.new(0, 10, 0),
		Color3.fromRGB(196, 38, 34),
		Enum.Material.Plaster
	)
	cylinder(0.4, 6.4, p + Vector3.new(0, 11.2, 0), IRON, Enum.Material.Metal)
	local lantern = cylinder(
		2.6,
		2.6,
		p + Vector3.new(0, 12.7, 0),
		Color3.fromRGB(230, 44, 36),
		Enum.Material.Neon
	)
	lantern.CastShadow = false
	block(
		Vector3.new(3.2, 0.5, 3.2),
		CFrame.new(p + Vector3.new(0, 14.25, 0)),
		IRON,
		Enum.Material.Metal
	)
	local finial = block(
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(p + Vector3.new(0, 14.9, 0)),
		IRON,
		Enum.Material.Metal
	)
	finial.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 50)
	light.Range = 30
	light.Brightness = 2.5
	light.Parent = lantern
	model.Parent = base
end

-- r2 art review: the kit wall read as a flat grey slab from the water. Code-built over every straight / ladder-bay
-- piece: a dark weed-stained band at the waterline, granite coping stones proud of the face (not over the ladders),
-- and a tyre fender on a rope every third straight piece. Placeholder art (CLAUDE.md); kit front = local -Z.
local COPING =
	{ Color3.fromRGB(176, 170, 160), Color3.fromRGB(164, 158, 149), Color3.fromRGB(184, 178, 168) }
local function dressWalls(base: Instance, kit: { Placement })
	local model = Instance.new("Model")
	model.Name = "Harbour_WallDress"
	local function block(
		name: string,
		size: Vector3,
		cf: CFrame,
		colour: Color3,
		mat: Enum.Material,
		collide: boolean
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide
		p.CanTouch = false
		p.CanQuery = collide
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = mat
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local n = 0
	for _, p in kit do
		local ladder = p.asset == "M_Hbr_QuayKit_LadderBay"
		if p.asset == "M_Hbr_QuayKit_Straight" or ladder then
			n += 1
			local cf = p.cf
			local top = cf.Position.Y
			-- waterline band: Y -1.4..1.4 (tide and swell wet it), just proud of the face
			local band = block(
				"WetBand",
				Vector3.new(Harbour.GRID + 0.02, 2.8, 0.2),
				cf * CFrame.new(0, Harbour.SEA_Y - top, -0.18),
				Color3.fromRGB(46, 54, 44),
				Enum.Material.Granite,
				false
			)
			band.CastShadow = false
			if not ladder then
				for i, x in { -2.25, 2.25 } do
					block(
						"Coping",
						Vector3.new(4.42, 0.45, 1.3),
						cf * CFrame.new(x, 0.22, 0.35),
						COPING[(n + i) % #COPING + 1],
						Enum.Material.Granite,
						true
					)
				end
				if n % 3 == 0 then
					local tyre = block(
						"Fender",
						Vector3.new(0.7, 2.4, 2.4),
						cf
							* CFrame.new(0, 2 - top + Harbour.SEA_Y, -0.65)
							* CFrame.Angles(0, math.pi / 2, 0),
						Color3.fromRGB(26, 26, 28),
						Enum.Material.Rubber,
						false
					)
					tyre.Shape = Enum.PartType.Cylinder
					local hole = block(
						"FenderHole",
						Vector3.new(0.72, 1.1, 1.1),
						tyre.CFrame,
						Color3.fromRGB(8, 8, 9),
						Enum.Material.SmoothPlastic,
						false
					)
					hole.Shape = Enum.PartType.Cylinder
					local ropeLen = top - (Harbour.SEA_Y + 3.2)
					block(
						"FenderRope",
						Vector3.new(0.14, ropeLen, 0.14),
						cf * CFrame.new(0, -ropeLen / 2, -0.4),
						Color3.fromRGB(196, 170, 120),
						Enum.Material.Fabric,
						false
					).CastShadow =
						false
				end
			end
		end
	end
	model.Parent = base
end

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
	buildRail(base) -- the greybox quay edge is the same line, so the rail goes up either way

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

	-- terrain: a dark rubble footing under the pier and along the quay toe so the wall feet (Y -8) bed in (Slate:
	-- pale Rock read as white chunks through the shallow water)
	local tOk, tErr = pcall(function()
		local foot = Harbour.WALL_FOOT + 0.3
		local P = Harbour.PIER
		local pierLen = Harbour.GRID * P.slots + 10
		terrain:FillBlock(
			CFrame.new((P.west + P.east) / 2, (foot - 30) / 2, P.z0 + pierLen / 2),
			Vector3.new(P.east - P.west + 4, foot + 30, pierLen),
			Enum.Material.Slate
		)
		local x0, x1 = Harbour.YARD_QUAY.x0, Harbour.QUAY_X0 + Harbour.GRID * Harbour.QUAY_SLOTS
		terrain:FillBlock(
			CFrame.new((x0 + x1) / 2, (foot - 16) / 2, Harbour.QUAY_FACE_Z + 1.5),
			Vector3.new(x1 - x0, foot + 16, 5),
			Enum.Material.Slate
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
	local wOk, wErr = pcall(function()
		dressWalls(base, kit)
	end)
	if not wOk then
		warn(`[Harbour] wall dressing failed: {wErr}`)
	end
	local bOk, bErr = pcall(function()
		buildBreakwater(base, map)
	end)
	if not bOk then
		warn(`[Harbour] breakwater dressing failed: {bErr}`)
	end
	-- the hospital asset brings its own ramp and pontoon on the rear terrace, which Swaps yaws inland (onto the
	-- grass by Fore Street); the harbour kit's hospital pontoon (x 130) is the real berth, so the built-in one goes
	local hosp = base:FindFirstChild("Hospital")
	if hosp then
		for _, d in hosp:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "Pontoon", 1, true) then
				d:Destroy()
			end
		end
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
	for _, run in Harbour.armourRuns() do
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
		-- Harbour Road jogs onto the quay west of x -30 (south edge z -14, tools/world/layout.py): the box
		-- yields there so the road and its markings are not buried under the greybox
		local JOG_X, JOG_Z = -30, -14
		local x0, x1 = quay.Position.X - quay.Size.X / 2, quay.Position.X + quay.Size.X / 2
		if x0 < JOG_X and JOG_X < x1 and minZ < JOG_Z then
			local west = quay:Clone()
			west.Size = Vector3.new(JOG_X - x0, quay.Size.Y, back - JOG_Z)
			west.CFrame = CFrame.new((x0 + JOG_X) / 2, quay.Position.Y, (JOG_Z + back) / 2)
			west.Parent = quay.Parent
			quay.Size = Vector3.new(x1 - JOG_X, quay.Size.Y, quay.Size.Z)
			quay.CFrame = CFrame.new((JOG_X + x1) / 2, quay.Position.Y, quay.Position.Z)
		end
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
