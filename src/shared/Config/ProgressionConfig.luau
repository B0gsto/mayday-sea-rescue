--!strict
-- ProgressionConfig: vehicle unlocks and payout multipliers. Pure data (no services), safe to load in Lune.
-- No ranks and no Reputation (docs/23 (q), WP-28): a craft unlocks through its building on your island
-- (`needs`, a DockConfig.Buildings key; shared/UnlockTree reads it). Rules: src/shared/ProgressionRules.luau.

export type VehicleUnlock = {
	needs: string?, -- the DockConfig building it needs (nil: none)
	price: number, -- Cash to buy once the building stands (0 = free)
	passOnly: boolean?, -- Robux only: owned through its MonetizationConfig.GamePasses `vehicle` pass, never Cash
}

local ProgressionConfig = {}

ProgressionConfig.SchemaVersion = 1

ProgressionConfig.Vehicles = {
	JetSki = { price = 0 },
	RIB = { needs = "Boathouse", price = 2500 }, -- tune
	Lifeboat = { needs = "LifeboatSlip", price = 18000 }, -- tune
	RescueHelicopter = { needs = "Hangar", price = 85000 }, -- tune: in week 1 (tests/Pacing)
	Submarine = { needs = "SubPen", price = 64000 }, -- tune
	-- Premium fleet (2026-10-21, user): Robux only, through the vehicle's Game Pass; launched from the boathouse.
	StormRunner = { needs = "Boathouse", price = 0, passOnly = true },
	Tidewalker = { needs = "Boathouse", price = 0, passOnly = true },
	RiptideX = { needs = "Boathouse", price = 0, passOnly = true },
	GildedGull = { needs = "Boathouse", price = 0, passOnly = true },
} :: { [string]: VehicleUnlock }

-- docs 03 section 2: Cash x1.5 in storms, x2 in a Great Storm.
ProgressionConfig.StormCashMultiplier = 1.5
ProgressionConfig.GreatStormCashMultiplier = 2

ProgressionConfig.MaxCrew = 4 -- docs 02 section 7

ProgressionConfig.StartingCash = 0

return ProgressionConfig
