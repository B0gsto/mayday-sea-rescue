--!strict
-- Flipbooks (FX1 / FX2, docs/12 2.11): the photoreal VFX sheets rendered from Blender sims by
-- art/source/fx/build_fx.py, their ParticleEmitter flipbook settings, and the per-tier particle
-- budgets of docs/06 section 3.5 ("quality tiers drop effects, never physics").
--
--   Flipbooks.id(name)                    "rbxassetid://..." (AssetIds.Fx), or a stock fallback
--   Flipbooks.spec(name)                  the sheet's layout / mode / framerate (frozen table)
--   Flipbooks.scale(kind, tier)           particle-rate multiplier for a tier ("High" | "Medium" | "Low")
--   Flipbooks.rate(kind, base, tier)      base * scale, rounded down to whole particles / s
--   Flipbooks.apply(emitter, name)        Texture + FlipbookLayout / Mode / Framerate / StartRandom
--
-- Lit sheets (spray, mist, smoke, foam, rain, underwater) are rendered under a soft overcast rig as
-- near-albedo and want LightInfluence 1; emissive sheets (flare head, sparks, parachute glow) carry
-- alpha from brightness and want LightEmission 1, LightInfluence 0.

local AssetIds = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("AssetIds"))

export type Layout = "None" | "Grid4x4" | "Grid8x8"
export type Mode = "Loop" | "OneShot" | "PingPong" | "Random"
export type Spec = {
	layout: Layout,
	mode: Mode,
	fps: number, -- frames per second for Loop / PingPong (OneShot spans the particle's lifetime)
	startRandom: boolean,
	emissive: boolean,
	fallback: string,
}
export type Kind = "spray" | "spindrift" | "rain" | "crestFoam" | "ambient" | "signal"

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function spec(
	layout: Layout,
	mode: Mode,
	fps: number,
	startRandom: boolean,
	emissive: boolean,
	fallback: string
): Spec
	return table.freeze({
		layout = layout,
		mode = mode,
		fps = fps,
		startRandom = startRandom,
		emissive = emissive,
		fallback = fallback,
	})
end

local Flipbooks = {}

Flipbooks.SHEETS = table.freeze({
	-- FX1 spray: one particle = one sim from first throw to dissipation (OneShot over the lifetime)
	FX_Spray_BowSheet = spec("Grid8x8", "OneShot", 0, false, false, SMOKE),
	FX_Spray_SlamBurst = spec("Grid8x8", "OneShot", 0, false, false, SMOKE),
	FX_Spray_Mist = spec("Grid8x8", "OneShot", 0, false, false, SMOKE),
	FX_Spray_Spindrift = spec("Grid8x8", "OneShot", 0, false, false, SMOKE),
	-- FX1 foam: single alpha maps (Trail / Beam / flat particle textures)
	FX_Foam_HullRing = spec("None", "Loop", 0, false, false, SMOKE),
	FX_Foam_WakeRibbon = spec("None", "Loop", 0, false, false, SMOKE),
	FX_Foam_CrestStreak = spec("None", "Loop", 0, false, false, SMOKE),
	FX_Foam_Swash = spec("None", "Loop", 0, false, false, SMOKE),
	-- FX2 rain: 16 streak variants (random start, held), splash and ripple sequences
	FX_Rain_Streak = spec("Grid4x4", "Loop", 0, true, false, SPARK),
	FX_Rain_SplashRing = spec("Grid4x4", "OneShot", 0, false, false, SPARK),
	FX_Rain_OnWater = spec("Grid4x4", "OneShot", 0, false, false, SPARK),
	-- FX2 smoke and pyrotechnics
	FX_Smoke_Orange = spec("Grid8x8", "OneShot", 0, false, false, SMOKE),
	FX_Flare_Smoke = spec("Grid8x8", "OneShot", 0, false, false, SMOKE),
	FX_Flare_Head = spec("Grid4x4", "Loop", 24, true, true, FIRE),
	FX_Flare_Sparks = spec("Grid4x4", "OneShot", 0, false, true, SPARK),
	FX_Flare_Parachute = spec("Grid4x4", "Loop", 18, true, true, SPARK),
	-- FX2 underwater: 16 floc variants (random start, held); a wobbling bubble loop
	FX_Under_MarineSnow = spec("Grid4x4", "Loop", 0, true, false, SPARK),
	FX_Under_Bubbles = spec("Grid4x4", "Loop", 12, true, false, SPARK),
} :: { [string]: Spec })

-- docs/06 3.5: spray, spindrift and rain Full / Half / Quarter; no spindrift far out on Low; crest
-- foam particles only on High. Ambient dressing (underwater snow, bubbles) is thinned like spray.
-- Signals (orange smoke, flares) are gameplay cues the player must see, so every tier keeps them.
local SCALE: { [Kind]: { [string]: number } } = {
	spray = { High = 1, Medium = 0.5, Low = 0.25 },
	spindrift = { High = 1, Medium = 0.5, Low = 0 },
	rain = { High = 1, Medium = 0.5, Low = 0.25 },
	crestFoam = { High = 1, Medium = 0, Low = 0 },
	ambient = { High = 1, Medium = 0.6, Low = 0.3 },
	signal = { High = 1, Medium = 1, Low = 1 },
}
Flipbooks.SCALE = SCALE

local Fx: { [string]: string } = (AssetIds :: any).Fx or {}

function Flipbooks.spec(name: string): Spec
	local s = Flipbooks.SHEETS[name]
	assert(s, "Flipbooks: unknown sheet " .. name)
	return s
end

-- The uploaded sheet, or the stock texture of the same kind until the upload lands (layout None then).
function Flipbooks.id(name: string): string
	return Fx[name] or Flipbooks.spec(name).fallback
end

function Flipbooks.uploaded(name: string): boolean
	return Fx[name] ~= nil
end

function Flipbooks.scale(kind: Kind, tier: string): number
	local row = SCALE[kind]
	assert(row, "Flipbooks: unknown kind " .. tostring(kind))
	return row[tier] or row.High
end

function Flipbooks.rate(kind: Kind, base: number, tier: string): number
	return math.floor(base * Flipbooks.scale(kind, tier))
end

function Flipbooks.apply(emitter: ParticleEmitter, name: string)
	local s = Flipbooks.spec(name)
	emitter.Texture = Flipbooks.id(name)
	if Flipbooks.uploaded(name) and s.layout ~= "None" then
		emitter.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[s.layout]
		emitter.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[s.mode]
		emitter.FlipbookFramerate = NumberRange.new(s.fps)
		emitter.FlipbookStartRandom = s.startRandom
	else
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	end
	if s.emissive then
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
	else
		emitter.LightInfluence = 1
	end
end

return Flipbooks
