--!strict
-- RP-P1 after-pass matrix: samples the three budget spots at the default tier and at the
-- Studio-only Low tier (Workspace.PerfQuality) in one client call, so it takes one Studio lock.
-- Run after `play start` with the storm already forced:
--   python3 tools/studio/smoke.py lua Server 'return game:GetService("ServerStorage").Storm_DevCommand:Invoke("/storm now")'
--   python3 tools/studio/smoke.py lua Client tools/studio/perfRun.luau
-- Studio Play on this Mac is not a phone; the numbers compare builds, not devices.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local out: { string } = {}

local function emit(line: string): ()
	print(line)
	table.insert(out, line)
end

local function weather(): string
	local ok, w = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Weather)
	end)
	return if ok and type(w) == "table" and type(w.getState) == "function"
		then tostring(w.getState())
		else "?"
end

local function sample(spot: string): ()
	local tier = tostring(Workspace:GetAttribute("PerfQuality") or "default")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local pos = if hrp and hrp:IsA("BasePart")
		then hrp.Position
		else Workspace.CurrentCamera.CFrame.Position
	local radius = tonumber(player:GetAttribute("PerfRadius")) or 1024
	local descendants, parts, sounds, particles, near = 0, 0, 0, 0, 0
	for _, d in Workspace:GetDescendants() do
		descendants += 1
		if d:IsA("BasePart") then
			parts += 1
			if (d.Position - pos).Magnitude <= radius then
				near += 1
			end
		elseif d:IsA("Sound") then
			sounds += 1
		elseif d:IsA("ParticleEmitter") then
			particles += 1
		end
	end
	local tags = {}
	for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
		local ok, mb = pcall(function()
			return Stats:GetMemoryUsageMbForTag(tag)
		end)
		if ok and typeof(mb) == "number" and mb >= 20 then
			table.insert(tags, string.format("%s=%.0f", tag.Name, mb))
		end
	end
	table.sort(tags)
	local ambient = Workspace:FindFirstChild("AmbientLocal")
	local npcs = 0
	if ambient then
		for _, d in ambient:GetDescendants() do
			if d:IsA("Humanoid") then
				npcs += 1
			end
		end
	end
	local scatter = Workspace:FindFirstChild("ScatterLocal")
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
	emit(
		string.format(
			"PERF spot=%s tier=%s weather=%s pos=%.0f,%.0f,%.0f desc=%d parts=%d near%d=%d "
				.. "memMb=%.0f npc=%d sounds=%d particles=%d scatter=%s/%s avgMs=%.1f p95Ms=%.1f",
			spot,
			tier,
			weather(),
			pos.X,
			pos.Y,
			pos.Z,
			descendants,
			parts,
			radius,
			near,
			Stats:GetTotalMemoryUsageMb(),
			npcs,
			sounds,
			particles,
			tostring(scatter and scatter:GetAttribute("ScatterTier")),
			tostring(scatter and scatter:GetAttribute("ScatterTris")),
			avg * 1000,
			p95 * 1000
		)
	)
	if #tags > 0 then
		emit("  memTags " .. table.concat(tags, " "))
	end
end

local function setTier(tier: string?): ()
	Workspace:SetAttribute("PerfQuality", tier)
	task.wait(6)
end

local part = tostring(player:GetAttribute("PerfPart") or "all")

-- 1. the cold-open jet ski offshore (the storm was forced before this call)
if part ~= "land" then
local wait = 0
while player:GetAttribute("CameraMode") ~= "Chase" and wait < 60 do
	task.wait(2)
	wait += 2
end
player:SetAttribute("PerfRadius", 1024)
setTier(nil)
sample("jetskiStorm")
setTier("Low")
sample("jetskiStorm")
end

if part ~= "jet" then
-- 2. the harbour town and Haven Sands on foot (after the cold open has fully let go)
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if humanoid then
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end
task.wait(40)
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
local function place(px: number, py: number, pz: number, lx: number, ly: number, lz: number): ()
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(px, py, pz))
	end
	camera.CFrame = CFrame.lookAt(Vector3.new(px, py + 8, pz + 70), Vector3.new(lx, ly, lz))
end
place(0, 6, -30, 0, 6, -140)
setTier(nil)
sample("town")
place(0, 6, -30, 0, 6, -140)
setTier("Low")
sample("town")
place(1000, 6, 330, 1000, 6, 380)
setTier(nil)
sample("havenSands")
place(1000, 6, 330, 1000, 6, 380)
setTier("Low")
sample("havenSands")
end

return table.concat(out, "\n")
