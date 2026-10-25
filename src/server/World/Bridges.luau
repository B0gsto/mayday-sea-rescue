--!strict
-- Bridges (docs/23 (p), WP-27): six short walkable Lego bridges joining each island to its two neighbours (a full
-- ring), code-built placeholder Parts from HubLayout.Bridges: a reddish-brown deck climbing at 11.3 deg from both
-- plates to a rounded crest (underside ~20 studs over the sea at mid-span, so boats pass under), red rails on white
-- posts with an invisible anti-fall fence above them, and a grey pier at each plate's edge. WorldDressingService
-- calls Bridges.place(base) once at server start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout")
)

local SEG = 6 -- deck segment length (studs along the deck; short so the crest reads round)
local THICK = 1.2
local RAIL_H = 3.5
local FENCE_H = 12 -- invisible: no jumping off
local POST_EVERY = 3 -- a post every this many segments
local PIER = 3
local SEABED_Y = -40

local DECK = Color3.fromRGB(105, 64, 40) -- Lego reddish brown
local RED = Color3.fromRGB(196, 40, 28)
local WHITE = Color3.fromRGB(242, 243, 242)
local GREY = Color3.fromRGB(99, 95, 98) -- dark stone grey
local MAT = Enum.Material.SmoothPlastic

local Bridges = {}

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

local function build(br: HubLayout.Bridge, parent: Instance)
	local model = Instance.new("Model")
	model.Name = br.id
	model:SetAttribute("Islands", `{br.a} {br.b}`)
	local flat = Vector3.new(br.to.X - br.from.X, 0, br.to.Z - br.from.Z)
	local span = flat.Magnitude
	local dir = flat.Unit
	local right = dir:Cross(Vector3.yAxis)
	local half = br.width / 2

	-- deck, rails, fence: one set per segment along the profile
	local n = math.ceil(span / SEG)
	for k = 0, n - 1 do
		local a, b = HubLayout.deckAt(br, k / n), HubLayout.deckAt(br, (k + 1) / n)
		local len = (b - a).Magnitude + 0.3 -- overlap: no seams to trip on
		local cf = CFrame.lookAt((a + b) / 2, b)
		part(
			model,
			"Deck",
			Vector3.new(br.width, THICK, len),
			cf * CFrame.new(0, -THICK / 2, 0),
			DECK
		)
		for _, side in { -1, 1 } do
			part(
				model,
				"Rail",
				Vector3.new(0.8, 0.8, len),
				cf * CFrame.new(side * (half - 0.4), RAIL_H, 0),
				RED
			)
			local fence = part(
				model,
				"Fence",
				Vector3.new(0.6, FENCE_H, len),
				cf * CFrame.new(side * (half - 0.4), RAIL_H + FENCE_H / 2, 0),
				WHITE
			)
			fence.Transparency = 1
			fence.CanQuery = false
			fence.CastShadow = false
			if k % POST_EVERY == 0 then
				part(
					model,
					"Post",
					Vector3.new(0.8, RAIL_H, 0.8),
					CFrame.new(a)
						* CFrame.new(right * side * (half - 0.4))
						* CFrame.new(0, RAIL_H / 2, 0),
					WHITE
				)
			end
		end
	end

	-- a pier under the deck at each plate edge (the water span between them stays open for boats)
	local a, b = HubLayout.byId[br.a], HubLayout.byId[br.b]
	for _, isl in { a, b } do
		local t0, t1 = 0, 1 -- the deck point where it leaves the plate: bisect along the deck
		local inside = function(t: number): boolean
			local p = br.from:Lerp(br.to, t)
			return HubLayout.onPlate(isl, p.X, p.Z)
		end
		if not inside(0) then
			t0, t1 = 1, 0
		end
		for _ = 1, 20 do
			local m = (t0 + t1) / 2
			if inside(m) then
				t0 = m
			else
				t1 = m
			end
		end
		local p = HubLayout.deckAt(br, t0)
		local top = p.Y - THICK
		local foot = Vector3.new(p.X, (top + SEABED_Y) / 2, p.Z)
			+ dir * (if t1 > t0 then PIER else -PIER)
		part(
			model,
			"Pier",
			Vector3.new(br.width - 2, top - SEABED_Y, PIER),
			CFrame.lookAt(foot, foot + dir),
			GREY
		)
	end
	model.Parent = parent
end

function Bridges.place(base: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Bridges"
	for _, br in HubLayout.Bridges do
		build(br, folder)
	end
	folder.Parent = base
end

return Bridges
