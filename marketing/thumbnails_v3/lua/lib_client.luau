-- shared client prelude: hide every HUD each frame, photo mode on, helpers to pin the camera and drive
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
plr:SetAttribute("PhotoModeOpen", true)
_G.TourStop, _G.TourRestart, _G.TourAlong, _G.TourMark = nil, nil, nil, nil
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
-- a name bound twice stacks (an old scene's autopilot kept steering): unbind every copy
for _, n in { "TourCam", "TourHide", "TourDrive", "TourLoop", "TourBrake" } do
	for _ = 1, 20 do pcall(function() RunService:UnbindFromRenderStep(n) end) end
end
local function hideWorldGui(d)
	if d:IsA("BillboardGui") or d:IsA("SurfaceGui") and d:GetAttribute("Hud") then
		d.Enabled = false
	elseif d:IsA("Highlight") then
		d.Enabled = false
	end
end
if not _G.TourHideConn then
	for _, d in workspace:GetDescendants() do hideWorldGui(d) end
	_G.TourHideConn = workspace.DescendantAdded:Connect(hideWorldGui)
end
RunService:BindToRenderStep("TourHide", Enum.RenderPriority.Last.Value, function()
	for _, g in plr.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") or g:IsA("BillboardGui") then g.Enabled = false end
	end
	for _, d in plr.PlayerGui:GetDescendants() do
		if d:IsA("BillboardGui") then d.Enabled = false end
	end
end)
local function pin(fn, fov)
	RunService:BindToRenderStep("TourCam", Enum.RenderPriority.Camera.Value + 50, function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = fn()
		cam.FieldOfView = fov or 50
	end)
end
local function myVehicle()
	for _, folder in { workspace.Vehicles, workspace.LandVehicles } do
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and string.sub(m.Name, 1, #plr.Name + 1) == plr.Name .. "_" then
				return m, m:FindFirstChildWhichIsA("VehicleSeat", true)
			end
		end
	end
	return nil, nil
end
-- throttle (and steer toward target()) every frame after the control module writes the seat
local function drive(throttle, target)
	RunService:BindToRenderStep("TourDrive", Enum.RenderPriority.Input.Value + 10, function()
		local _, seat = myVehicle()
		if not (seat and seat:IsA("VehicleSeat")) then return end
		seat.ThrottleFloat = throttle
		local t = target and target()
		if t then
			local loc = seat.CFrame:PointToObjectSpace(t)
			seat.SteerFloat = math.clamp(math.atan2(loc.X, -loc.Z) * 2, -1, 1)
		end
	end)
end
local devRemote = game.ReplicatedStorage:WaitForChild("Net"):WaitForChild("Dev_Action")
local function dev(action, ...)
	return devRemote:InvokeServer(action, { ... })
end
local function me() return plr.UserId end
-- survivors with a loaded root; mine (my call's, PrivateTo = me) first, then free-roam swimmers
local function findSurvivors()
	local mine, other = {}, {}
	for _, d in workspace.CallProps:GetDescendants() do
		local root = d:IsA("Model") and d:GetAttribute("Survivor") and d:FindFirstChild("HumanoidRootPart")
		if root and root.Position.Magnitude > 1 then
			table.insert(if tonumber(d:GetAttribute("PrivateTo")) == plr.UserId then mine else other, d)
		end
	end
	table.move(other, 1, #other, #mine + 1, mine)
	return mine
end
-- autopilot (no teleports: a client PivotTo of a crewed hull can fling it): drive to `start`, line up on `dir`,
-- then run along the line through `start` at `runThrottle`. Returns the live status table (phase, along()).
local function autopilot(start, dir, runThrottle, via)
	local st = { phase = "toStart", via = table.clone(via or {}) }
	start = start * Vector3.new(1, 0, 1)
	RunService:BindToRenderStep("TourDrive", Enum.RenderPriority.Input.Value + 10, function()
		if st.phase == "manual" or st.phase == "fill" then return end
		local boat, seat = myVehicle()
		if not (seat and seat:IsA("VehicleSeat")) then return end
		local pos = boat.PrimaryPart.Position * Vector3.new(1, 0, 1)
		local fwd = seat.CFrame.LookVector * Vector3.new(1, 0, 1)
		local target, thr
		if st.phase == "toStart" then
			local wp = st.via[1]
			if wp then
				target, thr = wp * Vector3.new(1, 0, 1), 0.4
				if (target - pos).Magnitude < 25 then table.remove(st.via, 1) end
			else
				target, thr = start, 0.4
				if (start - pos).Magnitude < (st.arrive or 14) then st.phase = "align" st.alignAt = os.clock() st.log = (st.log or "") .. string.format(" align@%.0f,%.0f", pos.X, pos.Z) end
			end
		end
		if st.phase == "align" then
			target, thr = pos + dir * 50, 0.2
			if fwd.Unit:Dot(dir) > 0.96 or os.clock() - (st.alignAt or 0) > 6 then st.phase = if st.wait then "ready" else "run" st.log = (st.log or "") .. string.format(" run@%.0f,%.0f", pos.X, pos.Z) end
		end
		if st.phase == "ready" then
			-- parked on the line waiting for the go: hold station against the idle creep (back and forth on the jet)
			local fwdSpeed = boat.PrimaryPart.AssemblyLinearVelocity:Dot(dir)
			target, thr = pos + dir * 50, math.clamp((start - pos):Dot(dir) * 0.04 - fwdSpeed * 0.15, -0.4, 0.3)
		end
		if st.phase == "run" then
			target, thr = if st.runTarget then st.runTarget(pos) else start + dir * ((pos - start):Dot(dir) + 45), runThrottle
		elseif st.phase == "hold" then
			target, thr = nil, 0
		end
		if target then
			local loc = seat.CFrame:PointToObjectSpace(target)
			local ang = math.atan2(loc.X, -loc.Z)
			-- learn the hull's steering sense (a turn right is a negative yaw rate); some hulls answer reversed
			local w = boat.PrimaryPart.AssemblyAngularVelocity.Y
			if math.abs(seat.SteerFloat) > 0.6 and math.abs(w) > 0.1 then
				if w * seat.SteerFloat * (st.sign or 1) < 0 then st.right = (st.right or 0) + 1 else st.wrong = (st.wrong or 0) + 1 end
				st.sign = if (st.wrong or 0) > (st.right or 0) + 40 then -1 else 1
			end
			seat.SteerFloat = math.clamp(ang * 2.5, -1, 1) * (st.sign or 1)
			-- slow right down to turn while manoeuvring (a planing hull carves a ~120 stud circle)
			if st.phase ~= "run" and st.phase ~= "ready" and math.abs(ang) > 0.35 then thr = math.min(thr, st.turnThr or 0.12) end
			-- pinned on a wall or a hull while manoeuvring: back off for a moment
			local now = os.clock()
			if st.phase == "toStart" or st.phase == "align" then
				if boat.PrimaryPart.AssemblyLinearVelocity.Magnitude < 1.5 then st.slowSince = st.slowSince or now else st.slowSince = nil end
				if st.slowSince and now - st.slowSince > 2.5 then st.reverseUntil, st.slowSince = now + 2, nil end
			end
			if st.reverseUntil and now < st.reverseUntil then
				thr = -0.7
				seat.SteerFloat = -seat.SteerFloat
			end
			seat.ThrottleFloat = thr
		else
			seat.ThrottleFloat = thr
			seat.SteerFloat = 0
		end
	end)
	return st
end
-- client-side park of my (client-owned) craft at rest; the crew is welded on, so zero every part's motion first
local function placeLocal(cf)
	local boat = myVehicle()
	if not boat then return "no vehicle" end
	local parts = boat:GetDescendants()
	table.move(plr.Character:GetDescendants(), 1, #plr.Character:GetDescendants(), #parts + 1, parts)
	for _, d in parts do
		if d:IsA("BasePart") then d.AssemblyLinearVelocity = Vector3.zero d.AssemblyAngularVelocity = Vector3.zero end
	end
	boat:PivotTo(cf)
	for _, d in parts do
		if d:IsA("BasePart") then d.AssemblyLinearVelocity = Vector3.zero d.AssemblyAngularVelocity = Vector3.zero end
	end
	task.wait(2.5)
	local r = boat.PrimaryPart
	return string.format("placed %.0f,%.1f,%.0f up=%.2f", r.Position.X, r.Position.Y, r.Position.Z, r.CFrame.UpVector.Y)
end
-- a fresh hull at my bay, me at the helm: hop off (an empty craft is replaced on request), then launch
local function relaunch(id)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	for _ = 1, 3 do
		if not (hum and hum.SeatPart) then break end
		local weld = hum.SeatPart:FindFirstChild("SeatWeld")
		hum.Sit = false
		hum.Jump = true
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		if weld then weld:Destroy() end
		task.wait(1)
	end
	local ok, msg = dev("vehicle", me(), id)
	task.wait(3)
	return ok, msg
end
