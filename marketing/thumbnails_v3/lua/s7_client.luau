-- my land vehicle (myVehicle() would find a boat first)
local function myVehicle()
	for _, m in workspace.LandVehicles:GetChildren() do
		if m:IsA("Model") and m.Name == plr.Name .. "_CoastguardResponse" then return m, m:FindFirstChildWhichIsA("VehicleSeat", true) end
	end
end
local function drive(throttle, target)
	for _ = 1, 20 do pcall(function() RunService:UnbindFromRenderStep("TourDrive") end) end
	RunService:BindToRenderStep("TourDrive", Enum.RenderPriority.Input.Value + 10, function()
		local _, seat = myVehicle()
		if not seat then return end
		seat.ThrottleFloat = throttle
		local t = target and target()
		if t then
			local loc = seat.CFrame:PointToObjectSpace(t)
			seat.SteerFloat = math.clamp(math.atan2(loc.X, -loc.Z) * 2, -1, 1)
		end
	end)
end
local net = game.ReplicatedStorage:WaitForChild("Net")
local lc = net:FindFirstChild("Land_Control")
if lc then lc:FireServer("LightBar", true) lc:FireServer("Headlights", true) end
local dir = Vector3.new(1, 0, 0)
local Z = -162
_G.TourPhase = function() return "run" end
_G.TourRestart = function()
	drive(0.55, function()
		local car = myVehicle()
		local p = car and car:GetPivot().Position or Vector3.zero
		return Vector3.new(p.X + 40, p.Y, Z)
	end)
end
_G.TourStop = function() drive(0) end
-- low in front of the 4x4, looking back and up: the bunting strung overhead, cottages either side
pin(function()
	local car = myVehicle()
	if not car then return cam.CFrame end
	local p = car:GetPivot().Position
	return CFrame.lookAt(p + dir * 15 + Vector3.new(0, -1.0, 6.5), p + Vector3.new(-3, 3.4, -1.5))
end, 55)
local car = myVehicle()
return "s7 ready " .. tostring(car) .. " lightbar " .. tostring(car and car:GetAttribute("LightBar"))
