--!strict
-- GoalBoard: the Lego counter board's bricks on the next build's empty lot (GoalBoardController draws its face:
-- icon, Cash bar, "240/400"). `at` = where it stands on the lot, Y 0 = the ground, -Z = the way it faces.
-- Two red posts, a blue face plate between them, a studded yellow cap. No shared planes (tests/ZFight.spec.luau).
local GoalBoard = {}

GoalBoard.W, GoalBoard.H = 12, 6 -- the face plate, studs
GoalBoard.LIFT = 2.6 -- studs from the ground to the face's bottom edge

local STUDS = "rbxassetid://18878365966" -- the island's 4 x 4 stud tile (DockPieces)
local RED = Color3.fromRGB(224, 56, 40)
local BLUE = Color3.fromRGB(44, 142, 240)
local YELLOW = Color3.fromRGB(250, 208, 40)

local function brick(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

function GoalBoard.build(at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "GoalBoard"
	local w, h, lift = GoalBoard.W, GoalBoard.H, GoalBoard.LIFT
	local top = lift + h
	-- the face (Front = -Z, Back = +Z both carry the counter)
	local face = brick(m, "Face", Vector3.new(w, h, 0.6), at * CFrame.new(0, lift + h / 2, 0), BLUE)
	-- posts beside it, sunk a stud into the ground, deeper than the face so their fronts stand proud
	for _, x in { -w / 2 - 0.5, w / 2 + 0.5 } do
		brick(m, "Post", Vector3.new(1, top + 1, 1), at * CFrame.new(x, (top - 1) / 2, 0), RED)
	end
	-- the cap over both posts, wider and deeper than they are (no flush ends)
	local cap =
		brick(m, "Cap", Vector3.new(w + 2.3, 1, 1.4), at * CFrame.new(0, top + 0.5, 0), YELLOW)
	local studs = Instance.new("Texture")
	studs.Name = "Studs"
	studs.Face = Enum.NormalId.Top
	studs.Texture = STUDS
	studs.StudsPerTileU, studs.StudsPerTileV = 4, 4
	studs.Color3 = YELLOW:Lerp(Color3.new(0, 0, 0), 0.12)
	studs.Transparency = 0.15
	studs.Parent = cap
	m.PrimaryPart = face
	return m
end

return GoalBoard
