local tgt, dir = workspace:GetAttribute("TourTgt"), workspace:GetAttribute("TourDir")
local side = dir:Cross(Vector3.yAxis).Unit
local start = workspace:GetAttribute("TourStart").Position
local victim, bestD = nil, 45
for _, d in workspace.CallProps:GetDescendants() do
	local r = d:IsA("Model") and d:GetAttribute("Survivor") and d:FindFirstChild("HumanoidRootPart")
	local dist = r and (r.Position * Vector3.new(1, 0, 1) - tgt).Magnitude
	if dist and dist < bestD then victim, bestD = d, dist end
end
local st = autopilot(start, dir, 1)
st.phase = "hold"
st.wait = true
_G.TourGo = function() if st.phase == "ready" then st.phase = "run" end end
local last = tgt
local function vpos()
	local r = victim and victim:FindFirstChild("HumanoidRootPart")
	if r then last = r.Position * Vector3.new(1, 0, 1) end
	return last
end
st.runTarget = function() return vpos() + Vector3.new(-8, 0, 0) + dir * 40 end
_G.TourAlong = function()
	local boat = myVehicle()
	return boat and (vpos() - boat:GetPivot().Position):Dot(dir) or 0
end
_G.TourPhase = function() return st.phase end
_G.TourLog = function()
	local b, seat = myVehicle()
	return (st.log or "") .. " v " .. tostring(vpos()) .. " boat " .. tostring(b and b.PrimaryPart.Position) .. " occ " .. tostring(seat and seat.Occupant ~= nil)
end
-- each take: relaunch from the bay (a safe reset of the hull), then drive out to the start
_G.TourRestart = function()
	st.phase = "hold"
	-- no relaunch while seated: a vehicle request completes the call's launch step, and then the survivors
	-- "answer the boat" (swim to it) instead of waiting and waving
	local _, seat = myVehicle()
	if not (seat and seat.Occupant) then relaunch("JetSki") task.wait(1) end
	local b = myVehicle()
	local inside = b and b.PrimaryPart.Position.Z < 380
	st.via = if inside then { Vector3.new(-40, 0, 150), Vector3.new(4, 0, 300), Vector3.new(2, 0, 410), Vector3.new(0, 0, 560), Vector3.new(0, 0, start.Z + 30) }
		else { Vector3.new(start.X > 0 and 120 or -120, 0, start.Z + 30) }
	st.phase = "toStart"
end
-- low, just behind the waving swimmer, the jet ski charging in with the town behind it
pin(function()
	local v = vpos()
	local boat = myVehicle()
	local bp = boat and boat:GetPivot().Position * Vector3.new(1, 0, 1) or v
	local W = Vector3.new(1, 0, 0) -- the survivor's side of the lane
	-- low chase from behind and west of the jet ski: the waving survivor ahead, the harbour light and Port Haven beyond
	return CFrame.lookAt(bp - dir * 17 + W * 4.5 + Vector3.new(0, 1.8, 0), bp + dir * 20 + W * 4.5 + Vector3.new(0, 3.0, 0))
end, 45)
_G.TourMark = 23
return "cam ready victim " .. tostring(victim)
