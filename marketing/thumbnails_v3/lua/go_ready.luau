-- the take: wait until the craft is parked on its mark, give it a moment to settle
local t0 = os.clock()
while _G.TourPhase() ~= "ready" and os.clock() - t0 < 100 do task.wait(0.2) end
task.wait(_G.TourSettle or 2)
return string.format("phase %s after %.1fs %s", _G.TourPhase(), os.clock() - t0, _G.TourLog and _G.TourLog() or "")
