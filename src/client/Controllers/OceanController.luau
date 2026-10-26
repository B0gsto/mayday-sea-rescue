--!strict
-- OceanController: draws the client-side mesh ocean everywhere (no Terrain water).
--
-- Layout, centred on the camera and snapped in whole outer-cell steps so vertices never slide:
--   near patch  EditableMesh grid, full detail, heights exactly Waves.heightAt at every vertex
--               (edge vertices are stitched to the outer ring's edge so there are no cracks)
--   outer ring  coarser EditableMesh grid with a hole the near patch fills; waves fade to flat
--               sea over its outer part so it meets the far plane
--   far plane   four flat SurfaceAppearance strips out to a 700-stud square (Ocean/FarPlane)
--   horizon     sectors from that square out to ~4200 studs: the inner ring in the far plane's
--               material, the outer ring fading to the Atmosphere haze colour (Ocean/Horizon)
-- Round 2 also adds Ocean/Seabed (caustics and depth-tint slices over shallow seabed), takes the
-- water and haze colours from WeatherController (Lighting attributes OceanWaterColor /
-- OceanHazeColor) and publishes its cost on workspace.ClientOcean (attributes StepMs, Tier, Mode).
-- Heights: Waves.heightAt(x, z, t, Weather.getWaveParams(position, t)), t = GetServerTimeNow,
-- the same function physics uses.
-- Look (ocean spike round 1): every ocean MeshPart wears a SurfaceAppearance (src/client/Ocean/
-- OceanSurface: FFT chop normal map, low roughness) with world-locked UVs that drift slowly
-- downwind (High tier), explicit per-vertex normals from the analytic wave gradient, and a
-- per-preset water tint (part.Color; SurfaceAppearance ignores EditableMesh vertex colours). In
-- storms the surface swaps to the rougher streaked material, a coarse foam overlay mesh rises
-- through the water on crests (sunk below the surface elsewhere), and spindrift particles blow
-- downwind near the camera.
-- Quality tier from UserGameSettings.SavedQualityLevel (src/client/Ocean/OceanQuality); rebuilt
-- when the player changes it. If EditableMesh is unavailable, falls back to a low-res grid of
-- Parts (src/client/Ocean/PartGrid) so the game still runs.
--
-- Per-frame budget (High tier, every frame; Medium 30 Hz, Low 15 Hz):
--   ~1665 height samples (1089 near + 576 ring; minus ~128 stitched edge vertices)
--     each: one Weather zone lookup + Waves.COUNT (4) sines          ~0.4-0.6 ms
--   ~1665 EditableMesh:SetPosition + SetColor on bucket changes only   ~0.4-0.6 ms
--   part CFrames only when the grid snaps (6 writes)
--   No tables or closures are created per frame; Vector3 is a value type (no heap allocation).
--
-- API:
--   OceanController.GetVisualHeight(x, z): number  -- surface Y as drawn (last update time), for
--                                                  -- snapping remote hulls on screen
--   OceanController.GetMode(): "Mesh" | "Parts" | "None"

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ocean = script.Parent.Parent:WaitForChild("Ocean")
local FarPlane = require(Ocean:WaitForChild("FarPlane"))
local Flipbooks = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Fx")
		:WaitForChild("Flipbooks")
)
local Horizon = require(Ocean:WaitForChild("Horizon"))
local MeshGrid = require(Ocean:WaitForChild("MeshGrid"))
local OceanQuality = require(Ocean:WaitForChild("OceanQuality"))
local OceanSurface = require(Ocean:WaitForChild("OceanSurface"))
local PartGrid = require(Ocean:WaitForChild("PartGrid"))
local Seabed = require(Ocean:WaitForChild("Seabed"))
local Underwater = require(Ocean:WaitForChild("Underwater"))
local Wake = require(Ocean:WaitForChild("Wake"))
local WaveField = require(Ocean:WaitForChild("WaveField"))

