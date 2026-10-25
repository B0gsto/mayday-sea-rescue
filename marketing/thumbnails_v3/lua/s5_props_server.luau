-- where is the ferry, and two more rescue craft on scene: the game's own NPC rescue builds (VehicleService.BuildProp,
-- as Ops/NpcPickup uses), resting on the water. Requiring the module here only builds models; it touches no live state.
local ferry = workspace.CallProps:FindFirstChild("GaleQueen", true)
local fpos = ferry and ferry:GetPivot().Position or Vector3.new(60, 0, 500)
workspace:SetAttribute("TourFerry", fpos)
for _, m in workspace:GetChildren() do if m.Name:match("^TourProp") then m:Destroy() end end
local VS = require(game.ServerScriptService.Server.Services.VehicleService)
local function prop(id, x, z, look)
	local m = VS.BuildProp(id)
	if not m then return "no " .. id end
	m.Name = "TourProp_" .. id
	m:PivotTo(VS.RestCFrame(m, x, z, look))
	m.Parent = workspace
	return id .. " at " .. fmt(m:GetPivot().Position)
end
local a = prop("RIB", fpos.X - 30, fpos.Z + 34, Vector3.new(0.9, 0, -0.3))
local b = prop("JetSki", fpos.X + 6, fpos.Z + 46, Vector3.new(-0.5, 0, -0.85)) .. " | " .. prop("Lifeboat", fpos.X + 46, fpos.Z + 22, Vector3.new(-0.95, 0, -0.3))
local n = 0
for _, d in workspace.CallProps:GetDescendants() do if d:IsA("Model") and d:GetAttribute("Survivor") then n += 1 end end
return string.format("ferry %s at %s | %s | %s | survivors %d", tostring(ferry), fmt(fpos), a, b, n)
