-- Ocean spike capture setup (Client datamodel, play mode): frame stats, then scriptable camera.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ps = Players.LocalPlayer:WaitForChild("PlayerScripts")
local ctrlModule = ps:FindFirstChild("OceanController", true)
local ctrl = ctrlModule and require(ctrlModule)
-- Test seabed (client-local terrain) for the shallow and underwater shots: sand flat with ripples
-- of rock, top at about -8, sloping off to -20.
local T = workspace.Terrain
T:FillBlock(CFrame.new(600, -14, -400), Vector3.new(240, 12, 240), Enum.Material.Sand)
T:FillBlock(CFrame.new(600, -24, -400), Vector3.new(320, 8, 320), Enum.Material.Sand)
for i, r in { { 570, -9, -430, 7 }, { 640, -10, -380, 9 }, { 610, -7, -455, 5 }, { 545, -11, -370, 8 }, { 660, -9, -445, 6 } } do
	T:FillBall(Vector3.new(r[1], r[2], r[3]), r[4], if i % 2 == 0 then Enum.Material.Rock else Enum.Material.Basalt)
end
T:FillBall(Vector3.new(585, -12, -405), 4, Enum.Material.Slate)
-- A beach on the far side of the patch, rising out of the water, for the shoreline.
-- Round 3: moved north (crest at z -200); at z -560 its crest sat under the (600, -600) deep-water cameras.
T:FillWedge(CFrame.new(600, -6, -240), Vector3.new(240, 16, 80), Enum.Material.Sand)
local n, total, worst = 0, 0, 0
local conn = RunService.RenderStepped:Connect(function(dt)
	n += 1
	total += dt
	worst = math.max(worst, dt)
end)
task.wait(3)
conn:Disconnect()
-- The running controller publishes its stats on workspace.ClientOcean (a required copy reads 0).
local oceanFolder = workspace:FindFirstChild("ClientOcean")
local ms = oceanFolder and oceanFolder:GetAttribute("StepMs") or -1
local tierName = oceanFolder and oceanFolder:GetAttribute("Tier") or "?"
local modeName = oceanFolder and oceanFolder:GetAttribute("Mode") or "?"
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
-- Round 3: the game's CameraController re-binds the camera every frame, so shot CFrames never held
-- (round 2 noon/shallow/underwater were all the spawn view). Unbind it and force the shot camera
-- (workspace attribute ShotCF, set by each shot) both before the ocean's step and last.
for _, name in { "MaydayCameraPre", "MaydayCamera" } do
	pcall(function()
		RunService:UnbindFromRenderStep(name)
	end)
end
local function lockCamera()
	local cf = workspace:GetAttribute("ShotCF")
	if typeof(cf) == "CFrame" then
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Scriptable
		c.CFrame = cf
	end
end
pcall(function()
	RunService:UnbindFromRenderStep("ShotLockA")
	RunService:UnbindFromRenderStep("ShotLockB")
end)
RunService:BindToRenderStep("ShotLockA", Enum.RenderPriority.Camera.Value, lockCamera)
RunService:BindToRenderStep("ShotLockB", Enum.RenderPriority.Last.Value, lockCamera)
-- Cyan-slab hunt: visible parts / decals / textures with a saturated cyan colour.
local cyan = {}
for _, d in workspace:GetDescendants() do
	local col, vis
	if d:IsA("BasePart") then
		col, vis = d.Color, d.Transparency < 0.95
	elseif d:IsA("Decal") then
		col, vis = d.Color3, d.Transparency < 0.95
	end
	if col and vis then
		local h, s2, v = col:ToHSV()
		if h * 360 >= 155 and h * 360 <= 205 and s2 > 0.45 and v > 0.25 and #cyan < 10 then
			table.insert(cyan, d:GetFullName() .. "(" .. (if d:IsA("BasePart") then d.Material.Name else "decal") .. ")")
		end
	end
end
local char = Players.LocalPlayer.Character
if char and char:FindFirstChild("HumanoidRootPart") then
	char.HumanoidRootPart.Anchored = true
end
return string.format(
	"frame avg %.2f ms (%.0f fps), worst %.1f ms; ocean update %.3f ms, tier %s, mode %s",
	total / math.max(n, 1) * 1000, n / math.max(total, 1e-6), worst * 1000, ms, tierName,
	modeName
) .. "; cyan parts: " .. (if #cyan > 0 then table.concat(cyan, ", ") else "none")
	.. string.format("; weather %s", tostring(game.ReplicatedStorage:FindFirstChild("Weather", true) and require(game.ReplicatedStorage.Shared.Weather).getState()))
