-- Lune: MeshPart.DoubleSided can't be set from game scripts, so it is baked into the uploaded Model.
-- Reads the Open Cloud FBX import (assets/models/M_Chr_Bosun_LODn.rbxm), sets DoubleSided on the fur card
-- parts (FurHead, FurFront, FurRear, FurTail) and writes assets/fbx/M_Chr_Bosun/M_Chr_Bosun_LODn.rbxm, which
-- is re-uploaded as the Model under the same name (tools/assets.py upload ... --name M_Chr_Bosun_LODn),
-- then tools/gen_asset_ids.py.
-- usage (from the game dir): lune run art/source/characters/M_Chr_Bosun/set_double_sided.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local FUR = { "FurHead", "FurFront", "FurRear", "FurTail" }
for lod = 0, 2 do
	local src = `assets/models/M_Chr_Bosun_LOD{lod}.rbxm`
	local out = `assets/fbx/M_Chr_Bosun/M_Chr_Bosun_LOD{lod}.rbxm`
	local roots = roblox.deserializeModel(fs.readFile(src))
	local n = 0
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("MeshPart") then
				for _, key in FUR do
					if string.find(d.Name, "_" .. key .. "_", 1, true) then
						d.DoubleSided = true
						n += 1
					end
				end
			end
		end
	end
	fs.writeFile(out, roblox.serializeModel(roots))
	print(`{out}: DoubleSided on {n} fur parts`)
end
