-- wait for the autopilot's run phase and the mark (studs short of the subject)
_G.TourRestart()
local t0 = os.clock()
while not (_G.TourPhase() == "run" and _G.TourAlong() < (_G.TourMark or 45)) and os.clock() - t0 < 100 do task.wait() end
local b = myVehicle and nil
local cf = workspace.CurrentCamera.CFrame
return string.format("phase %s at %.0f after %.1fs %s cam %s look %s", _G.TourPhase(), _G.TourAlong(), os.clock() - t0, _G.TourLog and _G.TourLog() or "", tostring(cf.Position), tostring(cf.LookVector))
