--!strict
-- SectorSpots (docs/31 B.2): dresses each Shared.Calls.SectorSpots spot with finished M_Prop_HubKit pieces (no new
-- model), scaled up so the silhouette reads from the next zone in: sea stacks, a wreck aground, a lighthouse rock (the
-- hub's atoll and beacon). Each spot's local -Z (the atoll's ramp) faces the ring centre. Rocks and the wreck get an
-- invisible box collider; the atoll and beacon keep HubLandmark's. LOD1 (no studs): these are mostly seen from far.
-- WorldDressingService calls place(base) once at server start; tests/SectorSpots.spec.luau runs build with a fake kit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLandmark = require(script.Parent:WaitForChild("HubLandmark"))
local Spots = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Calls"):WaitForChild("SectorSpots")
)

local SectorSpots = {}

local function at(module: string, x: number, z: number, yaw: number, scale: number): HubLandmark.Row
	return { module = module, x = x, z = z, y = 0, yaw = yaw, scale = scale }
end

local ROCK, STACK, WRECK, BUOY, RAFT = "L05_RockA", "L06_RockB", "L03_Wreck", "L04_Buoy", "L07_Raft"

-- Rows round each spot's centre (studs, local -Z toward the ring centre), all inside its radius and apart (no overlap).
SectorSpots.LAYOUTS = {
	GullStacks = {
		at(STACK, 0, 0, 0, 3), -- 58 tall
		at(ROCK, 95, 40, 120, 2.4),
		at(STACK, -70, 70, 250, 1.8),
		at(ROCK, -30, -95, 60, 1.6),
		at(RAFT, 100, -80, 30, 1.2),
		at(BUOY, 120, 90, 0, 1.5),
		at(BUOY, -140, -30, 0, 1.5),
	},
	WreckShoal = {
		at(WRECK, 0, 0, 25, 3), -- 100 long
		at(ROCK, -85, 50, 200, 2),
		at(STACK, 70, -60, 80, 1.6),
		at(BUOY, 40, -95, 0, 1.4),
		at(BUOY, -45, -90, 0, 1.4),
		at(RAFT, 110, 50, 60, 1),
	},
	StormLight = {
		at(STACK, 110, 30, 30, 2.2),
		at(ROCK, -90, 75, 150, 2),
		at(ROCK, -40, -120, 300, 1.3),
		at(BUOY, 115, -85, 0, 1.3),
		at(BUOY, -140, -20, 0, 1.3),
	},
} :: { [string]: { HubLandmark.Row } }

-- StormLight also stands the hub's atoll and beacon at its centre (scale 1: HubLandmark's colliders assume it).
for i = HubLandmark.BEACON_ROWS, 1, -1 do
	table.insert(SectorSpots.LAYOUTS.StormLight, 1, HubLandmark.LAYOUT[i])
end

local SOLID = { [ROCK] = true, [STACK] = true, [WRECK] = true }

function SectorSpots.build(base: Instance, kit: Model?)
	if not kit then
		warn("[SectorSpots] M_Prop_HubKit did not load: the spots stay open water")
		return
	end
	for _, spot in Spots.Spots do
		local m = HubLandmark.assemble(kit, SectorSpots.LAYOUTS[spot.id], spot.id)
		if m then
			for _, p in m:GetChildren() do
				local part = p :: BasePart
				if SOLID[part.Name] then
					HubLandmark.solid(m, part.Size * Vector3.new(0.7, 1, 0.7), part.CFrame)
				end
			end
			local b = math.rad(spot.bearing)
			local frame = CFrame.new(spot.center)
				* CFrame.Angles(0, math.atan2(math.cos(b), math.sin(b)), 0)
			for _, p in m:GetChildren() do
				local part = p :: BasePart
				part.CFrame = frame * part.CFrame
			end
			m.Parent = base
		end
	end
end

function SectorSpots.place(base: Instance)
	-- required here: AssetLoader doesn't load in Lune
	local AssetLoader =
		require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
	SectorSpots.build(base, AssetLoader.getTemplate("M_Prop_HubKit", "LOD1"))
end

return SectorSpots
