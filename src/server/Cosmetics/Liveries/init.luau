--!strict
-- Liveries (RP-M5 E1, server cosmetic feature; auto-loaded by CosmeticsService): repaints every
-- vehicle a player spawns (RIB, jet ski, the bigger boats) in their equipped
-- "Livery" option (src/shared/Config/Cosmetics/Livery.luau), and repaints them again when the
-- choice changes. "Standard" restores the stock paint. No new uploads:
--   * uploaded MeshParts (LiveryPaint.MESH_RULES): the stock SurfaceAppearances (dry and wet) are
--     parked in a Configuration "LiveryStock" on the part and replaced by map-only copies of the
--     same texture set (script.Appearances, built by Rojo: normal + roughness + metalness, no
--     ColorMap) with AlphaMode TintMask and Color = the livery colour (verified in Studio: Overlay
--     without a ColorMap renders white, TintMask renders the Color). The AssetLoader wet swap (SurfaceVariants /
--     WetState) keeps working because the same names are used; wet uses LiveryPaint.wet(colour).
--   * greybox Parts with a "Paint" attribute (Boat/Builder): Color is set; the stock
--     colour is kept in the attribute "LiveryStockColor".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local LiveryPaint = require(Shared:WaitForChild("LiveryPaint"))
local LiveryPattern = require(Shared:WaitForChild("LiveryPattern"))

local SLOT = "Livery"
local TRIM_NAME = "CosmeticLiveryTrim"
local AURA_NAME = "CosmeticRarityAura"
local AURA_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
local AURA_COLOR = {
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(165, 100, 255),
	Legendary = Color3.fromRGB(255, 196, 50),
	Mythic = Color3.fromRGB(255, 120, 230),
}

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
			local made = Instance.new("Configuration")
			made.Name = "SurfaceVariants"
			made.Parent = part
			variants = made
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

-- G38: the code-made trim (band / twin / stripes / chevron / glow) welded to the hull sides, the
-- tubes and the deck sole. The uploaded meshes only take flat tints, so this is what carries the
-- scheme at 30-60 studs. Both hull sides and the deck are planned per pattern.
local function band(parent: Model, anchor: BasePart, spec: any, color: Color3, glow: boolean)
	local p = Instance.new("Part")
	p.Name = "LiveryTrim"
	p.Size = spec.size
	p.CFrame = anchor.CFrame * CFrame.new(spec.offset) * CFrame.Angles(0, spec.yaw, 0)
	p.Color = color
	p.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
end

local function trim(model: Model, option: any, hull: BasePart?, tubes: BasePart?)
	local old = model:FindFirstChild(TRIM_NAME)
	if old then
		old:Destroy()
	end
	if not option or not LiveryPattern.known(option.pattern) then
		return
	end
	local color = LiveryPaint.colorFor(option, "stripe")
	if not color then
		return
	end
	local glowColor = typeof(option.glow) == "Color3" and option.glow or color
	local trimModel = Instance.new("Model")
	trimModel.Name = TRIM_NAME
	local function lay(anchor: BasePart, surface: string)
		for _, spec in LiveryPattern.plan(option.pattern, surface, anchor.Size) do
			band(trimModel, anchor, spec, if spec.glow then glowColor else color, spec.glow)
		end
	end
	if hull then
		lay(hull, "hull")
		lay(hull, "deck") -- the hull bbox top is the deck sole
	end
	if tubes and tubes ~= hull then
		lay(tubes, "tube")
	end
	trimModel.Parent = model
end

local function paintPart(part: BasePart, color: Color3?)
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
end

-- A subtle rarity aura for a Rare+ spin finish / wake, so other players notice it on the water.
local function rarityOf(option: any): string?
	if type(option) ~= "table" or type(option.rarity) ~= "string" then
		return nil
	end
	local rank = AURA_ORDER[option.rarity]
	return if rank and rank >= AURA_ORDER.Rare then option.rarity else nil
end

local function aura(model: Model, liveryId: string?, wakeId: string?)
	local old = model:FindFirstChild(AURA_NAME)
	if old then
		old:Destroy()
	end
	local best: string? = nil
	for _, pair in { { slot = "Livery", id = liveryId }, { slot = "Wake", id = wakeId } } do
		local option = if pair.id then Cosmetics.option(pair.slot, pair.id) else nil
		local rarity = rarityOf(option)
		if rarity and (best == nil or AURA_ORDER[rarity] > AURA_ORDER[best]) then
			best = rarity
		end
	end
	local color = if best then AURA_COLOR[best] else nil
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not color or not body then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = AURA_NAME
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 2.5
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.16)
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = body
end

-- Repaints one vehicle model in a livery option id (unknown or "Standard" = stock).
function Liveries.apply(model: Model, id: string?, wakeId: string?)
	local option = if id then Cosmetics.option(SLOT, id) else nil
	local painting = LiveryPaint.paints(option)
	local primary: BasePart? = nil
	local secondary: BasePart? = nil
	local tubes: BasePart? = nil
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if d:IsA("MeshPart") then
			local rule = LiveryPaint.meshRule(d.Name)
			local key = LiveryPaint.setKey(d.Name)
			if rule and key then
				if rule.role == "primary" and not primary then
					primary = d
				elseif rule.role == "secondary" and not secondary then
					secondary = d
				end
				local _, token = LiveryPaint.parseName(d.Name)
				if token == "Tubes" then
					tubes = d
				end
				paintMesh(
					d,
					key,
					if painting then LiveryPaint.colorFor(option, rule.role :: any) else nil
				)
				continue
			end
		end
		local role = LiveryPaint.attrRole(d:GetAttribute("Paint"))
		if role then
			paintPart(d, if painting then LiveryPaint.colorFor(option, role :: any) else nil)
		end
	end
	model:SetAttribute("Livery", if painting then id else nil)
	-- the RIB's primary is the tube pair: its hull / deck trim goes on the GRP hull below.
	-- The jet ski's primary is the whole hull, and its secondary sled sits under the water.
	local hullAnchor = if tubes then (secondary or primary) else primary
	trim(model, if painting then option else nil, hullAnchor, tubes)
	aura(model, if painting then id else nil, wakeId)
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
	Liveries.apply(model, service.Equipped(player, SLOT), service.Equipped(player, "Wake"))
	-- visuals may still be welding in on the spawn frame: paint once more after it
	task.defer(function()
		if model.Parent then
			Liveries.apply(model, service.Equipped(player, SLOT), service.Equipped(player, "Wake"))
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
	service.Changed:Connect(function(player: Player, slot: string, _id: string)
		if slot ~= SLOT and slot ~= "Wake" then
			return
		end
		for model in (vehicles[player] or {}) :: { [Model]: boolean } do
			if model.Parent then
				Liveries.apply(
					model,
					service.Equipped(player, SLOT),
					service.Equipped(player, "Wake")
				)
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
