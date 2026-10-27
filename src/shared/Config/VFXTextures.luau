--!strict
-- VFXTextures (docs/26): every texture VFXKit's presets use, by key. Swap a source (a Blender flipbook upload, a
-- verified free Creator Store image) by editing its row here only.
--   id       the Image ("rbxassetid://..." or a stock "rbxasset://" texture)
--   layout   the flipbook grid ("None" | "Grid2x2" | "Grid4x4" | "Grid8x8")
--   mode     "OneShot" (one cycle over the particle's life) | "Loop" | "PingPong" | "Random"
--   fps      Loop / PingPong frame rate; random: start on a random frame (variant sheets)
-- Store picks: docs/26-vfx-sources.md (each id checked on economy.roblox.com; free proof = the free public model or
-- Roblox Resources decal it ships in). A third-party image can be moderated later: replace store art with our own
-- Lego flipbooks before launch. TODO(blender flipbook): lego_plates, confetti_bricks and coin wait on our sheets.
local Config = script.Parent
local AssetIds = require(Config.AssetIds)
local UiImages = require(Config.UiImages)

export type Texture = {
	id: string,
	layout: string,
	mode: string,
	fps: number?,
	random: boolean?,
}

local Fx = (AssetIds :: any).Fx :: { [string]: string }
local CONFETTI = "rbxassetid://241685484" -- russelnuts, a white square (in model 688963157 Confetti Particles), tinted

return table.freeze({
	-- GoldenMan_Dev, stylized splash ring rising into a crown (in model 16354714995 Golden Particle Pack)
	splash_crown = { id = "rbxassetid://17063077953", layout = "Grid4x4", mode = "OneShot" },
	-- dragonome, a white teardrop (in model 688959832 Rain Particle, Nanonauts)
	droplets = { id = "rbxassetid://243132757", layout = "None", mode = "Loop" },
	-- Roblox Resources "water_splash_ring", a soft foam donut (decal 16811365121, public domain)
	foam_ring = { id = "rbxassetid://16811365086", layout = "None", mode = "Loop" },
	-- ours: the FX1 bow sheet (8x8), the boats' bow spray too
	bow_wave = { id = Fx.FX_Spray_BowSheet, layout = "Grid8x8", mode = "OneShot" },
	-- GoldenMan_Dev, chunky cartoon puffs that pop and shrink (in model 16354714995)
	puff_smoke = { id = "rbxassetid://16664772965", layout = "Grid4x4", mode = "OneShot" },
	-- TODO(blender flipbook) lego_plates: the tinted confetti square stands in for a flat Lego plate
	lego_plates = { id = CONFETTI, layout = "None", mode = "Loop" },
	-- TODO(blender flipbook) confetti_bricks: the tinted confetti square until our brick sheet lands
	confetti_bricks = { id = CONFETTI, layout = "None", mode = "Loop" },
	-- TODO(blender flipbook) coin: the HUD's coin sprite until our spinning coin sheet lands
	coin = { id = UiImages.Hud.Coin, layout = "None", mode = "Loop" },
	-- IxJoke, a thick white ring that grows and thins (in model 112672322113504 / 16354714995)
	shockwave_ring = { id = "rbxassetid://16477162837", layout = "Grid4x4", mode = "OneShot" },
	-- Arro_x, a soft-edged ring disc (in model 10198615035 Rei's Particle Pack); tinted gold
	glow_ring = { id = "rbxassetid://838367768", layout = "None", mode = "Loop" },
	-- m27frogy, the classic thin rain streak (in model 483675631 Rain (Particle)); the wheel's spin streaks too
	spin_streak = { id = "rbxassetid://241868005", layout = "None", mode = "Loop" },
	rain_streak = { id = "rbxassetid://241868005", layout = "None", mode = "Loop" },
	-- Snaliel, an elongated drop streak (in model 10198615035)
	sea_spray = { id = "rbxassetid://6763809313", layout = "None", mode = "Loop" },
	-- TheeTatahThailand, a glossy round bubble (in model 5463907036 Bubble effect!)
	bubbles = { id = "rbxassetid://243953162", layout = "None", mode = "Loop" },
} :: { [string]: Texture })
