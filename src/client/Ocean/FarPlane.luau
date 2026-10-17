--!strict
-- FarPlane: flat Deep Teal sea from the edge of the wave rings out towards the horizon.
-- Four thin Parts in a pinwheel around a square hole, so the plane never shows through wave
-- troughs inside the rings. Parts are capped at 2048 studs per axis, so each strip is at most
-- 2048 long and the plane reaches (2048 - innerHalf) studs from the camera; Atmosphere haze
-- (stream D lighting) should hide the edge. Moving it is 4 CFrame writes per snap (not per frame).

local OceanPalette = require(script.Parent.OceanPalette)

local MAX_PART = 2048
local OVERLAP = 4 -- studs the plane tucks under the flat outer edge of the ring -- tune
local DROP = 0.15 -- top surface sits this far below sea level to avoid z-fighting -- tune
local THICKNESS = 1

export type FarPlane = {
	parts: { BasePart },
	offsets: { Vector3 },
	seaLevel: number,
}

local FarPlane = {}

function FarPlane.new(parent: Instance, innerHalf: number, seaLevel: number): FarPlane
	local r = math.max(innerHalf - OVERLAP, 1)
	local width = MAX_PART - 2 * r
	local length = 2 * r + width -- == MAX_PART
	local y = -DROP - THICKNESS / 2
	-- Pinwheel: each strip covers one side plus one corner.
	local layout = {
		{
			size = Vector3.new(length, THICKNESS, width),
			offset = Vector3.new(width / 2, y, -r - width / 2),
		},
		{
			size = Vector3.new(width, THICKNESS, length),
			offset = Vector3.new(r + width / 2, y, width / 2),
		},
		{
			size = Vector3.new(length, THICKNESS, width),
			offset = Vector3.new(-width / 2, y, r + width / 2),
		},
		{
			size = Vector3.new(width, THICKNESS, length),
			offset = Vector3.new(-r - width / 2, y, -width / 2),
		},
	}
	local parts: { BasePart } = {}
	local offsets: { Vector3 } = {}
	for n, entry in layout do
		local part = Instance.new("Part")
		part.Name = `OceanFar{n}`
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = OceanPalette.colours[OceanPalette.SEA_BUCKET]
		part.Reflectance = 0.05 -- tune, match MeshGrid
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = entry.size
		part.CFrame = CFrame.new(entry.offset + Vector3.new(0, seaLevel, 0))
		part.Parent = parent
		parts[n] = part
		offsets[n] = entry.offset
	end
	return { parts = parts, offsets = offsets, seaLevel = seaLevel }
end

function FarPlane.moveTo(plane: FarPlane, cx: number, cz: number)
	local base = Vector3.new(cx, plane.seaLevel, cz)
	for n, part in plane.parts do
		part.CFrame = CFrame.new(base + plane.offsets[n])
	end
end

function FarPlane.destroy(plane: FarPlane)
	for _, part in plane.parts do
		part:Destroy()
	end
	table.clear(plane.parts)
end

return FarPlane
