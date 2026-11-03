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
export type Punch = {
	fov: number, -- degrees in (negative widens)
	time: number,
	magnitude: number?, -- shake degrees (Camera/Shake)
	roughness: number?,
	pos: Vector3?,
	shake: number?, -- FX2 shorthand 0..1 instead of magnitude / roughness
}
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
		-- the bow wave's wash, every mooring (the tug horn is rationed to HORN_GAP in DepotController)
		sounds = { { clip = "FX_SplashSmall", volume = 0.5, pitch = 0.7 } },
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

function Presets.visible(distance: number, cull: number?): boolean
	return distance <= (cull or Presets.CULL)
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
local PALE_GOLD = Color3.fromRGB(255, 226, 140) -- rays: GOLD over the red plates read orange (AD r3)

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
			rays(14, { PALE_GOLD, WARM }, 26, HQ_AT, 0.45),
			{ transparency = { 0.4, 0.5, 1 } }
		),
		studRing(GOLD, 32, 1.1, HQ_AT),
		studRing(WHITE, 22, 0.9, HQ_AT + 0.18),
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
		with(core(GOLD, 5, GOLD_AT, 0.6), { lifetime = { 0.22, 0.22 } }),
		rays(10, { GOLD, YELLOW }, 7, GOLD_AT, 0.4),
		studRing(GOLD, 13, 0.85, GOLD_AT),
		with(coins(13, { 22, 30 }, 50, GOLD_AT), { size = { 1.3 } }), -- up and out, never a pile on you
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
	beams = { { color = WHITE, width = 10, height = 50, time = 1.6, emission = 0.6, tint = true } }, -- pink, not white
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
-- ring and the plates race out low, dust settles, confetti and short rays only above the roof. It escalates with the
-- level (docs/28 feel 6): Lv2 adds a gold ring and a second, higher confetti burst; Lv3 more plates and a gold light
-- pillar off the roof. Each tier carries its own sting: a chime that climbs one more step per level (the HQ and the
-- wheel keep Music_CrateFanfare).
local function snd(clip: string, delay: number, volume: number, pitch: number): Sound
	return { clip = clip, delay = delay, volume = volume, pitch = pitch }
end
local function buildSnap(tier: number): Preset
	local layers = {
		studRing(WHITE, 20, 0.8, 0),
		groundRing("shockwave_ring", WHITE, { 11, 12.5 }, 0.6, 0.1),
		plates({ RED, WHITE, YELLOW, NAVY }, ({ 16, 16, 24 })[tier]),
		with(table.clone(BUILD[2]), { transparency = { 0.5 }, count = 8 }), -- the dust never hides you
		with(
			confetti(({ 20, 36, 54 })[tier], { 18, 28 }, 38, { RED, WHITE, YELLOW, SEA, GREEN }),
			{ lifetime = { 1.9, 2.6 } }
		),
		rays(({ 8, 10, 12 })[tier], { WHITE, YELLOW }, 5 + tier, 0, 0.3),
	}
	local stings: { Sound } = {
		snd("FX_PlasticDrop", 0, 1, 1),
		snd("FX_ChimeHit", 0.05, 0.6, 1.2),
		snd("FX_PlasticRain", 0.45, 0.7, 1.2),
	}
	for step = 1, tier do -- the climbing chime: C, E, G
		table.insert(
			stings,
			snd("FX_Chime", 0.1 + (step - 1) * 0.16, 0.45 + tier * 0.05, ({ 1, 1.26, 1.5 })[step])
		)
	end
	if tier >= 2 then
		table.insert(layers, studRing(GOLD, 26, 1, 0.15))
		table.insert(
			layers,
			with(
				confetti(
					({ 0, 24, 36 })[tier],
					{ 28, 40 },
					30,
					if tier >= 3 then { GOLD } else { GOLD, WHITE, RED }
				),
				{ delay = 0.25, lifetime = { 2.1, 2.8 }, drag = 1 }
			)
		)
		table.insert(stings, snd("FX_PowerUp", 0.02, 0.5, 1.1))
		table.insert(stings, snd("FX_ChimeTail", 0.5, 0.7, 1.1))
	end
	if tier >= 3 then
		table.insert(layers, studRing(WHITE, 32, 1.1, 0.3))
		table.insert(stings, snd("FX_TonalHit", 0, 0.8, 1.15))
	end
	return {
		job = if tier >= 3 then "showcase" else "spectacle",
		impact = 0,
		layers = layers,
		beams = if tier >= 3
			then { { color = GOLD, width = 7, height = 60, time = 1.6, emission = 0.3, at = "top" } }
			else nil,
		light = {
			color = if tier >= 2 then GOLD else WHITE,
			brightness = 1 + tier,
			range = 30,
			time = 0.6,
		},
		punch = { fov = 2 + tier * 0.5, magnitude = 0.4 + tier * 0.15, roughness = 20, time = 0.3 },
		sounds = stings,
	}