local SEA = WaveField.SEA_LEVEL
local RENDER_STEP_NAME = "MaydayOcean"
local EPS = 1e-6
local TILE = OceanSurface.TILE_STUDS
local DRIFT_SPEED = 0.9 -- studs/s the ripple normal map drifts downwind (High tier) -- tune
local STORM_ON, STORM_OFF = 0.55, 0.45 -- intensity hysteresis for the storm material -- tune
local USE_MESH_OCEAN = false -- see rebuild(): the mesh ocean draws black sheets
local FOAM_SINK = -0.9 -- foam overlay offset where there is no foam (hidden under the water)
local FOAM_LIFT = 0.06 -- foam overlay offset on full-foam crests -- tune
-- Shallows: the seabed depth under the camera lightens the whole sea's tint (never per-part
-- transparency, which drew a hard-edged rectangle over the harbour). -- tune
local CLEAR_DEPTH, OPAQUE_DEPTH, MAX_CLEAR = 4, 30, 0.72
local SPRAY_RATE = 70 -- spindrift particles/s at full storm (High) -- tune
-- Water albedo tints (part.Color under the Overlay SurfaceAppearance). WeatherController publishes
-- the blended preset's WaterColor and Atmosphere colour as Lighting attributes OceanWaterColor /
-- OceanHazeColor; these are the fallbacks. North Atlantic grey-green, darker in storm. -- tune
local TINT_CALM = Color3.fromHex("#36463F")
local TINT_STORM = Color3.fromHex("#232C2B")
local HAZE_DEFAULT = Color3.fromHex("#A9B0B4")
local SHALLOW_TINT = Color3.fromHex("#4F6A66") -- lighter aqua-green over sand (round 4: less olive) -- tune

local OceanController = {}
OceanController.Priority = 50

type Mode = "Mesh" | "Parts" | "None"

local folder: Folder? = nil
local tier: OceanQuality.Tier = OceanQuality.TIERS.High
local mode: Mode = "None"
local building = false
local rebuildQueued = false

