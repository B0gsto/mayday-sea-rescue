--!strict
-- StreakConfig: the daily streak reward and the welcome-back bonus (docs/15 section 1, hook H5).
-- Pure data (no services), safe to load in Lune. The day maths live in src/shared/StreakRules.luau.

local StreakConfig = {}

StreakConfig.WeekDays = 7

-- Day 1..7 of the streak: rising Cash. Day 7 also grants the weekly cosmetic flag.
StreakConfig.DayCash = { 100, 150, 225, 325, 450, 600, 900 }

-- Away more than 3 days: one welcome-back bonus, this Cash on top of that day's pay.
StreakConfig.WelcomeCash = 500

return StreakConfig