end
Presets.ALL.fx1_build_snap = buildSnap(1)
Presets.ALL.fx1_build_snap_lv2 = buildSnap(2)
Presets.ALL.fx1_build_snap_lv3 = buildSnap(3)

local BUY_AT = 0.25

-- spectacle: a Robux purchase lands (PurchaseFxController, mon REVIEW #3): a gold charge, a ka-ching on the hit, a
-- fountain of coins and Lego bricks in the station colours round you, a gold studded ring and a short gold pillar
Presets.ALL.fx1_purchase = {
	job = "showcase",
	big = true,
	impact = BUY_AT,
	layers = {
		with(charge(GOLD, 8, BUY_AT), { emission = 0.5 }),
		with(core(GOLD, 5, BUY_AT, 0.5), { lifetime = { 0.2, 0.2 } }),
		rays(8, { GOLD, WHITE }, 7, BUY_AT, 0.35),
		studRing(GOLD, 12, 0.85, BUY_AT),
		studRing(WHITE, 8, 0.7, BUY_AT + 0.15),
		with(coins(16, { 24, 34 }, 40, BUY_AT), { size = { 1.5 } }),
		with(
			confetti(30, { 20, 30 }, 50, { RED, WHITE, YELLOW, NAVY }),
			{ delay = BUY_AT, size = { 1.5, 1.4 }, lifetime = { 1.8, 2.4 } }
		),
		with(plates({ RED, WHITE, GOLD }, 12), { delay = BUY_AT + 0.05, size = { 1.7 } }),
	},
	beams = { { color = GOLD, width = 5, height = 36, time = 1, emission = 0.45 } },
	light = { color = GOLD, brightness = 3, range = 26, time = 0.8 },
	punch = { fov = 3, magnitude = 0.5, roughness = 18, time = 0.35 },
	frame = { tint = Color3.fromRGB(255, 248, 230), saturation = 0.2, brightness = 0.06 },
	sounds = sounds({
		{ "FX_Whoosh", 0, 0.6, 1.2 },
		{ "Shop_Till", BUY_AT, 1.2, 1 },
		{ "FX_Coins", BUY_AT + 0.05, 1, 1.05 },
		{ "FX_ChimeHit", BUY_AT, 0.8, 1.1 },
		{ "FX_PlasticRain", BUY_AT + 0.9, 0.7, 1.15 },
	}),
}

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

-- state: the jet ski's rooster tail (RiderController, every 0.1 s at the stern, up axis back over the wake;
-- opts.scale = speed): a fan of white / sea-teal streaks, chunky drops and studded foam puffs. Silent: the
-- driver's Hull_Wake bed swells with speed (AudioController), ski_splash carries the hits
Presets.ALL.ski_rooster = preset({
	job = "state",
	layers = {
		drops(5, { 20, 30 }, 14, 2.2),
		{
			tex = "sea_spray",
			count = 4,
			colors = { WHITE, SEA },
			streak = true,
			size = curve(4.5, 1.5, outCubic),
			transparency = POP,
			lifetime = { 0.45, 0.6 },
			speed = { 26, 36 },
			spread = { 10, 10 },
			accel = Vector3.new(0, -40, 0),
		},
		with(puffs(2, FOAM, 1.6, 3.8, 0.7), { speed = { 8, 12 }, spread = { 16, 16 } }),
	},
})