local near: MeshGrid.Grid? = nil
local ring: MeshGrid.Grid? = nil
local far: FarPlane.FarPlane? = nil
local foam: MeshGrid.Grid? = nil
local foamLift: { number } = {}
-- Round 4 whitecaps: per-vertex foam that persists after the crest has passed and decays (slowly
-- in a storm, so breaking crests leave wind-aligned streaks). World-locked: when the grid snaps,
-- the values shift with it (foamIndex maps a vertex's integer cell coordinate to its index).
local foamPersist: { number } = {}
local foamSpare: { number } = {}
local foamKey: { number } = {}
local foamIndex: { [number]: number } = {}
local foamT: number? = nil
local FOAM_KEY_SPAN = 4096
-- Crest-top positions from the last foam pass; spindrift is emitted only from these.
local MAX_CRESTS = 48
local crestPos: { Vector3 } = table.create(MAX_CRESTS)
local crestCount = 0
local sprayBudget = 0
local sprayAt = os.clock()
local spray: Part? = nil
local sprayEmitter: ParticleEmitter? = nil
local streakEmitter: ParticleEmitter? = nil -- FX1 crest foam streaks left on the crest (High tier only)
local streakEvery = 0
local underwater: Underwater.Underwater? = nil
local clarity = 0 -- 0 over deep water .. MAX_CLEAR over sand: drives the shallow tint
local depthCheckAt = 0
local surfaceKind = "Calm"
local tint: Color3 = TINT_CALM
local fallback: PartGrid.PartGrid? = nil
local gridHidden = false -- the Part grid hidden for a high camera (FarPlane cap shown)
local horizon: Horizon.Horizon? = nil
local seabed: Seabed.Seabed? = nil
local statsAt = 0

-- Near-patch stitching to the ring edge: vertex n takes lerp(ring[a], ring[b], t) when a > 0.
local stitchA: { number } = {}
local stitchB: { number } = {}
local stitchT: { number } = {}
-- Per ring vertex wave weight (1 inside fadeStart, 0 beyond fadeEnd).
local ringWeight: { number } = {}
local fadeStart = math.huge
local fadeEnd = math.huge

local snapStep = 16
local centreX, centreZ = math.huge, math.huge
local accumulator = 0
local lastT: number? = nil
local frameT = 0
local stepMsAvg = 0 -- exponential average of the ocean update cost (ms), for profiling

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Wave weight at an offset from the grid centre (square rings, so Chebyshev distance).
local function fadeWeight(dx: number, dz: number): number
	local d = math.max(math.abs(dx), math.abs(dz))
	if d <= fadeStart then
		return 1
	elseif d >= fadeEnd then
		return 0
	end
	return 1 - smoothstep(fadeStart, fadeEnd, d)
end

-- Fallback grid height: waves fade to flat at the grid edge so it meets the far plane seamlessly.
local function fallbackHeight(x: number, z: number): number
	return SEA + (WaveField.heightAt(x, z, frameT) - SEA) * fadeWeight(x - centreX, z - centreZ)
end

local function teardown()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	if near then
		MeshGrid.destroy(near)
		near = nil
	end
	if ring then
		MeshGrid.destroy(ring)
		ring = nil
	end
	if far then
		FarPlane.destroy(far)
		far = nil
	end
	if fallback then
		PartGrid.destroy(fallback)
		fallback = nil
	end
	if horizon then
		Horizon.destroy(horizon)
		horizon = nil
	end
	if seabed then
		Seabed.destroy(seabed)
		seabed = nil
	end
	if foam then
		MeshGrid.destroy(foam)
		foam = nil
	end
	if underwater then
		Underwater.destroy(underwater)
		underwater = nil
	end
	if spray then
		spray:Destroy()
		spray = nil
		sprayEmitter = nil
		streakEmitter = nil
	end
	table.clear(foamLift)
	table.clear(foamPersist)
	table.clear(foamSpare)
	table.clear(foamKey)
	table.clear(foamIndex)
	foamT = nil
	table.clear(stitchA)
	table.clear(stitchB)
	table.clear(stitchT)
	table.clear(ringWeight)
	fadeStart, fadeEnd = math.huge, math.huge
	centreX, centreZ = math.huge, math.huge
	mode = "None"
end

-- Maps near-patch edge vertices onto the ring's hole edge (both grids share the same centre).
local function buildStitching(nearGrid: MeshGrid.Grid, ringGrid: MeshGrid.Grid)
	local cell = ringGrid.cellSize
	for n = 1, nearGrid.count do
		local x, z = nearGrid.lx[n], nearGrid.lz[n]
		local onEdge = math.abs(math.abs(x) - nearGrid.half) < EPS
			or math.abs(math.abs(z) - nearGrid.half) < EPS
		stitchA[n], stitchB[n], stitchT[n] = 0, 0, 0
		if onEdge then
			local fi = (x + ringGrid.half) / cell
			local fj = (z + ringGrid.half) / cell
			local ia, ja = math.floor(fi + EPS), math.floor(fj + EPS)
			local ti, tj = fi - ia, fj - ja
			local ib, jb = ia, ja
			local t = 0
			if ti > EPS then
				ib, t = ia + 1, ti
			elseif tj > EPS then
				jb, t = ja + 1, tj
			end
			local a = ringGrid.index[MeshGrid.latticeKey(ringGrid, ia, ja)]
			local b = ringGrid.index[MeshGrid.latticeKey(ringGrid, ib, jb)]
			if a and b and a > 0 and b > 0 then
				stitchA[n], stitchB[n], stitchT[n] = a, b, t
			end
		end
	end
end

local function buildMesh(parent: Instance): boolean
	local nearGrid, nearErr =
		MeshGrid.new("OceanNear", parent, tier.nearCells, tier.nearCell, 0, surfaceKind, true)
	if not nearGrid then
		warn(`[Ocean] EditableMesh unavailable ({nearErr}); using the Part-grid fallback`)
		return false
	end
	near = nearGrid
	local ringGrid, ringErr = MeshGrid.new(
		"OceanRing",
		parent,
		tier.outerCells,
		tier.outerCell,
		tier.holeCells,
		surfaceKind
	)
	if ringGrid then
		ring = ringGrid
		local holeHalf = nearGrid.half
		fadeStart = holeHalf + 0.35 * (ringGrid.half - holeHalf) -- tune
		fadeEnd = ringGrid.half - ringGrid.cellSize -- last ring cell is flat sea
		for n = 1, ringGrid.count do
			ringWeight[n] = fadeWeight(ringGrid.lx[n], ringGrid.lz[n])
		end
		buildStitching(nearGrid, ringGrid)
		far = FarPlane.new(parent, ringGrid.half, SEA, surfaceKind, Horizon.INNER_HALF)
	else
		warn(`[Ocean] outer ring unavailable ({ringErr}); near patch only`)
		far = FarPlane.new(parent, nearGrid.half, SEA, surfaceKind, Horizon.INNER_HALF)
	end
	horizon = Horizon.new(parent, SEA, tint, HAZE_DEFAULT, surfaceKind)
	seabed = Seabed.new(parent)
	if tier.name ~= "Low" then
		-- Foam overlay: half the near patch's resolution; round 4 widens it (up to twice the near
		-- patch, inside the ring's unfaded area) so whitecaps reach past the boat in wide shots.
		local foamCell = tier.nearCell * 2
		local foamCells = math.clamp(
			math.floor(tier.outerCells * tier.outerCell * 0.8 / foamCell),
			tier.nearCells // 2,
			tier.nearCells
		)
		local foamGrid = MeshGrid.new("OceanFoam", parent, foamCells, foamCell, 0, "Foam")
		if foamGrid then
			foam = foamGrid
			foamGrid.part.Transparency = 1
			for n = 1, foamGrid.count do
				foamLift[n] = FOAM_SINK
				foamPersist[n], foamSpare[n] = 0, 0
				local key = (math.floor(foamGrid.lx[n] / foamCell + 0.5) + FOAM_KEY_SPAN // 2)
						* FOAM_KEY_SPAN
					+ math.floor(foamGrid.lz[n] / foamCell + 0.5)
					+ FOAM_KEY_SPAN // 2
				foamKey[n] = key
				foamIndex[key] = n
			end
		end
	end
	underwater = Underwater.new(parent)
	local sprayPart = Instance.new("Part")
	sprayPart.Name = "OceanSpray"
	sprayPart.Anchored = true
	sprayPart.CanCollide = false
	sprayPart.CanQuery = false
	sprayPart.CanTouch = false
	sprayPart.Transparency = 1
	sprayPart.Size = Vector3.new(3, 0.5, 3) -- one crest's lip; moved to a crest per burst
	local emitter = Instance.new("ParticleEmitter")
	-- FX1 spindrift: wind-torn crest spray (Mantaflow mist + droplet sim, 8x8 OneShot per particle)
	Flipbooks.apply(emitter, "FX_Spray_Spindrift")
	local sheet = if Flipbooks.uploaded("FX_Spray_Spindrift") then 1.6 else 1
	emitter.Color = ColorSequence.new(Color3.fromHex("#DCE2E1"))
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9 * sheet),
		NumberSequenceKeypoint.new(1, 4.5 * sheet),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.9, 1.8)
	emitter.Speed = NumberRange.new(5, 11)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Drag = 1.2
	-- the sheet's streamers run level: keep the billboards near upright
	emitter.Rotation = if sheet > 1 then NumberRange.new(-8, 8) else NumberRange.new(0, 360)
	emitter.RotSpeed = if sheet > 1 then NumberRange.new(-6, 6) else NumberRange.new(-40, 40)
	emitter.Rate = 0
	emitter.Parent = sprayPart
	if Flipbooks.uploaded("FX_Foam_CrestStreak") then
		local streak = Instance.new("ParticleEmitter")
		Flipbooks.apply(streak, "FX_Foam_CrestStreak")
		streak.Color = ColorSequence.new(Color3.fromHex("#E4EAE8"))
		streak.Orientation = Enum.ParticleOrientation.VelocityPerpendicular -- lies flat on the water
		streak.EmissionDirection = Enum.NormalId.Top
		streak.Speed = NumberRange.new(0.05)
		streak.Drag = 4
		streak.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 3),
			NumberSequenceKeypoint.new(1, 6.5),
		})
		streak.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		streak.Lifetime = NumberRange.new(2.5, 4)
		streak.Rotation = NumberRange.new(-15, 15)
		streak.Rate = 0
		streak.Parent = sprayPart
		streakEmitter = streak
	end
	sprayPart.Parent = parent
	spray = sprayPart
	sprayEmitter = emitter
	snapStep = tier.outerCell
	mode = "Mesh"
	return true
