-- fix round 3: freshly approved images NetFailed on first fetch (white parts in the first / wet shots): preload every
-- dry and wet SurfaceAppearance map of the RIB and helm (3 tries) before any capture
local CP = game:GetService("ContentProvider")
local ids, seen = {}, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("SurfaceAppearance") and string.find(d:GetFullName(), "M_Veh_JetSki", 1, true) then
		for _, k in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
			local ok, v = pcall(function() return d[k] end)
			if ok and type(v) == "string" and v ~= "" and not seen[v] then
				seen[v] = true
				table.insert(ids, v)
			end
		end
	end
end
local failed = {}
for attempt = 1, 3 do
	failed = {}
	local list = {}
	for _, id in ids do
		local dec = Instance.new("Decal")
		dec.Texture = id
		table.insert(list, dec)
	end
	pcall(function()
		CP:PreloadAsync(list, function(id, status)
			if status ~= Enum.AssetFetchStatus.Success then table.insert(failed, id) end
		end)
	end)
	if #failed == 0 then break end
	task.wait(3)
end
return string.format("preload: %d maps, %d failed after retries", #ids, #failed)
