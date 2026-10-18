--!strict
-- Liveries (RP-M5 E1, server cosmetic feature; auto-loaded by CosmeticsService): repaints every
-- vehicle a player spawns (RIB, jet ski, pickup, response car, beach ATV) in their equipped
-- "Livery" option (src/shared/Config/Cosmetics/Livery.luau), and repaints them again when the
-- choice changes. "Standard" restores the stock paint. No new uploads:
--   * uploaded MeshParts (LiveryPaint.MESH_RULES): the stock SurfaceAppearances (dry and wet) are
--     parked in a Configuration "LiveryStock" on the part and replaced by map-only copies of the
--     same texture set (script.Appearances, built by Rojo: normal + roughness + metalness, no
--     ColorMap) with AlphaMode TintMask and Color = the livery colour (verified in Studio: Overlay
--     without a ColorMap renders white, TintMask renders the Color). The AssetLoader wet swap (SurfaceVariants /
--     WetState) keeps working because the same names are used; wet uses LiveryPaint.wet(colour).
--   * greybox Parts with a "Paint" attribute (Car/Builder, Boat/Builder): Color is set; the stock
--     colour is kept in the attribute "LiveryStockColor". Metallic liveries add a faint
--     clear-coat Reflectance on cars.
-- The trailer and the ambulance keep their service paint (LiveryPaint.SKIP_VEHICLES).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local LiveryPaint = require(Shared:WaitForChild("LiveryPaint"))

local SLOT = "Livery"
local METALLIC_REFLECTANCE = 0.06

local Liveries = {}

local service: any = nil
local templates = script:FindFirstChild("Appearances")
local vehicles: { [Player]: { [Model]: boolean } } = {}

