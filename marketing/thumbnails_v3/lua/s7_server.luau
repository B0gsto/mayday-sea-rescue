local car
for _, m in workspace.LandVehicles:GetChildren() do
	if string.sub(m.Name, 1, #p.Name + 1) == p.Name .. "_" and m:GetAttribute("VehicleId") ~= "BoatTrailer" then car = m end
end
if not car then return "no car" end
local params = RaycastParams.new()
params.FilterDescendantsInstances = { p.Character, car }
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local x = workspace:GetAttribute("TourCarX") or -150
local hit = workspace:Raycast(Vector3.new(x, 80, -162), Vector3.new(0, -160, 0), params)
local ground = hit and hit.Position or Vector3.new(x, 5, -162)
local _, size = car:GetBoundingBox()
car:PivotTo(CFrame.lookAt(ground + Vector3.new(0, size.Y / 2 + 0.5, 0), ground + Vector3.new(100, size.Y / 2 + 0.5, 0)))
for _, d in car:GetDescendants() do
	if d:IsA("BasePart") then d.AssemblyLinearVelocity = Vector3.zero d.AssemblyAngularVelocity = Vector3.zero end
end
task.wait(2)
return string.format("%s at %s ground %s (%s)", car.Name, fmt(car:GetPivot().Position), fmt(ground), hit and hit.Instance.Name or "nohit")
