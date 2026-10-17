--!strict
-- Seabed: what the shallows look like from above and below (ocean spike round 2).
--   caustics   two crossing, slowly scrolling layers of a baked tileable caustic network
--              (art/ocean/bake_ocean_round2.py, asset Mayday_ocean_caustics) on an invisible
--              plate that sits on the seabed under the camera. Fades out with depth and with
--              the light level (no caustics at night or in a storm).
--   depth tint stacked water-coloured slices below the surface, each a radial-faded Decal on an
--              invisible plate. Terrain hides the slices below it, so a sand bar 3 studs down is
--              seen through one slice and a 20-stud hole through eight: a real depth gradient
--              of water colour over the sand, with no shader. Hidden underwater and over deep
--              sea.
-- Everything is created once; update() only moves plates and writes a few properties.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local CAUSTICS_ID = "rbxassetid://136964922100171"
local RADIAL_FADE_ID = "rbxassetid://136993624736043"
local PLATE = 400 -- studs -- tune
local CAUSTIC_TILES = { 26, 41 } -- studs per tile for the two layers -- tune
local CAUSTIC_SPEED = { Vector2.new(0.9, 0.5), Vector2.new(-0.6, 0.8) } -- studs/s -- tune
local CAUSTIC_MAX_DEPTH = 40 -- studs -- tune
local SLICES = 8
local SLICE_STEP = 2.6 -- studs between depth slices -- tune
local SLICE_TRANSPARENCY = 0.9 -- per slice; 0.8 hid the sand at 8 studs (round 3) -- tune
local SLICE_SIZE = 360

export type Seabed = {
	folder: Folder,
	plate: Part,
	layers: { Texture },
	slices: { Part },
	decals: { Decal },
	slicesOn: boolean,
	seabedY: number,
	hasBed: boolean,
	checkAt: number,
	params: RaycastParams,
}

local Seabed = {}

local function plate(name: string, parent: Instance, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = parent
	return p
end

function Seabed.new(parent: Instance): Seabed
	local folder = Instance.new("Folder")
	folder.Name = "OceanSeabed"
	folder.Parent = parent
	local causticPlate = plate("Caustics", folder, Vector3.new(PLATE, 0.2, PLATE))
	local layers = {}
	for i, tile in CAUSTIC_TILES do
		local t = Instance.new("Texture")
		t.Name = `Caustic{i}`
		t.Texture = CAUSTICS_ID
		t.Face = Enum.NormalId.Top
		t.StudsPerTileU = tile
		t.StudsPerTileV = tile
		t.Color3 = Color3.fromHex("#F4FFF8")
		t.Transparency = 1
		t.Parent = causticPlate
		layers[i] = t
	end
	local slices, decals = {}, {}
	for i = 1, SLICES do
		local p = plate(`DepthSlice{i}`, folder, Vector3.new(SLICE_SIZE, 0.05, SLICE_SIZE))
		local d = Instance.new("Decal")
		d.Texture = RADIAL_FADE_ID
		d.Face = Enum.NormalId.Top
		d.Transparency = 1
		d.Parent = p
		slices[i], decals[i] = p, d
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	return {
		folder = folder,
		plate = causticPlate,
		layers = layers,
		slices = slices,
		decals = decals,
		slicesOn = false,
		seabedY = -math.huge,
		hasBed = false,
		checkAt = 0,
		params = params,
	}
end

-- cx, cz: ocean grid centre; seaY: sea level; cameraUnder: camera below the drawn surface;
-- tint: current water colour; t: shared time (for the caustic scroll).
function Seabed.update(
	s: Seabed,
	cx: number,
	cz: number,
	seaY: number,
	cameraUnder: boolean,
	tint: Color3,
	t: number
)
	local now = os.clock()
	if now >= s.checkAt then
		s.checkAt = now + 0.5
		local hit =
			Workspace:Raycast(Vector3.new(cx, seaY + 4, cz), Vector3.new(0, -200, 0), s.params)
		s.hasBed = hit ~= nil and hit.Position.Y < seaY - 0.5
		s.seabedY = if hit then hit.Position.Y else -math.huge
	end
	local depth = seaY - s.seabedY
	-- Caustics: brightest in shallow sunlit water, gone by CAUSTIC_MAX_DEPTH or in dim light.
	local light = math.clamp((Lighting.Brightness - 0.6) / 2.2, 0, 1)
	local strength = if s.hasBed
		then (1 - math.clamp((depth - 3) / (CAUSTIC_MAX_DEPTH - 3), 0, 1)) * light
		else 0
	local transparency = 1 - 0.85 * strength
	for i, layer in s.layers do
		if layer.Transparency ~= transparency then
			layer.Transparency = transparency
		end
		if strength > 0 then
			local v = CAUSTIC_SPEED[i] * t
			layer.OffsetStudsU = v.X % CAUSTIC_TILES[i]
			layer.OffsetStudsV = v.Y % CAUSTIC_TILES[i]
		end
	end
	if strength > 0 then
		s.plate.CFrame = CFrame.new(cx, s.seabedY + 0.12, cz)
	end
	-- Depth tint slices: only above water, over a seabed shallower than the stack.
	local on = s.hasBed and not cameraUnder and depth < SLICES * SLICE_STEP + 12
	if on ~= s.slicesOn then
		s.slicesOn = on
		for _, d in s.decals do
			d.Transparency = if on then SLICE_TRANSPARENCY else 1
		end
	end
	if on then
		for i, p in s.slices do
			p.CFrame = CFrame.new(cx, seaY - SLICE_STEP * i + 0.4, cz)
			local d = s.decals[i]
			if d.Color3 ~= tint then
				d.Color3 = tint
			end
		end
	end
end

function Seabed.destroy(s: Seabed)
	s.folder:Destroy()
end

return Seabed
