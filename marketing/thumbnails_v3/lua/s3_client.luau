-- (3) the RIB, three survivors aboard, heading home past the harbour light. Pick-ups first (s3_fill: idle up to
-- the nearest survivor until the RIB is full), then the take runs in from the south through the harbour mouth.
local LIGHT = Vector3.new(44, 0, 360)
local start, dir = Vector3.new(22, 0, 600), Vector3.new(0, 0, -1)
local st = autopilot(start, dir, 0.9)
_G.TourSt = st
st.turnThr = 0.3
st.phase = "hold"
st.arrive = 25
local function count()
	local b = myVehicle()
	return b and (tonumber(b:GetAttribute("SurvivorCount")) or 0) or 0
end
_G.TourAlong = function()
	local b = myVehicle()
	return b and ((LIGHT - b:GetPivot().Position) * Vector3.new(1, 0, 1)):Dot(dir) or 0
end
_G.TourPhase = function() return st.phase end
_G.TourLog = function() return (st.log or "") .. " aboard " .. count() end
_G.TourGo = function() end
-- the pick-up helm (a render-step state machine, so it keeps going between Studio calls): straight at the
-- nearest free survivor, idling the last stretch, until the RIB is full; then off to the start of the run home
local target
for _ = 1, 20 do pcall(function() RunService:UnbindFromRenderStep("TourBrake") end) end
RunService:BindToRenderStep("TourBrake", Enum.RenderPriority.Input.Value + 11, function()
	if st.phase ~= "fill" then return end
	local b, seat = myVehicle()
	if not (b and seat) then return end
	if count() >= 3 then
		st.via = { Vector3.new(start.X, 0, start.Z + 40) }
		st.phase = "toStart"
		return
	end
	local bp = b.PrimaryPart.Position
	if not (target and target.Parent and not target:GetAttribute("OnVehicle")) then
		target = nil
		local bd
		for _, d in workspace.CallProps:GetDescendants() do
			local r = d:IsA("Model") and d:GetAttribute("Survivor") and not d:GetAttribute("OnVehicle") and d:FindFirstChild("HumanoidRootPart")
			if r and r.Position.Y < 0.5 then
				local dd = (r.Position - bp).Magnitude
				if not bd or dd < bd then target, bd = d, dd end
			end
		end
	end
	local r = target and target:FindFirstChild("HumanoidRootPart")
	if r then
		local fwd = (b.PrimaryPart.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
		local to = (r.Position - bp) * Vector3.new(1, 0, 1)
		local aim = r.Position + to.Unit:Cross(Vector3.yAxis) * -5
		local loc = seat.CFrame:PointToObjectSpace(aim)
		seat.SteerFloat = math.clamp(math.atan2(loc.X, -loc.Z) * 2, -1, 1)
		local speed = b.PrimaryPart.AssemblyLinearVelocity:Dot(fwd)
		local d = to.Magnitude
		seat.ThrottleFloat = if d > 80 then 0.8 elseif d > 14 then (if speed > 8 then 0 else 0.3) else (if speed > 2 then -0.6 else 0)
	end
end)
_G.TourRestart = function() st.phase = "fill" end
pin(function()
	local b = myVehicle()
	if not b then return cam.CFrame end
	local cf = b.PrimaryPart.CFrame
	local fwd = (cf.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = fwd:Cross(Vector3.yAxis)
	local p = cf.Position * Vector3.new(1, 0, 1)
	-- low off the port quarter looking ahead: crew and survivors aboard, the harbour light and Port Haven ahead
	return CFrame.lookAt(p - fwd * 17 - right * 13 + Vector3.new(0, 2.6, 0), p + fwd * 16 + right * 5 + Vector3.new(0, 6, 0))
end, 50)
_G.TourMark = 26
_G.TourStop = function() _G.TourSt.phase = "hold" end
return "s3 ready aboard " .. count()

