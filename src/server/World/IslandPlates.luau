--!strict
-- IslandPlates (WP-24): the six player islands are no longer terrain. Each is a flat Lego baseplate built from
-- Parts (the owner: "a simple plain Lego island"), placed from RingLayout.IslandPlate: a bright green slab ~2 studs
-- thick whose top is at the plateau the lots already use, a darker trim skirt round the outer edge down past the
-- waterline, a thin sand-yellow strip along the berth notch's walls (the U cut-out where the boats and the sub
-- berth), and a tiled studs Texture on the slab's top. Anchored, CanCollide, SmoothPlastic throughout.
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
	for _, r in P.rects do
		local cx, cz, w, d = (r[1] + r[2]) / 2, -(r[3] + r[4]) / 2, r[2] - r[1], r[4] - r[3]
		local p = part(
			parent,
			"Slab",
			Vector3.new(w, P.thick, d),
			isl.frame * CFrame.new(cx, -P.thick / 2, cz),
			GREEN
		)
		local tex = Instance.new("Texture")
		tex.Name = "Studs"
		tex.Face = Enum.NormalId.Top
		tex.Texture = STUD_TEXTURE
		tex.StudsPerTileU = 8 -- the tile holds 4 x 4 studs: 2-stud studs, like the buildings' (WP-25)
		tex.StudsPerTileV = 8
		tex.Color3 = STUD_TINT
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
	local strips = {
		{ -hw - STRIP_W, -hw, P.notch.head, e }, -- the notch's left wall
		{ hw, hw + STRIP_W, P.notch.head, e }, -- the notch's right wall
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
