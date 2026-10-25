-- the take: from wherever the RIB is (after a run it ends up inside), out through the mouth to the start, then in
local st = _G.TourSt
local b = workspace.Vehicles:FindFirstChild(game.Players.LocalPlayer.Name .. "_RIB")
local inside = b and b.PrimaryPart.Position.Z < 370
st.via = if inside then { Vector3.new(4, 0, 300), Vector3.new(2, 0, 420), Vector3.new(22, 0, 640) } else { Vector3.new(22, 0, 640) }
st.phase = "toStart"
local t0 = os.clock()
while not (_G.TourPhase() == "run" and _G.TourAlong() < (_G.TourMark or 38)) and os.clock() - t0 < 110 do task.wait() end
return string.format("phase %s at %.0f after %.1fs %s", _G.TourPhase(), _G.TourAlong(), os.clock() - t0, _G.TourLog())
