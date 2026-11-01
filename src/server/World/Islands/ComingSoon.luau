--!strict
-- ComingSoon: the phase-2 islands (GitHub issue #1) are bare terrain for now; this puts a "Coming soon"
-- noticeboard and a barrier at the island's landing, facing whoever arrives from the dock.
-- Not an island id, so the Islands loader never runs it on its own. With the Lego kit (M_Prop_BoardKit L02) loaded,
-- the code Parts stay as invisible colliders and the PNG goes on the kit board's face.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
)
local AssetLoader =
	require(script.Parent.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))

local ComingSoon = {}

local FACE = "rbxassetid://123799723191842" -- assets/ui/signs/sign_coming_soon.png (1024 x 512)
local WOOD = Color3.fromRGB(120, 86, 58)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function ComingSoon.place(base: Instance, island: any)
	local landing: Vector3 = island.landing
	local toward: Vector3 = island.dock or island.center
	local flat = Vector3.new(toward.X, landing.Y, toward.Z)
	if (flat - landing).Magnitude < 1 then
		flat = landing + Vector3.new(0, 0, 10)
	end
	-- the board's front (-Z of its CFrame) faces the dock, so a player stepping ashore reads it
	local root = CFrame.lookAt(landing, flat)

	local model = Instance.new("Model")
	model.Name = `ComingSoon_{island.id}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local boardCf = root * CFrame.new(0, 6.2, 0)
	part(
		model,
		"PostL",
		Vector3.new(0.6, 8, 0.6),
		root * CFrame.new(-4.6, 4, 0.2),
		WOOD,
		Enum.Material.Wood
	)
	part(
		model,
		"PostR",
		Vector3.new(0.6, 8, 0.6),
		root * CFrame.new(4.6, 4, 0.2),
		WOOD,
		Enum.Material.Wood
	)
	local board = part(model, "Board", Vector3.new(10, 5, 0.4), boardCf, WOOD, Enum.Material.Wood)
	local decal = Instance.new("Decal")
	decal.Texture = FACE
	decal.Face = Enum.NormalId.Front
	decal.Parent = board

	-- a yellow barrier in front, like a closed site
	local barrierCf = root * CFrame.new(0, 1.6, -4)
	part(
		model,
		"BarrierLegL",
		Vector3.new(0.3, 3.2, 0.3),
		barrierCf * CFrame.new(-3.5, 0, 0),
		Color3.fromRGB(235, 235, 235),
		Enum.Material.SmoothPlastic
	)
	part(
		model,
		"BarrierLegR",
		Vector3.new(0.3, 3.2, 0.3),
		barrierCf * CFrame.new(3.5, 0, 0),
		Color3.fromRGB(235, 235, 235),
		Enum.Material.SmoothPlastic
	)
	part(
		model,
		"Barrier",
		Vector3.new(7.6, 0.8, 0.2),
		barrierCf * CFrame.new(0, 0.9, 0),
		Color3.fromRGB(240, 200, 30),
		Enum.Material.SmoothPlastic
	)

	local kit = AssetLoader.cloneModule("M_Prop_BoardKit", "ATT_Soon", root, { "L02_ComingSoon" })
	if kit then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		local atts = AssetIds.Attachments.M_Prop_BoardKit
		-- 11.5 x 5.75 (the PNG's 2:1), 0.02 thick, its front face on ATT_SoonFace
		local cf = root * CFrame.new(atts.ATT_SoonFace - atts.ATT_Soon) * CFrame.new(0, 0, 0.01)
		local face =
			part(kit, "Face", Vector3.new(11.5, 5.75, 0.02), cf, WOOD, Enum.Material.SmoothPlastic)
		face.Transparency = 1
		face.CanCollide, face.CanQuery, face.CanTouch = false, false, false
		face.CastShadow = false
		decal.Parent = face
		kit.Name = "Kit"
		kit.Parent = model
	end

	model.PrimaryPart = board
	model.Parent = base
end

return ComingSoon
