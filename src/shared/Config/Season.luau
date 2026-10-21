--!strict
-- Season: the Season Logbook (docs/15 hook H8; docs/04 section 3.1). Pure data, safe in Lune.
--
-- Season 1 runs 2026-10-24 00:00 UTC to 2026-12-05 23:59:59 UTC. The free track has 30 tiers;
-- every rescue, challenge, streak crate, album sticker and event rescue adds Season XP (scaled
-- by the rescue's grade). A tier pays Cash, Rep, a cosmetic data flag or a lantern-style surprise.
-- Unclaimed tiers stay claimable until the season end (fair-FOMO: nothing is lost).
--
-- The paid track is data only for now: the product sits at id 0 / ready = false in
-- MonetizationConfig and no purchase UI exists (the tier ids are the cosmetics it will grant).

export type Xp = {
	operation: { [string]: number },
	big: number,
	storm: number,
	event: number,
	sticker: number,
	challenge: number,
	streak: number,
}

export type Tier = {
	tier: number,
	xp: number, -- cumulative Season XP that finishes this tier
	cash: number,
	rep: number,
	cosmetic: string?,
	surprise: string?,
}

export type Paid = {
	product: string,
	price: number,
	cosmetics: { string },
}

export type Config = {
	id: string,
	name: string,
	startUtc: number,
	endUtc: number,
	maxTier: number,
	stepXp: number,
	firstTierXp: number,
	tiers: { Tier },
	xp: Xp,
	eventVariants: { [string]: boolean },
	cosmetics: { [string]: string },
	surprises: { [string]: string },
	paid: Paid,
}

local MAX_TIER = 30
local FIRST_TIER_XP = 100
local STEP_XP = 40

-- Per-tier pay (index = tier). Holes are tiers that only pay the neighbours' kind.
local CASH: { [number]: number } = {
	150,
	150,
	200,
	250,
	300,
	350,
	400,
	450,
	1000,
	1200,
	1300,
	1500,
	1700,
	1800,
	2000,
	2200,
	2400,
	2600,
	2800,
	3000,
	3200,
	3400,
	3600,
	3800,
	4000,
	4200,
	4500,
	4800,
	5200,
	6000,
}
local REP: { [number]: number } = {
	[2] = 20,
	[6] = 30,
	[10] = 40,
	[14] = 50,
	[18] = 60,
	[22] = 70,
	[26] = 80,
	[29] = 100,
}
local COSMETIC: { [number]: string } = {
	[3] = "Decal_Season1",
	[8] = "Wake_Season1",
	[12] = "Title_Season1",
	[30] = "Livery_Season1",
}
local SURPRISE: { [number]: string } = {
	[5] = "Lantern",
	[13] = "Gull",
	[19] = "Star",
}

local tiers: { Tier } = {}
local xp = 0
for i = 1, MAX_TIER do
	xp += FIRST_TIER_XP + STEP_XP * (i - 1)
	tiers[i] = {
		tier = i,
		xp = xp,
		cash = CASH[i] or 0,
		rep = REP[i] or 0,
		cosmetic = COSMETIC[i],
		surprise = SURPRISE[i],
	}
end

local Season: Config = {
	id = "S1",
	name = "Season 1",
	startUtc = 1792800000, -- 2026-10-24 00:00:00 UTC
	endUtc = 1796515199, -- 2026-12-05 23:59:59 UTC
	maxTier = MAX_TIER,
	stepXp = STEP_XP,
	firstTierXp = FIRST_TIER_XP,
	tiers = tiers,
	xp = {
		operation = { Gold = 120, Silver = 95, Bronze = 70 },
		big = 50,
		storm = 30,
		event = 60,
		sticker = 40,
		challenge = 60,
		streak = 80,
	},
	eventVariants = { GhostShip = true },
	cosmetics = {
		Decal_Season1 = "Decal",
		Wake_Season1 = "Wake",
		Title_Season1 = "Title",
		Livery_Season1 = "Livery",
	},
	surprises = {
		Lantern = "Lantern",
		Gull = "Gull",
		Star = "Star",
	},
	paid = {
		product = "SeasonLogbook",
		price = 399,
		cosmetics = { "PaidDecal", "PaidWake", "PaidHorn", "PaidUniform", "PaidDog", "PaidTrophy" },
	},
}

return Season