end

local function buildFallback(parent: Instance)
	local grid = PartGrid.new(parent, tier.fallbackCells, tier.fallbackCell)
	fallback = grid
	gridHidden = false
	fadeStart, fadeEnd = grid.half * 0.6, grid.half -- tune
	-- All Parts in the grid's material: a SurfaceAppearance far sea never matched it (map pass 3 N1).
	far = FarPlane.new(parent, grid.half, SEA, surfaceKind, Horizon.INNER_HALF, false)
	horizon = Horizon.new(parent, SEA, tint, HAZE_DEFAULT, surfaceKind, true)
	snapStep = tier.fallbackCell
	underwater = Underwater.new(parent) -- a snorkel face-down or a dived sub
	mode = "Parts"
end

-- Grid snapped by (dx, dz) studs: carry the persistent foam with the world (cleared if the step is
-- not a whole number of foam cells, e.g. the first placement).
local function shiftFoam(dx: number, dz: number)
	local grid = foam
	if not grid or #foamPersist == 0 then
		return
	end
	local di, dj = dx / grid.cellSize, dz / grid.cellSize
	local old, new = foamPersist, foamSpare
	if
		di ~= di
		or dj ~= dj
		or di % 1 ~= 0
		or dj % 1 ~= 0
		or math.abs(di) > 64
		or math.abs(dj) > 64
	then
		for n = 1, grid.count do
			old[n] = 0
		end
		return
	end
	local offset = di * FOAM_KEY_SPAN + dj
	for n = 1, grid.count do
		local src = foamIndex[foamKey[n] + offset]
		new[n] = if src then old[src] else 0
	end
	foamPersist, foamSpare = new, old
