-- steer in at the nearest survivor; when one starts climbing aboard, wait into the up-and-over part of the climb
_G.TourSeen = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("Survivor") and d:GetAttribute("OnVehicle") then _G.TourSeen[d] = true end
end
_G.TourPick()
_G.TourApproach = true
local t0 = os.clock()
local function climbing()
	for _, d in workspace.CallProps:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Survivor") and d:GetAttribute("OnVehicle") and not _G.TourSeen[d] then return d end
	end
end
local d
while os.clock() - t0 < 110 do
	d = climbing()
	if d then break end
	if os.clock() % 5 < 0.05 then _G.TourPick() end
	task.wait()
end
task.wait(_G.TourClimbDelay or 0.55)
_G.TourApproach = false
return string.format("climb %s after %.1fs", tostring(d), os.clock() - t0)
