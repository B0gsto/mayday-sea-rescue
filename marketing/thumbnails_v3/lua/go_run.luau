-- the take: wait until the craft is parked at the start (staged beforehand), then run to the mark
local t0 = os.clock()
while _G.TourPhase() ~= "ready" and _G.TourPhase() ~= "run" and os.clock() - t0 < 90 do task.wait(0.2) end
_G.TourGo()
while not (_G.TourPhase() == "run" and _G.TourAlong() < (_G.TourMark or 45)) and os.clock() - t0 < 120 do task.wait() end
local cf = workspace.CurrentCamera.CFrame
return string.format("phase %s at %.0f after %.1fs %s", _G.TourPhase(), _G.TourAlong(), os.clock() - t0, _G.TourLog and _G.TourLog() or "")