-- state: side spray off the outside of a hard carve (RiderController, every 0.1 s; opts.scale = lateral g):
-- a white bow-wave sheet, drops and studded puffs thrown out and up. Silent like ski_rooster
Presets.ALL.ski_carve = preset({
	job = "state",
	layers = {
		drops(5, { 16, 24 }, 25, 2), -- a Layer first: the literal below then types as one
		{
			tex = "bow_wave",
			count = 1,
			colors = { FOAM },
			size = curve(2, 6, outBack),
			transparency = { 0.15, 0.25, 1 },
			lifetime = { 0.45, 0.55 },
			speed = { 3, 5 },
			spread = { 25, 25 },
		},
		with(puffs(2, FOAM, 1.8, 4, 0.6), { speed = { 6, 10 }, spread = { 30, 30 } }),
	},
})

-- feedback: a hard carve bites or the jet ski slams a crest (RiderController): a crown, drops, studded puffs and
-- a foam ring on the water; a splash under a spray hiss
Presets.ALL.ski_splash = preset({
	job = "feedback",
	layers = {
		crown(1, 3, 8),
		drops(12, { 16, 24 }, 40, 2.2),
		puffs(5, FOAM, 2, 4.5, 0.65),
		groundRing("foam_ring", FOAM, curve(3, 9, outCubic), 0.8),
	},
	sounds = {
		{ clip = "FX_SplashSmall", volume = 0.8 } :: FxSound,
		{ clip = "Hull_SprayHiss", delay = 0.03, volume = 0.5, pitch = 1.1 } :: FxSound,
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

-- the sub's ballast air (sub_dive / sub_surface): glossy bubbles rising off the hull
local function ballast(count: number, delay: number?): Layer
	return {
		tex = "bubbles",
		count = count,
		colors = { WHITE },
		size = curve(0.5, 1.2, outCubic), -- they grow as they rise
		transparency = { 0.1, 0.15, 1 },
		lifetime = { 0.8, 1.3 },
		speed = { 5, 9 },
		spread = { 35, 35 },
		drag = 1.5,
		delay = delay,
	}
end

-- feedback: your sub goes under (SubController; origin at the hull, opts.height up to the surface): ballast
-- bubbles off the hull, a small crown and a foam ring closing over it; a deep splash and a glug
Presets.ALL.sub_dive = preset({
	job = "feedback",
	layers = {
		ballast(14),
		with(crown(1, 3, 7), { at = "top" }),
		with(groundRing("foam_ring", FOAM, curve(6, 14, outCubic), 0.9, 0.05), { at = "top" }),
	},
	sounds = {
		{ clip = "Splash_Entry", volume = 0.45, pitch = 0.8 } :: FxSound,
		{ clip = "FX_Plop", delay = 0.15, volume = 0.8, pitch = 0.6 } :: FxSound,
	},
})

-- feedback: your sub breaks the surface (SubController; same origin): a burst of bubbles, then a crown, drops
-- and a foam ring where it pops up; a slap and a splash, a small camera kick
Presets.ALL.sub_surface = preset({
	job = "feedback",
	layers = {
		ballast(10),
		with(crown(2, 5, 10), { at = "top", delay = 0.05 }),
		with(drops(14, { 14, 20 }, 35, 1.6), { at = "top", delay = 0.05 }),
		with(groundRing("foam_ring", FOAM, curve(7, 16, outCubic), 1, 0.1), { at = "top" }),
	},
	sounds = {
		{ clip = "Hull_Slap", volume = 0.8, pitch = 0.9 } :: FxSound,
		{ clip = "FX_SplashSmall", delay = 0.05, volume = 0.8 } :: FxSound,
	},
	punch = { fov = 2, shake = 0.12, time = 0.3 },
})

-- ambience: a Lego dolphin of a passing pod dives back in (SeaLifeController): a small crown and drops; a plop
Presets.ALL.dolphin_leap = preset({
	job = "ambience",
	layers = {
		crown(1, 2.5, 6),
		drops(10, { 12, 18 }, 35, 1.4),
	},
	sounds = { { clip = "FX_SplashSmall", volume = 0.7, pitch = 1.15 } :: FxSound },
})

-- spectacle: the Lego whale breaches out at sea and crashes back (SeaLifeController): a wide crown, a tall
-- column of drops, foam puffs and a foam ring; a deep splash under a slap
Presets.ALL.whale_breach = preset({
	job = "spectacle",
	cull = 700, -- a far-off breach is the point: it reads across open sea
	layers = {
		crown(3, 8, 22),
		drops(26, { 24, 34 }, 40, 3),
		puffs(8, FOAM, 4, 9, 1.1),
		with(
			groundRing("foam_ring", FOAM, curve(14, 30, outCubic), 1.4, 0.05),
			{ transparency = { 0.1, 0.25, 0.8 } }
		),
	},
	sounds = {
		{ clip = "Splash_Entry", volume = 1, pitch = 0.6 } :: FxSound,
		{ clip = "Hull_Slam", delay = 0.05, volume = 0.6, pitch = 0.7 } :: FxSound,
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

-- feedback: that recruit reaches their job spot and clocks on (FeedbackController, feel review 11): a low teal ring
-- at their feet, a few plates hop, then their first pay coins pop over them; a snap, then coins
Presets.ALL.crew_start = preset({
	job = "feedback",
	layers = {
		with(
			groundRing("shockwave_ring", SEA, curve(2, 7, outCubic), 0.45),
			{ transparency = { 0.15, 0.35, 1 } }
		),
		with(plates({ SEA, WHITE, YELLOW }, 8), { size = { 1.6 }, speed = { 8, 11 } }),
		{
			tex = "coin",
			count = 4,
			colors = { WHITE },
			size = curve(0.8, 1.6, outBack),
			transparency = { 0, 0, 0, 1 },
			lifetime = { 0.6, 0.75 },
			speed = { 16, 20 },
			spread = { 18, 18 },
			accel = GRAVITY,
			delay = 0.9,
		},
	},
	sounds = {
		{ clip = "FX_Snap", volume = 0.8, pitch = 1.15 } :: FxSound,
		{ clip = "Cash_Coins", delay = 0.9, volume = 0.6, pitch = 1.15 } :: FxSound,
	},
})

-- feedback: the recruit's category icon lands over their building's sign (FeedbackController): a hop of teal plates
-- off the icon, above the building (never on it), with a ding
Presets.ALL.crew_clockon = preset({
	job = "feedback",
	layers = {
		with(plates({ SEA, WHITE, YELLOW }, 10), { size = { 1.4 }, speed = { 9, 12 } }),
	},
	sounds = {
		{ clip = "FX_Ding", volume = 0.8, pitch = 1.2 } :: FxSound,
		{ clip = "FX_ChimeHit", volume = 0.5, pitch = 1.1 } :: FxSound,
	},
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

-- spectacle: the boat levels up (docs/30, UpgradeStationController): played as it blasts at the top of the lift. Bricks
-- and spray out, then the slam: a foam ring on the water and one big boom at `impact`. No light, nothing flashes.
Presets.ALL.boat_levelup = preset({
	job = "spectacle",
	impact = 0.5,
	layers = {
		confetti(44, { 46, 74 }, 70, { RED, WHITE, YELLOW, NAVY, SEA }),
		with(plates({ RED, WHITE, YELLOW, NAVY }, 16), { size = { 3.2 } }),
		with(puffs(14, FOAM, 5, 12, 0.8), { ring = true, delay = 0.5 }),
		groundRing("shockwave_ring", FOAM, { 9, 13 }, 0.7, 0.5),
	},
	sounds = sounds({ { "FX_Boom", 0, 1.3, 1 } }),
	punch = { fov = 4, shake = 0.4, time = 0.35 },
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

-- spectacle: a sea plate lands (docs/27 plate_drop; ConstructionController lowers the deck, then plays this at the
-- deck centre on the water, radius = the plate's half width): one deep stud-snap, foam and white rings burst out
-- under the whole plate, splash crowns and spray, Lego plates skip out low, a dust puff settles; gulls after
Presets.ALL.plate_drop = preset({
	job = "spectacle",
	layers = {
		with(
			groundRing("foam_ring", FOAM, curve(12, 50, outCubic), 1.3), -- x4 by VFXKit at a plate radius
			{ transparency = { 0, 0.2, 0.75 } }
		),
		with(
			groundRing("shockwave_ring", WHITE, curve(10, 40, outCubic), 0.7, 0.04),
			{ transparency = { 0, 0.3, 1 } }
		),
		with(crown(6, 8, 18), { ring = true }),
		with(drops(30, { 20, 30 }, 55, 2.4), { ring = true }),
		with(plates({ RED, WHITE, YELLOW, SEA }, 24), { speed = { 22, 32 }, spread = { 20, 20 } }),
		with(puffs(10, FOAM, 4, 9, 0.9), { ring = true, speed = { 6, 10 }, spread = { 80, 80 } }),
	},
	sounds = {
		{ clip = "FX_PlasticDrop", volume = 1, pitch = 0.55 } :: FxSound, -- the deep CLICK
		{ clip = "FX_Thud", delay = 0.02, volume = 0.8, pitch = 0.6 } :: FxSound,
		{ clip = "Splash_Entry", delay = 0.08, volume = 0.7, pitch = 0.8 } :: FxSound,
		{ clip = "Gull_Flock", delay = 0.9, volume = 0.6 } :: FxSound,
	},
	punch = { fov = 3, shake = 0.35, time = 0.35 },
})

-- feedback: a craft flies off the Ramp Wharf's jump ramp (SeaPlateController, at the lip): a spray fan off the lip,
-- a foam ring under it; a whoosh and a splash
Presets.ALL.ramp_jump = preset({
	job = "feedback",
	layers = {
		crown(2, 5, 10),
		drops(16, { 18, 26 }, 35, 2),
		with(
			groundRing("foam_ring", FOAM, curve(6, 14, outCubic), 0.9),
			{ transparency = { 0.1, 0.3, 0.8 } }
		),
	},
	sounds = {
		{ clip = "FX_Whoosh", volume = 0.6, pitch = 1.3 } :: FxSound,
		{ clip = "FX_SplashSmall", delay = 0.05, volume = 0.7 } :: FxSound,
	},
	punch = { fov = -4, shake = 0, time = 0.35 },
})

-- state: a low helicopter's rotor wash on the sea (HeliController, every ~0.25 s while it hovers low over the
-- water; scale = how low): a foam ring pushed out under it and spray puffs blown flat off the ring. Silent (the
-- rotor loop and its wash bed carry it)
Presets.ALL.heli_downwash = preset({
	job = "state",
	layers = {
		with(
			groundRing("foam_ring", FOAM, curve(6, 16, outCubic), 0.9),
			{ transparency = { 0.3, 0.45, 1 } }
		),
		with(puffs(6, FOAM, 1.6, 3.6, 0.7), {
			ring = true,
			speed = { 16, 22 },
			spread = { 8, 8 },
			drag = 2.5,
			transparency = POP,
		}),
		with(drops(6, { 10, 16 }, 60, 1.2), { ring = true }),
	},
})

-- feedback: you push off into a sprint (SprintController; its up axis points back and up from the push-off foot):
-- a small kick of studded dust and two plates off the heel; a swoosh over a soft scuff
Presets.ALL.sprint_kick = preset({
	job = "feedback",
	layers = {
		with(puffs(4, DUST, 0.9, 2.2, 0.45), { speed = { 6, 10 }, spread = { 25, 25 }, drag = 5 }),
		with(
			plates({ WHITE, YELLOW }, 2),
			{ size = { 1.1 }, speed = { 9, 12 }, spread = { 20, 20 } }
		),
	},
	sounds = {
		{ clip = "FX_Swoosh", volume = 0.8, pitch = 1.15 } :: FxSound,
		{ clip = "FX_Thud", volume = 0.25, pitch = 1.6 } :: FxSound,
	},
})

-- feedback: a sprint brakes to a stop (SprintController; up axis forward and up from the planted front foot): a
-- low skid of studded dust ahead of the foot; a scuff thud under a short low swoosh
Presets.ALL.sprint_brake = preset({
	job = "feedback",
	layers = {
		with(puffs(5, DUST, 0.8, 2, 0.5), { speed = { 5, 8 }, spread = { 35, 35 }, drag = 6 }),
		with(plates({ WHITE }, 1), { size = { 1 }, speed = { 6, 8 }, spread = { 25, 25 } }),
	},
	sounds = {
		{ clip = "FX_Thud", volume = 0.35, pitch = 1.4 } :: FxSound,
		{ clip = "FX_Swoosh", volume = 0.5, pitch = 0.8 } :: FxSound,
	},
})

---------------------------------------------------------------- spin cinematic (owner 2026-11-01)
-- SpinCinematic's beats (Camera/SpinCinematic), fired by name with opts.color = the rarity and opts.still (the
-- cinematic drives its own camera). Bolt, brick and halo are Lego flipbooks; flare and rays are stand-ins until
-- theirs pass (an id change in VFXTextures). Played with the CFrame's up axis toward the camera (flare, halo, tunnel)
-- or straight up (beam, rays, shafts, bolt, coins, stars).
local STAR = Color3.fromRGB(255, 246, 214)
local BOLT_BLUE = Color3.fromRGB(170, 200, 255)

local function spinRays(count: number, length: number, delay: number, emission: number): Layer
	return with(tinted(rays(count, { WHITE }, length, delay, emission)), { tex = "spincine_rays" })
end

-- feedback: one rung of the rarity ladder: the hub flare pops a size up and throws a ring of studs
Presets.ALL.spincine_flare = preset({
	job = "spectacle",
	big = true,
	layers = {
		with(tinted(core(WHITE, 9, 0, 0.7)), { tex = "spincine_flare" }),
		with(spinRays(8, 8, 0, 0.5), { spread = { 180, 180 }, lifetime = { 0.4, 0.5 } }),
		tinted(studRing(WHITE, 9, 0.45, 0)),
	},
	light = { color = WHITE, brightness = 2, range = 20, time = 0.4 },
	sounds = sounds({ { "FX_Pop", 0, 0.7, 1 } }), -- SpinCinematic adds the climbing chime
})

-- spectacle: Rare: a rarity-coloured pillar shoots up off the wheel
Presets.ALL.spincine_beam = preset({
	job = "spectacle",
	big = true,
	layers = {
		with(spinRays(10, 16, 0, 0.5), { spread = { 30, 30 } }),
		tinted(studRing(WHITE, 14, 0.8, 0)),
	},
	beams = { { color = WHITE, width = 7, height = 90, time = 1.6, emission = 0.6, tint = true } },
	light = { color = WHITE, brightness = 3, range = 30, time = 1 },
	sounds = sounds({ { "FX_PowerUp", 0, 1, 1 }, { "FX_Chime", 0.15, 0.8, 1.2 } }),
})

-- spectacle: Epic / Legendary god rays fanning up off the stage
Presets.ALL.spincine_rays = preset({
	job = "showcase",
	big = true,
	layers = {
		with(spinRays(14, 22, 0, 0.5), { lifetime = { 1.2, 1.6 }, drag = 5 }),
		with(spinRays(10, 16, 0.5, 0.45), { lifetime = { 1, 1.3 }, drag = 5 }),
		with(tinted(charge(WHITE, 12, 0.5)), { tex = "spincine_flare", emission = 0.5 }),
	},
	sounds = sounds({ { "FX_Reveal", 0, 0.9, 1 } }),
})

-- spectacle: Mythic's ray tunnel: streaks race out from round the stage past the camera (opts.radius)
Presets.ALL.spincine_tunnel = preset({
	job = "showcase",
	big = true,
	layers = {
		{
			tex = "spincine_rays",
			count = 48,
			colors = { STAR, GOLD },
			ring = true,
			streak = true,
			size = { 3, 9, 6 },
			transparency = { 0.6, 0.2, 1 },
			lifetime = { 0.5, 0.7 },
			speed = { 50, 80 },
			emission = 0.7,
		},
	},
	sounds = sounds({ { "FX_Whoosh", 0, 0.8, 1.2 } }),
})

-- spectacle: Mythic's lightning strike lands on the wheel: a cold core, sparks, a stud ring and plates
Presets.ALL.spincine_bolt = preset({
	job = "showcase",
	big = true,
	layers = {
		with(core(STAR, 22, 0, 0.9), { tex = "spincine_flare" }),
		{
			tex = "spincine_bolt", -- toy lightning forks thrown off the strike (one variant each: random start, fps 0)
			count = 12,
			colors = { STAR, BOLT_BLUE },
			size = { 5, 9, 6 },
			transparency = { 0, 0.15, 1 },
			lifetime = { 0.3, 0.55 },
			speed = { 30, 55 },
			spread = { 180, 180 },
			rotation = { 0, 360 },
			drag = 4,
			emission = 1,
		},
		studRing(WHITE, 26, 0.8, 0),
		plates({ WHITE, YELLOW }, 14),
	},
	light = { color = BOLT_BLUE, brightness = 4, range = 60, time = 0.8 },
	sounds = sounds({ { "Thunder_Near", 0, 1.2, 1 }, { "FX_Boom", 0, 1.1, 0.8 } }),
})

-- spectacle: Mythic's night: a starfield ring at opts.radius (play it at a few heights)
Presets.ALL.spincine_stars = preset({
	job = "showcase",
	big = true,
	layers = {
		{
			tex = "spincine_flare",
			count = 90,
			colors = { STAR, BOLT_BLUE },
			ring = true,
			size = { 0, 0.9, 0.9, 0 },
			transparency = { 0, 0, 0, 1 },
			lifetime = { 6, 8 },
			speed = { 0.5, 2 },
			spread = { 60, 60 },
			emission = 1,
		},
	},
	sounds = sounds({ { "FX_Magic", 0, 0.5, 0.8 } }),
})

-- spectacle: Epic's nebula on the payoff stage: big soft studded clouds in the rarity colour drifting round the box
-- (opts.radius; play it at a few heights)
Presets.ALL.spincine_nebula = preset({
	job = "showcase",
	big = true,
	layers = {
		{
			tex = "puff_smoke",
			count = 24,
			colors = { WHITE },
			tint = true,
			ring = true,
			size = { 14, 26 },
			transparency = { 1, 0.55, 0.6, 1 },
			lifetime = { 3.5, 4.5 },
			speed = { 1, 3 },
			spread = { 40, 40 },
			rotation = { 0, 360 },
			spin = { -10, 10 },
			emission = 0.4,
		},
	},
	sounds = sounds({ { "FX_Magic", 0, 0.6, 0.75 } }),
})

-- spectacle: the gold Lego halo locks shut round the prize: a glow ring, a stud ring, gold confetti and rays
Presets.ALL.spincine_halo = preset({
	job = "showcase",
	big = true,
	layers = {
		with(
			groundRing("spincine_halo", GOLD, { 14, 26 }, 1.2),
			{ transparency = { 0, 0.1, 1 }, emission = 1 }
		),
		studRing(PALE_GOLD, 18, 0.9, 0.15),
		with(
			confetti(36, { 20, 34 }, 180, { GOLD, YELLOW, WHITE }),
			{ drag = 1.2, accel = Vector3.new(0, -14, 0) }
		),
		{
			tex = "spincine_brick", -- gold bricks tumbling off the locked ring; the sheet is gold already, so no tint
			count = 16,
			colors = { WHITE },
			size = { 2.4, 2.4, 2 },
			transparency = { 0, 0, 1 },
			lifetime = { 1.1, 1.7 },
			speed = { 16, 30 },
			spread = { 180, 180 },
			drag = 1,
			accel = Vector3.new(0, -18, 0),
			emission = 0.2,
		},
		with(rays(12, { PALE_GOLD }, 18, 0, 0.6), { tex = "spincine_rays", spread = { 180, 180 } }),
	},
	light = { color = GOLD, brightness = 4, range = 40, time = 1.4 },
	sounds = sounds({
		{ "FX_ChimeHit", 0, 1, 1 },
		{ "FX_TonalHit", 0, 0.9, 1.1 },
		{ "FX_ChimeTail", 0.3, 0.9, 1 },
	}),
})

-- spectacle: Legendary's golden sea: a gold splash ring where the plinth breaks the surface, shafts of light
Presets.ALL.spincine_shafts = preset({
	job = "showcase",
	big = true,
	layers = {
		groundRing("foam_ring", GOLD, { 8, 20 }, 1.2),
		groundRing("shockwave_ring", PALE_GOLD, { 6, 26 }, 1.4, 0.2),
		with(
			rays(10, { PALE_GOLD, GOLD }, 26, 0, 0.5),
			{ tex = "spincine_rays", lifetime = { 1.4, 1.8 }, drag = 4, spread = { 25, 25 } }
		),
	},
	beams = {
		{ color = GOLD, width = 14, height = 140, time = 4.5, emission = 0.5 },
		{ color = WARM, width = 6, height = 160, time = 4.2, emission = 0.8 },
	},
	light = { color = GOLD, brightness = 4, range = 50, time = 3 },
	sounds = sounds({ { "FX_Magic", 0, 1, 0.9 }, { "FX_SplashSmall", 0.1, 1, 0.7 } }),
})

-- spectacle: Legendary's coin rain from a disc above the stage (opts.radius)
Presets.ALL.spincine_coins = preset({
	job = "showcase",
	big = true,
	layers = {
		with(
			coins(40, { 2, 6 }, 60, 0),
			{ ring = true, lifetime = { 2.2, 2.8 }, accel = Vector3.new(0, -25, 0), drag = 0.6 }
		),
		with(
			coins(30, { 2, 6 }, 60, 0.6),
			{ ring = true, lifetime = { 2.2, 2.8 }, accel = Vector3.new(0, -25, 0), drag = 0.6 }
		),
		with(
			confetti(30, { 4, 10 }, 70, { GOLD, YELLOW }),
			{ ring = true, lifetime = { 2.4, 3 }, drag = 0.8, accel = Vector3.new(0, -12, 0) }
		),
	},
	sounds = sounds({
		{ "FX_Coins", 0, 1.1, 1 },
		{ "FX_PlasticRain", 0.4, 1, 1 },
		{ "FX_Coins", 0.7, 0.8, 1.1 },
	}),
})

-- spectacle: someone else's Legendary / Mythic: a tall rarity-coloured beam into the sky off their island
Presets.ALL.spincine_skybeam = preset({
	job = "spectacle",
	big = true,
	cull = 900,
	layers = { with(tinted(core(WHITE, 16, 0, 0.6)), { tex = "spincine_flare" }) },
	beams = {
		{ color = WHITE, width = 12, height = 420, time = 4, emission = 0.7, tint = true },
		{ color = WHITE, width = 4, height = 460, time = 3.5, emission = 1, tint = false },
	},
	sounds = sounds({ { "FX_PowerUp", 0, 0.8, 0.8 } }),
})

return Presets
