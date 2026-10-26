--!strict
-- WorkerBadge (WP-26): a worker's category icon and rarity stars, wordless. Used by WorkerController (the
-- billboard over a picked-up survivor and over your workers) and the Crew panel.
--   WorkerBadge.icon(parent, category)          the category icon on its coloured disc, filling `parent`
--   WorkerBadge.stars(parent, rarity, size)     1..3 gold stars in a row
--   WorkerBadge.billboard(model)                icon + stars over the model (legendary: gold ring + glow)
--   WorkerBadge.crew(adornee, category, parent) one badge + a count label for a building's crew
--   WorkerBadge.GRAD[category]                  its kit gradient name
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))

local WorkerBadge = {}

local GOLD = Color3.fromRGB(255, 208, 60)
local WHITE = Color3.new(1, 1, 1)

WorkerBadge.GRAD = {
	Builder = "yellow",
	Gatherer = "blue",
	Rescuer = "red",
	Mechanic = "orange",
	Medic = "green",
}
-- a kit icon where one exists, else a drawn glyph
local KIT = { Builder = "build", Gatherer = "cash", Rescuer = "lifebuoy" }
local GLYPH = { Mechanic = "speed", Medic = "cross" }

function WorkerBadge.icon(parent: Instance, category: string)
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Style.grad(WorkerBadge.GRAD[category] or "teal").top
	Style.corner(disc, 999)
	Style.stroke(disc, 2, true)
	disc.Parent = parent
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.72, 0.72)
	inner.Parent = disc
	if KIT[category] then
		Style.icon(inner, KIT[category])
	else
		Glyph.draw(GLYPH[category] or "ring", inner, WHITE)
	end
end

-- a four-point star inside a square parent (Glyph pills)
local function star(parent: Instance)
	Glyph.bar(parent, Vector2.new(0.9, 0.26), Vector2.new(0.5, 0.5), 0, GOLD, 0.5)
	Glyph.bar(parent, Vector2.new(0.26, 0.9), Vector2.new(0.5, 0.5), 0, GOLD, 0.5)
	Glyph.bar(parent, Vector2.new(0.6, 0.26), Vector2.new(0.5, 0.5), 45, GOLD, 0.5)
	Glyph.bar(parent, Vector2.new(0.6, 0.26), Vector2.new(0.5, 0.5), -45, GOLD, 0.5)
end

function WorkerBadge.stars(parent: Instance, rarity: number, size: number)
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundColor3 = Color3.fromRGB(28, 34, 52) -- a dark pill: gold stars read on any card colour
	row.BackgroundTransparency = 0.25
	row.Size = UDim2.fromOffset(size * 3 + 8, size + 4)
	Style.corner(row, 999)
	row.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = row
	for _ = 1, math.clamp(rarity, 1, 3) do
		local s = Instance.new("Frame")
		s.BackgroundTransparency = 1
		s.Size = UDim2.fromOffset(size, size)
		s.Parent = row
		star(s)
	end
	return row
end

function WorkerBadge.billboard(model: Model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local category, rarity =
		model:GetAttribute("WorkerCategory"), model:GetAttribute("WorkerRarity")
	if
		not (root and root:IsA("BasePart"))
		or type(category) ~= "string"
		or model:FindFirstChild("WorkerTag")
	then
		return
	end
	local stars = if type(rarity) == "number" then rarity else 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorkerTag"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(64, 54)
	gui.StudsOffset = Vector3.new(0, 3.8, 0) -- just over the head: under the building signs behind them
	gui.MaxDistance = 60 -- near only: a crowd of badges never covers the signs from afar
	gui.LightInfluence = 0
	gui.Parent = model
	-- aboard a craft (welded into its assembly) the badge would float over the driver's head: hide it there
	task.spawn(function()
		while gui.Parent do
			local assembly = root.AssemblyRootPart
			gui.Enabled = assembly == nil or assembly == root
			task.wait(0.5)
		end
	end)
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(34, 34)
	icon.Parent = gui
	WorkerBadge.icon(icon, category)
	local row = WorkerBadge.stars(gui, stars, 17)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.fromScale(0.5, 1)
	if stars >= 3 then -- legendary: a gold ring and a warm glow round them
		local ring = (icon:FindFirstChild("Disc") :: Frame):FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Color = GOLD
			ring.Thickness = 4
		end
		local light = Instance.new("PointLight")
		light.Name = "WorkerGlow"
		light.Color = GOLD
		light.Range = 10
		light.Brightness = 2
		light.Parent = root
	end
end

-- One badge for a building's whole crew (4+ there: single badges merged into a band): the icon and "x4".
-- The caller sets its Count label's text.
function WorkerBadge.crew(adornee: Instance, category: string, parent: Instance): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "CrewTag"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(92, 44)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(40, 40)
	icon.Position = UDim2.fromOffset(2, 2)
	icon.Parent = gui
	WorkerBadge.icon(icon, category)
	local n = Style.label(gui, "", 30)
	n.Name = "Count"
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.Position = UDim2.fromOffset(46, 0)
	n.Size = UDim2.new(1, -46, 1, 0)
	gui.Parent = parent
	return gui
end

return WorkerBadge