end

-- Writes every vertex for time t. Allocation-free.
local function updateMesh(t: number, ou: number, ov: number, fu: number, fv: number)
	local ringGrid = ring
	if ringGrid then
		local heights, gxs, gzs, lx, lz =
			ringGrid.heights, ringGrid.gx, ringGrid.gz, ringGrid.lx, ringGrid.lz
		for n = 1, ringGrid.count do
			local w = ringWeight[n]
			if w > 0 then
				local h, gx, gz = WaveField.gradientAt(centreX + lx[n], centreZ + lz[n], t)
				heights[n] = SEA + (h - SEA) * w
				gxs[n], gzs[n] = gx * w, gz * w
			else
				heights[n] = SEA
				gxs[n], gzs[n] = 0, 0
			end
		end
		MeshGrid.apply(ringGrid, SEA, ou, ov)
	end
	local nearGrid = near
	if nearGrid then
		local heights, gxs, gzs, lx, lz =
			nearGrid.heights, nearGrid.gx, nearGrid.gz, nearGrid.lx, nearGrid.lz
		local ringHeights = if ringGrid then ringGrid.heights else nil
		for n = 1, nearGrid.count do
			local h, gx, gz = WaveField.gradientAt(centreX + lx[n], centreZ + lz[n], t)
			local a = stitchA[n]
			if ringHeights and a and a > 0 then
				local ha = ringHeights[a]
				h = ha + (ringHeights[stitchB[n]] - ha) * stitchT[n]
			end
			heights[n], gxs[n], gzs[n] = h, gx, gz
		end
		MeshGrid.apply(nearGrid, SEA, ou, ov)
	end
	local foamGrid = foam
	if foamGrid then
		local intensity = WaveField.intensity()
		-- Whitecaps in every weather (the North Atlantic is never glassy): rare breaking peaks on
		-- calm swell, most crests breaking in a storm. Fresh foam is driven by crest height plus
		-- the steepness of the downwind (front) face, so it sits on the crest lip and spills down
		-- the face; it then persists and decays, slowly in a storm, broken into wind-aligned
		-- streaks. Crest vertices feed the spindrift (crests only).
		-- not 0: an opaque MeshPart ignores its TextureID alpha and the foam draws as a solid sheet
		foamGrid.part.Transparency = 0.02
		crestCount = 0
		local dt = if foamT then math.clamp(t - foamT, 0, 0.5) else 0
		foamT = t
		local amp = math.max(WaveField.maxAmplitude(), 0.1)
		-- Max slope of the sine sum (sum of k * A): about 0.22 calm, 0.29 storm.
		local slopeMax = 0.22 + 0.07 * intensity
		local wx, wz = WaveField.windDirection()
		local heights, gxs, gzs, lx, lz =
			foamGrid.heights, foamGrid.gx, foamGrid.gz, foamGrid.lx, foamGrid.lz
		local edge = foamGrid.half - foamGrid.cellSize * 0.5
		-- Breaking threshold drops and coverage rises as the storm builds. -- tune
		local lo = 0.92 - 0.5 * intensity
		local cover = 0.55 + 0.45 * math.min(intensity * 1.6, 1)
		local decay = math.exp(-dt / (0.5 + 4 * intensity)) -- foam half-life ~0.35 s calm, ~3 s storm
		local streakAmt = 0.25 + 0.75 * intensity
		local persist = foamPersist
		for n = 1, foamGrid.count do
			local x, z = centreX + lx[n], centreZ + lz[n]
			local h, gx, gz = WaveField.gradientAt(x, z, t)
			local w = fadeWeight(lx[n], lz[n])
			local hN = (h - SEA) / amp
			local face = math.max(-(gx * wx + gz * wz), 0) / slopeMax
			local steep = math.sqrt(gx * gx + gz * gz) / slopeMax
			local fresh = smoothstep(lo, lo + 0.24, hN + 0.32 * face + 0.12 * steep) * cover * w
			local p = math.max(fresh, persist[n] * decay)
			persist[n] = p
			-- Remnant foam: world-locked bands across the wind, wavy along it (streaks).
			local across, along = x * -wz + z * wx, x * wx + z * wz
			local band = 0.5
				+ 0.5 * math.sin(across * 0.85 + 1.8 * math.sin(along * 0.045 + across * 0.11))
			local f = math.max(fresh, p * smoothstep(0.3, 0.85, band) * streakAmt)
			if math.abs(lx[n]) > edge or math.abs(lz[n]) > edge then
				f = 0 -- keep the overlay's border under the water
			elseif fresh > 0.6 and crestCount < MAX_CRESTS and (n % 3 == 0) then
				crestCount += 1
				crestPos[crestCount] = Vector3.new(x, h + 0.4, z)
			end
			heights[n] = SEA + (h - SEA) * w
			gxs[n], gzs[n] = gx * w, gz * w
			foamLift[n] = FOAM_SINK + (FOAM_LIFT - FOAM_SINK) * math.min(f * 2.2, 1)
		end
		MeshGrid.apply(foamGrid, SEA, fu, fv, foamLift)
	end
