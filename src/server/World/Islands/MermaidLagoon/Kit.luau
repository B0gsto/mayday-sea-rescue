--!strict
-- Mermaid Lagoon kit: the code-built placeholder props (palms, agapanthus, parasols, loungers, café furniture, the
-- reclining mermaid). Each builder adds anchored, non-touching Parts to `m` in world space. Materials stay off the
-- terrain-remapped slots (memory: materialservice-remap): SmoothPlastic, Wood, Fabric, Plaster, Marble, Metal.

local Kit = {}

local LEAF =
	{ Color3.fromRGB(62, 112, 46), Color3.fromRGB(78, 128, 52), Color3.fromRGB(96, 138, 58) }
local TRUNK = { Color3.fromRGB(126, 100, 74), Color3.fromRGB(104, 82, 62) }

function Kit.part(
	m: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- A cylinder from a to b.
function Kit.cyl(
	m: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	d: number,
	color: Color3,
	material: Enum.Material?
): Part
	return Kit.part(
		m,
		name,
		Vector3.new((b - a).Magnitude, d, d),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

-- A flat triangle from two wedges (the usual two-wedge split at the foot of the apex's altitude).
function Kit.tri(
	m: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color3,
	material: Enum.Material?,
	thick: number?
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local function wedge(mid: Vector3, r: Vector3, bk: Vector3, len: number)
		local w = Instance.new("WedgePart")
		w.Name = "Tri"
		w.Anchored = true
		w.CanTouch = false
		w.CanCollide = false
		w.Size = Vector3.new(thick or 0.12, height, len)
		w.CFrame = CFrame.fromMatrix(mid, r, up, bk)
		w.Color = color
		w.Material = material or Enum.Material.SmoothPlastic
		w.Parent = m
	end
	wedge((a + b) / 2, right, back, math.abs(ab:Dot(back)))
	wedge((a + c) / 2, -right, -back, math.abs(ac:Dot(back)))
end

-- A palm: curved ringed trunk, arching fronds with pointed tips, a dark heart and fruit.
function Kit.palm(
	m: Instance,
	base: Vector3,
	height: number,
	yaw: number,
	rng: Random,
	stout: boolean?
)
	local lean = CFrame.Angles(0, yaw, 0).LookVector
		* height
		* (if stout then 0.08 else rng:NextNumber(0.18, 0.32))
	local d0 = if stout then height * 0.11 else height * 0.065
	local prev = base - Vector3.new(0, 1, 0)
	local n = 5
	for i = 1, n do
		local t = i / n
		local p = base + Vector3.new(0, height * t, 0) + lean * t * t
		local d = d0 * (1 - 0.35 * t)
		local seg = Kit.cyl(
			m,
			"Trunk",
			prev,
			p + (p - prev).Unit * 0.25,
			d,
			TRUNK[i % 2 + 1],
			Enum.Material.Wood
		)
		seg.CanCollide = i <= 2
		prev = p
	end
	local top = prev
	local heart = Kit.part(
		m,
		"Heart",
		Vector3.one * d0 * 1.5,
		CFrame.new(top),
		LEAF[1],
		nil,
		Enum.PartType.Ball
	)
	heart.CanCollide = false
	local fruitColour = if stout then Color3.fromRGB(214, 140, 52) else Color3.fromRGB(96, 74, 44)
	for i = 1, 3 do
		local a = i * 2.1
		local f = Kit.part(
			m,
			"Fruit",
			Vector3.one * d0 * 0.55,
			CFrame.new(top + Vector3.new(math.cos(a) * d0 * 0.6, -d0 * 0.6, math.sin(a) * d0 * 0.6)),
			fruitColour,
			nil,
			Enum.PartType.Ball
		)
		f.CanCollide = false
	end
	local fronds = if stout then 11 else 9
	local s = height / 12
	for k = 1, fronds do
		local yawK = k / fronds * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local pitch = rng:NextNumber(0.35, 0.75) -- up first, then droop
		local pos = top
		local colour = LEAF[rng:NextInteger(1, #LEAF)]
		local widths = { 1.5 * s, 1.25 * s }
		local lens = { 3.6 * s, 3.3 * s }
		local segCF = CFrame.new()
		for j = 1, 2 do
			segCF = CFrame.new(pos) * CFrame.Angles(0, yawK, 0) * CFrame.Angles(pitch, 0, 0)
			local mid = segCF * CFrame.new(0, 0, -lens[j] / 2)
			local blade = Kit.part(m, "Frond", Vector3.new(widths[j], 0.1, lens[j]), mid, colour)
			blade.CanCollide = false
			blade.CastShadow = j == 1
			pos = (segCF * CFrame.new(0, 0, -lens[j])).Position
			pitch -= rng:NextNumber(0.5, 0.7)
		end
		local tipCF = CFrame.new(pos) * CFrame.Angles(0, yawK, 0) * CFrame.Angles(pitch, 0, 0)
		Kit.tri(
			m,
			(tipCF * CFrame.new(-widths[2] / 2, 0.05, 0)).Position,
			(tipCF * CFrame.new(widths[2] / 2, 0.05, 0)).Position,
			(tipCF * CFrame.new(0, 0, -2.6 * s)).Position,
			colour
		)
	end
end

-- Agapanthus (the Scilly road-verge lily): strap leaves and blue globe heads on tall stems.
function Kit.agapanthus(m: Instance, at: Vector3, rng: Random)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local leaf = Kit.part(
			m,
			"Leaf",
			Vector3.new(0.35, 0.08, 2.6),
			CFrame.new(at)
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(0.75, 0, 0)
				* CFrame.new(0, 0, -1.2),
			LEAF[2]
		)
		leaf.CanCollide = false
	end
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.4, 0.4)
		local head = at
			+ Vector3.new(math.cos(a) * 0.6, rng:NextNumber(3.2, 4.2), math.sin(a) * 0.6)
		Kit.cyl(m, "Stem", at, head, 0.12, LEAF[3]).CanCollide = false
		local blue = if i == 2 then Color3.fromRGB(236, 238, 250) else Color3.fromRGB(92, 104, 214)
		Kit.part(
			m,
			"Bloom",
			Vector3.one * 1.15,
			CFrame.new(head),
			blue,
			Enum.Material.Fabric,
			Enum.PartType.Ball
		).CanCollide =
			false
	end
end

-- A beach parasol: pole and an eight-panel striped canopy.
function Kit.parasol(m: Instance, at: Vector3, a: Color3, b: Color3, tilt: number?)
	local up = CFrame.new(at) * CFrame.Angles(tilt or 0, 0, 0)
	Kit.cyl(
		m,
		"Pole",
		at - Vector3.new(0, 0.6, 0),
		(up * CFrame.new(0, 7.8, 0)).Position,
		0.22,
		Color3.fromRGB(240, 236, 228)
	)
	local apex = (up * CFrame.new(0, 7.7, 0)).Position
	for i = 0, 7 do
		local a0, a1 = i / 8 * math.pi * 2, (i + 1) / 8 * math.pi * 2
		Kit.tri(
			m,
			apex,
			(up * CFrame.new(math.cos(a0) * 4.2, 6.3, math.sin(a0) * 4.2)).Position,
			(up * CFrame.new(math.cos(a1) * 4.2, 6.3, math.sin(a1) * 4.2)).Position,
			if i % 2 == 0 then a else b,
			Enum.Material.Fabric
		)
	end
	Kit.part(
		m,
		"Finial",
		Vector3.one * 0.45,
		CFrame.new(apex + Vector3.new(0, 0.2, 0)),
		Color3.fromRGB(240, 236, 228),
		nil,
		Enum.PartType.Ball
	)
end

-- A wooden sun lounger, its back up, facing local -Z; cf = the foot centre on the ground.
function Kit.lounger(m: Instance, cf: CFrame, fabric: Color3)
	local wood = Color3.fromRGB(196, 150, 100)
	Kit.part(
		m,
		"Frame",
		Vector3.new(2.3, 0.3, 4.6),
		cf * CFrame.new(0, 0.9, 0),
		wood,
		Enum.Material.Wood
	)
	for _, z in { -2, 2 } do
		Kit.part(
			m,
			"Leg",
			Vector3.new(2.3, 0.8, 0.3),
			cf * CFrame.new(0, 0.4, z),
			wood,
			Enum.Material.Wood
		)
	end
	Kit.part(
		m,
		"Pad",
		Vector3.new(2.0, 0.18, 3.0),
		cf * CFrame.new(0, 1.12, -0.7),
		fabric,
		Enum.Material.Fabric
	)
	local back = cf * CFrame.new(0, 1.0, 1.7) * CFrame.Angles(-0.85, 0, 0) * CFrame.new(0, 0, 1.1)
	Kit.part(m, "Back", Vector3.new(2.3, 0.25, 2.2), back, wood, Enum.Material.Wood)
	Kit.part(
		m,
		"BackPad",
		Vector3.new(2.0, 0.12, 2.0),
		back * CFrame.new(0, 0.18, 0),
		fabric,
		Enum.Material.Fabric
	)
end

-- A bistro table with two chairs; cf = centre on the floor.
function Kit.table(m: Instance, cf: CFrame, top: Color3)
	local iron = Color3.fromRGB(40, 118, 112) -- painted bistro iron
	Kit.part(
		m,
		"Top",
		Vector3.new(0.2, 3, 3),
		cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		top,
		nil,
		Enum.PartType.Cylinder
	)
	Kit.part(
		m,
		"Leg",
		Vector3.new(2.5, 0.25, 0.25),
		cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		iron,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for _, s in { -1, 1 } do
		local c = cf * CFrame.new(s * 2.4, 0, 0) * CFrame.Angles(0, s * math.pi / 2, 0)
		Kit.part(
			m,
			"Seat",
			Vector3.new(1.6, 0.2, 1.6),
			c * CFrame.new(0, 1.6, 0),
			iron,
			Enum.Material.Metal
		)
		Kit.part(
			m,
			"ChairLeg",
			Vector3.new(0.2, 1.5, 0.2),
			c * CFrame.new(0, 0.75, 0),
			iron,
			Enum.Material.Metal
		)
		Kit.part(
			m,
			"ChairBack",
			Vector3.new(1.6, 1.5, 0.2),
			c * CFrame.new(0, 2.4, 0.75),
			iron,
			Enum.Material.Metal
		)
	end
end

-- The reclining mermaid in weathered marble, propped on one elbow on a broken plinth, raising a shell. Built at
-- `cf` (seabed centre, she faces -Z); returns the height of her highest point above cf.
function Kit.mermaid(m: Instance, cf: CFrame, s: number): number
	local skin = Color3.fromRGB(226, 232, 222)
	local tail = Color3.fromRGB(150, 196, 182)
	local stone = Color3.fromRGB(176, 170, 156)
	local function at(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x * s, y * s, z * s)).Position
	end
	local function ball(name: string, p: Vector3, d: number, c: Color3)
		Kit.part(
			m,
			name,
			Vector3.one * d * s,
			CFrame.new(p),
			c,
			Enum.Material.Marble,
			Enum.PartType.Ball
		)
	end
	Kit.part(
		m,
		"Plinth",
		Vector3.new(1.2 * s, 7.5 * s, 7.5 * s),
		cf * CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0.05, 0.4, math.pi / 2 + 0.06),
		stone,
		Enum.Material.Granite,
		Enum.PartType.Cylinder
	)
	-- tail: hips -> curl round the plinth front -> fluke
	local tailPts = {
		at(0.9, 1.6, 0),
		at(2.6, 1.3, -0.6),
		at(4.2, 1.1, -1.8),
		at(5.2, 1.3, -3.4),
		at(5.6, 1.9, -4.6),
	}
	local dia = { 2.0, 1.6, 1.15, 0.75 }
	for i = 1, 4 do
		Kit.cyl(m, "Tail", tailPts[i], tailPts[i + 1], dia[i] * s, tail, Enum.Material.Marble)
		ball("TailJoint", tailPts[i + 1], dia[i] * 0.98, tail)
	end
	local tip = tailPts[5]
	Kit.tri(m, tip, at(4.4, 3.0, -5.6), at(5.0, 1.8, -5.4), tail, Enum.Material.Marble, 0.3 * s)
	Kit.tri(m, tip, at(6.9, 2.9, -5.2), at(6.2, 1.9, -5.0), tail, Enum.Material.Marble, 0.3 * s)
	-- body, propped at ~35 degrees
	ball("Hips", at(0.9, 1.6, 0), 2.1, tail)
	Kit.cyl(m, "Waist", at(0.9, 1.7, 0), at(-0.4, 2.5, 0), 1.6 * s, skin, Enum.Material.Marble)
	ball("Chest", at(-0.6, 2.7, 0), 1.9, skin)
	ball("Neck", at(-1.3, 3.3, 0), 0.7, skin)
	ball("Head", at(-1.7, 3.8, -0.1), 1.25, skin)
	ball("Hair", at(-1.45, 3.95, 0.35), 1.35, Color3.fromRGB(196, 206, 190))
	Kit.cyl(
		m,
		"Locks",
		at(-1.4, 3.9, 0.45),
		at(-0.4, 2.4, 0.8),
		0.8 * s,
		Color3.fromRGB(196, 206, 190),
		Enum.Material.Marble
	)
	-- the propping arm (elbow on the plinth) and the raised arm with the shell
	Kit.cyl(
		m,
		"UpperArm",
		at(-1.1, 3.0, 0.7),
		at(-2.0, 1.2, 0.9),
		0.55 * s,
		skin,
		Enum.Material.Marble
	)
	Kit.cyl(
		m,
		"Forearm",
		at(-2.0, 1.2, 0.9),
		at(-3.4, 1.1, 0.2),
		0.5 * s,
		skin,
		Enum.Material.Marble
	)
	Kit.cyl(
		m,
		"RaisedArm",
		at(-0.9, 3.1, -0.7),
		at(-2.4, 4.1, -1.4),
		0.5 * s,
		skin,
		Enum.Material.Marble
	)
	Kit.part(
		m,
		"Shell",
		Vector3.new(0.35, 1.3, 1.3) * s,
		CFrame.new(at(-2.7, 4.3, -1.6)) * CFrame.Angles(0, 0.6, 0),
		Color3.fromRGB(240, 214, 200),
		Enum.Material.Marble,
		Enum.PartType.Cylinder
	)
	return 5.0 * s
end

return Kit
