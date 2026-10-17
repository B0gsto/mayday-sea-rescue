-- B02 look-dev (Client datamodel, play mode): hide GUIs, build a dry/wet swatch board of every MaterialVariant in the sky
-- over open sea, and define helpers for the shot snippets (_G.B02). Run after art/ocean/shot-setup.luau (camera lock).
local MS = game:GetService("MaterialService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
if pg then
	for _, g in pg:GetDescendants() do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
end
local old = workspace:FindFirstChild("B02_LookDev")
if old then
	old:Destroy()
end
local board = Instance.new("Folder")
board.Name = "B02_LookDev"
board.Parent = workspace
local ORIGIN = Vector3.new(-900, 24, 1500) -- low over open sea: at 200 the board sat in the cloud layer
local TILE, GAP = 12, 3
local dry = {}
for _, v in MS:GetChildren() do
	if v:IsA("MaterialVariant") and v:GetAttribute("Wet") == false then
		table.insert(dry, v)
	end
end
table.sort(dry, function(a, b)
	return a.Name < b.Name
end)
local order = {}
for i, v in dry do
	local col, row = (i - 1) % 5, (i - 1) // 5
	for w = 0, 1 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(TILE, 1, TILE)
		p.Material = v.BaseMaterial
		p.MaterialVariant = if w == 1 then v.Name .. "_Wet" else v.Name
		p.Color = Color3.new(1, 1, 1)
		p.CFrame = CFrame.new(
			ORIGIN
				+ Vector3.new(col * (2 * TILE + GAP * 2) + w * (TILE + 0.5), 0, row * (TILE + GAP))
		)
		p.Name = p.MaterialVariant
		p.Parent = board
	end
	table.insert(order, v.Name)
end
local lamp = Instance.new("Part")
lamp.Anchored, lamp.Transparency, lamp.CanCollide = true, 1, false
lamp.CFrame = CFrame.new(ORIGIN + Vector3.new(68, 40, 30)) * CFrame.Angles(-math.pi / 2, 0, 0)
lamp.Parent = board
local spot = Instance.new("SpotLight")
spot.Angle, spot.Range, spot.Brightness, spot.Color, spot.Enabled =
	90, 80, 4, Color3.fromRGB(255, 214, 170), false
spot.Face = Enum.NormalId.Front
spot.Parent = lamp
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local slots = {
	"Sand",
	"Sandstone",
	"Salt",
	"Limestone",
	"Pebble",
	"Rock",
	"Slate",
	"Basalt",
	"Grass",
	"LeafyGrass",
	"Mud",
	"Ground",
	"Pavement",
	"Asphalt",
	"Cobblestone",
	"Concrete",
}
local function hideGui()
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if gui then
		for _, g in gui:GetDescendants() do
			if g:IsA("ScreenGui") then
				g.Enabled = false
			end
		end
	end
end
_G.B02 = {
	origin = ORIGIN,
	hideGui = hideGui,
	spot = spot,
	ground = function(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp)
		return hit and hit.Position.Y or 0
	end,
	-- a beach or dune point (ground 2 to 12 studs above sea level) nearest the Haven Sands centre, for the close-up
	landPoint = function()
		local best, bd
		for x = 640, 1340, 20 do
			for z = 100, 620, 20 do
				local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp)
				if hit and hit.Position.Y > 2 and hit.Position.Y < 12 then
					local d = (Vector3.new(x, 0, z) - Vector3.new(990, 0, 360)).Magnitude
					if not bd or d < bd then
						best, bd = hit.Position, d
					end
				end
			end
		end
		return best or Vector3.new(990, 4, 360)
	end,
	shoot = function(cam, look)
		hideGui()
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Scriptable
		c.CFrame = CFrame.lookAt(cam, look)
		workspace:SetAttribute("ShotCF", c.CFrame)
	end,
	preset = function(name, clock)
		game.Lighting:SetAttribute("WeatherBase", name)
		if clock then
			game.Lighting.ClockTime = clock
		end
		spot.Enabled = name == "Night"
	end,
	wetTerrain = function(on)
		for _, s in slots do
			local name = string.gsub(MS:GetBaseMaterialOverride(Enum.Material[s]), "_Wet$", "")
			if name ~= "" then
				MS:SetBaseMaterialOverride(Enum.Material[s], if on then name .. "_Wet" else name)
			end
		end
	end,
}
local overrides = {}
for _, s in slots do
	table.insert(overrides, s .. "=" .. MS:GetBaseMaterialOverride(Enum.Material[s]))
end
return "B02 board: "
	.. #dry
	.. " pairs (dry|wet) in rows of 5, sorted: "
	.. table.concat(order, ", ")
	.. "; overrides: "
	.. table.concat(overrides, ", ")