end

-- Storm material swap, water tint and spindrift rate; cheap, runs with every update.
local function updateLook()
	local intensity = WaveField.intensity()
	local kind = surfaceKind
	if intensity >= STORM_ON then
		kind = "Storm"
	elseif intensity <= STORM_OFF then
		kind = "Calm"
	end
	if kind ~= surfaceKind then
		surfaceKind = kind
		if near then
			OceanSurface.attach(near.part, kind)
		end
		if ring then
			OceanSurface.attach(ring.part, kind)
		end
		if far then
			FarPlane.setSurface(far, kind)
		end
		if horizon then
			Horizon.setSurface(horizon, kind)
		end
	end
	local water = Lighting:GetAttribute("OceanWaterColor")
	local haze = Lighting:GetAttribute("OceanHazeColor")
	local deepTint = if typeof(water) == "Color3"
		then water
		else TINT_CALM:Lerp(TINT_STORM, math.clamp(intensity, 0, 1))
	-- Over sand the surface reads lighter and greener (clarity is 0 over deep water).
	local newTint = deepTint:Lerp(SHALLOW_TINT, clarity / MAX_CLEAR * 0.5)
	if horizon then
		Horizon.setColours(
			horizon,
			newTint, -- the same tint as the far plane it meets
			if typeof(haze) == "Color3" then haze else HAZE_DEFAULT
		)
	end
	if newTint ~= tint or (near and near.part.Color ~= newTint) then
		tint = newTint
		if near then
			near.part.Color = newTint
		end
		if ring then
			ring.part.Color = newTint
		end
		if far then
			for _, part in far.parts do
				part.Color = newTint
			end
		end
	end
	-- Seabed depth under the camera (terrain raycast twice a second) -> surface transparency.
	local now = os.clock()
	if now >= depthCheckAt then
		depthCheckAt = now + 0.5
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain }
		-- The near tile is 128 studs across: sample a 3x3 grid over it and take the deepest point, so
		-- a camera over the shallow quay never turns the whole tile clear above deep, dark water (a
		-- dark glossy rectangle next to the dock).
		local depth = -math.huge
		for ox = -48, 48, 48 do
			for oz = -48, 48, 48 do
				local hit = Workspace:Raycast(
					Vector3.new(centreX + ox, SEA + 4, centreZ + oz),
					Vector3.new(0, -400, 0),
					params
				)
				depth = math.max(depth, if hit then SEA - hit.Position.Y else math.huge)
			end
		end
		local target = MAX_CLEAR * (1 - smoothstep(CLEAR_DEPTH, OPAQUE_DEPTH, depth))
		-- Tint only: a see-through near tile and ring over an opaque far plane drew a hard-edged
		-- light rectangle over the harbour basin (Transparency is per part, not per vertex).
		if math.abs(target - clarity) > 0.01 then
			clarity = target
		end
	end
	local emitter = sprayEmitter
	if emitter then
		local s = math.clamp((intensity - 0.35) / 0.65, 0, 1)
		local tierScale = Flipbooks.scale("spray", tier.name) -- docs/06 3.5: Full / Half / Quarter
		-- Manual emission from crest tops only (the part hops to a crest per burst).
		emitter.Rate = 0
		local now2 = os.clock()
		sprayBudget = math.min(sprayBudget + SPRAY_RATE * s * s * tierScale * (now2 - sprayAt), 40)
		sprayAt = now2
		local wx, wz = WaveField.windDirection()
		emitter.Acceleration = Vector3.new(wx * 38, -29.4, wz * 38)
		local sprayP = spray
		if sprayP and crestCount > 0 then
			while sprayBudget >= 1 do
				sprayBudget -= 1
				sprayP.CFrame = CFrame.new(crestPos[math.random(1, crestCount)])
				emitter:Emit(1)
				local streak = streakEmitter
				streakEvery += 1
				if streak and streakEvery >= 3 and Flipbooks.scale("crestFoam", tier.name) > 0 then
					streakEvery = 0
					streak.Rotation = NumberRange.new(
						math.deg(math.atan2(wz, wx)) - 15,
						math.deg(math.atan2(wz, wx)) + 15
					)
					streak:Emit(1)
				end
			end
		elseif crestCount == 0 then
			sprayBudget = 0
		end
	end
