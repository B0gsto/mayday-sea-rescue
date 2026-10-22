--!strict
-- Wildlife: the animal sanctuary and pets (docs/15 section 2, hook H4). Pure data plus the
-- deterministic rescue roll, safe to load in Lune (tests/Pets.spec.luau).
--
-- Each species is a chunky code-built Part animal (big eyes, simple shapes) until art lands
-- (CLAUDE.md). `rarePalette` is the rare colour variant the kids collect: a golden seal, an
-- albino puffin and so on. `verb` is the freeing action the world asks for: hold to cut a net or
-- a line, wipe oil off a bird.
--
-- Recovery is real time, 10 minutes, from the moment the animal is landed (rescue completed);
-- `PetRules` keeps the timestamp on the profile so it keeps recovering while the player is away.
-- Fair FOMO (docs/15 section 1): the sanctuary is free and nothing is lost for not playing.

export type PartShape = Enum.PartType
export type PartMaterial = Enum.Material

export type PartSpec = {
	name: string,
	size: Vector3,
	at: CFrame,
	color: string, -- palette key: Body, Belly, Head, Accent, Eye, Wing, Shell, Glint
	shape: PartShape?,
	material: PartMaterial?,
}

export type Palette = { [string]: Color3 }

export type Species = {
	id: string,
	label: string, -- 1-2 words, the pen prompt
	rareLabel: string, -- the rare colour variant's 1-2 words
	verb: string, -- Cut / Wipe / Free, the world action while freeing
	call: string, -- the radio line (no paragraphs)
	rareCall: string,
	palette: Palette,
	rarePalette: Palette,
	parts: { PartSpec },
}

local W = {}

local function p(
	name: string,
	size: Vector3,
	at: CFrame,
	color: string,
	shape: PartShape?,
	material: PartMaterial?
): PartSpec
	return {
		name = name,
		size = size,
		at = at,
		color = color,
		shape = shape,
		material = material,
	}
end

