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
		size = { 1.6 },
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
		size = { 1, 0.9 },
		transparency = { 0, 0, 1 },
		lifetime = { 1.4, 2.1 },
		speed = speed,
		spread = { spread, spread },
		accel = Vector3.new(0, -30, 0),
		drag = 0.6,
		rotation = { 0, 360 },
		spin = { -300, 300 },
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
		transparency = { 0, 0.3, 1 },
		lifetime = { life, life },
		speed = { 0.01, 0.01 },
		delay = delay,
	}
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
		size = { 3.5, 8 },
		transparency = { 0, 0.15, 0.7, 1 }, -- gone before the sheet's late wispy frames
		lifetime = { 0.8, 1.2 },
		speed = { 4, 7 },
		spread = { 80, 80 },
		drag = 3,
		rotation = { 0, 360 },
	},
	confetti(14, { 14, 22 }, 40, { RED, WHITE, YELLOW, SEA, GREEN }),
}

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
			groundRing("shockwave_ring", GOLD, { 4, 60 }, 0.9),
			groundRing("shockwave_ring", GOLD, { 3, 42 }, 0.9, 0.15),
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
				size = { 5, 11 },
				transparency = { 0.1, 1 },
				lifetime = { 0.7, 0.9 },
				speed = { 0.5, 1 },
				spread = { 10, 10 },
			},
			{
				tex = "droplets",
				count = 20,
				colors = { FOAM, SEA },
				streak = true, -- the teardrop stretches along its flight
				size = { 1.1, 0.6 },
				transparency = { 0, 0.2, 1 },
				lifetime = { 0.6, 0.9 },
				speed = { 12, 18 },
				spread = { 35, 35 },
				accel = GRAVITY,
			},
			groundRing("foam_ring", FOAM, { 4, 15 }, 0.9),
		},
	},
	-- spectacle (small): the rescue is done (OpsDebrief); lifebuoy plates and coins round you, then CashBurst
	rescue_done = {
		job = "spectacle",
		layers = {
			plates({ RED, WHITE }, 20),
			{
				tex = "coin",
				count = 12,
				colors = { WHITE },
				size = { 2.2 },
				transparency = { 0, 0, 0, 1 },
				lifetime = { 0.9, 1.2 },
				speed = { 14, 20 },
				spread = { 30, 30 },
				accel = GRAVITY,
			},
		},
	},
	-- spectacle: a golden call taken (Waypoint); a gold brick burst round you and a gold ring
	golden_accept = {
		job = "spectacle",
		layers = {
			confetti(30, { 16, 26 }, 60, { GOLD, WHITE }),
			groundRing("glow_ring", GOLD, { 4, 24 }, 0.9),
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
				size = { 6, 16 },
				transparency = { 0.2, 1 },
				lifetime = { 0.9, 1.3 },
				speed = { 3, 6 },
				spread = { 50, 15 },
			},
			groundRing("foam_ring", FOAM, { 6, 30 }, 1.4, 0.2),
			groundRing("foam_ring", FOAM, { 4, 22 }, 1.2, 0.5),
			{ -- the horn's soft puff
				tex = "puff_smoke",
				count = 4,
				colors = { WHITE },
				at = "top",
				size = { 2.5, 7 },
				transparency = { 0.15, 0.4, 1 },
				lifetime = { 1.2, 1.8 },
				speed = { 3, 5 },
				spread = { 12, 12 },
				drag = 1.5,
				rotation = { 0, 360 },
				delay = 0.1,
			},
		},
	},
	-- feedback: a flapper tick while the prize wheel spins; pass a CFrame whose RightVector is the rim's tangent
	wheel_spin = {
		job = "feedback",
		layers = {
			{
				tex = "spin_streak",
				count = 4,
				colors = { WHITE, GOLD },
				streak = true,
				dir = "Right",
				size = { 2.4, 1 },
				transparency = { 0, 1 },
				lifetime = { 0.3, 0.4 },
				speed = { 18, 26 },
				spread = { 10, 10 },
				emission = 0.3,
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
			tinted(groundRing("shockwave_ring", WHITE, { 2, 24 }, 0.7)),
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
				size = { 3, 7.5 },
				transparency = { 0.1, 0.3, 1 },
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

return Presets
