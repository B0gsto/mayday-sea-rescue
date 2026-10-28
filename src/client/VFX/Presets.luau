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
--   flash   true: skipped under Reduce motion (a big bright core)
--   ease / fade  a curve between the size / transparency keypoints ("out" fast then settle, "in", "back" overshoot)
-- A preset may also carry (FX1 spectacle, docs/26 "Satisfaction bar"), all timed from `impact` seconds after the play:
--   beams   light pillars (a Beam from the origin or the `top` point straight up), opts.color tints `tint` ones
--   punch   a camera kick: fov (degrees in) + a Camera/Shake layer; never under Reduce motion or opts.still
--   frame   the impact frame: a 2-3 frame screen tint / saturation / brightness pop that eases back (never orange)
--   hitstop seconds the bursts run at a fifth speed right at the impact (the HQ only)
--   sounds  layered clips (AudioConfig names) at the play point: impact + sweetener + tail
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
	flash: boolean?,
	ease: string?,
	fade: string?,
}
export type Beam = {
	color: Color3,
	width: number,
	height: number,
	time: number,
	emission: number?,
	at: string?,
	tint: boolean?,
}
export type Punch =
	{ fov: number, magnitude: number, roughness: number, time: number, pos: Vector3? }
export type Frame = { tint: Color3, saturation: number, brightness: number, contrast: number? }
export type Sound = { clip: string, delay: number?, volume: number?, pitch: number? }
export type Light = {
	color: Color3,
	brightness: number,
	range: number,
	time: number,
	minScale: number?,
}
export type Preset = {
	job: string,
	big: boolean?,
	layers: { Layer },
	light: Light?,
	impact: number?,
	beams: { Beam }?,
	punch: Punch?,
	frame: Frame?,
	hitstop: number?,
	sounds: { Sound }?,
}

-- docs/26 budgets: particles per play at full quality
Presets.CAPS =
	table.freeze({ feedback = 40, state = 40, ambience = 12, spectacle = 120, showcase = 160 })
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

---------------------------------------------------------------- curves

local EASE: { [string]: (number) -> number } = {
	out = function(x)
		return 1 - (1 - x) ^ 3
	end,
	["in"] = function(x)
		return x ^ 3
	end,
	back = function(x) -- overshoots ~10% then settles
		local u = x - 1
		return 1 + 2.7 * u ^ 3 + 1.7 * u ^ 2
	end,
}

