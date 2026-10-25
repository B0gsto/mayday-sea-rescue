-- (4) the All-Weather Lifeboat at sea, flat out, big bow wave; low front three-quarter, Port Haven behind
local start, dir = Vector3.new(-30, 0, 560), Vector3.new(-0.65, 0, 1).Unit -- south-west, clear of the ferry and the channel marks
local tgt = start + dir * 500 -- a virtual mark along the run
local st = autopilot(start, dir, 1)
st.phase = "hold"
_G.TourSt = st
st.arrive = 25
st.turnThr = 0.3
_G.TourGo = function() if st.phase == "ready" then st.phase = "run" end end
_G.TourAlong = function()
	local boat = myVehicle()
	return boat and (tgt - boat:GetPivot().Position):Dot(dir) or 0
end
_G.TourPhase = function() return st.phase end
_G.TourLog = function() return st.log or "" end
_G.TourRestart = function()
	st.phase = "hold"
	local b = myVehicle()
	if not (b and b:GetAttribute("VehicleId") == "Lifeboat") then relaunch("Lifeboat") task.wait(1) b = myVehicle() end
	st.via = if b.PrimaryPart.Position.Z < 380 then { Vector3.new(-40, 0, 150), Vector3.new(4, 0, 300), Vector3.new(2, 0, 400), Vector3.new(-20, 0, 420) } else { Vector3.new(-20, 0, 420) }
	st.phase = "toStart"
end
_G.TourMark = 500 - 260 -- 140 studs into the run: up to speed
pin(function()
	local boat = myVehicle()
	if not boat then return cam.CFrame end
	local cf = boat.PrimaryPart.CFrame
	-- the way it is actually moving (the hull root's axes need not point at the bow)
	local v = boat.PrimaryPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local fwd = if v.Magnitude > 5 then v.Unit else dir
	local right = fwd:Cross(Vector3.yAxis)
	local p = cf.Position * Vector3.new(1, 0, 1)
	local e = p + fwd * 46 + right * 16 + Vector3.new(0, 1.6, 0)
	return CFrame.lookAt(e, p + fwd * 6 + Vector3.new(0, 4.5, 0))
end, 46)
_G.TourStop = function() _G.TourSt.phase = "hold" end
return "s4 ready"

