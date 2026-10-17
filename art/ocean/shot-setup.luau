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
T:FillWedge(CFrame.new(600, -6, -560) * CFrame.Angles(0, math.pi, 0), Vector3.new(240, 16, 80), Enum.Material.Sand)
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
local char = Players.LocalPlayer.Character
if char and char:FindFirstChild("HumanoidRootPart") then
	char.HumanoidRootPart.Anchored = true
end
return string.format(
	"frame avg %.2f ms (%.0f fps), worst %.1f ms; ocean update %.3f ms, tier %s, mode %s",
	total / math.max(n, 1) * 1000, n / math.max(total, 1e-6), worst * 1000, ms, tierName,
	modeName
) .. string.format("; weather %s", tostring(game.ReplicatedStorage:FindFirstChild("Weather", true) and require(game.ReplicatedStorage.Shared.Weather).getState()))
