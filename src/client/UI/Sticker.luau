--!strict
-- Sticker: the album's sticker art and the stamp slam (docs/21 §3, package C1). No text but the island
-- name (1-3 words) under a stamp.
--   Sticker.draw(parent, islandId, stickerId, found) -> Frame   a round island stamp or a square sticker
--                                                              (a grey silhouette until found)
--   Sticker.slam(islandId, stickerId, page)   the on-screen thump: a stamp slams down, ink ring, shake,
--                                             confetti, slap + sparkle; a found collectible pops smaller
-- Art: UiImages.Stickers (island stamps by island id, Bottle / View, critters by species); a sticker with no
-- uploaded image falls back to the Frame-glyph drawing below.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DiscoveryRules"))
local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)

local Client = script.Parent.Parent
local AudioController = require(Client:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(Client:WaitForChild("Camera"):WaitForChild("Comfort"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local Sticker = {}

local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromHex("3A444C")
local DARK = Color3.fromHex("262E35")
local GOLD = Color3.fromHex("FFD06A")
local KIND_COLOUR = {
	Bottle = Color3.fromHex("3FAE7A"),
	View = Color3.fromHex("C9962E"),
	Critter = Color3.fromHex("FF8A3D"),
}
local CONFETTI = {
	Color3.fromHex("FFD06A"),
	Color3.fromHex("FF781E"),
	Color3.fromHex("78E6A0"),
	Color3.fromHex("78BEFF"),
	Color3.fromHex("FFFFFF"),
	Color3.fromHex("FF5C8A"),
}

-- icon shapes: pills { width, height, x, y, rotation, radius? } in scale units of a square
type Bar = { number }
local ICONS: { [string]: { Bar } } = {
	light = {
		{ 0.2, 0.46, 0.5, 0.62, 0, 0.2 },
		{ 0.32, 0.08, 0.5, 0.37, 0 },
		{ 0.16, 0.14, 0.5, 0.28, 0, 0.3 },
		{ 0.26, 0.05, 0.25, 0.26, -12 },
		{ 0.26, 0.05, 0.75, 0.26, 12 },
		{ 0.5, 0.07, 0.5, 0.86, 0 },
	},
	castle = {
		{ 0.62, 0.28, 0.5, 0.66, 0, 0.1 },
		{ 0.15, 0.5, 0.22, 0.56, 0, 0.1 },
		{ 0.15, 0.5, 0.78, 0.56, 0, 0.1 },
		{ 0.2, 0.6, 0.5, 0.48, 0, 0.1 },
		{ 0.06, 0.16, 0.5, 0.14, 0 },
	},
	bird = {
		{ 0.36, 0.46, 0.48, 0.6, 0 },
		{ 0.28, 0.28, 0.5, 0.32, 0 },
		{ 0.2, 0.1, 0.68, 0.36, 12 },
		{ 0.12, 0.3, 0.3, 0.62, 20 },
	},
	mill = {
		{ 0.22, 0.44, 0.5, 0.68, 0, 0.25 },
		{ 0.72, 0.08, 0.5, 0.4, 45 },
		{ 0.72, 0.08, 0.5, 0.4, -45 },
		{ 0.12, 0.12, 0.5, 0.4, 0 },
	},
	wreck = {
		{ 0.72, 0.16, 0.48, 0.66, -14, 0.4 },
		{ 0.06, 0.48, 0.44, 0.4, -14 },
		{ 0.3, 0.06, 0.5, 0.3, -14 },
		{ 0.8, 0.05, 0.5, 0.82, 0 },
	},
	arch = {
		{ 0.16, 0.5, 0.26, 0.6, 0, 0.3 },
		{ 0.16, 0.5, 0.74, 0.6, 0, 0.3 },
		{ 0.66, 0.2, 0.5, 0.36, 0, 0.5 },
		{ 0.8, 0.05, 0.5, 0.86, 0 },
	},
	palm = {
		{ 0.08, 0.52, 0.52, 0.6, 8 },
		{ 0.4, 0.09, 0.34, 0.32, -28 },
		{ 0.4, 0.09, 0.68, 0.32, 28 },
		{ 0.36, 0.09, 0.5, 0.26, 0 },
		{ 0.6, 0.12, 0.5, 0.86, 0 },
	},
	seal = {
		{ 0.6, 0.3, 0.48, 0.62, -10 },
		{ 0.26, 0.24, 0.72, 0.42, 0 },
		{ 0.16, 0.08, 0.24, 0.74, 30 },
		{ 0.8, 0.05, 0.5, 0.84, 0 },
	},
	Bottle = {
		{ 0.32, 0.5, 0.5, 0.62, 0, 0.35 },
		{ 0.13, 0.22, 0.5, 0.3, 0, 0.3 },
		{ 0.16, 0.08, 0.5, 0.18, 0, 0.3 },
		{ 0.18, 0.2, 0.5, 0.62, 0, 0.2 },
	},
	View = {
		{ 0.62, 0.15, 0.48, 0.36, -22 },
		{ 0.12, 0.22, 0.78, 0.24, -22 },
		{ 0.05, 0.42, 0.4, 0.66, 18 },
		{ 0.05, 0.42, 0.6, 0.66, -18 },
	},
	Critter = {
		{ 0.42, 0.36, 0.5, 0.64, 0 },
		{ 0.15, 0.17, 0.24, 0.42, 0 },
		{ 0.15, 0.17, 0.4, 0.28, 0 },
		{ 0.15, 0.17, 0.6, 0.28, 0 },
		{ 0.15, 0.17, 0.76, 0.42, 0 },
	},
}

local function icon(parent: Instance, name: string, colour: Color3)
	for _, b in ICONS[name] or ICONS.light do
		Glyph.bar(parent, Vector2.new(b[1], b[2]), Vector2.new(b[3], b[4]), b[5], colour, b[6])
	end
end

local function find(islandId: string, stickerId: string): (Rules.Page?, Rules.Sticker?)
	local page = Rules.ById[islandId]
	if not page then
		return nil, nil
	end
	for _, s in page.stickers do
		if s.id == stickerId then
			return page, s
		end
	end
	return page, nil
end

function Sticker.draw(parent: Instance, islandId: string, stickerId: string, found: boolean): Frame
	local page, s = find(islandId, stickerId)
	local f = Instance.new("Frame")
	f.Name = "Sticker"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = parent
	if not (page and s) then
		return f
	end
	local stamp = s.kind == "Stamp"
	local key = if stamp then islandId elseif s.kind == "Critter" then (s :: any).species else s.kind
	local picture = key and UiImages.Stickers[key]
	if picture and picture ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Face"
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = picture
		img.ScaleType = Enum.ScaleType.Fit
		if not found then -- a dark silhouette until found
			img.ImageColor3 = DARK
			img.ImageTransparency = 0.25
		end
		img.Parent = f
		return f
	end
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(0.92, 0.92)
	face.BackgroundColor3 = if not found then GREY elseif stamp then page.colour else WHITE
	face.Parent = f
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = face
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if stamp then UDim.new(0.5, 0) else UDim.new(0.22, 0)
	corner.Parent = face
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Thickness = if stamp then 4 else 3
	edge.Color = if found then WHITE else DARK
	edge.Parent = face
	if stamp and found then
		-- the inked inner ring of a rubber stamp
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.82, 0.82)
		ring.BackgroundTransparency = 1
		ring.Parent = face
		HudTheme.corner(ring, 999)
		local ink = Instance.new("UIStroke")
		ink.Thickness = 2
		ink.Color = WHITE
		ink.Transparency = 0.35
		ink.Parent = ring
	end
	local art = Instance.new("Frame")
	art.Name = "Icon"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.62, 0.62)
	art.BackgroundTransparency = 1
	art.Parent = face
	local colour = if not found
		then DARK
		elseif stamp then WHITE
		else KIND_COLOUR[s.kind] or page.colour
	icon(art, if stamp then page.icon else s.kind, colour)
	return f
end

-- confetti: frames thrown out of the centre, falling under gravity
local function confetti(host: Frame, count: number)
	local bits = {}
	for i = 1, count do
		local c = Instance.new("Frame")
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(0.5, 0.5)
		c.Size = UDim2.fromScale(0.012 + math.random() * 0.01, 0.022 + math.random() * 0.012)
		c.BackgroundColor3 = CONFETTI[(i - 1) % #CONFETTI + 1]
		c.BorderSizePixel = 0
		c.ZIndex = 5
		c.Parent = host
		local a = math.random() * math.pi * 2
		local speed = 0.35 + math.random() * 0.55
		table.insert(bits, {
			f = c,
			x = 0.5,
			y = 0.5,
			vx = math.cos(a) * speed * 0.6,
			vy = math.sin(a) * speed - 0.45,
			spin = (math.random() - 0.5) * 900,
		})
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local age = os.clock() - t0
		for _, b in bits do
			b.vy += 1.1 * dt
			b.x += b.vx * dt
			b.y += b.vy * dt
			b.f.Position = UDim2.fromScale(b.x, b.y)
			b.f.Rotation += b.spin * dt
			b.f.BackgroundTransparency = math.clamp((age - 1.1) / 0.6, 0, 1)
		end
		if age > 1.8 then
			conn:Disconnect()
			for _, b in bits do
				b.f:Destroy()
			end
		end
	end)
end

local busy = 0
function Sticker.slam(islandId: string, stickerId: string, page: boolean?)
	local isle, s = find(islandId, stickerId)
	if not (isle and s) then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	-- queue behind a slam still on screen
	local wait = math.max(busy - os.clock(), 0)
	busy = os.clock() + wait + 2.4
	task.wait(wait)

	local stamp = s.kind == "Stamp"
	local reduced = Comfort.reducedMotion()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DiscoveryStamp"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.Parent = playerGui
	local host = Instance.new("Frame")
	host.Size = UDim2.fromScale(1, 1)
	host.BackgroundTransparency = 1
	host.Parent = gui

	local size = if stamp then 0.42 else 0.26
	local holder = Instance.new("Frame")
	holder.Name = "Stamp"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromScale(size, size)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.BackgroundTransparency = 1
	holder.Rotation = -8
	holder.Parent = host
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	Sticker.draw(holder, islandId, stickerId, true)

	local name: TextLabel? = nil
	if stamp then
		local l = HudTheme.label(
			"Name",
			isle.name,
			UDim2.fromScale(1.6, 0.16),
			HudTheme.NumberFont,
			40,
			holder
		)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, 1.04)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextColor3 = WHITE
		l.TextScaled = true
		l.TextTransparency = 1
		HudTheme.outline(l)
		l.TextStrokeTransparency = 1
		name = l
	end

	local ease = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if reduced then
		scale.Scale = 1
	else
		scale.Scale = if stamp then 3 else 2.2
		holder.Rotation = -30
		TweenService:Create(scale, ease, { Scale = 1 }):Play()
		TweenService:Create(holder, ease, { Rotation = -8 }):Play()
		task.wait(0.2)
	end

	-- the thump
	AudioController.play("Album_Sticker", nil, if stamp then 1.4 else 1, if stamp then 0.8 else 1.1)
	task.delay(0.12, function()
		AudioController.play("Album_Sparkle", nil, if page then 1.3 else 1)
	end)
	if name then
		TweenService
			:Create(
				name,
				TweenInfo.new(0.25),
				{ TextTransparency = 0, TextStrokeTransparency = 0.55 }
			)
			:Play()
	end
	if not reduced then
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = holder.Position
		ring.Size = holder.Size
		ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
		ring.BackgroundTransparency = 1
		ring.Parent = host
		HudTheme.corner(ring, 999)
		local ink = Instance.new("UIStroke")
		ink.Thickness = 10
		ink.Color = if page then GOLD else isle.colour
		ink.Parent = ring
		local grow = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(ring, grow, { Size = UDim2.fromScale(size * 1.9, size * 1.9) }):Play()
		TweenService:Create(ink, grow, { Transparency = 1, Thickness = 2 }):Play()
		confetti(host, if stamp or page then 48 else 24)
		-- screen shake on the impact
		task.spawn(function()
			for i = 1, 8 do
				local k = (9 - i) / 8 * (if stamp then 0.012 else 0.006)
				host.Position =
					UDim2.fromScale((math.random() - 0.5) * k * 2, (math.random() - 0.5) * k * 2)
				task.wait(1 / 40)
			end
			host.Position = UDim2.new()
		end)
	end

	task.wait(if stamp then 1.6 else 1.1)
	-- off toward the phone button (top left), shrinking
	local out = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	if reduced then
		TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 0.01 }):Play()
	else
		TweenService:Create(holder, out, { Position = UDim2.fromScale(0.06, 0.12), Rotation = 10 })
			:Play()
		TweenService:Create(scale, out, { Scale = 0.1 }):Play()
	end
	if name then
		TweenService
			:Create(name, TweenInfo.new(0.2), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end
	task.wait(0.45)
	gui:Destroy()
end

return Sticker
