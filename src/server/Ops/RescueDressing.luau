--!strict
-- RescueDressing (server): the code-built look of each rare-call variant (docs/15 H2): outfit
-- colours, an accessory part, a dog made of Parts, a golden bird, a white yacht hull. Called from
-- the places that build casualties and boats (RescueService.spawnVictim/buildDisabledBoat,
-- CliffScene, SinkingScene). Placeholder art until real models land (CLAUDE.md).
--
-- Two mounting modes, chosen by the caller's context:
--   floater + mount  parts ride a RescueService floater (offset from its sea-surface frame)
--   root             parts are welded to a stationary model's primary part (offset from its CFrame)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RescueVariants = require(Shared:WaitForChild("Config"):WaitForChild("RescueVariants"))

local RescueDressing = {}

type Mount = (part: BasePart, offset: CFrame) -> ()

export type Ctx = {
	floater: any?,
	mount: Mount?,
	root: BasePart?,
	large: boolean?, -- the sinking scene's 24 x 7 x 52 hull
}

local function part(
	name: string,
	size: Vector3,
	colour: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	return p
end

-- Adds a part: on the floater through the caller's mount, or welded to the stationary root.
local function add(
	model: Model,
	ctx: Ctx,
	name: string,
	size: Vector3,
	offset: CFrame,
	colour: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = part(name, size, colour, shape, material)
	p.Parent = model
	if ctx.mount and ctx.floater then
		ctx.mount(p, offset)
	elseif ctx.root then
		p.Anchored = false
		p.CFrame = ctx.root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.root
		weld.Part1 = p
		weld.Parent = p
	else
		p.CFrame = offset
	end
	return p
end

local function hide(model: Instance, names: { string })
	for _, name in names do
		local child = model:FindFirstChild(name, true)
		if child and child:IsA("BasePart") then
			child.Transparency = 1
			child.CanQuery = false
		end
	end
end

local TORSO = -1.35 -- the swimmer's torso centre on a water floater (RescueService.RIG_TORSO - 4.55)
local HEAD = TORSO + 2.5 -- the rigged swimmer floats mid-chest deep in the lifejacket (CasualtyAsset)
local GOLD = Color3.fromRGB(255, 205, 80)

-- A spectacular variant (docs/15 H2): the Golden Gull reads at a distance. Legendary creatures
-- are drawn at twice size and carry a gold glow and sparkles; Epics get a smaller glow and no beam
-- (the beam itself and the sky flare are AlbumService.AnnounceCall).
local function scaleOffset(offset: CFrame, scale: number): CFrame
	return CFrame.new(offset.Position * scale) * (offset - offset.Position)
end

local function glow(host: BasePart, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = host
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 222, 120)
	sparkle.Parent = host
end

local function personProp(model: Model, ctx: Ctx, id: string, torso: CFrame, head: CFrame)
	if id == "Kayaker" then
		add(
			model,
			ctx,
			"Kayak",
			Vector3.new(2.3, 0.5, 6.4),
			torso * CFrame.new(0, 0.15, 0),
			Color3.fromRGB(214, 116, 52)
		)
		add(
			model,
			ctx,
			"Paddle",
			Vector3.new(0.16, 0.16, 4.8),
			head * CFrame.new(1.3, -0.4, 0) * CFrame.Angles(0, 0.3, 0.55),
			Color3.fromRGB(236, 230, 218)
		)
	elseif id == "Paddleboarder" then
		add(
			model,
			ctx,
			"Board",
			Vector3.new(2.5, 0.24, 6.8),
			torso * CFrame.new(0, -0.05, 0),
			Color3.fromRGB(240, 238, 228)
		)
		add(
			model,
			ctx,
			"Paddle",
			Vector3.new(0.16, 0.16, 4.4),
			head * CFrame.new(1.2, -0.3, 0) * CFrame.Angles(0, 0.2, 0.6),
			Color3.fromRGB(226, 220, 208)
		)
	elseif id == "PirateSwimmer" then
		add(
			model,
			ctx,
			"Tricorn",
			Vector3.new(2.2, 0.22, 2.2),
			head * CFrame.new(0, 0.7, 0),
			Color3.fromRGB(34, 32, 38)
		)
		add(
			model,
			ctx,
			"Eyepatch",
			Vector3.new(0.5, 0.34, 0.08),
			head * CFrame.new(0.24, 0.12, -0.63),
			Color3.fromRGB(24, 24, 28)
		)
		add(
			model,
			ctx,
			"Sash",
			Vector3.new(2.14, 0.44, 1.1),
			torso * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, 0.25),
			Color3.fromRGB(178, 48, 58)
		)
	elseif id == "Hiker" then
		add(
			model,
			ctx,
			"Backpack",
			Vector3.new(1.5, 1.7, 0.9),
			torso * CFrame.new(0, 0, 0.9),
			Color3.fromRGB(86, 116, 72)
		)
		add(
			model,
			ctx,
			"BucketHat",
			Vector3.new(1.7, 0.18, 1.7),
			head * CFrame.new(0, 0.72, 0),
			Color3.fromRGB(214, 198, 150)
		)
	elseif id == "Climber" then
		add(
			model,
			ctx,
			"Helmet",
			Vector3.new(1.5, 0.7, 1.5),
			head * CFrame.new(0, 0.42, 0),
			Color3.fromRGB(228, 160, 40)
		)
		add(
			model,
			ctx,
			"RopeCoil",
			Vector3.new(1.1, 1.1, 0.5),
			torso * CFrame.new(0, 0, 0.85),
			Color3.fromRGB(232, 216, 170)
		)
	elseif id == "Paraglider" then
		add(
			model,
			ctx,
			"Helmet",
			Vector3.new(1.4, 0.6, 1.4),
			head * CFrame.new(0, 0.4, 0),
			Color3.fromRGB(214, 88, 138)
		)
		add(
			model,
			ctx,
			"CanopyRoll",
			Vector3.new(1.9, 0.55, 0.7),
			torso * CFrame.new(0, 0.2, 0.95) * CFrame.Angles(0, 0, 0.12),
			Color3.fromRGB(222, 96, 150)
		)
	elseif id == "RipSwimmer" then
		add(
			model,
			ctx,
			"SwimCap",
			Vector3.new(1.25, 0.42, 1.25),
			head * CFrame.new(0, 0.5, 0),
			Color3.fromRGB(230, 86, 70)
		)
	elseif id == "BodyBoarder" then
		add(
			model,
			ctx,
			"BodyBoard",
			Vector3.new(2.1, 0.2, 4.2),
			torso * CFrame.new(0, -0.1, -0.3),
			Color3.fromRGB(240, 214, 72)
		)
		add(
			model,
			ctx,
			"Leash",
			Vector3.new(0.08, 0.08, 1.5),
			torso * CFrame.new(0.8, -0.35, 2.1),
			Color3.fromRGB(40, 40, 44)
		)
	elseif id == "Surfer" then
		add(
			model,
			ctx,
			"Surfboard",
			Vector3.new(2.4, 0.22, 7.4),
			torso * CFrame.new(0, -0.55, 0),
			Color3.fromRGB(64, 182, 196)
		)
		add(
			model,
			ctx,
			"SurfFin",
			Vector3.new(0.16, 0.55, 0.9),
			torso * CFrame.new(0, -0.95, 2.9),
			Color3.fromRGB(32, 96, 112)
		)
	elseif id == "Mermaid" then
		add(
			model,
			ctx,
			"MermaidTail",
			Vector3.new(1.15, 0.5, 3),
			torso * CFrame.new(0, -0.35, 1.35) * CFrame.Angles(-0.12, 0, 0),
			Color3.fromRGB(58, 178, 164)
		)
		add(
			model,
			ctx,
			"TailFin",
			Vector3.new(1.9, 0.16, 1.1),
			torso * CFrame.new(0, -0.4, 2.95) * CFrame.Angles(0, 0.18, 0),
			Color3.fromRGB(90, 208, 190)
		)
	elseif id == "Grandad" then
		add(
			model,
			ctx,
			"FlatCap",
			Vector3.new(1.5, 0.3, 1.5),
			head * CFrame.new(0, 0.6, 0.05),
			Color3.fromRGB(126, 104, 74)
		)
		add(
			model,
			ctx,
			"Thermos",
			Vector3.new(0.8, 0.34, 0.34),
			torso * CFrame.new(0.72, 0.05, -0.5) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(198, 204, 206),
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
	elseif id == "SeaScout" then
		add(
			model,
			ctx,
			"Neckerchief",
			Vector3.new(1.7, 0.34, 1.15),
			torso * CFrame.new(0, 0.56, 0),
			Color3.fromRGB(52, 118, 74)
		)
		add(
			model,
			ctx,
			"Woggle",
			Vector3.new(0.3, 0.3, 0.3),
			torso * CFrame.new(0, 0.45, -0.62),
			Color3.fromRGB(218, 180, 72),
			Enum.PartType.Ball
		)
	end
end

local function creature(model: Model, ctx: Ctx, id: string, legendary: boolean)
	if id == "LostDog" then
		local brown = Color3.fromRGB(160, 104, 62)
		add(
			model,
			ctx,
			"DogBody",
			Vector3.new(1.5, 0.9, 2.4),
			CFrame.new(0, TORSO + 0.35, 0),
			brown
		)
		add(
			model,
			ctx,
			"DogHead",
			Vector3.new(0.95, 0.95, 0.95),
			CFrame.new(0, TORSO + 0.75, -1.35),
			brown,
			Enum.PartType.Ball
		)
		add(
			model,
			ctx,
			"DogMuzzle",
			Vector3.new(0.5, 0.4, 0.5),
			CFrame.new(0, TORSO + 0.55, -1.9),
			Color3.fromRGB(196, 152, 112)
		)
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"DogEar",
				Vector3.new(0.24, 0.6, 0.34),
				CFrame.new(side * 0.42, TORSO + 1.2, -1.2),
				Color3.fromRGB(120, 74, 42)
			)
			add(
				model,
				ctx,
				"DogLeg",
				Vector3.new(0.28, 0.8, 0.28),
				CFrame.new(side * 0.5, TORSO - 0.2, -0.7),
				brown
			)
			add(
				model,
				ctx,
				"DogLeg",
				Vector3.new(0.28, 0.8, 0.28),
				CFrame.new(side * 0.5, TORSO - 0.2, 0.8),
				brown
			)
		end
		add(
			model,
			ctx,
			"DogTail",
			Vector3.new(0.22, 0.22, 0.9),
			CFrame.new(0, TORSO + 0.7, 1.4) * CFrame.Angles(-0.5, 0, 0),
			brown
		)
		add(
			model,
			ctx,
			"DogCollar",
			Vector3.new(0.72, 0.22, 0.72),
			CFrame.new(0, TORSO + 0.5, -1),
			Color3.fromRGB(200, 52, 52)
		)
	elseif id == "Seal" then
		local grey = Color3.fromRGB(128, 136, 148)
		add(model, ctx, "SealBody", Vector3.new(1.4, 0.8, 2.6), CFrame.new(0, TORSO + 0.3, 0), grey)
		add(
			model,
			ctx,
			"SealHead",
			Vector3.new(1, 0.9, 0.9),
			CFrame.new(0, TORSO + 0.7, -1.4),
			grey,
			Enum.PartType.Ball
		)
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"SealFlipper",
				Vector3.new(0.8, 0.16, 1.1),
				CFrame.new(side * 0.85, TORSO + 0.25, -0.7) * CFrame.Angles(0, 0, side * 0.35),
				Color3.fromRGB(104, 112, 124)
			)
		end
		add(
			model,
			ctx,
			"FishingNet",
			Vector3.new(1.55, 0.12, 2.7),
			CFrame.new(0, TORSO + 0.58, 0) * CFrame.Angles(0, 0.2, 0),
			Color3.fromRGB(52, 72, 58)
		).Transparency =
			0.35
	elseif id == "GoldenGull" then
		local gold = Color3.fromRGB(240, 190, 58)
		local scale = if legendary then 2 else 1
		local function gadd(
			name: string,
			size: Vector3,
			offset: CFrame,
			colour: Color3,
			shape: Enum.PartType?
		): Part
			return add(model, ctx, name, size * scale, scaleOffset(offset, scale), colour, shape)
		end
		local body = gadd(
			"GullBody",
			Vector3.new(1, 0.8, 1.8),
			CFrame.new(0, TORSO + 1.3, 0),
			gold,
			Enum.PartType.Ball
		)
		for side = -1, 1, 2 do
			gadd(
				"GullWing",
				Vector3.new(2.6, 0.16, 1.1),
				CFrame.new(side * 1.4, TORSO + 1.45, 0) * CFrame.Angles(0, side * 0.25, side * 0.2),
				Color3.fromRGB(252, 214, 96)
			)
		end
		gadd(
			"GullHead",
			Vector3.new(0.62, 0.62, 0.62),
			CFrame.new(0, TORSO + 1.85, -0.85),
			gold,
			Enum.PartType.Ball
		)
		gadd(
			"GullBeak",
			Vector3.new(0.22, 0.2, 0.5),
			CFrame.new(0, TORSO + 1.8, -1.3),
			Color3.fromRGB(226, 128, 36)
		)
		gadd(
			"TangledLine",
			Vector3.new(0.07, 0.07, 3.6),
			CFrame.new(0, TORSO + 0.9, 1.8) * CFrame.Angles(-0.35, 0, 0),
			Color3.fromRGB(226, 226, 214)
		)
		if legendary then
			glow(body, 6, 60)
		end
	end