-- Evenly spread values with an eased curve between each pair, as { time, value } keypoints (a NumberSequence takes
-- at most 20). Unknown or no ease: the values as they are (linear).
function Presets.curve(values: { number }, ease: string?): { { number } }
	local f = ease and EASE[ease]
	local segs = #values - 1
	if not f or segs < 1 then
		local out = {}
		for i, v in values do
			table.insert(out, { if segs < 1 then 0 else (i - 1) / segs, v })
		end
		return out
	end
	local m = math.min(8, math.floor(19 / segs))
	local out = {}
	for i = 1, segs do
		for j = 0, m - 1 do
			local x = j / m
			table.insert(
				out,
				{ (i - 1 + x) / segs, values[i] + (values[i + 1] - values[i]) * f(x) }
			)
		end
	end
	table.insert(out, { 1, values[#values] })
	return out
end

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

-- Seconds until every layer's last particle and beam is gone (the pooled host is free again).
function Presets.duration(p: Preset): number
	local t = 0
	for _, l in p.layers do
		t = math.max(t, (l.delay or 0) + l.lifetime[2])
	end
	for _, b in (p.beams or {}) :: { Beam } do
		t = math.max(t, (p.impact or 0) + b.time)
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

---------------------------------------------------------------- FX1 spectacle
-- The four big moments at the owner's showcase bar (docs/26 "Satisfaction bar"): a charge, then at `impact` a core
-- flash, a fan of light rays, studded shockwave rings, a brick / coin burst, a light pillar, a light pulse, a camera
-- punch and a layered sound. Lego bits only; nothing lands on a building (it all bursts from above the roof).

local function core(color: Color3, size: number, delay: number, emission: number): Layer
	return {
		tex = "core_flash",
		count = 1,
		colors = { color },
		at = "top",
		size = { size * 0.3, size, size * 1.15 },
		transparency = { 0, 0.15, 1 },
		lifetime = { 0.35, 0.35 },
		speed = { 0, 0 },
		emission = emission,
		delay = delay,
		flash = true,
		ease = "out", -- snaps open
		fade = "in", -- holds bright, then drops
	}
end

-- the wind-up: a small glow swelling over `time` (the impact follows)
local function charge(color: Color3, size: number, time: number): Layer
	return {
		tex = "core_flash",
		count = 1,
		colors = { color },
		at = "top",
		size = { size * 0.15, size },
		transparency = { 0.5, 0 },
		lifetime = { time, time },
		speed = { 0, 0 },
		emission = 0.8,
		ease = "in", -- the swell accelerates into the hit
	}
end

-- god rays fanning up from the top point; they stretch out and stop (drag), then fade
local function rays(
	count: number,
	colors: { Color3 },
	length: number,
	delay: number,
	emission: number
): Layer
	return {
		tex = "light_ray",
		count = count,
		colors = colors,
		at = "top",
		streak = true,
		size = { length * 0.35, length, length * 0.9 },
		transparency = { 0.1, 0.25, 1 },
		lifetime = { 0.55, 0.75 },
		speed = { 30, 45 },
		spread = { 75, 75 },
		drag = 7,
		emission = emission,
		delay = delay,
		ease = "back", -- shoots out past full length and settles
	}
end

local function studRing(color: Color3, size: number, life: number, delay: number): Layer
	return with(groundRing("stud_ring", color, { size * 0.8, size }, life, delay), {
		transparency = { 0, 0, 0.5 },
	})
end

local function coins(count: number, speed: { number }, spread: number, delay: number): Layer
	return {
		tex = "coin",
		count = count,
		colors = { WHITE },
		at = "top",
		size = { 2.2 },
		transparency = { 0, 0, 0, 1 },
		lifetime = { 1.3, 1.7 },
		speed = speed,
		spread = { spread, spread },
		accel = GRAVITY,
		drag = 0.4,
		delay = delay,
	}
end

local function sounds(list: { { any } }): { Sound }
	local out = {}
	for _, s in list do
		table.insert(out, { clip = s[1], delay = s[2], volume = s[3], pitch = s[4] })
	end
	return out
end

local HQ_AT = 0.5 -- the charge, then everything hits at once
local WARM = Color3.fromRGB(255, 236, 180) -- the white-hot core, warmed so it never blows the frame out

-- spectacle: your HQ levels up, the biggest moment in the game (the only white-hot core and the only slow-mo)
Presets.ALL.fx1_hq_levelup = {
	job = "showcase",
	big = true,
	impact = HQ_AT,
	hitstop = 0.22,
	layers = {
		charge(GOLD, 20, HQ_AT),
		with(core(WARM, 12, HQ_AT, 0.6), { lifetime = { 0.22, 0.22 } }), -- a hit, gone before it hides the HQ
		with( -- under 0.5 emission and half see-through: still gold on a bright sky
			rays(14, { GOLD, YELLOW }, 26, HQ_AT, 0.45),
			{ transparency = { 0.4, 0.5, 1 } }
		),
		studRing(GOLD, 24, 1.1, HQ_AT),
		studRing(WHITE, 17, 0.9, HQ_AT + 0.18),
		with( -- floats down for ~2.5 s: the settle
			confetti(60, { 36, 56 }, 32, { RED, WHITE, YELLOW, NAVY, GOLD }),
			{ delay = HQ_AT, lifetime = { 2.2, 2.8 }, drag = 1.1, accel = Vector3.new(0, -18, 0) }
		),
		with(plates({ RED, WHITE, YELLOW, NAVY }, 16), { delay = HQ_AT }),
		with(table.clone(BUILD[2]), { delay = HQ_AT + 0.05 }), -- the dust ring settles
		coins(16, { 26, 40 }, 45, HQ_AT + 0.12),
	},
	beams = {
		{ color = GOLD, width = 6, height = 70, time = 2.2, emission = 0.5, at = "top" },
		{ color = WARM, width = 3, height = 80, time = 1.6, emission = 0.8, at = "top" },
	},
	light = { color = GOLD, brightness = 6, range = 60, time = 1.4 },
	punch = {
		fov = 7,
		magnitude = 1.6,
		roughness = 16,
		time = 0.55,
		pos = Vector3.new(0.15, 0.3, 0),
	},
	frame = {
		tint = Color3.fromRGB(255, 250, 236),
		saturation = 0.35,
		brightness = 0.12,
		contrast = 0.12,
	},
	sounds = sounds({
		{ "FX_Whoosh", 0, 1, 0.9 },
		{ "FX_Boom", HQ_AT, 1.2, 0.9 },
		{ "FX_TonalHit", HQ_AT, 1, 1 },
		{ "FX_ChimeTail", HQ_AT + 0.25, 1, 1 },
		{ "FX_PlasticRain", HQ_AT + 1.1, 1, 1.1 },
	}),
}

local GOLD_AT = 0.3

-- spectacle: a golden call delivered (OpsDebrief): a gold pillar, gold rays and a coin fountain round you
Presets.ALL.fx1_golden_rescue = {
	job = "showcase",
	big = true,
	impact = GOLD_AT,
	layers = {
		with(charge(GOLD, 9, GOLD_AT), { emission = 0.5 }),
		core(GOLD, 7, GOLD_AT, 0.6),
		rays(10, { GOLD, YELLOW }, 7, GOLD_AT, 0.4),
		studRing(GOLD, 13, 0.85, GOLD_AT),
		with(coins(13, { 30, 42 }, 60, GOLD_AT), { size = { 1.3 } }), -- up and out, never a pile on you
		with(
			confetti(24, { 18, 28 }, 55, { GOLD, WHITE }),
			{ delay = GOLD_AT, size = { 1.4, 1.3 } }
		),
		with(plates({ GOLD }, 10), { delay = GOLD_AT + 0.05, emission = 0.3, size = { 1.6 } }),
	},
	beams = { { color = GOLD, width = 6, height = 45, time = 1.2, emission = 0.5 } },
	light = { color = GOLD, brightness = 4, range = 30, time = 1 },
	punch = {
		fov = 4,
		magnitude = 0.8,
		roughness = 18,
		time = 0.4,
		pos = Vector3.new(0.05, 0.12, 0),
	},
	frame = { tint = Color3.fromRGB(255, 247, 224), saturation = 0.25, brightness = 0.08 },
	sounds = sounds({
		{ "FX_Whoosh", 0, 0.7, 1.15 },
		{ "FX_TonalHit", GOLD_AT, 0.8, 1.2 },
		{ "FX_Coins", GOLD_AT + 0.05, 1.2, 1 },
		{ "FX_ChimeHit", GOLD_AT, 1, 1 },
		{ "FX_ChimeTail", GOLD_AT + 0.4, 0.8, 1.1 },
	}),
}

local WHEEL_AT = 0.2 -- a short rarity-coloured charge as the capsule pops

-- spectacle: a Legendary / Mythic prize pops over the wheel; opts.color = the rarity, opts.scale 0.88 / 1
Presets.ALL.fx1_wheel_jackpot = {
	job = "showcase",
	big = true,
	impact = WHEEL_AT,
	layers = {
		with(tinted(charge(WHITE, 14, WHEEL_AT)), { emission = 0.4 }), -- low emission: pink, not a white dot
		tinted(core(WHITE, 14, WHEEL_AT, 0.9)),
		tinted(rays(12, { WHITE }, 18, WHEEL_AT, 0.5)), -- under 0.6 so the rarity colour still reads
		tinted(studRing(WHITE, 12, 0.8, WHEEL_AT)),
		tinted(studRing(WHITE, 8, 0.7, WHEEL_AT + 0.25)),
		with(
			tinted(confetti(56, { 16, 30 }, 55, { WHITE })),
			{ delay = WHEEL_AT, size = { 1.6, 1.5 } }
		),
		with(
			confetti(14, { 14, 24 }, 50, { WHITE, GOLD }),
			{ delay = WHEEL_AT, size = { 1.6, 1.5 } }
		),
		with(coins(14, { 18, 30 }, 50, WHEEL_AT + 0.08), { at = "origin", size = { 1.8 } }) :: Layer,
	},
	beams = { { color = WHITE, width = 10, height = 50, time = 1.6, emission = 1, tint = true } },
	light = { color = WHITE, brightness = 4, range = 36, time = 1 },
	punch = { fov = 4, magnitude = 0.9, roughness = 18, time = 0.4 },
	frame = { tint = WHITE, saturation = 0.3, brightness = 0.08 }, -- opts.color (the rarity) tints it lightly
	sounds = sounds({
		{ "FX_Boom", 0, 0.8, 1.1 },
		{ "FX_TonalHit", 0, 0.9, 1.1 },
		{ "FX_ChimeHit", 0.08, 1, 1 },
		{ "FX_ChimeTail", 0.3, 0.9, 1 },
		{ "FX_PlasticRain", 0.9, 0.8, 1.15 },
	}),
}

-- spectacle (small): a building finished / upgraded, the Lego build snap: the last brick clacks home, a studded
-- ring and the plates race out low, dust settles, confetti and short rays only above the roof
Presets.ALL.fx1_build_snap = {
	job = "spectacle",
	impact = 0,
	layers = {
		studRing(WHITE, 20, 0.8, 0),
		groundRing("shockwave_ring", WHITE, { 11, 12.5 }, 0.6, 0.1),
		plates({ RED, WHITE, YELLOW, NAVY }, 12),
		with(table.clone(BUILD[2]), { transparency = { 0.5 }, count = 8 }), -- the dust never hides you
		confetti(12, { 18, 28 }, 38, { RED, WHITE, YELLOW, SEA, GREEN }),
		rays(8, { WHITE, YELLOW }, 6, 0, 0.3),
	},
	light = { color = WHITE, brightness = 2, range = 30, time = 0.6 },
	punch = { fov = 2.5, magnitude = 0.5, roughness = 20, time = 0.3 },
	sounds = sounds({
		{ "FX_PlasticDrop", 0, 1, 1 },
		{ "FX_ChimeHit", 0.05, 0.6, 1.2 },
		{ "FX_PlasticRain", 0.45, 0.7, 1.2 },
	}),
}

return Presets
