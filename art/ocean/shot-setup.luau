-- Ocean spike capture setup (Client datamodel, play mode): frame stats, then scriptable camera.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ps = Players.LocalPlayer:WaitForChild("PlayerScripts")
local ctrlModule = ps:FindFirstChild("OceanController", true)
local ctrl = ctrlModule and require(ctrlModule)
-- Round 4: the real island terrain (map/terrain) is in the build; the round 1-3 test seabed is gone and
-- every shot sits over real open water (art/ocean/make_shots.py writes the shot lists).
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
