-- H2 (from the V2 RIB wet_check): proves the wet SurfaceAppearance swap applies (run after the shots, Edit datamodel)
local CS = game:GetService("CollectionService")
local tagged, swapped, wetIds = 0, 0, 0
if _G.LookDev then _G.LookDev.apply("Overcast", true) end
for _, p in CS:GetTagged("HasWetVariant") do
	if p:IsDescendantOf(workspace) and string.find(p.Name, "M_Bld_Chandlery_Ext", 1, true) then
		tagged += 1
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		if p:GetAttribute("WetState") == true then swapped += 1 end
		local dry = p:FindFirstChild("SurfaceVariants") and p.SurfaceVariants:FindFirstChild("SurfaceAppearance_Dry")
		if sa and dry and sa.ColorMap ~= dry.ColorMap then wetIds += 1 end
	end
end
if _G.LookDev then _G.LookDev.apply("Overcast", false) end
return string.format("wet_check: Chandlery Ext parts tagged %d, WetState true %d, wet ColorMap differs from dry %d", tagged, swapped, wetIds)
