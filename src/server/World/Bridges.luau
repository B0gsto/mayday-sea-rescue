--!strict
-- Bridges (docs/23 (p), WP-27): six short walkable Lego bridges joining each island to its two neighbours (a full
-- ring), Lego bricks from RingLayout.Bridges (WP-25): a tan stud deck (the paths' plate) on a blue beam, climbing at 11.3 deg
-- from both plates to a rounded crest (underside ~20 studs over the sea at mid-span, so boats pass under), slim
-- red-and-white rails on white posts with yellow stud caps, an invisible anti-fall fence above them, a lamp post
-- and a light grey pier with a white cap at each plate's edge. Persistent streaming, like the plates: never dropped from high up.
-- WorldDressingService calls Bridges.place(base) once at server start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RingLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RingLayout")
)

local SEG = 6 -- deck segment length (studs along the deck; short so the crest reads round)
local THICK = 1.2
local RAIL_H = 3.5
local FENCE_H = 12 -- invisible: no jumping off
local POST_EVERY = 3 -- a post every this many segments
local PIER = 3
local SEABED_Y = -40

local DECK = Color3.fromRGB(212, 184, 132) -- Lego tan, the island paths' colour (WP-25 r7)
local BEAM = Color3.fromRGB(40, 96, 208) -- Lego blue
local RED = Color3.fromRGB(224, 56, 40)
local WHITE = Color3.fromRGB(242, 240, 232)
local YELLOW = Color3.fromRGB(250, 208, 40)
local GREY = Color3.fromRGB(163, 162, 165) -- light bluish grey
local STUDS = "rbxassetid://18878365966" -- the 4 x 4 stud tile (IslandPlates)
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

local function build(br: RingLayout.Bridge, parent: Instance)
	local model = Instance.new("Model")
	model.Name = br.id
	model:SetAttribute("Islands", `{br.a} {br.b}`)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- seen from afar like the plates
	local flat = Vector3.new(br.to.X - br.from.X, 0, br.to.Z - br.from.Z)
	local span = flat.Magnitude
	local dir = flat.Unit
	local right = dir:Cross(Vector3.yAxis)
	local half = br.width / 2

	-- deck, rails, fence: one set per segment along the profile
	local n = math.ceil(span / SEG)
	for k = 0, n - 1 do
		local a, b = RingLayout.deckAt(br, k / n), RingLayout.deckAt(br, (k + 1) / n)
		local len = (b - a).Magnitude + 0.3 -- overlap: no seams to trip on
		local cf = CFrame.lookAt((a + b) / 2, b)
		local deck = part(
			model,
			"Deck",
			Vector3.new(br.width - 1, THICK, len),
			cf * CFrame.new(0, -THICK / 2, 0),
			DECK
		)
		local tex = Instance.new("Texture")
		tex.Face = Enum.NormalId.Top
		tex.Texture = STUDS
		tex.StudsPerTileU, tex.StudsPerTileV = 8, 8
		tex.Color3 = DECK:Lerp(Color3.new(0, 0, 0), 0.15)
		tex.Transparency = 0.1
		tex.Parent = deck
		part(
			model,
			"Beam",
			Vector3.new(br.width, THICK, len),
			cf * CFrame.new(0, -THICK * 1.5 + 0.05, 0),
			BEAM
		).CastShadow =
			false
		for _, side in { -1, 1 } do
			part(
				model,
				"Rail",
				Vector3.new(if k % 2 == 0 then 0.5 else 0.42, if k % 2 == 0 then 0.5 else 0.42, len), -- white inside red at the overlaps
				cf * CFrame.new(side * (half - 0.4), RAIL_H, 0),
				if k % 2 == 0 then RED else WHITE -- WP-25 r7: slim candy-stripe rails, lighter in the bridge view
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
				local foot = CFrame.new(a) * CFrame.new(right * side * (half - 0.4))
				part(
					model,
					"Post",
					Vector3.new(1, RAIL_H + 0.4, 1),
					foot * CFrame.new(0, RAIL_H / 2 + 0.2, 0),
					WHITE
				)
				part(
					model,
					"Stud",
					Vector3.new(0.4, 0.8, 0.8),
					foot * CFrame.new(0, RAIL_H + 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
					YELLOW
				).Shape =
					Enum.PartType.Cylinder
			end
		end
	end

	-- a pier under the deck at each plate edge (the water span between them stays open for boats)
	local a, b = RingLayout.byId[br.a], RingLayout.byId[br.b]
	for _, isl in { a, b } do
		local t0, t1 = 0, 1 -- the deck point where it leaves the plate: bisect along the deck
		local inside = function(t: number): boolean
			local p = br.from:Lerp(br.to, t)
			return RingLayout.onPlate(isl, p.X, p.Z)
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
		local p = RingLayout.deckAt(br, t0)
		-- a Lego lamp post at the bridge foot (WP-25 r7), right of the way on to the bridge; r9: off the deck on the
		-- plate, out of the bridge view's foreground
		local side = if t1 > t0 then 1 else -1
		local lampAt = p + right * side * (half + 14) - dir * side * 3
		part(
			model,
			"LampPost",
			Vector3.new(0.6, 9, 0.6),
			CFrame.new(lampAt + Vector3.new(0, 4.5, 0)),
			WHITE
		)
		local bulb = part(
			model,
			"Lamp",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(lampAt + Vector3.new(0, 9.5, 0)),
			YELLOW
		)
		bulb.Shape = Enum.PartType.Ball
		bulb:AddTag("NightLamp") -- WorkerController lights it at night only
		local top = p.Y - THICK
		local foot = Vector3.new(p.X, (top + SEABED_Y) / 2, p.Z)
			+ dir * (if t1 > t0 then PIER else -PIER)
		local pier = part(
			model,
			"Pier",
			Vector3.new(br.width - 2, top - SEABED_Y, PIER),
			CFrame.lookAt(foot, foot + dir),
			GREY
		)
		part(
			model,
			"PierCap",
			Vector3.new(br.width - 1, 1, PIER + 1),
			pier.CFrame * CFrame.new(0, (top - SEABED_Y) / 2 - 1.5, 0),
			WHITE
		)
	end
	model.Parent = parent
end

function Bridges.place(base: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Bridges"
	for _, br in RingLayout.Bridges do
		build(br, folder)
	end
	folder.Parent = base
end

return Bridges
