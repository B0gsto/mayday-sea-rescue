--!strict
-- IslandPlates (WP-24): the six player islands are no longer terrain. Each is a flat Lego baseplate built from
-- Parts (the owner: "a simple plain Lego island"), placed from RingLayout.IslandPlate: a bright green slab ~2 studs
-- thick whose top is at the plateau the lots already use, a darker trim skirt round the outer edge down past the
-- waterline, a thin sand-yellow strip along the berth notch's walls (the U cut-out where the boats and the sub
-- berth), and a tiled studs Texture on the slab's top. WP-25 r7: a lighter lawn in the middle, a tan beach step
-- round the outside with rocks at the corners. Anchored, CanCollide, SmoothPlastic throughout.
-- WorldDressingService calls place(base).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RingLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RingLayout")
)

local GREEN = Color3.fromRGB(75, 151, 75) -- Roblox "Bright green", the classic baseplate
local TRIM = Color3.fromRGB(39, 92, 46)
local SAND = Color3.fromRGB(226, 198, 140)
local MAT = Enum.Material.SmoothPlastic
local STUD_TEXTURE = "rbxassetid://18878365966" -- a 4 x 4 stud tile (SurfaceType.Studs does not render here)
local STUD_TINT = Color3.fromRGB(60, 126, 60) -- the studs texture is white: tint it just under the slab green
local LAWN = Color3.fromRGB(100, 176, 84) -- WP-25 r7: the inner rects a lighter lawn, the outer ring the darker edge
local LAWN_TINT = Color3.fromRGB(84, 152, 70)
local INNER = 3 -- rects 1..INNER are the plate's middle (RingLayout.IslandPlate.rects)
local BEACH_W = 6 -- WP-25 r7: the tan beach step round the plate, outside the trim
local BEACH_TOP, BEACH_FOOT = 2, -1.5 -- world Y: a step half way down from the plate (top 4) to the sea
local ROCK = Color3.fromRGB(163, 162, 165)
local ROCK_DARK = Color3.fromRGB(99, 95, 98)
local BUSH = Color3.fromRGB(40, 127, 70)
local TRIM_W = 2 -- the edge trim's width, outside the slab's footprint
local SKIRT_DOWN = 1 -- the trim's bottom, studs under sea level so waves never expose the plate's underside
local STRIP_W = 1.2 -- the sand-yellow berth strip's width

local IslandPlates = {}

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

-- one green slab part per footprint rect, `thick` studs under the top, with a tiled studs Texture on top
-- (one stud per stud), on a dark trim body down past the waterline so the notch walls and corner steps never
-- show a gap under the plate
local function slab(parent: Instance, isl: RingLayout.Island)
	local P = RingLayout.IslandPlate
	local bodyH = P.topY - P.thick + SKIRT_DOWN
	for i, r in P.rects do
		local cx, cz, w, d = (r[1] + r[2]) / 2, -(r[3] + r[4]) / 2, r[2] - r[1], r[4] - r[3]
		local p = part(
			parent,
			"Slab",
			Vector3.new(w, P.thick, d),
			isl.frame * CFrame.new(cx, -P.thick / 2, cz),
			if i <= INNER then LAWN else GREEN
		)
		local tex = Instance.new("Texture")
		tex.Name = "Studs"
		tex.Face = Enum.NormalId.Top
		tex.Texture = STUD_TEXTURE
		tex.StudsPerTileU = 8 -- the tile holds 4 x 4 studs: 2-stud studs, like the buildings' (WP-25)
		tex.StudsPerTileV = 8
		tex.Color3 = if i <= INNER then LAWN_TINT else STUD_TINT
		tex.Transparency = 0.15 -- the plate still reads plain green from a distance
		tex.Parent = p
		part(
			parent,
			"Body",
			Vector3.new(w, bodyH, d),
			isl.frame * CFrame.new(cx, -P.thick - bodyH / 2, cz),
			TRIM
		).CastShadow =
			false
	end
end

