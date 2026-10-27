--!strict
-- Glyph: small vector icons drawn from rounded Frames (no emoji, no image assets), for HUD cards,
-- SurfaceGui tags and billboards. Every glyph fills a square parent in scale units.
--   Glyph.draw(kind, parent, colour)  kind: "swimmer" | "boat" | "cross" | "ring" | "check"
--                                     | "speed" | "seat" | "coin" | "home" | "flare" | "clock" | "quest"
--                                     | "medal"
--   Glyph.bar(parent, size, pos, rotation, colour)  one pill (scale units), the building block
local Glyph = {}

function Glyph.bar(
	parent: Instance,
	size: Vector2,
	pos: Vector2,
	rotation: number,
	colour: Color3,
	radius: number? -- corner radius as a share of the short side (default 1 = pill)
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(pos.X, pos.Y)
	f.Size = UDim2.fromScale(size.X, size.Y)
	f.Rotation = rotation
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius or 1, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

local bar = Glyph.bar

-- a head and both arms in a lifebuoy (the pager's PIW sprite): the old bars read as a flare, and
-- next to the home glyph as the same marker (playtest 2026-10-24)
local function swimmer(p: Instance, c: Color3)
	local buoy = bar(p, Vector2.new(0.84, 0.84), Vector2.new(0.5, 0.56), 0, c)
	buoy.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = c
	s.Thickness = 3
	s.Parent = buoy
	bar(p, Vector2.new(0.3, 0.3), Vector2.new(0.5, 0.28), 0, c) -- head
	bar(p, Vector2.new(0.14, 0.42), Vector2.new(0.24, 0.3), 25, c) -- arms up, waving
	bar(p, Vector2.new(0.14, 0.42), Vector2.new(0.76, 0.3), -25, c)
end

local function boat(p: Instance, c: Color3)
	bar(p, Vector2.new(0.24, 0.2), Vector2.new(0.44, 0.38), 0, c, 0.2) -- wheelhouse
	bar(p, Vector2.new(0.72, 0.16), Vector2.new(0.46, 0.55), 0, c) -- hull
	bar(p, Vector2.new(0.3, 0.12), Vector2.new(0.78, 0.5), -28, c) -- bow
	bar(p, Vector2.new(0.86, 0.07), Vector2.new(0.5, 0.78), 0, c) -- water
end

local function cross(p: Instance, c: Color3)
	bar(p, Vector2.new(0.22, 0.7), Vector2.new(0.5, 0.5), 0, c, 0.25)
	bar(p, Vector2.new(0.7, 0.22), Vector2.new(0.5, 0.5), 0, c, 0.25)
end

local function ring(p: Instance, c: Color3)
	local r = bar(p, Vector2.new(0.62, 0.62), Vector2.new(0.5, 0.5), 0, c)
	r.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = c
	s.Thickness = 4
	s.Parent = r
end

local function check(p: Instance, c: Color3)
	bar(p, Vector2.new(0.14, 0.4), Vector2.new(0.34, 0.6), -45, c)
	bar(p, Vector2.new(0.14, 0.7), Vector2.new(0.6, 0.47), 38, c)
end

local function speed(p: Instance, c: Color3)
	for _, x in { 0.36, 0.62 } do
		bar(p, Vector2.new(0.12, 0.38), Vector2.new(x, 0.37), -40, c)
		bar(p, Vector2.new(0.12, 0.38), Vector2.new(x, 0.63), 40, c)
	end
end

local function seat(p: Instance, c: Color3)
	bar(p, Vector2.new(0.24, 0.24), Vector2.new(0.4, 0.3), 0, c) -- head
	bar(p, Vector2.new(0.46, 0.34), Vector2.new(0.4, 0.66), 0, c, 0.45) -- shoulders
	bar(p, Vector2.new(0.3, 0.09), Vector2.new(0.8, 0.26), 0, c) -- plus
	bar(p, Vector2.new(0.09, 0.3), Vector2.new(0.8, 0.26), 0, c)
end

local function home(p: Instance, c: Color3)
	bar(p, Vector2.new(0.5, 0.12), Vector2.new(0.33, 0.33), -40, c) -- roof
	bar(p, Vector2.new(0.5, 0.12), Vector2.new(0.67, 0.33), 40, c)
	bar(p, Vector2.new(0.52, 0.4), Vector2.new(0.5, 0.66), 0, c, 0.15) -- walls
end

local function coin(p: Instance, _: Color3)
	bar(p, Vector2.new(0.9, 0.9), Vector2.new(0.5, 0.5), 0, Color3.fromRGB(246, 206, 96))
	bar(p, Vector2.new(0.62, 0.62), Vector2.new(0.5, 0.5), 0, Color3.fromRGB(214, 164, 62))
end

local function flare(p: Instance, c: Color3)
	bar(p, Vector2.new(0.13, 0.4), Vector2.new(0.5, 0.72), 0, c, 0.3) -- hand flare stick
	bar(p, Vector2.new(0.3, 0.3), Vector2.new(0.5, 0.36), 0, c) -- the burning head
	bar(p, Vector2.new(0.08, 0.2), Vector2.new(0.24, 0.2), -45, c) -- sparks
	bar(p, Vector2.new(0.08, 0.2), Vector2.new(0.76, 0.2), 45, c)
	bar(p, Vector2.new(0.08, 0.16), Vector2.new(0.5, 0.06), 0, c)
end

local function clock(p: Instance, c: Color3)
	ring(p, c)
	bar(p, Vector2.new(0.08, 0.24), Vector2.new(0.5, 0.39), 0, c) -- hands
	bar(p, Vector2.new(0.2, 0.08), Vector2.new(0.59, 0.5), 0, c)
end

-- a Medal: red / blue ribbons over a gold disc (the skill tree's currency)
local function medal(p: Instance, _: Color3)
	bar(p, Vector2.new(0.2, 0.34), Vector2.new(0.38, 0.28), -18, Color3.fromHex("3B6FD4"), 0.15)
	bar(p, Vector2.new(0.2, 0.34), Vector2.new(0.62, 0.28), 18, Color3.fromHex("E33B3B"), 0.15)
	bar(p, Vector2.new(0.72, 0.72), Vector2.new(0.5, 0.64), 0, Color3.fromHex("FFC928"))
	bar(p, Vector2.new(0.46, 0.46), Vector2.new(0.5, 0.64), 0, Color3.fromHex("E09E12"))
	bar(p, Vector2.new(0.12, 0.24), Vector2.new(0.5, 0.62), 90, Color3.fromHex("FFF0B0"), 0.2)
	bar(p, Vector2.new(0.24, 0.12), Vector2.new(0.5, 0.62), 0, Color3.fromHex("FFF0B0"), 0.2)
end

-- a quest: "!" (the giver's glyph)
local function quest(p: Instance, c: Color3)
	bar(p, Vector2.new(0.18, 0.5), Vector2.new(0.5, 0.38), 0, c)
	bar(p, Vector2.new(0.18, 0.18), Vector2.new(0.5, 0.84), 0, c)
end

local DRAW: { [string]: (Instance, Color3) -> () } = {
	swimmer = swimmer,
	boat = boat,
	cross = cross,
	ring = ring,
	check = check,
	speed = speed,
	seat = seat,
	coin = coin,
	home = home,
	flare = flare,
	clock = clock,
	medal = medal,
	quest = quest,
}

function Glyph.draw(kind: string, parent: Instance, colour: Color3)
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local fn: (Instance, Color3) -> () = DRAW[kind] or ring
	fn(parent, colour)
end

return Glyph
