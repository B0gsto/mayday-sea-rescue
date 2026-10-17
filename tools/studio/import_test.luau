--!strict
--# selene: allow(global_usage)
--[==[
import_test.luau: orientation regression test for tools/studio/import_asset.luau (Edit datamodel, run after the
importer is installed, e.g. after a pass's import-setup.luau: `python3 tools/studio/smoke.py lua Edit tools/studio/import_test.luau`).

1. B00 bollard (synthetic): a stand-in for the self-test bollard (0.35 x 0.35 x 0.55 m = 1.05 x 1.05 x 1.65 studs,
   origin at its base) built the way the cloud FBX importer delivers uploads: part CFrame upright, Model WorldPivot at
   the Blender origin, and the FBX node's axis rotation (90, 0, 0) left in the part's PivotOffset. After
   _G.ImportAsset with cframe {x, y, z} the model must stand upright (height on Y, pivot up = +Y, look = -Z) with the
   pivot at its base, and yaw 90 must turn the forward from -Z to -X.
2. RIB (when Workspace.LookDev.M_Veh_RIB exists, imported by the pass): pivot upright, bounding box length along Z,
   height along Y (8.7 x 9.5 x 26.1 studs), bow (ATT_BowPoint) forward of the props (ATT_Prop1) along -Z.
Returns "import_test PASS ..." or "import_test FAIL: ..." (one line).
]==]
local ImportAsset = (_G :: any).ImportAsset
if type(ImportAsset) ~= "function" then
	return "import_test FAIL: _G.ImportAsset not installed (run import_asset.luau first)"
end
local fails, notes = {}, {}
local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end
local function check(ok: boolean, what: string)
	if not ok then
		table.insert(fails, what)
	end
end
local function upright(cf: CFrame, label: string)
	check(cf.UpVector:Dot(Vector3.yAxis) > 0.999, label .. " pivot up " .. tostring(cf.UpVector))
end

-- 1. synthetic bollard
local m = Instance.new("Model")
m.Name = "M_Hbr_Bollard_01_ImportTest"
local p = Instance.new("Part")
p.Name = "M_Hbr_Bollard_01_LOD0"
p.Size = Vector3.new(1.05, 1.65, 1.05)
p.CFrame = CFrame.new(0, 0.825, 0)
p.Parent = m
m.Parent = workspace
m.WorldPivot = CFrame.new()
p.PivotOffset = CFrame.new(0, -0.825, 0) * CFrame.Angles(math.rad(90), 0, 0) -- as the cloud importer leaves it
local folder = Instance.new("Folder")
folder.Name = "__ImportTest"
folder.Parent = workspace
local ok, err = pcall(function()
	ImportAsset({ name = m.Name, source = m, tier = "standard", sets = {}, parent = folder, cframe = { 10, 100, 20 } })
	local pivot = m:GetPivot()
	upright(pivot, "bollard")
	check(pivot.LookVector:Dot(-Vector3.zAxis) > 0.999, "bollard look " .. tostring(pivot.LookVector))
	check((pivot.Position - Vector3.new(10, 100, 20)).Magnitude < 1e-3, "bollard pivot at " .. tostring(pivot.Position))
	check(near(p.Position.Y, 100.825, 1e-3), "bollard base not at pivot (centre y " .. p.Position.Y .. ")")
	local world = p.CFrame:VectorToWorldSpace(p.Size)
	check(near(math.abs(world.Y), 1.65, 1e-3), "bollard height not on Y: " .. tostring(world))
	ImportAsset({ name = m.Name, source = m, tier = "standard", sets = {}, parent = folder, cframe = { 0, 0, 0, 90 } })
	check(m:GetPivot().LookVector:Dot(-Vector3.xAxis) > 0.999, "bollard yaw 90 look " .. tostring(m:GetPivot().LookVector))
end)
check(ok, "bollard import error: " .. tostring(err))
folder:Destroy()
m:Destroy()
table.insert(notes, "bollard upright")

-- 2. the RIB, if a pass imported it
local lookDev = workspace:FindFirstChild("LookDev")
local rib = lookDev and lookDev:FindFirstChild("M_Veh_RIB")
if rib and rib:IsA("Model") then
	local pivot = rib:GetPivot()
	upright(pivot, "RIB")
	-- world-axis box of the LOD0 visual parts
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in rib:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "_LOD0", 1, true) then
			local h = d.Size / 2
			for _, s in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = d.CFrame:PointToWorldSpace(h * s)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	local size = hi - lo
	check(size.Z > size.X and size.Z > size.Y, "RIB length not on Z: " .. tostring(size))
	check(near(size.Z, 26.1, 0.6) and near(size.Y, 9.5, 0.6), "RIB box " .. tostring(size) .. " (want 8.7, 9.5, 26.1)")
	check(near(lo.Y, pivot.Position.Y, 0.15), "RIB pivot not at the keel base")
	local bow, prop = rib:FindFirstChild("ATT_BowPoint", true), rib:FindFirstChild("ATT_Prop1", true)
	if bow and prop and bow:IsA("Attachment") and prop:IsA("Attachment") then
		check(bow.WorldPosition.Z < prop.WorldPosition.Z - 20, "RIB bow not forward (-Z) of the props")
	end
	table.insert(notes, string.format("RIB box %.1f x %.1f x %.1f", size.X, size.Y, size.Z))
end
if #fails > 0 then
	return "import_test FAIL: " .. table.concat(fails, "; ")
end
return "import_test PASS: " .. table.concat(notes, "; ")
