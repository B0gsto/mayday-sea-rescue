task.wait(1)
dev("bosun", me())
task.wait(4)
local ground = workspace:GetAttribute("TourGround")
-- low on the quay stones, looking along the edge: pup and dog in front, boats and the harbour behind
-- the player stands anchored on the quay (s6 anchor step); low from the harbour side, the town behind them
pin(function() return CFrame.lookAt(Vector3.new(62, 7.7, -14.5), Vector3.new(62.6, 7.0, -3)) end, 60)
local pets = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and (d.Name:lower():find("seal") or d.Name:lower():find("pet")) then table.insert(pets, d:GetFullName()) end
	if #pets > 5 then break end
end
return "s6 ready " .. table.concat(pets, ", ")
