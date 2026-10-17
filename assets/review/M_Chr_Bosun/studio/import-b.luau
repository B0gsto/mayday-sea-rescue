
local function lod0Box(model)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") and string.find(p.Name, "_LOD0") and not string.find(p.Name, "_COL") then
			local h = p.Size / 2
			for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
				local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
				mn = mn:Min(w); mx = mx:Max(w)
			end end end
		end
	end
	return mn, mx
end

local HttpService = game:GetService("HttpService")
local report = _G.ImportAsset({["name"] = "M_Chr_Bosun", ["source"] = "Workspace/M_Chr_Bosun", ["tier"] = "hero", ["sets"] = {["Fur"] = {["Wet"] = {["RGH"] = "127650751038896", ["NOR"] = "136161537490250", ["ALB"] = "133152335720908"}, ["ALB"] = "132940714883591", ["RGH"] = "133402828268520", ["NOR"] = "102472218436672", ["MET"] = "92191140489137", ["alphaMode"] = "Transparency"}, ["Harness"] = {["MET"] = "128729814698779", ["Wet"] = {["NOR"] = "73590411681709", ["ALB"] = "76747465814971", ["RGH"] = "91347224757059"}, ["RGH"] = "124354172288228", ["NOR"] = "120618846558449", ["ALB"] = "130981403101613"}, ["Body"] = {["Wet"] = {["RGH"] = "89869746461866", ["ALB"] = "124715963239143", ["NOR"] = "78173250678751"}, ["ALB"] = "107761244501881", ["NOR"] = "84206738702518", ["MET"] = "92191140489137", ["RGH"] = "97126455887113"}}, ["partSets"] = {["M_Chr_Bosun_BodyHead_LOD0"] = "Body", ["M_Chr_Bosun_BodyFore_LOD0"] = "Body", ["M_Chr_Bosun_BodyHind_LOD0"] = "Body", ["M_Chr_Bosun_Harness_LOD0"] = "Harness", ["M_Chr_Bosun_FurFront_LOD0"] = "Fur", ["M_Chr_Bosun_FurRear_LOD0"] = "Fur", ["M_Chr_Bosun_BodyHead_LOD1"] = "Body", ["M_Chr_Bosun_BodyFore_LOD1"] = "Body", ["M_Chr_Bosun_BodyHind_LOD1"] = "Body", ["M_Chr_Bosun_Harness_LOD1"] = "Harness", ["M_Chr_Bosun_FurFront_LOD1"] = "Fur", ["M_Chr_Bosun_FurRear_LOD1"] = "Fur", ["M_Chr_Bosun_BodyHead_LOD2"] = "Body", ["M_Chr_Bosun_BodyFore_LOD2"] = "Body", ["M_Chr_Bosun_BodyHind_LOD2"] = "Body", ["M_Chr_Bosun_Harness_LOD2"] = "Harness", ["M_Chr_Bosun_FurFront_LOD2"] = "Fur", ["M_Chr_Bosun_FurRear_LOD2"] = "Fur"}})
local model = workspace.LookDev:FindFirstChild("M_Chr_Bosun")
local mn, mx = lod0Box(model)
local c = (mn + mx) / 2
local T = Vector3.new(-46.0, 4.0 + 40, -9.0)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {workspace.LookDev}
local hit = workspace:Raycast(T, Vector3.new(0, -80, 0), rp)
local top = if hit then hit.Position.Y else 4.0
local feet = Vector3.new(c.X, mn.Y, c.Z)
-- facing: the mouth attachment should point to -Z
local mouth = model:FindFirstChild("ATT_Mouth", true)
local yaw = 0
if mouth then
	local d = mouth.WorldPosition - c
	yaw = math.atan2(-d.X, -d.Z) -- rotation that takes d onto -Z
end
local target = Vector3.new(-46.0, top, -9.0)
model:PivotTo(CFrame.new(target) * CFrame.Angles(0, -yaw, 0) * CFrame.new(-feet) * model:GetPivot())
local mn2, mx2 = lod0Box(model)
local ds = {}
for _, p in model:GetDescendants() do
	if p:IsA("MeshPart") and string.find(p.Name, "_Fur") then
		local ok, err = pcall(function() (p :: any).DoubleSided = true end)
		local okr, val = pcall(function() return (p :: any).DoubleSided end)
		table.insert(ds, p.Name .. "=" .. (if ok then "set" else "fail:" .. tostring(err)) .. "/" .. tostring(okr and val))
	end
end
local m2 = if mouth then mouth.WorldPosition else Vector3.zero
return HttpService:JSONEncode({report = report, pre = _G.BosunPre, quayHit = hit and hit.Instance:GetFullName() or "none",
	quayTop = top, yawDeg = math.deg(yaw), bboxMin = {mn2.X, mn2.Y, mn2.Z}, bboxMax = {mx2.X, mx2.Y, mx2.Z},
	mouth = {m2.X, m2.Y, m2.Z}, doubleSided = ds})
