--!strict
-- StationConfig: the station crew's idle income and workshop upgrade (docs/15 hook H6, docs/03
-- section 6). Pure data, safe to load in Lune.
--
-- The crew level is the workshop level (0..3, bought in the phone's Pay Rise app). Radio Room and Kennel
-- levels are stored on the profile beside it (0 for everyone until those upgrades exist) and add a
-- small bonus: each Radio Room level +5% rate, each Kennel level +0.5 h cap.
--
-- Pacing (docs/03 section 10): level 0 pays 1,000 Cash/h against roughly 8,700 Cash/h of early
-- operations (about 11%), level 3 pays 3,600 Cash/h against late-game active rates (about 10-14%).
-- A full pot just stops filling: nothing is lost (docs/15 section 1).

local StationConfig = {}

StationConfig.MaxLevel = 3

-- Index = workshop level + 1. Each level raises the rate and the cap.
StationConfig.Crew = {
	{ rate = 1000, capHours = 1 },
	{ rate = 1600, capHours = 1.5 },
	{ rate = 2400, capHours = 2 },
	{ rate = 3600, capHours = 2.5 },
}

StationConfig.RadioRateBonus = 0.05 -- per Radio Room level
StationConfig.KennelCapHoursBonus = 0.5 -- per Kennel level

-- Cash cost of the next workshop level (index = current level + 1).
StationConfig.UpgradeCost = { 3000, 15000, 50000 }

return StationConfig
