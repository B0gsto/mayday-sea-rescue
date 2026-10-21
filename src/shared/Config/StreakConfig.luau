--!strict
-- StreakConfig: the daily streak crate and the welcome-back crate (docs/15 section 1, hook H5).
-- Pure data (no services), safe to load in Lune. The day maths live in src/shared/StreakRules.luau.

local StreakConfig = {}

StreakConfig.WeekDays = 7

-- Day 1..7 of the streak: rising Cash. Day 7 also grants the weekly cosmetic flag.
StreakConfig.DayCash = { 100, 150, 225, 325, 450, 600, 900 }

-- Away more than 3 days: one bigger welcome-back crate, this Cash on top of that day's pay.
StreakConfig.WelcomeCash = 500

-- The station porch: against the crew wing front, east of the workshop counter (StationConfig), facing the
-- harbour (+Z). Y is found by the client with a downward ray, falling back to this Y (the apron's terrain top)
-- before the terrain streams in. The sign stands at +5.9, clear of the bigger welcome-back crate.
StreakConfig.PorchPosition = Vector3.new(-93.3, 5.8, -37.6)

StreakConfig.PromptRange = 10 -- studs, the crate's ProximityPrompt
StreakConfig.OpenRange = 28 -- studs, the server's horizontal sanity check on an open request

return StreakConfig
