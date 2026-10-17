-- H2 (from the V2 RIB preload): preload every dry and wet SurfaceAppearance map of the three Chandlery assets (3 tries) before any capture
local CP = game:GetService("ContentProvider")
local ids, seen = {}, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("SurfaceAppearance") and string.find(d:GetFullName(), "Chandlery", 1, true) then
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
-- H2: freshly uploaded meshes answered "Asset content representation is being generated" on the first run: preload the
-- MeshParts of the three models too (3 tries, 5 s apart) and report what still fails
local parts, meshFailed = {}, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") and string.find(d:GetFullName(), "Chandlery", 1, true) then table.insert(parts, d) end
end
for attempt = 1, 3 do
	meshFailed = {}
	pcall(function()
		CP:PreloadAsync(parts, function(id, status)
			if status ~= Enum.AssetFetchStatus.Success then table.insert(meshFailed, id) end
		end)
	end)
	if #meshFailed == 0 then break end
	task.wait(5)
end
return string.format("preload: %d maps, %d failed after retries; %d mesh parts, %d mesh fetches failed", #ids, #failed, #parts, #meshFailed)
