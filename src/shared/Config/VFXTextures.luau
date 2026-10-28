--!strict
-- VFXTextures (docs/26): every texture VFXKit's presets use, by key. Swap a source (a Blender flipbook upload, a
-- verified free Creator Store image) by editing its row here only.
--   id       the Image ("rbxassetid://..." or a stock "rbxasset://" texture)
--   layout   the flipbook grid ("None" | "Grid2x2" | "Grid4x4" | "Grid8x8")
--   mode     "OneShot" (one cycle over the particle's life) | "Loop" | "PingPong" | "Random"
--   fps      Loop / PingPong frame rate; random: start on a random frame (variant sheets)
-- Store picks: docs/26-vfx-sources.md (each id checked on economy.roblox.com; free proof = the free public model or
-- Roblox Resources decal it ships in). A third-party image can be moderated later: replace store art with our own
-- Lego flipbooks before launch. Ours win: art/source/vfx (render.py, RESULT.md), AD 8.6, 2026-10-28; the store id
-- each replaced stays as a commented fallback.
local Config = script.Parent
local AssetIds = require(Config.AssetIds)

export type Texture = {
	id: string,
	layout: string,
	mode: string,
	fps: number?,
	random: boolean?,
}

local Fx = (AssetIds :: any).Fx :: { [string]: string }

return table.freeze({
	-- ours: a Lego splash ring rising into a crown (fallback: GoldenMan_Dev 17063077953, Grid4x4)
	splash_crown = { id = "rbxassetid://105078983093984", layout = "Grid4x4", mode = "OneShot" },
	-- ours: chunky drop variants, one per particle (fallback: dragonome teardrop 243132757, None)
	droplets = {
		id = "rbxassetid://124291314580825",
		layout = "Grid2x2",
		mode = "Loop",
		fps = 0,
		random = true,
	},
	-- ours: a foam ring whose blobs pop out, top-down (fallback: Roblox Resources 16811365086, None)
	foam_ring = { id = "rbxassetid://97781101719165", layout = "Grid4x4", mode = "OneShot" },
	-- ours: the FX1 bow sheet (8x8), the boats' bow spray too
	bow_wave = { id = Fx.FX_Spray_BowSheet, layout = "Grid8x8", mode = "OneShot" },
	-- ours: studded puff balls that grow, shrink and pop, no alpha fade (fallback: GoldenMan_Dev 16664772965, Grid4x4)
	puff_smoke = { id = "rbxassetid://118276956792285", layout = "Grid4x4", mode = "OneShot" },
	-- ours: flat plate / tile variants (fallback: russelnuts white square 241685484, tinted)
	lego_plates = {
		id = "rbxassetid://110924692483658",
		layout = "Grid2x2",
		mode = "Loop",
		fps = 0,
		random = true,
	},
	-- ours: brick / plate variants (fallback: the tinted square 241685484)
	confetti_bricks = {
		id = "rbxassetid://101996281678498",
		layout = "Grid2x2",
		mode = "Loop",
		fps = 0,
		random = true,
	},
	-- ours: a spinning coin loop (fallback: the HUD coin UiImages.Hud.Coin, None)
	coin = {
		id = "rbxassetid://138851004137338",
		layout = "Grid4x4",
		mode = "Loop",
		fps = 24,
		random = true,
	},
	-- ours: one chunky white ground ring that grows, tinted (fallback: IxJoke 16477162837, Grid4x4)
	shockwave_ring = { id = "rbxassetid://113712077274625", layout = "Grid4x4", mode = "OneShot" },
	-- Arro_x, a soft-edged ring disc (in model 10198615035 Rei's Particle Pack); tinted gold
	glow_ring = { id = "rbxassetid://838367768", layout = "None", mode = "Loop" },
	-- ours: one arc, spun by the layer's RotSpeed; frames only change the sweep (fallback: Snaliel 6763809313, None)
	spin_streak = { id = "rbxassetid://100897359653428", layout = "Grid2x2", mode = "OneShot" },
	-- ours: rain streak variants (fallback: m27frogy 241868005, None)
	rain_streak = {
		id = "rbxassetid://86454296521550",
		layout = "Grid2x2",
		mode = "Loop",
		fps = 0,
		random = true,
	},
	-- FX1 spectacle (docs/26 "Satisfaction bar"). ours: a ring of studded round plates riding a band; it races out
	-- and the plates pop (render.py stud_ring)
	stud_ring = { id = "rbxassetid://131845697391608", layout = "Grid4x4", mode = "OneShot" },
	-- ours (glow.py): a tapered god ray along +Y, flown VelocityParallel
	light_ray = { id = "rbxassetid://102807810048685", layout = "None", mode = "Loop" },
	-- ours (glow.py): the light pillar's Beam texture, soft edges across its width
	light_beam = { id = "rbxassetid://92389586692257", layout = "None", mode = "Loop" },
	-- ours (glow.py): a crisp round core with a soft halo
	core_flash = { id = "rbxassetid://136452411239756", layout = "None", mode = "Loop" },
	-- Snaliel, an elongated drop streak (in model 10198615035)
	sea_spray = { id = "rbxassetid://6763809313", layout = "None", mode = "Loop" },
	-- TheeTatahThailand, a glossy round bubble (in model 5463907036 Bubble effect!)
	bubbles = { id = "rbxassetid://243953162", layout = "None", mode = "Loop" },
} :: { [string]: Texture })
