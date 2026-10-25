_G.TourRestart()
local t0 = os.clock()
while _G.TourAlong() > (_G.TourMark or 50) and os.clock() - t0 < 6 do task.wait() end
return string.format("at %.0f after %.2fs", _G.TourAlong(), os.clock() - t0)
