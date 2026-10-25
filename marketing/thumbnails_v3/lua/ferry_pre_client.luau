-- start (or keep) the Capsized Ferry big call; the survivors are clustered off the harbour mouth
local n = 0
for _, d in workspace.CallProps:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("Survivor") and (d:GetPivot().Position - Vector3.new(60, 0, 500)).Magnitude < 150 then n += 1 end
end
local a = { "kept" }
if n == 0 then
	dev("opEnd", me(), false)
	task.wait(1)
	a = { dev("op", me(), "CapsizedFerry") }
	task.wait(2)
end
local ok, msg = relaunch(_G.TourCraft or "JetSki")
return "ferry " .. tostring(a[1]) .. " " .. tostring(a[2]) .. " near " .. n .. " | " .. tostring(ok) .. " " .. tostring(msg)