end

local function boat(model: Model, ctx: Ctx, id: string)
	local large = ctx.large == true
	if id == "FishingBoat" then
		add(
			model,
			ctx,
			"NetRoll",
			Vector3.new(1.4, 1.4, if large then 8 else 4),
			CFrame.new(0, if large then 4.2 else 1.5, if large then 12 else 4.5),
			Color3.fromRGB(64, 84, 70)
		)
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"Outrigger",
				Vector3.new(0.18, if large then 7 else 4.5, 0.18),
				CFrame.new(side * (if large then 10 else 3.4), if large then 4 else 2.2, 0)
					* CFrame.Angles(0, 0, side * 0.3),
				Color3.fromRGB(120, 96, 60)
			)
		end
	elseif id == "RowingBoat" then
		hide(model, { "Cabin", "Windshield", "Smoke" })
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"Oar",
				Vector3.new(0.14, 0.14, 5.4),
				CFrame.new(side * 1.8, 0.4, 0) * CFrame.Angles(0, side * 0.5, side * 0.22),
				Color3.fromRGB(176, 130, 78)
			)
		end
		add(
			model,
			ctx,
			"Bench",
			Vector3.new(5, 0.25, 0.8),
			CFrame.new(0, 0.9, -1),
			Color3.fromRGB(150, 104, 62)
		)
		add(
			model,
			ctx,
			"Bench",
			Vector3.new(5, 0.25, 0.8),
			CFrame.new(0, 0.9, 3),
			Color3.fromRGB(150, 104, 62)
		)
	elseif id == "CelebrityYacht" then
		add(
			model,
			ctx,
			"SunDeck",
			Vector3.new(5.2, 0.3, 6.5),
			CFrame.new(0, 4.5, 1.5),
			Color3.fromRGB(250, 250, 246)
		)
		add(
			model,
			ctx,
			"GoldRail",
			Vector3.new(5.4, 0.12, 0.12),
			CFrame.new(0, 5.1, 4.7),
			Color3.fromRGB(218, 178, 74)
		)
		add(
			model,
			ctx,
			"YachtFlag",
			Vector3.new(1.4, 0.7, 0.06),
			CFrame.new(0, 6.4, -5.6),
			Color3.fromRGB(218, 178, 74)
		)
		add(
			model,
			ctx,
			"FlagPole",
			Vector3.new(0.1, 2.6, 0.1),
			CFrame.new(0, 5.5, -5.6),
			Color3.fromRGB(220, 220, 214)
		)
	elseif id == "CharterBoat" then
		add(
			model,
			ctx,
			"Canopy",
			Vector3.new(5.4, 0.18, 5),
			CFrame.new(0, 4.9, -1.5),
			Color3.fromRGB(58, 150, 138)
		)
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"CanopyPost",
				Vector3.new(0.12, 2.1, 0.12),
				CFrame.new(side * 2.3, 3.9, -3.6),
				Color3.fromRGB(220, 220, 214)
			)
		end
	elseif id == "Tanker" then
		for i = -1, 1 do
			add(
				model,
				ctx,
				"Tank",
				Vector3.new(1.8, 5, 1.8),
				CFrame.new(i * 1.9, 3.6, 2) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(196, 198, 190),
				Enum.PartType.Cylinder,
				Enum.Material.Metal
			)
		end
		add(
			model,
			ctx,
			"HazardStripe",
			Vector3.new(6.15, 0.5, 14.15),
			CFrame.new(0, -0.8, 0),
			Color3.fromRGB(224, 122, 40)
		)
	elseif id == "SinkingFishingBoat" then
		add(
			model,
			ctx,
			"NetRoll",
			Vector3.new(2.2, 2.2, 12),
			CFrame.new(0, 4.4, 14),
			Color3.fromRGB(64, 84, 70)
		)
		add(
			model,
			ctx,
			"Buoy",
			Vector3.new(1, 1, 1),
			CFrame.new(8, 4.2, 20),
			Color3.fromRGB(240, 128, 40),
			Enum.PartType.Ball
		)
	elseif id == "Tugboat" then
		for side = -1, 1, 2 do
			for i = -2, 2 do
				add(
					model,
					ctx,
					"TyreFender",
					Vector3.new(1.6, 1.6, 0.9),
					CFrame.new(side * 12.4, 1.5, i * 9),
					Color3.fromRGB(28, 30, 32),
					Enum.PartType.Cylinder
				)
			end
		end
		add(
			model,
			ctx,
			"Mast",
			Vector3.new(0.5, 10, 0.5),
			CFrame.new(0, 20, -12),
			Color3.fromRGB(196, 160, 70)
		)
	elseif id == "FerryTender" then
		add(
			model,
			ctx,
			"BlueStripe",
			Vector3.new(24.2, 0.9, 52.2),
			CFrame.new(0, 2.2, 0),
			Color3.fromRGB(42, 92, 156)
		)
		for i = -1, 1 do
			add(
				model,
				ctx,
				"LifeRaft",
				Vector3.new(1.4, 1.4, 3.4),
				CFrame.new(i * 5, 5, 10) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(246, 246, 240),
				Enum.PartType.Cylinder
			)
		end
	elseif id == "SwanPedalo" then
		hide(model, { "Cabin", "Windshield", "Smoke" })
		add(
			model,
			ctx,
			"SwanBody",
			Vector3.new(3.6, 1.1, 5.6),
			CFrame.new(0, 1.05, -0.4),
			Color3.fromRGB(248, 248, 244)
		)
		add(
			model,
			ctx,
			"SwanNeck",
			Vector3.new(0.6, 2.4, 0.6),
			CFrame.new(0, 3, -2) * CFrame.Angles(-0.35, 0, 0),
			Color3.fromRGB(248, 248, 244)
		)
		add(
			model,
			ctx,
			"SwanHead",
			Vector3.new(0.95, 0.95, 0.95),
			CFrame.new(0, 4.2, -2.6),
			Color3.fromRGB(248, 248, 244),
			Enum.PartType.Ball
		)
		add(
			model,
			ctx,
			"SwanBeak",
			Vector3.new(0.28, 0.24, 0.7),
			CFrame.new(0, 4.15, -3.1),
			Color3.fromRGB(232, 148, 52)
		)
	elseif id == "PirateShip" then
		hide(model, { "Smoke" })
		add(
			model,
			ctx,
			"Mast",
			Vector3.new(0.34, 9, 0.34),
			CFrame.new(0, 5, 0.5),
			Color3.fromRGB(96, 68, 44)
		)
		add(
			model,
			ctx,
			"Sail",
			Vector3.new(5.2, 3.2, 0.12),
			CFrame.new(0, 6.2, 0.5),
			Color3.fromRGB(226, 220, 202)
		)
		add(
			model,
			ctx,
			"PirateFlag",
			Vector3.new(1.5, 0.9, 0.06),
			CFrame.new(0.9, 8.7, 0.5),
			Color3.fromRGB(28, 26, 30)
		)
	elseif id == "Trawler" then
		add(
			model,
			ctx,
			"TrawlBoom",
			Vector3.new(0.32, 0.32, 5.5),
			CFrame.new(0, 4.5, 3.5) * CFrame.Angles(-0.5, 0, 0),
			Color3.fromRGB(120, 96, 60)
		)
		add(
			model,
			ctx,
			"TrawlNet",
			Vector3.new(2.6, 2.2, 2.6),
			CFrame.new(0, 1.6, 5.5),
			Color3.fromRGB(52, 72, 58),
			Enum.PartType.Ball
		)
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"Float",
				Vector3.new(0.7, 0.7, 0.7),
				CFrame.new(side * 1.8, 1.1, 5.5),
				Color3.fromRGB(240, 128, 40),
				Enum.PartType.Ball
			)
		end
	elseif id == "Houseboat" then
		add(
			model,
			ctx,
			"CabinTop",
			Vector3.new(4.6, 1.8, 5.4),
			CFrame.new(0, 3.5, 0),
			Color3.fromRGB(240, 232, 208)
		)
		add(
			model,
			ctx,
			"WindowStrip",
			Vector3.new(4.65, 0.5, 5.45),
			CFrame.new(0, 3.8, 0),
			Color3.fromRGB(42, 66, 82)
		)
		for side = -1, 1, 2 do
			add(
				model,
				ctx,
				"Planter",
				Vector3.new(1.6, 0.5, 0.6),
				CFrame.new(side * 1.2, 4.65, -2.4),
				Color3.fromRGB(74, 118, 66)
			)
		end
	end
