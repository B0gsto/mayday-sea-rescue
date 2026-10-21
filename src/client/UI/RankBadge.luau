--!strict
-- RankBadge: the promotion beat's screen half (docs 03 section 3, docs 04 the unveil). A big
-- rank-coloured disc with insignia stripes scales in at screen centre under a shine sweep, shows
-- the rank's new unlock icons, then flies up to the rank bar. Service Stars get the smaller disc
-- with a star and the star count. No text but the rank name (1-2 words), no buttons: any input
-- skips the beat in RankCeremonyController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local RankCeremony = require(Shared:WaitForChild("RankCeremony"))

local RankBadge = {}

export type Spec = {
	kind: string, -- "rank" | "star"
	rankIndex: number,
	name: string,
	stars: number?,
	icons: { string }, -- icon kinds: boat / gear / medal / mission
}
export type Handle = { duration: number, stop: () -> () }

local player = Players.LocalPlayer

local function circle(parent: Instance, colour: Color3): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	return f
end

-- Tiny unlock pictograms built from frames: boat, gear, medal, mission flag.
local function glyph(kind: string, colour: Color3, parent: Instance)
	local g = Instance.new("Frame")
	g.Name = "Glyph"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	g.Size = UDim2.fromOffset(26, 26)
	g.BackgroundTransparency = 1
	g.Parent = parent
	local function bar(size: Vector2, pos: Vector2, rot: number?)
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromOffset(13 + pos.X, 13 + pos.Y)
		b.Size = UDim2.fromOffset(size.X, size.Y)
		b.BackgroundColor3 = colour
		b.BorderSizePixel = 0
		b.Rotation = rot or 0
		b.Parent = g
		return b
	end
	if kind == "boat" then
		bar(Vector2.new(22, 6), Vector2.new(0, 7))
		bar(Vector2.new(12, 7), Vector2.new(-1, 1))
		bar(Vector2.new(2, 10), Vector2.new(6, -5))
	elseif kind == "gear" then
		local ring = circle(g, colour)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromOffset(16, 16)
		local hole = circle(ring, HudTheme.Colors.panel)
		hole.AnchorPoint = Vector2.new(0.5, 0.5)
		hole.Position = UDim2.fromScale(0.5, 0.5)
		hole.Size = UDim2.fromOffset(7, 7)
		for i = 0, 3 do
			local tooth = bar(Vector2.new(3, 7), Vector2.new(0, 0), i * 45)
			tooth.AnchorPoint = Vector2.new(0.5, 0.5)
			tooth.Position = UDim2.fromScale(0.5, 0.5)
			tooth.Position = UDim2.fromOffset(13, 13)
			tooth.Rotation = i * 90
			tooth.Size = UDim2.fromOffset(24, 3)
			tooth.ZIndex = 0
		end
		ring.ZIndex = 2
		hole.ZIndex = 3
	elseif kind == "mission" then
		bar(Vector2.new(2, 20), Vector2.new(-7, 0))
		bar(Vector2.new(12, 8), Vector2.new(0, -6))
	else -- medal
		local disc = circle(g, colour)
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromOffset(13, 10)
		disc.Size = UDim2.fromOffset(14, 14)
		bar(Vector2.new(6, 10), Vector2.new(-4, 8), 14)
		bar(Vector2.new(6, 10), Vector2.new(4, 8), -14)
	end
end

local function iconTile(row: Frame, kind: string, colour: Color3, index: number)
	local tile = Instance.new("Frame")
	tile.Name = `Unlock{index}`
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.BackgroundColor3 = HudTheme.Colors.panel
	tile.BackgroundTransparency = 0.12
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(0, 0)
	tile.Parent = row
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 9)
	c.Parent = tile
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = tile
	glyph(kind, colour, tile)
	return tile
end

