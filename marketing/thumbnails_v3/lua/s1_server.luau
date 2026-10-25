-- (1) a free-roam swimmer (AmbientRescueService: no call, no NPC racer) in the open harbour; the jet ski runs
-- east-west just north of them (between them and the town), the camera sits low to the south looking at the town
workspace:SetAttribute("StudioBypassChecks", true)
local RUN, LANE = 170, Vector3.new(-8, 0, 0)
local ignore = { p.Character, workspace.Vehicles, workspace.CallProps }
local best
for _, d in workspace.CallProps:GetDescendants() do
	local root = d:IsA("Model") and d:GetAttribute("Survivor") and not d:GetAttribute("OnVehicle") and d:FindFirstChild("HumanoidRootPart")
	if root and root.Position.X > -110 and root.Position.X < 270 and root.Position.Z > 420 and root.Position.Z < 560 and root.Position.Y < 0 then
		local tgt = root.Position * Vector3.new(1, 0, 1)
		for _, dir in { Vector3.new(0, 0, -1) } do -- north: straight at the town
			local len = waterRun(tgt + LANE, -dir, RUN + 20, ignore)
			local cam = 0
			local score = len + cam
			local st = tgt - dir * RUN
			if len >= RUN and st.X > -80 and st.X < 420 and (not best or score > best.score) then best = { tgt = tgt, dir = dir, score = score } end
		end
	end
end
if not best then return "no swimmer in the open harbour" end
local start = best.tgt - best.dir * RUN + LANE
workspace:SetAttribute("TourTgt", best.tgt)
workspace:SetAttribute("TourDir", best.dir)
workspace:SetAttribute("TourStart", CFrame.lookAt(start, start + best.dir))
return string.format("tgt %s dir %s start %s", fmt(best.tgt), fmt(best.dir), fmt(start))
