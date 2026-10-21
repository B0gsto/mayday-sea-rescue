--!strict
-- BosunRig: the code-built placeholder Bosun (docs/14 section 4: a simple dog, no Blender model for now),
-- pure data (tests/BosunMotion.spec.luau). DogService turns every entry into a plain Part and joins it to
-- its parent with a Motor6D named `joint` (pivot in the authored frame, authored axes; BosunMotion writes
-- the Transforms, DogController applies them) or a Weld when `joint` is nil.
-- Authored frame: studs, origin on the ground between the feet, front -Z, up +Y, his right +X.
-- A black Labrador-type dog, about 2.1 studs at the shoulder, in an orange duty harness.
local BosunRig = {}

export type PartSpec = {
	name: string,
	shape: string, -- "Block" | "Ball" | "Cylinder"
	size: Vector3,
	cframe: CFrame, -- authored frame, rest pose
	color: string, -- hex
	material: string, -- Enum.Material name
	parent: string, -- "Body" (the invisible physics root) or another entry's name
	joint: string?, -- Motor6D name (a BosunMotion pose key); nil: welded
	pivot: Vector3?, -- the joint's pivot, authored frame
	harness: boolean?, -- hidden while a life jacket is on
}

BosunRig.COAT = "1E1C1E" -- black coat (not pure black, so the shape still reads)
local NOSE = "0C0C0D"
local EYE = "3B2414"
local TONGUE = "C9707E"
local HARNESS = "FF6600" -- Hull Orange duty harness (docs/05 8.3; DogWear.HARNESS_ORANGE)
local WEBBING = "1C1D20"
local TAPE = "D6D9DC" -- retroreflective tape

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local parts: { PartSpec } = {}
local function add(
	name: string,
	shape: string,
	size: Vector3,
	cf: CFrame,
	color: string,
	parent: string,
	joint: string?,
	pivot: Vector3?
): PartSpec
	local p: PartSpec = {
		name = name,
		shape = shape,
		size = size,
		cframe = cf,
		color = color,
		material = if color == BosunRig.COAT then "Fabric" else "SmoothPlastic",
		parent = parent,
		joint = joint,
		pivot = pivot,
	}
	table.insert(parts, p)
	return p
end

-- body: a block torso with a rounded chest and rump
add(
	"Torso",
	"Block",
	v(0.95, 0.9, 2.3),
	CFrame.new(0, 1.68, 0.05),
	BosunRig.COAT,
	"Body",
	"Root",
	v(0, 0, -0.85)
)
add("Chest", "Ball", v(1.0, 1.0, 1.0), CFrame.new(0, 1.66, -1.0), BosunRig.COAT, "Torso")
add("Rump", "Ball", v(0.92, 0.88, 0.88), CFrame.new(0, 1.74, 1.05), BosunRig.COAT, "Torso")

-- neck and head turn together about the neck base (the joint hides inside the chest)
local NECK = v(0, 2.0, -1.05)
add(
	"Head",
	"Block",
	v(0.78, 0.72, 0.8),
	CFrame.new(0, 2.62, -1.55),
	BosunRig.COAT,
	"Torso",
	"Neck",
	NECK
)
add(
	"Neck",
	"Block",
	v(0.56, 0.95, 0.56),
	CFrame.new(0, 2.2, -1.28) * CFrame.Angles(math.rad(-28), 0, 0),
	BosunRig.COAT,
	"Head"
)
add("Muzzle", "Block", v(0.48, 0.36, 0.55), CFrame.new(0, 2.48, -2.16), BosunRig.COAT, "Head")
add("Nose", "Block", v(0.24, 0.15, 0.08), CFrame.new(0, 2.6, -2.45), NOSE, "Head")
add(
	"Jaw",
	"Block",
	v(0.42, 0.12, 0.5),
	CFrame.new(0, 2.25, -2.12),
	BosunRig.COAT,
	"Head",
	"Jaw",
	v(0, 2.3, -1.86)
)
add("Tongue", "Block", v(0.22, 0.04, 0.3), CFrame.new(0, 2.32, -2.12), TONGUE, "Jaw")
for _, s in { -1, 1 } do
	local side = if s < 0 then "Left" else "Right"
	add(`Eye{side}`, "Ball", v(0.12, 0.12, 0.12), CFrame.new(0.22 * s, 2.76, -1.94), EYE, "Head")
	-- drop ears hanging beside the skull
	add(
		`Ear{side}`,
		"Block",
		v(0.1, 0.5, 0.34),
		CFrame.new(0.42 * s, 2.58, -1.42) * CFrame.Angles(0, 0, math.rad(8) * s),
		BosunRig.COAT,
		"Head"
	)