end

-- True for the variants that replace the person entirely (the lost dog, the seal, the golden gull).
function RescueDressing.isCreature(variantId: any): boolean
	local variant = RescueVariants.ById(variantId)
	return variant ~= nil and variant.style == "Creature"
end

-- Dress a casualty model for `variantId`. `ctx` carries how the model moves (see the header).
function RescueDressing.apply(model: Model, variantId: any, ctx: Ctx?)
	local variant = RescueVariants.ById(variantId)
	if not variant then
		return
	end
	local context: Ctx = ctx or {}
	if variant.paint then
		for name, colour in variant.paint do
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") and child.Name == name then
					child.Color = colour
				end
			end
		end
	end
	if variant.style == "Creature" then
		creature(model, context, variant.id, variant.rarity == "Legendary")
	elseif variant.style == "Boat" then
		boat(model, context, variant.id)
	else
		local torso = CFrame.new(0, TORSO, 0)
		local head = CFrame.new(0, HEAD, 0)
		if context.root and not context.floater then
			-- CliffScene's stationary casualty: place the hat and pack from the model's own bounds
			local ok, box, size = pcall(function()
				return model:GetBoundingBox()
			end)
			if ok then
				local centre = (box :: CFrame).Position
				torso = context.root.CFrame:ToObjectSpace(CFrame.new(centre))
				head = context.root.CFrame:ToObjectSpace(
					CFrame.new(centre.X, centre.Y + (size :: Vector3).Y * 0.32, centre.Z)
				)
			end
		end
		personProp(model, context, variant.id, torso, head)
	end
	if variant.rarity == "Epic" then
		local host = model:FindFirstChild("SunDeck", true) or model.PrimaryPart
		if host and host:IsA("BasePart") then
			glow(host, 2.5, 28)
		end
	end
end

return RescueDressing