-- the darker trim skirt outside the plate's outer edges (down past the waterline) and the thin sand-yellow strip
-- on top of the slab along the three walls of the berth notch
local function edges(parent: Instance, isl: RingLayout.Island)
	local P = RingLayout.IslandPlate
	local e = P.edge
	local hw = P.notch.halfWidth
	local h = P.topY + SKIRT_DOWN -- the trim's height: plate top down into the water
	local back, left, right, wingL, wingR =
		P.rects[4], P.rects[5], P.rects[6], P.rects[7], P.rects[8]
	local skirts = {
		{ back[1], back[2], -e - TRIM_W, back[3] }, -- back edge (the lagoon side)
		{ -e - TRIM_W, left[1], left[3], left[4] }, -- left edge
		{ right[2], e + TRIM_W, right[3], right[4] }, -- right edge
		{ wingL[1], wingL[2], wingL[4], e + TRIM_W }, -- fwd-left wing (beside the notch mouth)
		{ wingR[1], wingR[2], wingR[4], e + TRIM_W }, -- fwd-right wing
	}
	for _, s in skirts do
		part(
			parent,
			"Trim",
			Vector3.new(s[2] - s[1], h, s[4] - s[3]),
			isl.frame * CFrame.new((s[1] + s[2]) / 2, -h / 2, -(s[3] + s[4]) / 2),
			TRIM
		)
	end
	-- WP-25 r7: a tan stud beach step outside the trim on every outer edge and along the corner notches' walls,
	-- a gap left at the quest pontoon (its giver boats moor there), and a few rocks and a bush at each corner
	local T, W, c = TRIM_W, BEACH_W, e - P.chamfer
	local beaches = {
		{ -c, c, -e - T - W, -e - T }, -- back
		{ -e - T - W, -e - T, -c, c }, -- left
		{ e + T, e + T + W, -c, 15 }, -- right, either side of the lifeboat slip's ramp (DockConfig LifeboatSlip, fwd 20)
		{ e + T, e + T + W, 25, c },
		{ -c, -105, e + T, e + T + W }, -- fwd-left wing, either side of the quest pontoon
		{ -65, -hw, e + T, e + T + W },
		{ hw, c, e + T, e + T + W }, -- fwd-right wing
	}
	for _, sr in { -1, 1 } do
		for _, sf in { -1, 1 } do
			local function span(a: number, b: number, s: number): (number, number)
				return math.min(a * s, b * s), math.max(a * s, b * s)
			end
			local r0, r1 = span(c, c + W, sr)
			local f0, f1 = span(c, e + T + W, sf)
			table.insert(beaches, { r0, r1, f0, f1 }) -- along the corner wall facing across the notch
			r0, r1 = span(c + W, e + T + W, sr)
			f0, f1 = span(c, c + W, sf)
			table.insert(beaches, { r0, r1, f0, f1 })
			for k, rock in
				{
					{ c + 4, e + 4, 3.2 },
					{ e + 5, c + 4, 2.4 },
					{ c + 3, c + 3, 2.8 },
					{ c + 3, e - 12, 2 },
					{ e - 12, c + 3, 2.6 },
				}
			do
				local size = Vector3.new(rock[3] * 1.3, rock[3], rock[3])
				part(
					parent,
					if k == 3 then "Bush" else "Rock",
					size,
					isl.frame
						* CFrame.new(sr * rock[1], BEACH_TOP - P.topY + size.Y / 2, -sf * rock[2])
						* CFrame.Angles(0, k * 0.7, 0),
					if k == 3 then BUSH elseif k % 2 == 1 then ROCK else ROCK_DARK
				)
			end
		end
	end
	local beachH = BEACH_TOP - BEACH_FOOT
	for _, s in beaches do
		local p = part(
			parent,
			"Beach",
			Vector3.new(s[2] - s[1], beachH, s[4] - s[3]),
			isl.frame
				* CFrame.new((s[1] + s[2]) / 2, BEACH_TOP - P.topY - beachH / 2, -(s[3] + s[4]) / 2),
			SAND
		)
		local tex = Instance.new("Texture")
		tex.Face = Enum.NormalId.Top
		tex.Texture = STUD_TEXTURE
		tex.StudsPerTileU, tex.StudsPerTileV = 8, 8
		tex.Color3 = SAND:Lerp(Color3.new(0, 0, 0), 0.12)
		tex.Transparency = 0.15
		tex.Parent = p
	end
	-- the side walls carry DockPieces.base's stud-capped QuayCap (2.2 wide, 0.6 high), which swallowed their strips:
	-- the strip's wall face sat in the cap's and z-fought as a flickering tan line (owner, 2026-10-28)
	local strips = {
		{ -hw, hw, P.notch.head - STRIP_W, P.notch.head }, -- the notch's back wall (the quay)
	}
	for _, s in strips do
		part(
			parent,
			"QuayStrip",
			Vector3.new(s[2] - s[1], 0.4, s[4] - s[3]),
			isl.frame * CFrame.new((s[1] + s[2]) / 2, 0.2, -(s[3] + s[4]) / 2),
			SAND
		)
	end
end

local function build(isl: RingLayout.Island, parent: Instance)
	local model = Instance.new("Model")
	model.Name = `Plate{isl.index}`
	model:SetAttribute("Island", isl.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the whole island is seen from afar; streaming dropped slabs
	slab(model, isl)
	edges(model, isl)
	model.Parent = parent
end

function IslandPlates.place(base: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "IslandPlates"
	for _, isl in RingLayout.Islands do
		build(isl, folder)
	end
	folder.Parent = base
end

return IslandPlates
