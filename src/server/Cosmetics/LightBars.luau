--!strict
-- LightBars (server, RP-M5 stream B): builds the "LightBar" cosmetic onto each owner's vehicles.
-- Loaded by CosmeticsService (src/server/Cosmetics feature folder).
--
-- Every vehicle with a bar gets one Model "CosmeticLightBar" (tag "CosmeticLightBar", attribute
-- Pattern = the option's base pattern) holding parts built in code: a black anodised aluminium base
-- and end caps, a clear polycarbonate lens (Glass), a silver reflector and the LED modules ("Lamp",
-- SmoothPlastic when dark; the client turns lit ones Neon). Lamp attributes: LampIndex, LampColor,
-- Side (1 left / 2 right), Invert, Steady. One PointLight per half ("Light1" / "Light2" attachments,
-- Side attribute; a beacon has one with Side 0). All parts massless, non-colliding, welded to the
-- visual hull ("Body").
--   RIB      option bar over the asset's modelled bar on the A-frame; Stock = one blue LED beacon
--   JetSki   option = a small beacon on top of the stern mast; Stock = nothing
-- Vehicle attribute LightsOn: boats toggle it with the Cosmetics_Action "LightBar_Toggle" (driver
-- only).
-- The client (src/client/Cosmetics/LightBars) animates the flash, synced to SirenPattern / SirenTone.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config =
	require(Shared:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("LightBar")) :: any
local LightBarFlash = require(Shared:WaitForChild("LightBarFlash"))

local LightBars = {}
LightBars.Priority = 120

local TAG = "CosmeticLightBar"
local NAME = "CosmeticLightBar"
local ALU = Color3.fromRGB(30, 31, 34) -- black anodised aluminium
local CAP = Color3.fromRGB(22, 23, 25)
local LENS = Color3.fromRGB(214, 222, 230)
local REFLECTOR = Color3.fromRGB(118, 121, 127)
local DARK_LED = Color3.fromRGB(62, 64, 68)

local service: any = nil
local owners: { [Model]: Player } = {}

local function colorOf(name: string): Color3
	return Config.colors[name] or Config.colors.Blue
end

local function newPart(
	parent: Instance,
	anchor: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function addLight(host: BasePart, name: string, offset: Vector3, side: number, range: number)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = offset
	a:SetAttribute("Side", side)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = 2
	light.Shadows = false
	light.Enabled = false
	light.Parent = a
	a.Parent = host
end

local function tagLamp(p: Part, index: number, lamp: LightBarFlash.Lamp)
	p:SetAttribute("LampIndex", index)
	p:SetAttribute("LampColor", colorOf(lamp.color))
	p:SetAttribute("Side", lamp.side)
	p:SetAttribute("Invert", lamp.invert)
	p:SetAttribute("Steady", lamp.steady)
end

-- A low-profile LED bar centred on `cf` (lens body), `size` = (width, height, depth) studs.
local function buildBar(
	container: Model,
	anchor: BasePart,
	cf: CFrame,
	size: Vector3,
	option: any,
	range: number
)
	local w, h, d = size.X, size.Y, size.Z
	local capW = math.min(0.08, w * 0.04)
	local baseH = h * 0.3
	newPart(
		container,
		anchor,
		"Base",
		Vector3.new(w, baseH, d),
		cf * CFrame.new(0, -h / 2 + baseH / 2, 0),
		ALU,
		Enum.Material.Metal
	)
	for _, sx in { -1, 1 } do
		newPart(
			container,
			anchor,
			"EndCap",
			Vector3.new(capW, h, d * 1.02),
			cf * CFrame.new(sx * (w / 2 - capW / 2), 0, 0),
			CAP,
			Enum.Material.SmoothPlastic
		)
	end
	local lensH = h - baseH
	local lensW = w - 2 * capW
	local lensCf = cf * CFrame.new(0, -h / 2 + baseH + lensH / 2, 0)
	local lens = newPart(
		container,
		anchor,
		"Lens",
		Vector3.new(lensW, lensH, d),
		lensCf,
		LENS,
		Enum.Material.Glass
	)
	lens.Transparency = 0.55
	lens.Reflectance = 0.08
	local reflector = newPart(
		container,
		anchor,
		"Reflector",
		Vector3.new(lensW * 0.98, lensH * 0.62, d * 0.5),
		lensCf,
		REFLECTOR,
		Enum.Material.Metal
	)
	reflector.Reflectance = 0.1
	local n = LightBarFlash.lampCount(w)
	local lamps = LightBarFlash.layout(option, n)
	local seg = lensW / n
	for i, lamp in lamps do
		local x = -lensW / 2 + seg * (i - 0.5)
		local p = newPart(
			container,
			anchor,
			"Lamp",
			Vector3.new(seg * 0.74, lensH * 0.4, d * 0.78),
			lensCf * CFrame.new(x, 0, 0),
			DARK_LED,
			Enum.Material.SmoothPlastic
		)
		tagLamp(p, i, lamp)
	end
	addLight(reflector, "Light1", Vector3.new(-lensW / 4, 0, 0), 1, range)
	addLight(reflector, "Light2", Vector3.new(lensW / 4, 0, 0), 2, range)
end

-- A compact LED beacon: dark base, tinted dome, LED stack inside. `cf` = centre, `size` = (dia, h, dia).
local function buildBeacon(
	container: Model,
	anchor: BasePart,
	cf: CFrame,
	size: Vector3,
	colorName: string
)
	local dia, h = size.X, size.Y
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinders run along X
	local baseH = h * 0.22
	local base = newPart(
		container,
		anchor,
		"Base",
		Vector3.new(baseH, dia, dia),
		cf * CFrame.new(0, -h / 2 + baseH / 2, 0) * upright,
		CAP,
		Enum.Material.SmoothPlastic
	)
	base.Shape = Enum.PartType.Cylinder
	local domeH = h - baseH
	local domeCf = cf * CFrame.new(0, -h / 2 + baseH + domeH / 2, 0)
	local color = colorOf(colorName)
	local dome = newPart(
		container,
		anchor,
		"Lens",
		Vector3.new(domeH, dia * 0.9, dia * 0.9),
		domeCf * upright,
		color:Lerp(LENS, 0.3),
		Enum.Material.Glass
	)
	dome.Shape = Enum.PartType.Cylinder
	dome.Transparency = 0.4
	local lampPart = newPart(
		container,
		anchor,
		"Lamp",
		Vector3.new(domeH * 0.7, dia * 0.5, dia * 0.5),
		domeCf * upright,
		DARK_LED,
		Enum.Material.SmoothPlastic
	)
	lampPart.Shape = Enum.PartType.Cylinder
	tagLamp(lampPart, 1, { color = colorName, side = 1, invert = false, steady = false })
	local a = Instance.new("Attachment")
	a.Name = "Light1"
	a:SetAttribute("Side", 0)
	local light = Instance.new("PointLight")
	light.Range = 13
	light.Brightness = 1.8
	light.Shadows = false
	light.Enabled = false
	light.Parent = a
	a.Parent = lampPart
end

local function apply(model: Model, kind: string?, optionId: string)
	if not model.Parent then
		return
	end
	local old = model:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local option = service.Cosmetics.option("LightBar", optionId) or { id = "Stock", stock = true }
	local stock = option.stock == true
	local root = model.PrimaryPart
	if not root then
		return
	end
	local container = Instance.new("Model")
	container.Name = NAME
	container:SetAttribute("Option", option.id)
	container:SetAttribute("Pattern", option.pattern or "Alternate")
	local mounts = Config.mounts
	local built = false
	if kind == "JetSki" then
		if not stock then
			local anchor = (model:FindFirstChild("Body") :: BasePart?) or root
			local m = mounts.JetSki
			buildBeacon(container, anchor, root.CFrame * m.beacon, m.beaconSize, option.half[1])
			container:SetAttribute("Pattern", option.pattern or "Alternate")
			built = true
		end
	elseif kind == "Boat" and model:GetAttribute("VehicleId") == "RIB" then
		local anchor = (model:FindFirstChild("Body") :: BasePart?) or root
		local m = mounts.RIB
		if stock then
			buildBeacon(
				container,
				anchor,
				root.CFrame * m.beacon,
				m.beaconSize,
				Config.stockBeacon.color
			)
			container:SetAttribute("Pattern", Config.stockBeacon.pattern)
		else
			buildBar(container, anchor, root.CFrame * m.bar, m.barSize, option, 16)
		end
		built = true
	end
	if built then
		container.Parent = model
		CollectionService:AddTag(container, TAG)
	else
		container:Destroy()
	end
end

local function refresh(player: Player, model: Model)
	apply(model, service.KindOf(model), service.Equipped(player, "LightBar"))
end

local function track(player: Player, model: Model)
	if not owners[model] then
		model.Destroying:Connect(function()
			owners[model] = nil
		end)
	end
	owners[model] = player
	refresh(player, model)
end

local function driverOf(player: Player, model: Model): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat.Name == "DriverSeat" and seat:IsDescendantOf(model)
end

function LightBars.Init(cosmeticsService: any)
	service = cosmeticsService
	service.OnAction("LightBar_Toggle", function(player: Player)
		local model = service.VehicleOf(player)
		if not model or not driverOf(player, model) then
			return
		end
		if not model:FindFirstChild(NAME) then
			return
		end
		model:SetAttribute("LightsOn", model:GetAttribute("LightsOn") ~= true)
	end)
end

function LightBars.Start()
	service.VehicleSpawned:Connect(function(player: Player, model: Model)
		task.defer(track, player, model)
	end)
	-- the effective choice is the player's Cos_LightBar attribute (CosmeticsService mirrors it)
	local attr = service.Cosmetics.attribute("LightBar")
	local function watch(player: Player)
		player:GetAttributeChangedSignal(attr):Connect(function()
			local current = service.VehicleOf(player)
			if current and not owners[current] then
				track(player, current)
			end
			for model, owner in owners do
				if owner == player then
					refresh(player, model)
				end
			end
		end)
		local model = service.VehicleOf(player)
		if model then
			track(player, model)
		end
	end
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		for model, owner in owners do
			if owner == player then
				owners[model] = nil
			end
		end
	end)
end

return LightBars
