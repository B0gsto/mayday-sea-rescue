--!strict
-- Conveyors (convey1, owner 2026-10-29: "conveyor belts to go around to other people faster and inside your island"):
-- Lego moving walkways that carry a walking player. One ring of two-lane belts (keep right) runs the whole ring:
-- along every bridge deck and across every island on the bridge road, bridge foot to bridge foot; each island also
-- gets a spur from that road up the clear strip west of the HQ to the plaza (beside the prize wheel, near the jetty
-- head and the build tablet). A classic Roblox conveyor: anchored lanes with AssemblyLinearVelocity along the lane
-- (ConveyorController re-applies it on each client and scrolls the chevrons, plays the hum). Each straight is one
-- blue bed (the skirts and the divider show round the lanes) and two dark rubber lanes; flat legs reach past a bend
-- so the outer corner has no gap. Only humanoids walk here: workers, survivors and the dog are client-posed.
-- WorldDressingService calls Conveyors.place(base) once at server start; tests/Conveyors.spec.luau keeps them clear.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RingLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RingLayout")
)

local Conveyors = {}

Conveyors.SPEED = 12 -- studs/s: StarterPlayer.CharacterWalkSpeed, so riding while walking is 2x a walk
Conveyors.TAG = "BeltLane"
local LANE_W, GAP = 4.4, 0.6 -- each lane, and the bed's divider strip between the two
local BED_W, BED_H, LANE_H = 10, 0.5, 0.2 -- fits inside the bridge deck's 11 (its rails stand at +-5.6)
local OFF = (GAP + LANE_W) / 2 -- lane centre from the bed centre
local SPUR_R, SPUR_END = -48, 12 -- island frame: west of the HQ (|r| <= 27), east of the Depot stub (r -73..-65)

local BED = Color3.fromRGB(40, 96, 208) -- Lego blue (the bridge beam)
local RUBBER = Color3.fromRGB(39, 42, 49)
local CAP = Color3.fromRGB(163, 162, 165) -- light bluish grey roller
local CHEVRON = "rbxassetid://136235158774044" -- art/source/ui/belt_chevron.svg
local MAT = Enum.Material.SmoothPlastic

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = MAT
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function texture(
	p: Part,
	name: string,
	id: string,
	u: number,
	v: number,
	color: Color3,
	alpha: number
)
	local t = Instance.new("Texture")
	t.Name = name
	t.Face = Enum.NormalId.Top
	t.Texture = id
	t.StudsPerTileU, t.StudsPerTileV = u, v
	t.Color3 = color
	t.Transparency = alpha
	t.Parent = p
end

-- one straight: the bed on the ground from a to b (ground-top points), extended `e0` / `e1` studs past each end,
-- and a lane either side of the divider, each running its own way (LookVector = travel; right-hand traffic)
local function leg(parent: Instance, a: Vector3, b: Vector3, e0: number, e1: number)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude + e0 + e1
	local mid = (a + b) / 2 + dir * (e1 - e0) / 2
	local base = CFrame.lookAt(mid, mid + dir)
	part(parent, "BeltBed", Vector3.new(BED_W, BED_H, len), base * CFrame.new(0, BED_H / 2, 0), BED)
	for _, side in { 1, -1 } do
		local cf = base * CFrame.new(side * OFF, BED_H + LANE_H / 2, 0)
		if side < 0 then
			cf *= CFrame.Angles(0, math.pi, 0) -- the left lane runs back
		end
		local lane = part(parent, "BeltLane", Vector3.new(LANE_W, LANE_H, len - 0.1), cf, RUBBER)
		lane.AssemblyLinearVelocity = cf.LookVector * Conveyors.SPEED
		lane:SetAttribute("BeltSpeed", Conveyors.SPEED)
		texture(lane, "Chevron", CHEVRON, LANE_W, 4, Color3.fromRGB(236, 238, 242), 0.15)
		lane:AddTag(Conveyors.TAG)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z).Unit
end

-- a closed or open polyline of legs. A flat leg reaches past a bend by the bed's half width x tan(turn / 2) so the
-- outer corner is covered; a sloped leg (the bridge ramps) stops at its end, except between the crest's chords.
local function run(parent: Instance, pts: { Vector3 }, closed: boolean)
	local n = #pts
	local legs = if closed then n else n - 1
	local function at(i: number): Vector3?
		if closed then
			return pts[(i - 1) % n + 1]
		end
		return pts[i]
	end
	local function reach(self0: Vector3, self1: Vector3, other0: Vector3?, other1: Vector3?): number
		if not (other0 and other1) then
			return 0
		end
		local turn = math.acos(math.clamp(flat(self1 - self0):Dot(flat(other1 - other0)), -1, 1))
		if math.abs((self1 - self0).Unit.Y) < 1e-3 then
			return BED_W / 2 * math.tan(turn / 2) + 0.1
		end
		return if turn < math.rad(1) then 0.3 else 0
	end
	for k = 1, legs do
		local a, b = at(k) :: Vector3, at(k + 1) :: Vector3
		leg(parent, a, b, reach(a, b, at(k - 1), a), reach(a, b, b, at(k + 2)))
	end
end

-- deck points along a bridge: the two straight ramps whole, the rounded crest in four chords
local function deckTs(br: RingLayout.Bridge): { number }
	local c = RingLayout.BRIDGE.crest / (br.to - br.from).Magnitude
	local ts = { 0 }
	for k = 0, 4 do
		table.insert(ts, 0.5 - c + k * c / 2)
	end
	table.insert(ts, 1)
	return ts
end

-- the ring: bridge i's deck, then the next island's bridge road to bridge i + 1 (closing on itself)
function Conveyors.ringPoints(): { Vector3 }
	local pts = {}
	for _, br in RingLayout.Bridges do
		for _, t in deckTs(br) do
			table.insert(pts, RingLayout.deckAt(br, t))
		end
	end
	return pts
end

-- an island's spur, island frame (right, fwd): from the bridge road's edge up to the plaza, and its plaza end cap
function Conveyors.spurPoints(isl: RingLayout.Island): (Vector3, Vector3)
	local foot = isl.frame:PointToObjectSpace(RingLayout.Bridges[isl.index].from)
	local f0 = -foot.Z + BED_W / 2 -- the road's north edge (both feet sit at the same fwd)
	return (isl.frame * CFrame.new(SPUR_R, 0, -f0)).Position,
		(isl.frame * CFrame.new(SPUR_R, 0, -SPUR_END)).Position
end

function Conveyors.place(base: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Conveyors"
	local ring = Instance.new("Model")
	ring.Name = "Ring"
	ring.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- like the bridges and plates: never dropped mid-ride
	run(ring, Conveyors.ringPoints(), true)
	ring.Parent = folder
	for _, isl in RingLayout.Islands do
		local m = Instance.new("Model")
		m.Name = `Spur{isl.index}`
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local a, b = Conveyors.spurPoints(isl)
		run(m, { a, b }, false)
		local cap = part(
			m,
			"BeltCap",
			Vector3.new(BED_W, 0.8, 0.8),
			CFrame.lookAt(b, b + (b - a).Unit) * CFrame.new(0, 0.4, 0), -- X (the cylinder's axis) across the belt
			CAP
		)
		cap.Shape = Enum.PartType.Cylinder -- the end roller, its axis across the belt
		cap.CanQuery = false
		m.Parent = folder
	end
	folder.Parent = base
end

return Conveyors
