-- (2) a survivor climbing aboard the RIB, close-up. The take (s2_go) steers the RIB straight in at the nearest
-- survivor in the water and idles up alongside; they climb over the tube when it sits close and steady.
local S
local function spos() return S and S:FindFirstChild("HumanoidRootPart") and S.HumanoidRootPart.Position or nil end
local function pick()
	local b = myVehicle()
	local bp = b and b.PrimaryPart.Position or Vector3.zero
	local best, bd
	for _, d in workspace.CallProps:GetDescendants() do
		local r = d:IsA("Model") and d:GetAttribute("Survivor") and not d:GetAttribute("OnVehicle") and d:FindFirstChild("HumanoidRootPart")
		if r and r.Position.Y < 0 and r.Position.Z > 380 then
			local dd = (r.Position - bp).Magnitude
			if not bd or dd < bd then best, bd = d, dd end
		end
	end
	S = best
	return best
end
_G.TourPick = pick
_G.TourApproach = true
for _ = 1, 20 do pcall(function() RunService:UnbindFromRenderStep("TourDrive") end) end
RunService:BindToRenderStep("TourDrive", Enum.RenderPriority.Input.Value + 10, function()
	local b, seat = myVehicle()
	local sp = spos()
	if not (_G.TourApproach and b and seat and sp) then return end
	local cf = b.PrimaryPart.CFrame
	local fwd = (cf.LookVector * Vector3.new(1, 0, 1)).Unit
	local to = (sp - cf.Position) * Vector3.new(1, 0, 1)
	local d = to.Magnitude
	-- aim 5 studs to the left of them so they end up alongside the starboard tube
	local aim = sp + to.Unit:Cross(Vector3.yAxis) * -5
	local loc = seat.CFrame:PointToObjectSpace(aim)
	seat.SteerFloat = math.clamp(math.atan2(loc.X, -loc.Z) * 2, -1, 1)
	local speed = b.PrimaryPart.AssemblyLinearVelocity:Dot(fwd)
	seat.ThrottleFloat = if d > 60 then 0.6 elseif d > 14 then (if speed > 8 then 0 else 0.3) else (if speed > 2 then -0.6 else 0)
end)
local climber
pin(function()
	local b = myVehicle()
	if not b then return cam.CFrame end
	local cf = b.PrimaryPart.CFrame
	local fwd = (cf.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = fwd:Cross(Vector3.yAxis)
	if not climber then
		for _, d in workspace.CallProps:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("OnVehicle") == b.Name and not (_G.TourSeen or {})[d] then climber = d end
		end
	elseif climber:GetAttribute("OnVehicle") ~= b.Name then
		climber = nil
	end
	local v = (climber and climber:FindFirstChild("HumanoidRootPart") and climber.HumanoidRootPart.Position) or spos() or (cf.Position + right * 6)
	local s = if (v - cf.Position):Dot(right) >= 0 then right else -right
	-- low off the survivor's side of the hull, a little forward, looking aft at the tube they climb over
	local e = cf.Position + fwd * 9 + s * 13 + Vector3.new(0, 1.3, 0)
	return CFrame.lookAt(e, v:Lerp(cf.Position, 0.25) * Vector3.new(1, 0, 1) + Vector3.new(0, 1.5, 0))
end, 46)
local b = myVehicle()
return "s2 ready " .. tostring(b and b:GetAttribute("VehicleId")) .. " survivor " .. tostring(pick() and spos())