end

-- tail: two segments running back and down from the croup (+X pitch lowers it)
local TAIL = v(0, 1.95, 1.4)
local tail1 = CFrame.new(TAIL) * CFrame.Angles(math.rad(40), 0, 0)
add(
	"Tail1",
	"Block",
	v(0.22, 0.22, 0.62),
	tail1 * CFrame.new(0, 0, 0.31),
	BosunRig.COAT,
	"Torso",
	"Tail1",
	TAIL
)
local tip = tail1 * CFrame.new(0, 0, 0.6)
add(
	"Tail2",
	"Block",
	v(0.16, 0.16, 0.55),
	tip * CFrame.Angles(math.rad(15), 0, 0) * CFrame.new(0, 0, 0.27),
	BosunRig.COAT,
	"Tail1",
	"Tail2",
	tip.Position
)

-- legs: upper (shoulder / hip to knee) and lower (knee to paw), joints named <Front|Back><Left|Right><Upper|Lower>
BosunRig.HIP_Y = 1.5
BosunRig.KNEE_Y = 0.72
BosunRig.LEGS = {} :: { string }
for _, end_ in { "Front", "Back" } do
	local z = if end_ == "Front" then -0.82 else 0.92
	for _, s in { -1, 1 } do
		local leg = `{end_}{if s < 0 then "Left" else "Right"}`
		table.insert(BosunRig.LEGS, leg)
		local x = 0.28 * s
		local w = if end_ == "Back" then 0.32 else 0.27
		add(
			leg .. "Upper",
			"Block",
			v(w, 0.9, w + 0.06),
			CFrame.new(x, 1.15, z),
			BosunRig.COAT,
			"Torso",
			leg .. "Upper",
			v(x, BosunRig.HIP_Y, z)
		)
		add(
			leg .. "Lower",
			"Block",
			v(0.22, 0.66, 0.24),
			CFrame.new(x, 0.43, z),
			BosunRig.COAT,
			leg .. "Upper",
			leg .. "Lower",
			v(x, BosunRig.KNEE_Y, z)
		)
		add(
			leg .. "Paw",
			"Block",
			v(0.28, 0.14, 0.38),
			CFrame.new(x, 0.07, z - 0.06),
			BosunRig.COAT,
			leg .. "Lower"
		)
	end
end

-- the duty harness: back pad, side panels with retro tape, chest strap, grab handle
local HZ = -0.4
local function harness(name, shape, size, cf, color)
	add(name, shape, size, cf, color, "Torso").harness = true
end
harness("HarnessBack", "Block", v(0.99, 0.08, 0.95), CFrame.new(0, 2.15, HZ), HARNESS)
for _, s in { -1, 1 } do
	local side = if s < 0 then "Left" else "Right"
	harness(
		`HarnessSide{side}`,
		"Block",
		v(0.06, 0.78, 0.95),
		CFrame.new(0.5 * s, 1.78, HZ),
		HARNESS
	)
	harness(`HarnessTape{side}`, "Block", v(0.02, 0.08, 0.9), CFrame.new(0.535 * s, 1.86, HZ), TAPE)
end
harness("HarnessBelly", "Block", v(1.0, 0.07, 0.3), CFrame.new(0, 1.24, HZ), HARNESS)
harness("HarnessChest", "Block", v(0.86, 0.14, 0.08), CFrame.new(0, 1.82, -1.5), HARNESS)
harness("HarnessHandle", "Block", v(0.12, 0.08, 0.5), CFrame.new(0, 2.27, HZ), WEBBING)

BosunRig.PARTS = parts

-- Where the Wardrobe items are welded (DogWear `on`): Fore -> Torso, Head -> Head.
BosunRig.ANCHORS = { Fore = "Torso", Head = "Head" } :: { [string]: string }

return BosunRig