local function template(key: string, state: string): SurfaceAppearance?
	local node: Instance? = templates
	for part in string.gmatch(key, "[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	local sa = node and node:FindFirstChild(state)
	return if sa and sa:IsA("SurfaceAppearance") then sa else nil
end

-- puts a dry / wet pair on the part the way AssetLoader does (active by WetState, the other parked
-- in SurfaceVariants)
local function install(part: BasePart, dry: SurfaceAppearance?, wet: SurfaceAppearance?)
	local isWet = part:GetAttribute("WetState") == true
	local active = if isWet and wet then wet else dry
	local other = if active == dry then wet else dry
	if active then
		active.Name = "SurfaceAppearance"
		active.Parent = part
	end
	if other then
		local variants = part:FindFirstChild("SurfaceVariants")
		if not variants then
			variants = Instance.new("Configuration")
			variants.Name = "SurfaceVariants"
			variants.Parent = part
		end
		other.Name = if other == wet then "SurfaceAppearance_Wet" else "SurfaceAppearance_Dry"
		other.Parent = variants
	end
end

-- (dry, wet) currently on the part, detached
local function detach(part: BasePart): (SurfaceAppearance?, SurfaceAppearance?)
	local isWet = part:GetAttribute("WetState") == true
	local active = part:FindFirstChildWhichIsA("SurfaceAppearance")
	local variants = part:FindFirstChild("SurfaceVariants")
	local parked = variants and variants:FindFirstChildWhichIsA("SurfaceAppearance")
	if active then
		active.Parent = nil
	end
	if parked then
		parked.Parent = nil
	end
	if isWet then
		return parked :: SurfaceAppearance?, active
	end
	return active, parked :: SurfaceAppearance?
end

local function paintMesh(part: BasePart, key: string, color: Color3?)
	local stock = part:FindFirstChild("LiveryStock")
	if not color then
		if not stock then
			return
		end
		local dry, wet = detach(part)
		if dry then
			dry:Destroy()
		end
		if wet then
			wet:Destroy()
		end
		install(
			part,
			stock:FindFirstChild("Dry") :: SurfaceAppearance?,
			stock:FindFirstChild("Wet") :: SurfaceAppearance?
		)
		stock:Destroy()
		return
	end
	local dryT, wetT = template(key, "Dry"), template(key, "Wet")
	if not dryT then
		return
	end
	local dry, wet = detach(part)
	if stock then
		-- already painted: drop the previous livery copies
		if dry then
			dry:Destroy()
		end
		if wet then
			wet:Destroy()
		end
	else
		local s = Instance.new("Configuration")
		s.Name = "LiveryStock"
		if dry then
			dry.Name = "Dry"
			dry.Parent = s
		end
		if wet then
			wet.Name = "Wet"
			wet.Parent = s
		end
		s.Parent = part
	end
	-- TintMask: with no ColorMap the Color is the albedo (Overlay renders the map-less set white)
	local newDry = dryT:Clone()
	newDry.AlphaMode = Enum.AlphaMode.TintMask
	newDry.Color = color
	local newWet: SurfaceAppearance? = nil
	if wetT then
		local w = wetT:Clone()
		w.AlphaMode = Enum.AlphaMode.TintMask
		w.Color = LiveryPaint.wet(color)
		newWet = w
	end
	install(part, newDry, newWet)
end

local function paintPart(part: BasePart, color: Color3?, metallic: boolean, isCar: boolean)
	local stockColor = part:GetAttribute("LiveryStockColor")
	if not color then
		if typeof(stockColor) == "Color3" then
			part.Color = stockColor
			part.Reflectance = (part:GetAttribute("LiveryStockReflectance") :: number?) or 0
			part:SetAttribute("LiveryStockColor", nil)
			part:SetAttribute("LiveryStockReflectance", nil)
		end
		return
	end
	if typeof(stockColor) ~= "Color3" then
		part:SetAttribute("LiveryStockColor", part.Color)
		part:SetAttribute("LiveryStockReflectance", part.Reflectance)
	end
	part.Color = color
	local base = (part:GetAttribute("LiveryStockReflectance") :: number?) or 0
	part.Reflectance = if metallic and isCar then math.max(base, METALLIC_REFLECTANCE) else base
end

-- Repaints one vehicle model in a livery option id (unknown or "Standard" = stock).
function Liveries.apply(model: Model, id: string?)
	if LiveryPaint.SKIP_VEHICLES[model:GetAttribute("VehicleId") :: any] then
		return
	end
	local option = if id then Cosmetics.option(SLOT, id) else nil
	local painting = LiveryPaint.paints(option)
	local metallic = painting and option.metallic == true
	local isCar = model:GetAttribute("LandVehicle") ~= nil
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if d:IsA("MeshPart") then
			local rule = LiveryPaint.meshRule(d.Name)
			local key = LiveryPaint.setKey(d.Name)
			if rule and key then
				paintMesh(d, key, if painting then LiveryPaint.colorFor(option, rule.role) else nil)
				continue
			end
		end
		local role = LiveryPaint.attrRole(d:GetAttribute("Paint"))
		if role then
			paintPart(
				d,
				if painting then LiveryPaint.colorFor(option, role) else nil,
				metallic,
				isCar
			)
		end
	end
	model:SetAttribute("Livery", if painting then id else nil)
end

local function track(player: Player, model: Model)
	local set = vehicles[player]
	if not set then
		set = {}
		vehicles[player] = set
	end
	set[model] = true
	model.Destroying:Connect(function()
		local s = vehicles[player]
		if s then
			s[model] = nil
		end
	end)
	local id = service.Equipped(player, SLOT)
	Liveries.apply(model, id)
	-- visuals may still be welding in on the spawn frame: paint once more after it
	task.defer(function()
		if model.Parent then
			Liveries.apply(model, service.Equipped(player, SLOT))
		end
	end)
end

function Liveries.Init(s: any)
	service = s
end

function Liveries.Start()
	service.VehicleSpawned:Connect(function(player: Player, model: Model, _kind: string?)
		if player and model then
			track(player, model)
		end
	end)
	service.Changed:Connect(function(player: Player, slot: string, id: string)
		if slot ~= SLOT then
			return
		end
		for model in vehicles[player] or {} do
			if model.Parent then
				Liveries.apply(model, id)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		vehicles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		local model = service.VehicleOf(player)
		if model then
			track(player, model)
		end
	end
end

return Liveries