end

local function moveParts()
	local cf = CFrame.new(centreX, SEA, centreZ)
	if near then
		near.part.CFrame = cf
	end
	if ring then
		ring.part.CFrame = cf
	end
	if foam then
		-- the foam heights are sampled around (centreX, centreZ); left at the origin it drew a
		-- misplaced opaque sheet over the harbour quay (black sea patches, 2026-10-22)
		foam.part.CFrame = cf
	end
	if far then
		FarPlane.moveTo(far, centreX, centreZ)
	end
	if horizon then
		Horizon.moveTo(horizon, centreX, centreZ)
	end
	if spray then
		spray.CFrame = CFrame.new(centreX, SEA + 2.5, centreZ)
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera or mode == "None" then
		return
	end
	local pos = camera.CFrame.Position
	if underwater then -- every frame (not at the tier rate): its fog slices ride the camera
		Underwater.update(underwater, camera, OceanController.GetVisualHeight(pos.X, pos.Z))
	end
	local cx = math.floor(pos.X / snapStep + 0.5) * snapStep
	local cz = math.floor(pos.Z / snapStep + 0.5) * snapStep
	local snapped = cx ~= centreX or cz ~= centreZ
	accumulator += dt
	local interval = if tier.updateHz > 0 then 1 / tier.updateHz else 0
	if not snapped and accumulator < interval then
		return
	end
	accumulator = if interval > 0 then accumulator % interval else 0

	local clock0 = os.clock()
	local t = Workspace:GetServerTimeNow()
	frameT = t
	lastT = t
	WaveField.beginFrame(t, pos)
	if horizon then
		-- island hilltops, the lookout tower and bridge decks put a walking camera at 40-65 studs,
		-- where the 4,200-stud horizon square showed against the sky: the skirt comes on from 25 up
		Horizon.setHigh(horizon, pos.Y > SEA + 25)
	end
	if snapped then
		shiftFoam(cx - centreX, cz - centreZ)
		centreX, centreZ = cx, cz
		moveParts()
	end
	if mode == "Mesh" then
		-- World-locked UV offset in studs, plus a slow downwind drift on High (wraps per tile).
		-- The foam texture is wind-blown, so it drifts twice as fast as the ripples.
		local ou, ov = centreX % TILE, centreZ % TILE
		local fu, fv = ou, ov
		if tier.updateHz == 0 then
			local wx, wz = WaveField.windDirection()
			local d = DRIFT_SPEED * (t % 100000)
			ou, ov = (ou - wx * d) % TILE, (ov - wz * d) % TILE
			fu, fv = (fu - wx * 2 * d) % TILE, (fv - wz * 2 * d) % TILE
		end
		updateMesh(t, ou, ov, fu, fv)
		if far then
			FarPlane.setUV(far, ou, ov)
		end
		updateLook()
		local surfaceY = OceanController.GetVisualHeight(pos.X, pos.Z)
		local bed = seabed
		if bed then
			Seabed.update(bed, centreX, centreZ, SEA, pos.Y < surfaceY - 0.15, tint, t)
		end
		stepMsAvg += ((os.clock() - clock0) * 1000 - stepMsAvg) * 0.05
		-- Published for profiling scripts (they get their own module copy, so GetStats on a
		-- required copy reads 0): workspace.ClientOcean attributes StepMs, Tier, Mode.
		if clock0 >= statsAt and folder then
			statsAt = clock0 + 0.5
			folder:SetAttribute("StepMs", math.floor(stepMsAvg * 1000 + 0.5) / 1000)
			folder:SetAttribute("Tier", tier.name)
			folder:SetAttribute("Mode", mode)
		end
	elseif fallback then
		-- from the air (as the horizon skirt) the far plane's cap stands in for the wave grid: its wedge lattice
		-- read as a square of white dots
		local high = pos.Y > SEA + 60
		if high ~= gridHidden then
			gridHidden = high
			for _, p in fallback.parts do
				p.LocalTransparencyModifier = if high then 1 else 0
			end
			if far then
				FarPlane.setCap(far, high)
			end
		end
		PartGrid.update(fallback, centreX, centreZ, SEA, fallbackHeight, tint)
		updateLook()
	end
