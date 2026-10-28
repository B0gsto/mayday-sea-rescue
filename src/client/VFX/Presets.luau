--!strict
-- VFX presets (docs/26 "Moments"): every effect as data, played by name through VFXKit. Pure (Lune-tested in
-- tests/VFXPresets.spec.luau): the presets, their validation (job caps, required fields) and the quality /
-- distance / reduce-motion scaler.
-- A layer is one burst of one texture (VFXTextures key); `colors` with n entries makes n emitters sharing `count`.
--   size / transparency   keypoints spread evenly over the particle's life ({ 2, 6 } = 2 -> 6)
--   lifetime / speed      { min, max };  spread { x, y } degrees;  accel / drag / rotation / spin as on ParticleEmitter
--   at      "origin" (default) | "top": opts.height above the origin (confetti above a site, never on it)
--   ring    true: emitted round a ring of opts.radius (a footprint's edge) instead of a point
--   flat    true: lies flat on the ground (a shockwave / foam ring; give it speed { 0.01, 0.01 })
--   streak  true: stretched along its flight (spin streaks)
--   tint    true: opts.color replaces the layer's colours (rarity, call kind)
--   delay   seconds after the play
--   emission LightEmission (docs/26: <= 0.3 except `big` presets, the biggest rewards)
local Presets = {}

export type Layer = {
	tex: string,
	count: number,
	colors: { Color3 },
	size: { number },
	transparency: { number }?,
	lifetime: { number },
	speed: { number },
	spread: { number }?,
	accel: Vector3?,
	drag: number?,
	rotation: { number }?,
	spin: { number }?,
	dir: string?,
	at: string?,
	ring: boolean?,
	flat: boolean?,
	streak: boolean?,
	tint: boolean?,
	delay: number?,
	emission: number?,
}
export type Light = {
	color: Color3,
	brightness: number,
	range: number,
	time: number,
	minScale: number?,
}
export type Preset = { job: string, big: boolean?, layers: { Layer }, light: Light? }

-- docs/26 budgets: particles per play at full quality
Presets.CAPS = table.freeze({ feedback = 40, state = 40, ambience = 12, spectacle = 120 })
Presets.CULL = 250 -- studs from the camera: farther plays are skipped
Presets.EMISSION = 0.3

---------------------------------------------------------------- palette (docs/26 "Look")

local RED = Color3.fromRGB(201, 26, 9) -- Lego bright red, coastguard
local WHITE = Color3.fromRGB(242, 243, 242)
local NAVY = Color3.fromRGB(0, 32, 96)
local YELLOW = Color3.fromRGB(250, 200, 10)
local GOLD = Color3.fromRGB(255, 198, 64)
local SEA = Color3.fromRGB(0, 160, 175)
local GREEN = Color3.fromRGB(75, 151, 74)
local DUST = Color3.fromRGB(246, 238, 222) -- a warm white: tan reads as nothing on the green plates
local FOAM = Color3.fromRGB(232, 240, 238)
local SMOKE = Color3.fromRGB(226, 226, 222)

local GRAVITY = Vector3.new(0, -60, 0)

---------------------------------------------------------------- shared layers

local function plates(colors: { Color3 }, count: number): Layer
	return {
		tex = "lego_plates",
		count = count,
		colors = colors,
		ring = true,
		size = { 2.6 },
		transparency = { 0, 0, 0, 1 },
		lifetime = { 0.55, 0.8 }, -- about the hop's flight: particles never collide, so fade before the ground
		speed = { 14, 20 },
		spread = { 30, 30 },
		accel = Vector3.new(0, -50, 0),
		rotation = { 0, 360 },
		spin = { -220, 220 },
	}
end

local function confetti(count: number, speed: { number }, spread: number, colors: { Color3 }): Layer
	return {
		tex = "confetti_bricks",
		count = count,
		colors = colors,
		at = "top",
		size = { 1.9, 1.8 },
		transparency = { 0, 0, 1 },
		lifetime = { 1.4, 2.1 },
		speed = speed,
		spread = { spread, spread },
		accel = Vector3.new(0, -30, 0),
		drag = 0.6,
		rotation = { 0, 360 },
		spin = { -360, 360 },
	}
end

local function groundRing(
	tex: string,
	color: Color3,
	size: { number },
	life: number,
	delay: number?
): Layer
	return {
		tex = tex,
		count = 1,
		colors = { color },
		flat = true,
		size = size,
		transparency = { 0.1, 0.25, 0.6 },
		lifetime = { life, life },
		speed = { 0.01, 0.01 },
		delay = delay,
	}
end

-- a shared layer with some fields replaced
local function with(l: Layer, patch: { [string]: any }): Layer
	for k, v in patch do
		(l :: any)[k] = v
	end
	return l
end

-- the rarity's colour (opts.color), from the play point itself (the prize pops there)
local function tinted(l: Layer): Layer
	l.tint, l.at = true, nil
	return l
end

local BUILD: { Layer } = {
	plates({ RED, WHITE, YELLOW, NAVY }, 16),
	{ -- one dust puff ring round the footprint
		tex = "puff_smoke",
		count = 10,
		colors = { DUST },
		ring = true,
		size = { 5, 5.5 },
		transparency = { 0 }, -- the studded balls pop themselves
		lifetime = { 0.8, 1 },
		speed = { 4, 7 },
		spread = { 80, 80 },
		drag = 3,
		rotation = { 0, 360 },
	},
	confetti(14, { 14, 22 }, 40, { RED, WHITE, YELLOW, SEA, GREEN }),
}

local function arc(color: Color3, size: number): Layer
	return {
		tex = "spin_streak",
		count = 1,
		colors = { color },
		size = { size, size * 1.1 },
		transparency = { 0, 0.1, 1 },
		lifetime = { 0.45, 0.45 },
		speed = { 0, 0 },
		rotation = { 200, 200 },
		spin = { 540, 540 },
		emission = 0.3,
	}
end

local function concat(a: { Layer }, b: { Layer }): { Layer }
	local out = table.clone(a)
	table.move(b, 1, #b, #out + 1, out)
	return out
end

---------------------------------------------------------------- the moments

Presets.ALL = {
	-- feedback: a building / level finished (ConstructionController.finish); radius = footprint, height = roof
	build_done = { job = "feedback", layers = BUILD },
	-- spectacle: your HQ levels up; the build burst, a tall confetti brick column and a soft gold shockwave
	hq_levelup = {
		job = "spectacle",
		big = true,
		layers = concat(BUILD, {
			confetti(50, { 30, 44 }, 22, { RED, WHITE, YELLOW, GOLD }),
			-- the outer ring at 55% and half see-through: a full-size gold disc read as a flat decal over the HQ
			with(
				groundRing("shockwave_ring", GOLD, { 13, 14.5 }, 0.9),
				{ transparency = { 0.5, 0.6, 0.9 } }
			),
			groundRing("shockwave_ring", GOLD, { 11, 12 }, 0.7, 0.25),
		}),
		light = { color = GOLD, brightness = 2, range = 40, time = 0.8 },
	},
	-- feedback: a survivor leaves the water (the climb starts): a white crown, droplets, a foam ring
	pickup_splash = {
		job = "feedback",
		layers = {
			{
				tex = "splash_crown",
				count = 3,
				colors = { FOAM },
				size = { 6, 7 },
				transparency = { 0, 0, 0.4 },
				lifetime = { 0.7, 0.8 },
				speed = { 0.5, 1 },
				spread = { 10, 10 },
			},
			{
				tex = "droplets",
				count = 20,
				colors = { WHITE },
				size = { 1.6, 0.7 },
				transparency = { 0, 0.2, 1 },
				lifetime = { 0.6, 0.9 },
				speed = { 12, 18 },
				spread = { 35, 35 },
				accel = GRAVITY,
			},
			groundRing("foam_ring", FOAM, { 10, 11 }, 1),
		},
	},
	-- spectacle (small): the rescue is done (OpsDebrief); lifebuoy plates and coins round you, a gold stud
	-- fountain over your head (~1.4 s), then CashBurst
	rescue_done = {
		job = "spectacle",
		layers = {
			with(plates({ RED, WHITE }, 16), { size = { 3.4 }, speed = { 18, 26 } }),
			{
				tex = "coin",
				count = 7, -- half (AD r3: a big coin wave hid the player; the stud fountain is the main event)
				colors = { WHITE },
				size = { 1.8 },
				transparency = { 0, 0, 0, 1 },
				lifetime = { 0.7, 0.85 }, -- gone before they reach the water
				speed = { 24, 30 }, -- above the plates, so the coins read
				spread = { 28, 28 },
				accel = GRAVITY,
			},
			{ -- gold studs rise 7-10 studs, well over the head, and fall back
				tex = "lego_plates",
				count = 7,
				colors = { GOLD },
				size = { 1.7 },
				transparency = { 0, 0, 0, 1 },
				lifetime = { 1.1, 1.25 },
				speed = { 30, 35 },
				spread = { 12, 12 },
				accel = GRAVITY,
				rotation = { 0, 360 },
				spin = { -180, 180 },
				emission = 0.3,
				delay = 0.15,
			},
		},
	},
	-- spectacle: a golden call taken (Waypoint); a gold brick burst round you and a gold ring
	golden_accept = {
		job = "spectacle",
		layers = {
			confetti(30, { 16, 26 }, 60, { GOLD, WHITE }),
			groundRing("shockwave_ring", GOLD, { 14, 15 }, 0.8),
		},
		light = { color = GOLD, brightness = 1.5, range = 24, time = 0.6 },
	},
	-- state: the depot barge ties up (DepotController); pass the bow at the waterline, height = its deck
	barge_moor = {
		job = "state",
		layers = {
			{
				tex = "bow_wave",
				count = 3,
				colors = { FOAM },
				size = { 3, 7 },
				transparency = { 0.35, 1 },
				lifetime = { 0.9, 1.3 },
				speed = { 3, 6 },
				spread = { 50, 15 },
			},
			groundRing("foam_ring", FOAM, { 15, 17 }, 1.4, 0.2),
			groundRing("foam_ring", FOAM, { 10, 11 }, 1.2, 0.5),
			{ -- the horn's soft puff
				tex = "puff_smoke",
				count = 4,
				colors = { WHITE },
				at = "top",
				size = { 4, 5 },
				transparency = { 0 },
				lifetime = { 1.2, 1.8 },
				speed = { 3, 5 },
				spread = { 12, 12 },
				drag = 1.5,
				rotation = { 0, 360 },
				delay = 0.1,
			},
		},
	},
	-- feedback: a flapper tick while the prize wheel spins: a stud-thick arc whirls round the flapper and yellow
	-- stud chips fly off the rim
	wheel_spin = {
		job = "feedback",
		layers = {
			-- played at the hub: three concentric arcs at the rim's radius stack into a band that sweeps the rim
			arc(YELLOW, 13),
			arc(YELLOW, 12.2),
			arc(WHITE, 11.4),
		},
	},
	-- feedback: yellow brick chips thrown off the rim where the flapper clicks (with wheel_spin at the hub)
	wheel_chips = {
		job = "feedback",
		layers = {
			{ -- along the rim's travel (+X of the play CFrame), falling away
				tex = "confetti_bricks",
				count = 4,
				colors = { YELLOW },
				dir = "Right",
				size = { 1.9, 1.6 },
				transparency = { 0, 0, 1 },
				lifetime = { 0.6, 0.8 }, -- still flying after the 0.45 s arc
				speed = { 14, 20 },
				spread = { 35, 35 },
				accel = GRAVITY,
				rotation = { 0, 360 },
				spin = { -360, 360 },
			},
		},
	},
	-- spectacle: the prize pops; opts.color = the rarity, opts.scale sizes it (Common 0.4 .. Mythic 1)
	wheel_win = {
		job = "spectacle",
		big = true,
		layers = {
			tinted(confetti(70, { 14, 26 }, 70, { WHITE })),
			confetti(10, { 12, 20 }, 60, { WHITE }),
			tinted(groundRing("shockwave_ring", WHITE, { 12, 13 }, 0.7)),
		},
		light = { color = WHITE, brightness = 1.5, range = 24, time = 0.7, minScale = 0.8 },
	},
	-- ambience: one slow puff from a chimney near the player
	chimney_puff = {
		job = "ambience",
		layers = {
			{
				tex = "puff_smoke",
				count = 1,
				colors = { SMOKE },
				size = { 3.5, 5 },
				transparency = { 0, 0, 0.3 },
				lifetime = { 3, 4 },
				speed = { 2, 3 },
				spread = { 8, 8 },
				accel = Vector3.new(0.6, 0.3, 0),
				rotation = { 0, 360 },
				spin = { -15, 15 },
			},
		},
	},
} :: { [string]: Preset }

---------------------------------------------------------------- validation

local DIRS = { Top = true, Bottom = true, Left = true, Right = true, Front = true, Back = true }

local function range(v: any): boolean
	return type(v) == "table" and #v == 2 and type(v[1]) == "number" and v[2] >= v[1]
end

local function seq(v: any): boolean
	return type(v) == "table" and #v >= 1 and type(v[1]) == "number"
end

-- ok, or false and why. `textures` is VFXTextures (every layer's tex must be a key of it).
function Presets.validate(p: any, textures: { [string]: any }): (boolean, string?)
	local cap = type(p) == "table" and Presets.CAPS[p.job]
	if not cap then
		return false, "unknown job"
	end
	if type(p.layers) ~= "table" or #p.layers == 0 then
		return false, "no layers"
	end
	local total = 0
	for i, l in p.layers do
		local why = if not textures[l.tex]
			then "unknown texture"
			elseif type(l.count) ~= "number" or l.count < 1 then "count"
			elseif type(l.colors) ~= "table" or #l.colors == 0 then "colors"
			elseif not seq(l.size) then "size"
			elseif l.transparency ~= nil and not seq(l.transparency) then "transparency"
			elseif not range(l.lifetime) or l.lifetime[1] <= 0 then "lifetime"
			elseif not range(l.speed) then "speed"
			elseif l.dir ~= nil and not DIRS[l.dir] then "dir"
			elseif (l.emission or 0) > (if p.big then 1 else Presets.EMISSION) then "emission"
			else nil
		if why then
			return false, `layer {i}: {why}`
		end
		total += l.count
	end
	if total > cap then
		return false, `{total} particles > {p.job} cap {cap}`
	end
	return true, nil
end

-- Seconds until every layer's last particle is gone (the pooled host is free again).
function Presets.duration(p: Preset): number
	local t = 0
	for _, l in p.layers do
		t = math.max(t, (l.delay or 0) + l.lifetime[2])
	end
	return t
end

---------------------------------------------------------------- scaling

-- Graphics level 1..10 -> 0.3 .. 1; 0 (Automatic) -> 0.75 (the engine already trims on weak devices).
function Presets.quality(level: number): number
	if level <= 0 then
		return 0.75
	end
	return 0.3 + 0.7 * (math.clamp(level, 1, 10) - 1) / 9
end

-- Particles for one emitter: base * scale * quality, halved under reduce motion; never 0 for a base above 0
-- (a crown or a ring is one particle and must still show).
function Presets.count(base: number, scale: number, level: number, reduced: boolean): number
	if base <= 0 or scale <= 0 then
		return 0
	end
	local n = base * scale * Presets.quality(level) * (if reduced then 0.5 else 1)
	return math.max(1, math.floor(n + 0.5))
end

function Presets.visible(distance: number): boolean
	return distance <= Presets.CULL
end

---------------------------------------------------------------- FX2 core loop
-- The everyday moments at the owner's "satisfying and nice" bar (docs/26): anticipation -> impact -> settle in 2-4
-- layers with eased size / fade curves, and a layered sound. Extra preset fields (VFXKit plays them; `sounds` and
-- `punch` match the FX1 spectacle kit):
--   sounds      { { clip, delay?, volume?, pitch? } }  AudioConfig clips at the play point (impact + sweetener)
--   punch       { fov, shake, time }  a camera kick (fov degrees in, negative widens); off under Reduce motion
--   impactTint  Color3: a soft 0.25 s colour wash on the impact (never orange); off under Reduce motion

-- `n` samples of a -> b along the easing `f` (evenly spread keypoints: a curve, not a straight ramp)
local function curve(a: number, b: number, f: (number) -> number, n: number?): { number }
	local out = {}
	local k = n or 6
	for i = 0, k - 1 do
		table.insert(out, a + (b - a) * f(i / (k - 1)))
	end
	return out
end
local function outBack(t: number): number -- overshoots ~10% then settles
	return 1 + 2.70158 * (t - 1) ^ 3 + 1.70158 * (t - 1) ^ 2
end
local function outCubic(t: number): number
	return 1 - (1 - t) ^ 3
end
local function inCubic(t: number): number -- holds, then goes (a fade that stays solid)
	return t ^ 3
end

local POP = curve(0, 1, inCubic) -- solid, then a quick fade
local COOL = Color3.fromRGB(226, 242, 255)

local function puffs(count: number, color: Color3, from: number, to: number, life: number): Layer
	return {
		tex = "puff_smoke",
		count = count,
		colors = { color },
		size = curve(from, to, outBack),
		transparency = { 0 }, -- the studded balls pop themselves
		lifetime = { life * 0.8, life },
		speed = { 5, 9 },
		spread = { 60, 60 },
		drag = 3,
		rotation = { 0, 360 },
	}
end

local function drops(count: number, speed: { number }, spread: number, size: number): Layer
	return {
		tex = "droplets",
		count = count,
		colors = { WHITE },
		size = curve(size, size * 0.35, outCubic),
		transparency = POP,
		lifetime = { 0.5, 0.75 },
		speed = speed,
		spread = { spread, spread },
		accel = GRAVITY,
	}
end

local function crown(count: number, from: number, to: number): Layer
	return {
		tex = "splash_crown",
		count = count,
		colors = { FOAM },
		size = curve(from, to, outBack),
		transparency = { 0, 0, 0.1, 0.5 },
		lifetime = { 0.6, 0.7 },
		speed = { 0.5, 1 },
		spread = { 10, 10 },
	}
end

type FxSound = { clip: string, delay: number?, volume: number?, pitch: number? }

local function preset(p: { [string]: any }): Preset
	return p :: any
end

-- feedback: Captain Nitro fires (BoatController); played at the stern with its up axis pointing back over the
-- wake: a jet of drops, a white bow-wave fan and exhaust studs; a whoosh, a wide-FOV kick
Presets.ALL.nitro_burst = preset({
	job = "feedback",
	layers = {
		drops(14, { 26, 36 }, 14, 2.2),
		{
			tex = "bow_wave",
			count = 2,
			colors = { FOAM },
			size = curve(2, 8, outBack),
			transparency = { 0.15, 0.2, 1 },
			lifetime = { 0.5, 0.6 },
			speed = { 4, 6 },
			spread = { 20, 20 },
		},
		with(
			puffs(6, WHITE, 1.6, 4.2, 0.85),
			{ speed = { 12, 18 }, spread = { 14, 14 }, drag = 4 }
		),
		{ -- the jet: long stretched spray streaks, white and sea teal
			tex = "sea_spray",
			count = 8,
			colors = { WHITE, SEA },
			streak = true,
			size = curve(6.5, 2, outCubic),
			transparency = POP,
			lifetime = { 0.6, 0.8 },
			speed = { 42, 54 },
			spread = { 8, 8 },
			accel = Vector3.new(0, -30, 0),
		},
		with(
			plates({ WHITE, SEA }, 4),
			{ ring = false, size = { 1.6 }, speed = { 18, 24 }, spread = { 18, 18 } }
		),
	},
	sounds = {
		{ clip = "FX_Whoosh", volume = 1, pitch = 1.05 } :: FxSound,
		{ clip = "Hull_SprayHiss", delay = 0.05, volume = 0.7, pitch = 1.15 } :: FxSound,
	},
	punch = { fov = -9, shake = 0.2, time = 0.45 },
	impactTint = COOL,
})

-- feedback: the Nitro kick on the water (BoatController, upright at the stern with nitro_burst): a flat
-- sea-cyan ring snaps out 3 -> 18 studs, a foam ring after it
Presets.ALL.nitro_ring = preset({
	job = "feedback",
	layers = {
		with( -- 2-3 hull widths across, sea cyan so it reads on the white foam
			groundRing("shockwave_ring", SEA, curve(3, 18, outCubic), 0.4),
			{ transparency = { 0, 0.15, 1 } }
		),
		with(groundRing("foam_ring", FOAM, curve(4, 13, outCubic), 0.55), { delay = 0.04 }),
	},
})

-- state: Captain Nitro is still burning (BoatController, every ~0.12 s of the 4 s burst): the stern jet keeps
-- throwing streaks, drops and a puff back over the wake. Silent (the burst's whoosh and the engine carry it)
Presets.ALL.nitro_trail = preset({
	job = "state",
	layers = {
		drops(6, { 24, 32 }, 16, 2.4), -- a Layer first: the literal below then types as one
		{
			tex = "sea_spray",
			count = 6,
			colors = { WHITE, SEA },
			streak = true,
			size = curve(7, 2, outCubic),
			transparency = POP,
			lifetime = { 0.5, 0.65 },
			speed = { 38, 48 },
			spread = { 10, 10 },
			accel = Vector3.new(0, -30, 0),
		},
		with(
			puffs(2, WHITE, 2.2, 4.8, 0.65),
			{ speed = { 10, 14 }, spread = { 14, 14 }, drag = 4 }
		),
	},
})

-- feedback: the hull bumps a rock / quay / boat (BoatController); at the bow: a small crown, drops, spray puffs;
-- a wooden thud under a splash and a short shake
Presets.ALL.bump_splash = preset({
	job = "feedback",
	layers = {
		crown(2, 4, 9),
		drops(16, { 16, 24 }, 50, 2),
		puffs(6, FOAM, 2.2, 5, 0.65),
		with(
			confetti(6, { 14, 20 }, 45, { WHITE, Color3.fromRGB(160, 165, 169) }), -- Lego light grey chips
			{ at = "origin", size = { 2.8, 2.6 }, lifetime = { 0.6, 0.8 }, accel = GRAVITY }
		),
	},
	sounds = {
		{ clip = "FX_Thud", volume = 1, pitch = 0.9 } :: FxSound,
		{ clip = "FX_SplashSmall", delay = 0.03, volume = 0.9 } :: FxSound,
	},
	punch = { fov = 0, shake = 0.45, time = 0.3 },
	impactTint = COOL,
})

-- feedback: your boat is put in the water (a launch from the board / the free jet ski): a crown, drops, a foam ring
Presets.ALL.launch_splash = preset({
	job = "feedback",
	layers = {
		crown(2, 5, 9),
		drops(18, { 16, 24 }, 40, 1.6),
		drops(8, { 30, 40 }, 8, 2), -- the column shoots up first
		with(
			groundRing("foam_ring", FOAM, curve(8, 14, outCubic), 1, 0.05),
			{ transparency = { 0.1, 0.2, 0.7 } }
		),
	},
	sounds = {
		{ clip = "FX_Plop", volume = 1 } :: FxSound,
		{ clip = "Splash_Entry", delay = 0.05, volume = 0.45, pitch = 1.3 } :: FxSound,
	},
})

-- feedback: you take the helm (BoatController): the hull dips, a foam ring and a few drops; a slap and a splash
Presets.ALL.board_hop = preset({
	job = "feedback",
	layers = {
		groundRing("foam_ring", FOAM, curve(7, 12, outCubic), 0.8),
		with(
			groundRing("shockwave_ring", SEA, curve(4, 10, outCubic), 0.5),
			{ transparency = { 0.2, 0.4, 1 } }
		),
		drops(10, { 10, 14 }, 70, 1.5),
		puffs(4, WHITE, 1.4, 3, 0.5),
	},
	sounds = {
		{ clip = "Hull_Slap", volume = 0.5, pitch = 1.2 } :: FxSound,
		{ clip = "FX_SplashSmall", delay = 0.04, volume = 0.6, pitch = 1.1 } :: FxSound,
	},
})

-- feedback: a new crew member arrives at your dock (FeedbackController, as their name tag pops): plates hop out
-- round their feet, a dust ring, a few bricks over their head
Presets.ALL.crew_arrive = preset({
	job = "feedback",
	layers = {
		with(plates({ RED, WHITE, YELLOW }, 12), { size = { 1.8 }, speed = { 10, 14 } }),
		with(
			groundRing("shockwave_ring", WHITE, curve(3, 9, outCubic), 0.5),
			{ transparency = { 0.2, 0.4, 1 } }
		),
		confetti(10, { 8, 12 }, 40, { RED, WHITE, YELLOW }),
	},
	sounds = { { clip = "FX_Pop", volume = 1, pitch = 1.05 } :: FxSound },
})

-- spectacle (small): a quest handed in (HudController, award reason Quest:*): bricks rain from over your head, a
-- white ring and coins hop; a chime over the coins
Presets.ALL.quest_done = preset({
	job = "spectacle",
	layers = {
		confetti(22, { 14, 22 }, 35, { RED, WHITE, YELLOW, SEA, GREEN }),
		with(
			groundRing("shockwave_ring", WHITE, curve(4, 13, outCubic), 0.6),
			{ transparency = { 0.2, 0.35, 1 } }
		),
		with(plates({ YELLOW, WHITE }, 10), { speed = { 14, 18 } }),
		{
			tex = "coin",
			count = 6,
			colors = { WHITE },
			size = curve(0.8, 1.8, outBack),
			transparency = { 0, 0, 0, 1 },
			lifetime = { 0.7, 0.85 },
			speed = { 22, 28 },
			spread = { 20, 20 },
			accel = GRAVITY,
			delay = 0.1,
		},
	},
	sounds = {
		{ clip = "FX_Chime", volume = 1 } :: FxSound,
		{ clip = "Cash_Coins", delay = 0.15, volume = 0.6, pitch = 1.1 } :: FxSound,
	},
	punch = { fov = 2, shake = 0, time = 0.35 },
	impactTint = Color3.fromRGB(246, 248, 255),
})

-- feedback: a decor piece or a pet bought: a dust ring, plates hop, a few bricks above; till + pop
Presets.ALL.buy_pop = preset({
	job = "feedback",
	layers = {
		with(puffs(8, DUST, 2.5, 5, 0.6), { ring = true }),
		with(plates({ RED, WHITE, YELLOW, NAVY }, 12), { size = { 2 } }),
		confetti(8, { 10, 14 }, 35, { RED, WHITE, YELLOW, SEA }),
		{
			tex = "coin",
			count = 3,
			colors = { WHITE },
			size = curve(1.6, 3.4, outBack),
			transparency = { 0, 0, 0, 1 },
			lifetime = { 0.65, 0.8 },
			speed = { 20, 24 },
			spread = { 15, 15 },
			accel = GRAVITY,
			delay = 0.08,
		},
	},
	sounds = { { clip = "FX_Pop", volume = 1 } :: FxSound },
})

-- feedback: the Lego build beat's last brick lands (DockController): a white ring snaps out low round the
-- footprint, one studded dust ring rolls after it, plates hop off the edge; a thud under a brick snap, and on
-- your own plot a small settle shake (radius = the footprint)
Presets.ALL.place_dust = preset({
	job = "feedback",
	layers = {
		with(
			groundRing("shockwave_ring", WHITE, curve(6, 15, outCubic), 0.45),
			{ transparency = { 0, 0.3, 1 } }
		),
		with(
			puffs(10, DUST, 1.8, 3.2, 0.7),
			{ ring = true, speed = { 7, 11 }, spread = { 89, 89 }, delay = 0.04 }
		),
		with(plates({ WHITE, YELLOW, RED }, 12), { size = { 2 }, speed = { 12, 16 } }),
	},
	sounds = {
		{ clip = "FX_Thud", volume = 0.7, pitch = 1.25 } :: FxSound,
		{ clip = "FX_Snap", volume = 0.8, pitch = 0.85 } :: FxSound,
		{ clip = "FX_Pop", delay = 0.06, volume = 0.6, pitch = 0.9 } :: FxSound,
	},
	punch = { fov = 0, shake = 0.18, time = 0.25 },
})

-- feedback: a survivor lands aboard at the end of their climb (CasualtyController): lifebuoy plates hop off the
-- seat, a gold ring snaps out, a foam puff; a pop over a step tick (the call site adds a ding up a scale per seat)
Presets.ALL.survivor_aboard = preset({
	job = "feedback",
	layers = {
		with(
			plates({ RED, WHITE }, 14),
			{ ring = false, size = { 2.2 }, speed = { 14, 19 }, spread = { 55, 55 } }
		),
		with(puffs(5, WHITE, 2, 4.2, 0.55), { speed = { 3, 6 } }),
		with(
			groundRing("shockwave_ring", YELLOW, curve(2, 9, outCubic), 0.45),
			{ transparency = { 0, 0.2, 1 } }
		),
		groundRing("foam_ring", FOAM, curve(4, 8, outCubic), 0.9), -- it settles on the water
	},
	sounds = {
		{ clip = "FX_Pop", volume = 1, pitch = 1.15 } :: FxSound,
		{ clip = "UI_Step", delay = 0.05, volume = 0.8, pitch = 1.2 } :: FxSound,
	},
	punch = { fov = 2, shake = 0, time = 0.25 },
})

-- feedback: layered on pickup_splash (CasualtyController) as the survivor is pulled out: a tall crown snaps up, a
-- column of white drops shoots after them, teal drops fan out, a white ring kicks across the water; a splash, a
-- quick rising whoosh (the yank) and a soft pop; a small zoom kick
Presets.ALL.pickup_drops = preset({
	job = "feedback",
	layers = {
		crown(2, 4, 13),
		drops(10, { 32, 42 }, 10, 2.8), -- tall: it clears the hull from the chase camera
		with(drops(8, { 18, 24 }, 45, 2.2), { colors = { SEA } }),
		with(
			groundRing("shockwave_ring", WHITE, curve(4, 18, outCubic), 0.55),
			{ transparency = { 0, 0.25, 1 } }
		),
		with(puffs(4, FOAM, 2, 4.5, 0.6), { ring = true, speed = { 6, 9 }, spread = { 80, 80 } }),
		with(puffs(6, WHITE, 3.4, 6, 0.7), { speed = { 18, 28 }, spread = { 7, 7 }, drag = 3 }), -- the column
	},
	sounds = {
		{ clip = "FX_SplashSmall", volume = 1 } :: FxSound,
		{ clip = "FX_Whoosh", delay = 0.02, volume = 0.35, pitch = 1.7 } :: FxSound,
		{ clip = "FX_Pop", delay = 0.06, volume = 0.6, pitch = 0.95 } :: FxSound,
	},
	punch = { fov = 3, shake = 0.12, time = 0.3 },
})

return Presets
