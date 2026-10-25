-- NOTE: never require game ModuleScripts from here: the plugin context gets fresh copies, not the live services.
-- Drive the live game through its Studio hooks (ServerStorage.*Dev bindables, Dev_Action from the client).
local SS = game:GetService("ServerStorage")
local p = game.Players:GetPlayers()[1]
local function fmt(v) return string.format("%.0f,%.1f,%.0f", v.X, v.Y, v.Z) end
-- how far a hull can run from o along d over open water (down-rays every 8 studs; land, quays, hulls block)
local function waterRun(o, d, maxLen, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	for i = 0, maxLen, 8 do
		local at = o + d * i
		local hit = workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -60, 0), params)
		if hit and hit.Position.Y > 0.6 and hit.Material ~= Enum.Material.Water then return i end
	end
	return maxLen
end
-- the best open-water heading INTO point tgt: returns dir (unit, the way the craft travels) and run length
local function bestApproach(tgt, prefer, maxLen, ignore)
	local bestDir, bestLen, bestScore = nil, 0, -math.huge
	for k = 0, 23 do
		local a = k / 24 * 2 * math.pi
		local back = Vector3.new(math.cos(a), 0, math.sin(a)) -- from tgt toward the start
		local len = waterRun(tgt, back, maxLen, ignore)
		local score = len + (prefer and 60 * (-back):Dot(prefer) or 0)
		if score > bestScore then bestDir, bestLen, bestScore = -back, len, score end
	end
	return bestDir, bestLen
end
local function myVehicle()
	for _, folder in { workspace.Vehicles, workspace.LandVehicles } do
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and string.sub(m.Name, 1, #p.Name + 1) == p.Name .. "_" then return m end
		end
	end
end
local function mySurvivor()
	for _, d in workspace.CallProps:GetDescendants() do
		local root = d:IsA("Model") and d:GetAttribute("Survivor") and d:FindFirstChild("HumanoidRootPart")
		if root and tonumber(d:GetAttribute("PrivateTo")) == p.UserId and not d:GetAttribute("OnVehicle") then return d, root end
	end
end
-- park my craft at rest at cf (the server may move a client-owned assembly; it settles in ~2 s)
local function place(cf)
	local m = myVehicle()
	if not m then return "no vehicle" end
	m:PivotTo(cf)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.AssemblyLinearVelocity = Vector3.zero d.AssemblyAngularVelocity = Vector3.zero end
	end
	task.wait(3)
	return "placed " .. fmt(m.PrimaryPart.Position)
end
