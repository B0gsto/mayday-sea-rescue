-- my lifeboat stands by off the ferry's south-east quarter; the camera low to the south looks north over the
-- whole scene: keel-up Gale Queen, liferafts, survivors, crews, the harbour light and Port Haven behind
local F = workspace:GetAttribute("TourFerry") or Vector3.new(65, 0, 498)
F = F * Vector3.new(1, 0, 1)
local start, dir = F + Vector3.new(48, 0, 26), Vector3.new(-1, 0, -0.35).Unit
local st = autopilot(start, dir, 0)
st.phase = "hold"
st.wait = true
st.arrive = 20
_G.TourGo = function() end
_G.TourPhase = function() return st.phase end
_G.TourAlong = function() return 0 end
_G.TourLog = function() return st.log or "" end
_G.TourRestart = function()
	st.phase = "hold"
	local b = myVehicle()
	if not (b and b:GetAttribute("VehicleId") == "Lifeboat") then relaunch("Lifeboat") task.wait(1) b = myVehicle() end
	st.via = if b.PrimaryPart.Position.Z < 380 then { Vector3.new(-40, 0, 150), Vector3.new(4, 0, 300), Vector3.new(2, 0, 400), Vector3.new(F.X + 90, 0, F.Z - 40) } else { Vector3.new(F.X + 90, 0, F.Z - 40) }
	st.phase = "toStart"
end
local eye = F + Vector3.new(-42, 2.6, 92)
pin(function() return CFrame.lookAt(eye, F + Vector3.new(10, 6.5, -4)) end, 44)
return "s5 ready ferry " .. tostring(F)
