--!strict
-- Bridges (docs/23 (k), WP-18): six walkable suspension bridges from the hub to the player islands, code-built
-- placeholder Parts from HubLayout.Bridges: an arched Wood deck (sine arch, max grade ~11 deg, underside 48.8 studs
-- over the sea at mid-span so every boat and the helicopter pass under), Metal rails with an invisible anti-fall
-- fence above them, two red-and-white towers per bridge on the rims, Metal main cables, hangers and back-stays.
-- WorldDressingService calls Bridges.place(base) once at server start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout")
)

local SEG = 16 -- deck segment length (studs along the arch)
local THICK = 1.2
local RAIL_H = 4
local FENCE_H = 12 -- invisible: no jumping off
local CABLE_OUT = 1.5 -- main cables this far outside the rails
local LEG = 3

local WOOD = Color3.fromRGB(120, 90, 60)
local WHITE = Color3.fromRGB(236, 236, 230)
local RED = Color3.fromRGB(196, 48, 40)
local STEEL = Color3.fromRGB(60, 62, 68)

local Bridges = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a thin piece from a to b (non-colliding: cables, hangers)
local function strut(parent: Instance, name: string, a: Vector3, b: Vector3, w: number)
	local p = part(
		parent,
		name,
		Vector3.new(w, w, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		STEEL,
		Enum.Material.Metal
	)
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
end

local function build(br: HubLayout.Bridge, parent: Instance)
	local model = Instance.new("Model")
	model.Name = br.id
	local flat = Vector3.new(br.to.X - br.from.X, 0, br.to.Z - br.from.Z)
	local span = flat.Magnitude
	local dir = flat.Unit
	local right = dir:Cross(Vector3.yAxis)
	local half = br.width / 2

	-- deck, rails, fence: one set per segment along the arch
	local n = math.ceil(span / SEG)
	for k = 0, n - 1 do
		local a, b = HubLayout.deckAt(br, k / n), HubLayout.deckAt(br, (k + 1) / n)
		local len = (b - a).Magnitude + 0.4 -- overlap: no seams to trip on
		local cf = CFrame.lookAt((a + b) / 2, b)
		part(
			model,
			"Deck",
			Vector3.new(br.width, THICK, len),
			cf * CFrame.new(0, -THICK / 2, 0),
			WOOD,
			Enum.Material.Wood
		)
		for _, side in { -1, 1 } do
			part(
				model,
				"Rail",
				Vector3.new(0.6, RAIL_H, len),
				cf * CFrame.new(side * (half + 0.3), RAIL_H / 2, 0),
				WHITE,
				Enum.Material.Metal
			)
			local fence = part(
				model,
				"Fence",
				Vector3.new(0.6, FENCE_H, len),
				cf * CFrame.new(side * (half + 0.3), RAIL_H + FENCE_H / 2, 0),
				WHITE,
				Enum.Material.SmoothPlastic
			)
			fence.Transparency = 1
			fence.CanQuery = false
			fence.CastShadow = false
		end
	end

	-- towers: two legs either side of the deck, a crossbeam at the top and one under the deck
	local legOff = half + CABLE_OUT + LEG / 2
	local tops = {}
	for i, foot in br.towers do
		local t = (Vector3.new(foot.X - br.from.X, 0, foot.Z - br.from.Z)):Dot(dir) / span
		local deckY = HubLayout.deckY(br, t)
		local baseY = foot.Y - 12 -- sunk into the rim
		local h = br.towerTopY - baseY
		local tower = Instance.new("Model")
		tower.Name = `Tower{i}`
		for _, side in { -1, 1 } do
			local p = Vector3.new(foot.X, baseY + h / 2, foot.Z) + right * side * legOff
			part(
				tower,
				"Leg",
				Vector3.new(LEG, h, LEG),
				CFrame.lookAt(p, p + dir),
				RED,
				Enum.Material.SmoothPlastic
			)
		end
		local top = Vector3.new(foot.X, br.towerTopY - 1.5, foot.Z)
		part(
			tower,
			"Crossbeam",
			Vector3.new(2 * legOff + LEG, 3, LEG),
			CFrame.lookAt(top, top + dir),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		local under = Vector3.new(foot.X, deckY - THICK - 1.5, foot.Z)
		part(
			tower,
			"Crossbeam",
			Vector3.new(2 * legOff + LEG, 3, LEG),
			CFrame.lookAt(under, under + dir),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		tower.Parent = model
		tops[i] = { pos = Vector3.new(foot.X, br.towerTopY, foot.Z), t = t }
	end

	-- main cables (a parabola between the tower tops, low at mid-span), hangers down to the deck, back-stays to the ends
	local t0, t1 = tops[1].t, tops[2].t
	local function cableAt(t: number, side: number): Vector3
		local u = (t - t0) / (t1 - t0)
		local p = br.from:Lerp(br.to, t)
		local y = br.cableLowY + (br.towerTopY - br.cableLowY) * (2 * u - 1) ^ 2
		return Vector3.new(p.X, y, p.Z) + right * side * (half + CABLE_OUT)
	end
	local m = 24
	for _, side in { -1, 1 } do
		for k = 0, m - 1 do
			strut(
				model,
				"Cable",
				cableAt(t0 + (t1 - t0) * k / m, side),
				cableAt(t0 + (t1 - t0) * (k + 1) / m, side),
				0.8
			)
		end
		for k = 1, n - 1, 2 do
			local t = k / n
			if t > t0 and t < t1 then
				local d = HubLayout.deckAt(br, t) + right * side * (half + CABLE_OUT)
				strut(model, "Hanger", d, cableAt(t, side), 0.3)
			end
		end
		local off = right * side * (half + CABLE_OUT)
		strut(model, "BackStay", cableAt(t0, side), br.from + off, 0.8)
		strut(model, "BackStay", cableAt(t1, side), br.to + off, 0.8)
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