local function v(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function rot(x: number, y: number, z: number, rx: number, ry: number, rz: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)
end

local EYE = "Eye"
local GLINT = "Glint"

-- The five species. Faces are -Z (the same forward as the boats and the casualties).
W.SpeciesOrder = { "SealPup", "Puffin", "Otter", "Turtle", "Gull" } :: { string }

W.Species = {
	SealPup = {
		id = "SealPup",
		label = "Seal Pup",
		rareLabel = "Golden Seal",
		verb = "Cut",
		call = "Seal pup tangled in a net near the harbour.",
		rareCall = "Golden seal pup tangled in a net near the harbour.",
		palette = {
			Body = Color3.fromRGB(128, 136, 148),
			Belly = Color3.fromRGB(208, 214, 218),
			Head = Color3.fromRGB(136, 144, 156),
			Accent = Color3.fromRGB(38, 38, 44),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		rarePalette = {
			Body = Color3.fromRGB(230, 184, 82),
			Belly = Color3.fromRGB(255, 236, 176),
			Head = Color3.fromRGB(240, 198, 104),
			Accent = Color3.fromRGB(92, 64, 30),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		parts = {
			p("Body", Vector3.new(2.8, 1.4, 1.9), v(0, 0.95, 0), "Body"),
			p("Belly", Vector3.new(2.3, 0.7, 1.5), v(0, 0.55, -0.1), "Belly"),
			p("Head", Vector3.new(1.3, 1.15, 1.2), v(0, 1.55, -1.45), "Head", Enum.PartType.Ball),
			p("Snout", Vector3.new(0.7, 0.5, 0.6), v(0, 1.38, -2.05), "Head"),
			p(
				"Nose",
				Vector3.new(0.22, 0.18, 0.18),
				v(0, 1.5, -2.36),
				"Accent",
				Enum.PartType.Ball
			),
			p("Eye", Vector3.new(0.3, 0.3, 0.3), v(-0.38, 1.78, -1.98), EYE, Enum.PartType.Ball),
			p("Eye", Vector3.new(0.3, 0.3, 0.3), v(0.38, 1.78, -1.98), EYE, Enum.PartType.Ball),
			p(
				"Glint",
				Vector3.new(0.1, 0.1, 0.1),
				v(-0.32, 1.86, -2.14),
				GLINT,
				Enum.PartType.Ball
			),
			p("Glint", Vector3.new(0.1, 0.1, 0.1), v(0.32, 1.86, -2.14), GLINT, Enum.PartType.Ball),
			p("Flipper", Vector3.new(1.0, 0.18, 1.3), rot(-1.05, 0.45, -0.55, 0, 0, 0.28), "Body"),
			p("Flipper", Vector3.new(1.0, 0.18, 1.3), rot(1.05, 0.45, -0.55, 0, 0, -0.28), "Body"),
			p("Tail", Vector3.new(0.95, 0.16, 1.0), rot(0, 0.5, 1.05, 0.2, 0, 0), "Body"),
		},
	},
	Puffin = {
		id = "Puffin",
		label = "Puffin",
		rareLabel = "Albino Puffin",
		verb = "Wipe",
		call = "Puffin caught in an oil slick near the harbour.",
		rareCall = "Albino puffin caught in an oil slick near the harbour.",
		palette = {
			Body = Color3.fromRGB(40, 42, 48),
			Belly = Color3.fromRGB(246, 246, 240),
			Head = Color3.fromRGB(34, 36, 42),
			Accent = Color3.fromRGB(238, 146, 52),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		rarePalette = {
			Body = Color3.fromRGB(236, 232, 226),
			Belly = Color3.fromRGB(255, 255, 251),
			Head = Color3.fromRGB(246, 244, 240),
			Accent = Color3.fromRGB(238, 166, 166),
			Eye = Color3.fromRGB(120, 88, 88),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		parts = {
			p("Body", Vector3.new(1.5, 1.6, 1.3), v(0, 1.05, 0), "Body"),
			p("Belly", Vector3.new(1.0, 1.15, 0.95), v(0, 0.95, -0.35), "Belly"),
			p("Head", Vector3.new(1.1, 1.0, 1.0), v(0, 2.0, -0.2), "Head", Enum.PartType.Ball),
			p("Face", Vector3.new(0.92, 0.72, 0.22), v(0, 2.0, -0.7), "Belly"),
			p("Beak", Vector3.new(0.46, 0.4, 0.8), v(0, 1.98, -1.03), "Accent"),
			p("Eye", Vector3.new(0.22, 0.22, 0.22), v(-0.34, 2.14, -0.72), EYE, Enum.PartType.Ball),
			p("Eye", Vector3.new(0.22, 0.22, 0.22), v(0.34, 2.14, -0.72), EYE, Enum.PartType.Ball),
			p(
				"Glint",
				Vector3.new(0.08, 0.08, 0.08),
				v(-0.3, 2.2, -0.82),
				GLINT,
				Enum.PartType.Ball
			),
			p(
				"Glint",
				Vector3.new(0.08, 0.08, 0.08),
				v(0.3, 2.2, -0.82),
				GLINT,
				Enum.PartType.Ball
			),
			p("Wing", Vector3.new(0.2, 1.6, 0.9), rot(-0.9, 1.05, 0.1, 0, 0, 0.15), "Body"),
			p("Wing", Vector3.new(0.2, 1.6, 0.9), rot(0.9, 1.05, 0.1, 0, 0, -0.15), "Body"),
			p("Foot", Vector3.new(0.6, 0.16, 0.85), v(-0.38, 0.14, -0.5), "Accent"),
			p("Foot", Vector3.new(0.6, 0.16, 0.85), v(0.38, 0.14, -0.5), "Accent"),
			p("Tail", Vector3.new(0.7, 0.28, 0.5), v(0, 0.9, 0.76), "Body"),
		},
	},
	Otter = {
		id = "Otter",
		label = "Otter",
		rareLabel = "Silver Otter",
		verb = "Cut",
		call = "Otter caught in fishing line near the harbour.",
		rareCall = "Silver otter caught in fishing line near the harbour.",
		palette = {
			Body = Color3.fromRGB(132, 92, 60),
			Belly = Color3.fromRGB(214, 186, 150),
			Head = Color3.fromRGB(140, 98, 64),
			Accent = Color3.fromRGB(40, 34, 30),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		rarePalette = {
			Body = Color3.fromRGB(176, 182, 190),
			Belly = Color3.fromRGB(242, 244, 248),
			Head = Color3.fromRGB(190, 196, 204),
			Accent = Color3.fromRGB(70, 74, 82),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		parts = {
			p("Body", Vector3.new(2.5, 0.95, 1.15), v(0, 0.85, 0), "Body"),
			p("Tummy", Vector3.new(1.9, 0.5, 0.95), v(0, 0.52, -0.1), "Belly"),
			p("Head", Vector3.new(1.05, 1.0, 1.0), v(0, 1.35, -1.55), "Head", Enum.PartType.Ball),
			p("Muzzle", Vector3.new(0.62, 0.46, 0.52), v(0, 1.22, -2.02), "Belly"),
			p(
				"Nose",
				Vector3.new(0.2, 0.16, 0.16),
				v(0, 1.32, -2.28),
				"Accent",
				Enum.PartType.Ball
			),
			p("Eye", Vector3.new(0.28, 0.28, 0.28), v(-0.3, 1.52, -1.95), EYE, Enum.PartType.Ball),
			p("Eye", Vector3.new(0.28, 0.28, 0.28), v(0.3, 1.52, -1.95), EYE, Enum.PartType.Ball),
			p(
				"Glint",
				Vector3.new(0.09, 0.09, 0.09),
				v(-0.25, 1.58, -2.1),
				GLINT,
				Enum.PartType.Ball
			),
			p(
				"Glint",
				Vector3.new(0.09, 0.09, 0.09),
				v(0.25, 1.58, -2.1),
				GLINT,
				Enum.PartType.Ball
			),
			p("Ear", Vector3.new(0.32, 0.26, 0.16), v(-0.42, 1.76, -1.45), "Head"),
			p("Ear", Vector3.new(0.32, 0.26, 0.16), v(0.42, 1.76, -1.45), "Head"),
			p("Paw", Vector3.new(0.42, 0.26, 0.7), v(-0.52, 0.38, -1.1), "Body"),
			p("Paw", Vector3.new(0.42, 0.26, 0.7), v(0.52, 0.38, -1.1), "Body"),
			p("Tail", Vector3.new(0.52, 0.36, 1.9), rot(0, 0.78, 1.75, 0.16, 0, 0), "Body"),
		},
	},
	Turtle = {
		id = "Turtle",
		label = "Sea Turtle",
		rareLabel = "Golden Turtle",
		verb = "Cut",
		call = "Sea turtle tangled in line near the harbour.",
		rareCall = "Golden sea turtle tangled in line near the harbour.",
		palette = {
			Body = Color3.fromRGB(118, 138, 94),
			Belly = Color3.fromRGB(214, 204, 160),
			Head = Color3.fromRGB(126, 146, 102),
			Accent = Color3.fromRGB(88, 108, 72),
			Shell = Color3.fromRGB(88, 112, 74),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		rarePalette = {
			Body = Color3.fromRGB(180, 158, 102),
			Belly = Color3.fromRGB(246, 230, 176),
			Head = Color3.fromRGB(192, 170, 112),
			Accent = Color3.fromRGB(140, 112, 56),
			Shell = Color3.fromRGB(218, 170, 70),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		parts = {
			p("Shell", Vector3.new(2.3, 0.75, 2.7), v(0, 0.98, 0), "Shell", Enum.PartType.Ball),
			p("Plastron", Vector3.new(1.9, 0.26, 2.2), v(0, 0.58, 0), "Belly"),
			p("Head", Vector3.new(0.85, 0.75, 0.8), v(0, 0.95, -1.62), "Head", Enum.PartType.Ball),
			p("Eye", Vector3.new(0.22, 0.22, 0.22), v(-0.28, 1.1, -1.98), EYE, Enum.PartType.Ball),
			p("Eye", Vector3.new(0.22, 0.22, 0.22), v(0.28, 1.1, -1.98), EYE, Enum.PartType.Ball),
			p(
				"Glint",
				Vector3.new(0.07, 0.07, 0.07),
				v(-0.24, 1.15, -2.1),
				GLINT,
				Enum.PartType.Ball
			),
			p(
				"Glint",
				Vector3.new(0.07, 0.07, 0.07),
				v(0.24, 1.15, -2.1),
				GLINT,
				Enum.PartType.Ball
			),
			p("Flipper", Vector3.new(1.5, 0.16, 0.85), rot(-1.3, 0.6, -0.85, 0, 0.25, 0.2), "Body"),
			p(
				"Flipper",
				Vector3.new(1.5, 0.16, 0.85),
				rot(1.3, 0.6, -0.85, 0, -0.25, -0.2),
				"Body"
			),
			p(
				"Flipper",
				Vector3.new(1.0, 0.14, 0.6),
				rot(-1.05, 0.55, 0.95, 0, -0.2, 0.15),
				"Body"
			),
			p("Flipper", Vector3.new(1.0, 0.14, 0.6), rot(1.05, 0.55, 0.95, 0, 0.2, -0.15), "Body"),
			p("Tail", Vector3.new(0.4, 0.2, 0.62), v(0, 0.62, 1.5), "Body"),
		},
	},
	Gull = {
		id = "Gull",
		label = "Gull",
		rareLabel = "Snow Gull",
		verb = "Free",
		call = "Gull caught in fishing line near the harbour.",
		rareCall = "Snow gull caught in fishing line near the harbour.",
		palette = {
			Body = Color3.fromRGB(245, 245, 242),
			Belly = Color3.fromRGB(255, 255, 255),
			Head = Color3.fromRGB(250, 250, 248),
			Accent = Color3.fromRGB(240, 200, 60),
			Wing = Color3.fromRGB(190, 196, 204),
			Eye = Color3.fromRGB(18, 18, 22),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		rarePalette = {
			Body = Color3.fromRGB(255, 255, 255),
			Belly = Color3.fromRGB(255, 255, 255),
			Head = Color3.fromRGB(255, 255, 255),
			Accent = Color3.fromRGB(236, 190, 200),
			Wing = Color3.fromRGB(238, 242, 248),
			Eye = Color3.fromRGB(110, 90, 90),
			Glint = Color3.fromRGB(255, 255, 255),
		},
		parts = {
			p("Body", Vector3.new(1.25, 0.95, 1.9), v(0, 1.18, 0), "Body"),
			p("Belly", Vector3.new(0.95, 0.5, 1.35), v(0, 0.92, -0.05), "Belly"),
			p("Head", Vector3.new(0.82, 0.78, 0.8), v(0, 1.88, -0.92), "Head", Enum.PartType.Ball),
			p("Beak", Vector3.new(0.32, 0.28, 0.62), v(0, 1.84, -1.4), "Accent"),
			p("Eye", Vector3.new(0.2, 0.2, 0.2), v(-0.27, 2.0, -1.16), EYE, Enum.PartType.Ball),
			p("Eye", Vector3.new(0.2, 0.2, 0.2), v(0.27, 2.0, -1.16), EYE, Enum.PartType.Ball),
			p(
				"Glint",
				Vector3.new(0.07, 0.07, 0.07),
				v(-0.23, 2.05, -1.28),
				GLINT,
				Enum.PartType.Ball
			),
			p(
				"Glint",
				Vector3.new(0.07, 0.07, 0.07),
				v(0.23, 2.05, -1.28),
				GLINT,
				Enum.PartType.Ball
			),
			p("Wing", Vector3.new(2.5, 0.14, 1.0), rot(-1.28, 1.22, 0.0, 0, 0, 0.12), "Wing"),
			p("Wing", Vector3.new(2.5, 0.14, 1.0), rot(1.28, 1.22, 0.0, 0, 0, -0.12), "Wing"),
			p("Tail", Vector3.new(0.85, 0.12, 0.85), rot(0, 1.16, 1.15, 0.16, 0, 0), "Body"),
			p("Leg", Vector3.new(0.12, 0.62, 0.12), v(-0.32, 0.42, 0.25), "Accent"),
			p("Leg", Vector3.new(0.12, 0.62, 0.12), v(0.32, 0.42, 0.25), "Accent"),
			p("Foot", Vector3.new(0.42, 0.1, 0.52), v(-0.32, 0.12, 0.02), "Accent"),
			p("Foot", Vector3.new(0.42, 0.1, 0.52), v(0.32, 0.12, 0.02), "Accent"),
		},
	},
} :: { [string]: Species }

-- Recovery: real minutes from landing (docs/15 H4). One active pet at a time.
W.RecoverySeconds = 10 * 60 -- tune (docs/15: 10 real minutes)
W.MaxPets = 6
W.RareEvery = 8 -- one rescue in eight brings the rare colour variant -- tune

-- The station spot a pet naps at when the player idles there (PetController; the yard itself was removed).
W.Sanctuary = {
	position = Vector3.new(-158, 5.8, -48),
}

-- The pet follows at this offset behind the player; the animal's pivot sits on the ground.
W.Follow = {
	behind = 3.6,
	side = 3.2,
	hop = 0.32,
	speed = 8,
	snap = 70, -- studs: closer than this it always walks, farther it catches up at once
}

-- Riding the boat: the pet sits on the deck, aft of the helm and slightly to port.
W.Boat = {
	offset = Vector3.new(1.3, 0.45, 2.6),
	bob = 0.12,
}

-- The victim's invisible root sits below the surface (RescueService.RIG_TORSO - 4.55); lift the
-- animal's waterline back up to the sea surface.
W.RescueLift = 1.35

function W.label(speciesId: string, rare: boolean): string
	local spec = W.Species[speciesId]
	if not spec then
		return "Animal"
	end
	return if rare then spec.rareLabel else spec.label
end

function W.callLine(speciesId: string, rare: boolean): string
	local spec = W.Species[speciesId]
	if not spec then
		return "Wildlife in trouble near the harbour."
	end
	return if rare then spec.rareCall else spec.call
end

return W