-- Fades every drawn pixel of `root` and destroys the gui when done.
local function fadeOut(root: Instance, seconds: number)
	for _, inst in root:GetDescendants() do
		if inst:IsA("Frame") then
			TweenService:Create(inst, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
		elseif inst:IsA("TextLabel") then
			TweenService:Create(inst, TweenInfo.new(seconds), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		elseif inst:IsA("UIStroke") then
			TweenService:Create(inst, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
end

-- Plays the beat and returns at once. `spec.kind` picks the big rank badge or the small star.
function RankBadge.play(spec: Spec): Handle
	local duration = RankCeremony.seconds(spec.kind)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RankCeremony"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 42
	gui:SetAttribute("CinematicKeep", true)
	gui.Parent = player:WaitForChild("PlayerGui")

	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
		or Vector2.new(1280, 720)
	local big = math.clamp(viewport.Y * 0.27, 128, 200)
	local size = if spec.kind == "star" then big * 0.62 else big
	local colour = if spec.kind == "star"
		then RankCeremony.starColour()
		else RankCeremony.colour(spec.rankIndex)

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.44)
	holder.Size = UDim2.fromOffset(0, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local glow = circle(holder, colour)
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Size = UDim2.fromOffset(size * 2.2, size * 2.2)
	glow.BackgroundTransparency = 1
	glow.ZIndex = 1

	local disc = circle(holder, colour)
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Size = UDim2.fromOffset(0, 0)
	disc.ClipsDescendants = true
	disc.ZIndex = 2
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(12, 18, 23)
	stroke.Thickness = 3
	stroke.Transparency = 0.25
	stroke.Parent = disc
	local ring = circle(disc, Color3.new(1, 1, 1))
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.82, 0.82)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 3
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.new(1, 1, 1)
	ringStroke.Transparency = 0.72
	ringStroke.Thickness = 1.5
	ringStroke.Parent = ring

	-- Insignia: one stripe per rank (capped), light on dark colours and dark on light ones.
	local lum = colour.R * 0.3 + colour.G * 0.59 + colour.B * 0.11
	local stripeColour = if lum > 0.5
		then Color3.fromRGB(20, 26, 31)
		else Color3.fromRGB(245, 245, 240)
	if spec.kind == "rank" then
		local n = RankCeremony.stripes(spec.rankIndex)
		local h, gap = 0.036, 0.018
		local total = n * h + (n - 1) * gap
		for i = 1, n do
			local s = Instance.new("Frame")
			s.Name = `Stripe{i}`
			s.AnchorPoint = Vector2.new(0.5, 0)
			s.Position = UDim2.fromScale(0.5, 0.5 - total / 2 + (i - 1) * (h + gap))
			s.Size = UDim2.fromScale(0.46, h)
			s.BackgroundColor3 = stripeColour
			s.BackgroundTransparency = 0.1
			s.BorderSizePixel = 0
			s.ZIndex = 3
			s.Parent = disc
		end
	else
		local star = Instance.new("TextLabel")
		star.Name = "Star"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.4)
		star.Size = UDim2.fromScale(0.52, 0.4)
		star.BackgroundTransparency = 1
		star.Font = Enum.Font.BuilderSansMedium
		star.TextScaled = true
		star.Text = "★"
		star.TextColor3 = Color3.fromRGB(20, 26, 31)
		star.ZIndex = 3
		star.Parent = disc
		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.AnchorPoint = Vector2.new(0.5, 0.5)
		count.Position = UDim2.fromScale(0.5, 0.74)
		count.Size = UDim2.fromScale(0.4, 0.18)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.BuilderSansMedium
		count.TextScaled = true
		count.Text = tostring(spec.stars or 0)
		count.TextColor3 = Color3.fromRGB(20, 26, 31)
		count.ZIndex = 3
		count.Parent = disc
	end

	-- Shine: a bright bar swept across the disc, clipped by its rounded corners.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(-0.5, 0.5)
	shine.Size = UDim2.fromScale(0.22, 1.6)
	shine.Rotation = 18
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 1
	shine.BorderSizePixel = 0
	shine.ZIndex = 4
	shine.Parent = disc

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(0, size / 2 + 14)
	name.Size = UDim2.fromOffset(360, 34)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.BuilderSansMedium
	name.TextSize = 26
	name.Text = spec.name
	name.TextColor3 = HudTheme.Colors.text
	name.TextStrokeColor3 = Color3.fromRGB(8, 12, 15)
	name.TextStrokeTransparency = 0.35
	name.TextTransparency = 1
	name.ZIndex = 3
	name.Parent = holder

	local icons = if spec.kind == "rank" and #spec.icons > 0 then math.min(#spec.icons, 5) else 0
	local row = Instance.new("Frame")
	row.Name = "Unlocks"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromOffset(0, size / 2 + 54)
	row.Size = UDim2.fromOffset(icons * 54, 46)
	row.BackgroundTransparency = 1
	row.Parent = holder

	local alive = true
	local function tween(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween
		local tw = TweenService:Create(inst, info, props)
		tw:Play()
		return tw
	end

	tween(disc, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(size, size),
	})
	tween(glow, TweenInfo.new(0.5), { Size = UDim2.fromOffset(size * 2.2, size * 2.2) })
	glow.BackgroundTransparency = 0.92
	tween(name, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0.35 })
	task.delay(0.28, function()
		if not alive then
			return
		end
		shine.BackgroundTransparency = 0.55
		tween(shine, TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Position = UDim2.fromScale(1.5, 0.5),
			BackgroundTransparency = 0.72,
		})
	end)

	for i = 1, icons do
		task.delay(1.35 + (i - 1) * 0.11, function()
			if not alive then
				return
			end
			local kind = spec.icons[i]
			local tile = iconTile(row, kind, colour, i)
			tile.Position = UDim2.fromOffset((i - 0.5) * 54, 23)
			tween(tile, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(46, 46),
			})
		end)
	end

	-- Dock: the badge flies up to the rank strip at the top right while the words and icons fade.
	local flyAt = if spec.kind == "star" then 1.7 else 3.2
	task.delay(flyAt, function()
		if not alive then
			return
		end
		tween(name, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fadeOut(row, 0.3)
		tween(holder, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
			Position = UDim2.new(1, -86, 0, 62),
		})
		tween(disc, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
			Size = UDim2.fromOffset(size * 0.3, size * 0.3),
		})
		tween(glow, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
			Size = UDim2.fromOffset(size * 0.55, size * 0.55),
		})
	end)

	task.delay(duration - 0.55, function()
		if not alive then
			return
		end
		tween(stroke, TweenInfo.new(0.3), { Transparency = 0.2 })
		fadeOut(holder, 0.45)
	end)
	task.delay(duration, function()
		if alive then
			alive = false
			gui:Destroy()
		end
	end)

	return {
		duration = duration,
		stop = function()
			if alive then
				alive = false
				gui:Destroy()
			end
		end,
	}
end

return RankBadge