end

local function build()
	if building then
		rebuildQueued = true
		return
	end
	building = true
	repeat
		rebuildQueued = false
		teardown()
		tier = OceanQuality.current()
		local parent = folder :: Folder
		-- shortcut: always the Part grid. The EditableMesh near/ring patches intermittently draw large
		-- pure-black sheets (2026-10-23: 8/12 Studio shots, foam overlay on or off; 0/8 on Parts).
		-- Set USE_MESH_OCEAN once that's fixed; Studio attribute OceanForceParts still forces Parts.
		local forceParts = not USE_MESH_OCEAN
			or RunService:IsStudio() and Workspace:GetAttribute("OceanForceParts") == true
		if forceParts or not buildMesh(parent) then
			teardown()
			buildFallback(parent)
		end
		print(`[Ocean] {mode} ocean, {tier.name} tier`)
	until not rebuildQueued
	-- after every camera writer (CameraController +1, capture tour cams): at Camera + 1 a photo
	-- camera left the wave patch behind at the player, a square of white dots in the harbour seen from the air
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value - 1, step)
	building = false
end

function OceanController.Init()
	local f = Instance.new("Folder")
	f.Name = "ClientOcean"
	f.Parent = Workspace
	folder = f
end

function OceanController.Start()
	OceanQuality.onChanged(function()
		task.spawn(build)
	end)
	Wake.start(SEA) -- hull foam and wake trails behind boats (Ocean/Wake)
	build() -- yields (CreateMeshPartAsync)
end

-- Surface Y as currently drawn at (x, z): the shared wave function at the last update time,
-- with the outer-ring fade applied. Matches the mesh exactly at near-patch vertices.
function OceanController.GetVisualHeight(x: number, z: number): number
	local t = lastT or Workspace:GetServerTimeNow()
	local h = WaveField.heightAt(x, z, t)
	if mode == "None" then
		return h
	end
	return SEA + (h - SEA) * fadeWeight(x - centreX, z - centreZ)
end

function OceanController.GetMode(): Mode
	return mode
end

return OceanController
