--!strict
-- StreakConfig: the daily streak reward and the welcome-back bonus (docs/15 section 1, hook H5).
-- Pure data (no services), safe to load in Lune. The day maths live in src/shared/StreakRules.luau.

local StreakConfig = {}

StreakConfig.WeekDays = 7

-- Day 1..7 of the streak: rising Cash. Day 7 also grants the weekly cosmetic flag.
StreakConfig.DayCash = { 100, 150, 225, 325, 450, 600, 900 }

-- Sized to the boat (playtest 2026-11-07: day 2's 150 Cash was nothing next to L11's 6,000): day N pays at least this
-- share of the next boat level's price, up to BoatCashMax. DayCash stays the floor (and the whole pay at L50). -- tune
StreakConfig.BoatShare = { 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.6 }
StreakConfig.BoatCashMax = 30000

-- Away more than 3 days: one welcome-back bonus, this Cash on top of that day's pay.
StreakConfig.WelcomeCash = 500

return StreakConfig
