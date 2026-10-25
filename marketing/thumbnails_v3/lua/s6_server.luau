local view = SS.PetDev:Invoke("view")
local id
local function scan(t, depth)
	if type(t) ~= "table" or depth > 4 then return end
	if t.species == "SealPup" and t.id then id = t.id end
	for _, v in t do scan(v, depth + 1) end
end
scan(view, 0)
local eq = id and { SS.PetDev:Invoke("equip", id) }
-- stand on the quay edge facing the harbour
local params = RaycastParams.new()
params.FilterDescendantsInstances = { p.Character, workspace.Bosun }
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local spot = Vector3.new(92, 60, -9)
local hit = workspace:Raycast(spot, Vector3.new(0, -120, 0), params)
local ground = hit and hit.Position or Vector3.new(30, 5, -12)
p.Character:PivotTo(CFrame.lookAt(ground + Vector3.new(0, 3, 0), ground + Vector3.new(0, 3, 40)))
workspace:SetAttribute("TourGround", ground)
return string.format("pet id %s equip %s ground %s (%s)", tostring(id), eq and tostring(eq[1]) .. " " .. tostring(eq[2]) or "-", fmt(ground), hit and hit.Instance:GetFullName() or "nohit")
