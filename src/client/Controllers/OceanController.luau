--!strict
-- OceanController: draws the client-side mesh ocean everywhere (no Terrain water).
--
-- Layout, centred on the camera and snapped in whole outer-cell steps so vertices never slide:
--   near patch  EditableMesh grid, full detail, heights exactly Waves.heightAt at every vertex
--               (edge vertices are stitched to the outer ring's edge so there are no cracks)
--   outer ring  coarser EditableMesh grid with a hole the near patch fills; waves fade to flat
--               sea over its outer part so it meets the far plane
--   far plane   four flat Deep Teal Parts out towards the horizon (src/client/Ocean/FarPlane)
-- Heights: Waves.heightAt(x, z, t, Weather.getWaveParams(position, t)), t = GetServerTimeNow,
-- the same function physics uses. Colour by height via vertex colours (src/client/Ocean/OceanPalette).
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

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ocean = script.Parent.Parent:WaitForChild("Ocean")
local FarPlane = require(Ocean:WaitForChild("FarPlane"))
local MeshGrid = require(Ocean:WaitForChild("MeshGrid"))
local OceanQuality = require(Ocean:WaitForChild("OceanQuality"))
local PartGrid = require(Ocean:WaitForChild("PartGrid"))
local WaveField = require(Ocean:WaitForChild("WaveField"))

local SEA = WaveField.SEA_LEVEL
local RENDER_STEP_NAME = "MaydayOcean"
local EPS = 1e-6

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
local fallback: PartGrid.PartGrid? = nil

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

local function fallbackGradient(x: number, z: number): (number, number, number)
	return WaveField.gradientAt(x, z, frameT)
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
	local nearGrid, nearErr = MeshGrid.new("OceanNear", parent, tier.nearCells, tier.nearCell, 0)
	if not nearGrid then
		warn(`[Ocean] EditableMesh unavailable ({nearErr}); using the Part-grid fallback`)
		return false
	end
	near = nearGrid
	local ringGrid, ringErr =
		MeshGrid.new("OceanRing", parent, tier.outerCells, tier.outerCell, tier.holeCells)
	if ringGrid then
		ring = ringGrid
		local holeHalf = nearGrid.half
		fadeStart = holeHalf + 0.35 * (ringGrid.half - holeHalf) -- tune
		fadeEnd = ringGrid.half - ringGrid.cellSize -- last ring cell is flat sea
		for n = 1, ringGrid.count do
			ringWeight[n] = fadeWeight(ringGrid.lx[n], ringGrid.lz[n])
		end
		buildStitching(nearGrid, ringGrid)
		far = FarPlane.new(parent, ringGrid.half, SEA)
	else
		warn(`[Ocean] outer ring unavailable ({ringErr}); near patch only`)
		far = FarPlane.new(parent, nearGrid.half, SEA)
	end
	snapStep = tier.outerCell
	mode = "Mesh"
	return true
end

local function buildFallback(parent: Instance)
	local grid = PartGrid.new(parent, tier.fallbackCells, tier.fallbackCell)
	fallback = grid
	far = FarPlane.new(parent, grid.half, SEA)
	snapStep = tier.fallbackCell
	mode = "Parts"
end

-- Writes every vertex for time t. Allocation-free.
local function updateMesh(t: number)
	local ringGrid = ring
	if ringGrid then
		local heights, lx, lz = ringGrid.heights, ringGrid.lx, ringGrid.lz
		for n = 1, ringGrid.count do
			local w = ringWeight[n]
			if w > 0 then
				local h = WaveField.heightAt(centreX + lx[n], centreZ + lz[n], t)
				heights[n] = SEA + (h - SEA) * w
			else
				heights[n] = SEA
			end
		end
		MeshGrid.apply(ringGrid, SEA)
	end
	local nearGrid = near
	if nearGrid then
		local heights, lx, lz = nearGrid.heights, nearGrid.lx, nearGrid.lz
		local ringHeights = if ringGrid then ringGrid.heights else nil
		for n = 1, nearGrid.count do
			local a = stitchA[n]
			if ringHeights and a and a > 0 then
				local ha = ringHeights[a]
				heights[n] = ha + (ringHeights[stitchB[n]] - ha) * stitchT[n]
			else
				heights[n] = WaveField.heightAt(centreX + lx[n], centreZ + lz[n], t)
			end
		end
		MeshGrid.apply(nearGrid, SEA)
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
	if far then
		FarPlane.moveTo(far, centreX, centreZ)
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera or mode == "None" then
		return
	end
	local pos = camera.CFrame.Position
	local cx = math.floor(pos.X / snapStep + 0.5) * snapStep
	local cz = math.floor(pos.Z / snapStep + 0.5) * snapStep
	local snapped = cx ~= centreX or cz ~= centreZ
	accumulator += dt
	local interval = if tier.updateHz > 0 then 1 / tier.updateHz else 0
	if not snapped and accumulator < interval then
		return
	end
	accumulator = if interval > 0 then accumulator % interval else 0

	local t = Workspace:GetServerTimeNow()
	frameT = t
	lastT = t
	WaveField.beginFrame(t)
	if snapped then
		centreX, centreZ = cx, cz
		moveParts()
	end
	if mode == "Mesh" then
		updateMesh(t)
	elseif fallback then
		PartGrid.update(fallback, centreX, centreZ, SEA, fallbackGradient)
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
		if not buildMesh(parent) then
			teardown()
			buildFallback(parent)
		end
		print(`[Ocean] {mode} ocean, {tier.name} tier`)
	until not rebuildQueued
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, step)
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
	build() -- yields (CreateMeshPartAsync)
end

-- Surface Y as currently drawn at (x, z): the shared wave function at the last update time,
-- with the outer-ring fade applied. Matches the mesh exactly at near-patch vertices.
function OceanController.GetVisualHeight(x: number, z: number): number
	local t = lastT or Workspace:GetServerTimeNow()
	local h = WaveField.heightAt(x, z, t)
	if mode == "Mesh" then
		return SEA + (h - SEA) * fadeWeight(x - centreX, z - centreZ)
	end
	return h
end

function OceanController.GetMode(): Mode
	return mode
end

return OceanController
