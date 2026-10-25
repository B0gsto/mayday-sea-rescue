--!strict
-- G6 round-2 perf snapshot (build/ only). Attributes: PerfSpot "jetski" | "town", PerfTier "Low" | "High".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local spot = tostring(player:GetAttribute("PerfSpot") or "town")
local tier = player:GetAttribute("PerfTier")
if spot == "jetski" then
	local wait = 0
	while player:GetAttribute("CameraMode") ~= "Chase" and wait < 60 do
		task.wait(2)
		wait += 2
	end
else
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(0, 6, -30))
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 14, 40), Vector3.new(0, 6, -140))
	end
end
Workspace:SetAttribute("PerfQuality", tier)
task.wait(5)
local character = player.Character
local hrp = character and character:FindFirstChild("HumanoidRootPart")
local pos = if hrp and hrp:IsA("BasePart") then hrp.Position else Workspace.CurrentCamera.CFrame.Position
local descendants, parts, near, particles, lights, npcs = 0, 0, 0, 0, 0, 0
for _, d in Workspace:GetDescendants() do
	descendants += 1
	if d:IsA("BasePart") then
		parts += 1
		if (d.Position - pos).Magnitude <= 1024 then
			near += 1
		end
	elseif d:IsA("ParticleEmitter") then
		particles += 1
	elseif d:IsA("PointLight") then
		lights += 1
	elseif d:IsA("Humanoid") then
		npcs += 1
	end
end
local scatter = Workspace:FindFirstChild("ScatterLocal")
local ambient = Workspace:FindFirstChild("AmbientLocal")
local dts, total = {}, 0
local t0 = os.clock()
while os.clock() - t0 < 10 do
	local dt = RunService.Heartbeat:Wait()
	table.insert(dts, dt)
	total += dt
end
table.sort(dts)
local n = #dts
local avg = if n > 0 then total / n else 0
local p95 = if n > 0 then dts[math.min(n, math.max(1, math.ceil(n * 0.95)))] else 0
return string.format(
	"PERF2 spot=%s tier=%s cam=%s desc=%d parts=%d near=%d memMb=%.0f npc=%d particles=%d pointLights=%d "
		.. "scatter=%s/%s ambient=%s avgMs=%.1f p95Ms=%.1f",
	spot,
	tostring(Workspace:GetAttribute("PerfQuality")),
	tostring(player:GetAttribute("CameraMode")),
	descendants,
	parts,
	near,
	Stats:GetTotalMemoryUsageMb(),
	npcs,
	particles,
	lights,
	tostring(scatter and scatter:GetAttribute("ScatterTier")),
	tostring(scatter and scatter:GetAttribute("ScatterTris")),
	tostring(ambient and ambient:GetAttribute("AmbientTier")),
	avg * 1000,
	p95 * 1000
)
