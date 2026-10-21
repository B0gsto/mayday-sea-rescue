--!strict
-- Studio perf snapshot for the RP-P1 budget (docs/13, docs/06 section 3.5). Run on the Client during play:
--   python3 tools/studio/smoke.py lua Client 'game:GetService("Players").LocalPlayer:SetAttribute("PerfSpot", "town")'
--   python3 tools/studio/smoke.py lua Client tools/studio/perf.luau
-- Samples RunService.Heartbeat for 10 s, then reports the workspace/streaming counts, memory by
-- DeveloperMemoryTag and the active counts. Studio is a desktop machine, not a phone: these are not
-- phone measurements. The streaming radius is a place setting (not scriptable at run time), so set
-- PerfRadius to the radius built into the place; the Low tier is forced by setting the same
-- scatterQuality / oceanQuality overrides the settings panel writes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local spot = tostring(player:GetAttribute("PerfSpot") or "?")
local character = player.Character
local hrp = character and character:FindFirstChild("HumanoidRootPart")
local pos = if hrp and hrp:IsA("BasePart") then hrp.Position else Workspace.CurrentCamera.CFrame.Position

local descendants, parts, sounds, particles = 0, 0, 0, 0
for _, d in Workspace:GetDescendants() do
	descendants += 1
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Sound") then
		sounds += 1
	elseif d:IsA("ParticleEmitter") then
		particles += 1
	end
end

local radius = tonumber(player:GetAttribute("PerfRadius")) or 1024
local near = 0
for _, d in Workspace:GetDescendants() do
	if d:IsA("BasePart") and (d.Position - pos).Magnitude <= radius then
		near += 1
	end
end

local tags = {}
for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
	local ok, mb = pcall(function()
		return Stats:GetMemoryUsageMbForTag(tag)
	end)
	if ok and typeof(mb) == "number" and mb >= 0.05 then
		table.insert(tags, string.format("%s=%.1f", tag.Name, mb))
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
local okLevel, level = pcall(function()
	return UserSettings():GetService("UserGameSettings").SavedQualityLevel
end)
local quality = string.format(
	"slider=%s perf=%s",
	if okLevel then tostring(level) else "?",
	tostring(Workspace:GetAttribute("PerfQuality"))
)

local dts = {}
local total = 0
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

return table.concat({
	string.format(
		"PERF spot=%s quality=%s pos=%.0f,%.0f,%.0f",
		spot,
		quality,
		pos.X,
		pos.Y,
		pos.Z
	),
	string.format(
		"workspace descendants=%d parts=%d partsWithin%d=%d",
		descendants,
		parts,
		radius,
		near
	),
	string.format(
		"memory totalMb=%.1f ambientPeople=%s ambientCars=%s npcs=%d",
		Stats:GetTotalMemoryUsageMb(),
		tostring(ambient and ambient:GetAttribute("AmbientPeople")),
		tostring(ambient and ambient:GetAttribute("AmbientCars")),
		npcs
	),
	string.format(
		"heartbeat samples=%d avgMs=%.1f p95Ms=%.1f sounds=%d particles=%d",
		n,
		avg * 1000,
		p95 * 1000,
		sounds,
		particles
	),
	string.format(
		"scatter tier=%s tris=%s",
		tostring(scatter and scatter:GetAttribute("ScatterTier")),
		tostring(scatter and scatter:GetAttribute("ScatterTris"))
	),
	"memoryTags " .. table.concat(tags, " "),
}, "\n")
