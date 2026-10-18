--!strict
-- NpcFactory: builds a human NPC as a standard Roblox R15 character from a HumanoidDescription
-- (docs/12 section 2.9). Outfits come from Shared/Config/NpcOutfits; storms swap in the wet-weather
-- layer automatically. Server only.
--
--   NpcFactory.build(role, opts) -> (Model?, rootHeight)   YIELDS while the catalog assets load.
--     Returns nil when creation fails (the caller keeps or builds its greybox). rootHeight is the
--     distance from the feet to the HumanoidRootPart centre, for placing the rig on a deck or quay.
--   NpcFactory.greybox(role, opts) -> (Model, rootHeight)  never yields: the block-person fallback.
--   NpcFactory.spawn(role, opts) -> (Model, rootHeight)    build, else greybox.
--
-- The rig is inert scenery: HumanoidRootPart anchored (opts.anchored ~= false), every part
-- non-colliding, massless and untouchable, no state machine, no name or health bar, tagged
-- NpcFactory.TAG with attribute NpcRole. opts.pose plays a stock Roblox R15 animation on the
-- server Animator (replicates to clients): "Idle", "Wave", "Sit", "Tread" or nil for none.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcOutfits = require(Shared:WaitForChild("Config"):WaitForChild("NpcOutfits"))
local Weather: any = (function()
	local ok, m = pcall(require, Shared:WaitForChild("Weather"))
	return if ok then m else nil
end)()

local NpcFactory = {}
NpcFactory.TAG = "NpcCharacter"

export type Options = {
	seed: number?,
	storm: boolean?, -- nil = from the live weather (Warning / Storm)
	pose: string?,
	name: string?,
	anchored: boolean?,
	cframe: CFrame?, -- where the feet go (pivot of the rig at its feet), facing -Z
	parent: Instance?,
}

-- Stock Roblox R15 animations (the default Animate script's ids).
local POSES = {
	Idle = "rbxassetid://507766666",
	Wave = "rbxassetid://507770239",
	Sit = "rbxassetid://2506281703",
	Tread = "rbxassetid://481825862", -- swim idle
}

local function stormNow(opts: Options): boolean
	if opts.storm ~= nil then
		return opts.storm
	end
	local ok, state = pcall(function()
		return Weather and Weather.getState()
	end)
	return ok and (state == "Storm" or state == "Warning")
end

local function idList(ids: { number }): string
	local out = {}
	for _, id in ids do
		table.insert(out, tostring(id))
	end
	return table.concat(out, ",")
end

-- HumanoidDescription for an outfit. `rigidOnly` drops layered clothing (retry when a layer fails).
function NpcFactory.describe(outfit: NpcOutfits.Outfit, rigidOnly: boolean?): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = Color3.fromHex(outfit.skin or NpcOutfits.SKIN_TONES[2])
	d.HeadColor, d.TorsoColor = skin, skin
	d.LeftArmColor, d.RightArmColor = skin, skin
	d.LeftLegColor, d.RightLegColor = skin, skin
	local s = outfit.scale
	if s then
		d.HeightScale, d.WidthScale, d.DepthScale = s.height, s.width, s.depth
		d.HeadScale, d.BodyTypeScale, d.ProportionScale = s.head, s.bodyType, s.proportion
	end
	d.Face = outfit.face or 0
	d.Shirt = outfit.shirt or 0
	d.Pants = outfit.pants or 0
	d.HairAccessory = idList(outfit.hair)
	d.HatAccessory = idList(outfit.hat)
	d.FrontAccessory = idList(outfit.front)
	d.WaistAccessory = idList(outfit.waist)
	d.BackAccessory = idList(outfit.back)
	if not rigidOnly and #outfit.layers > 0 then
		local layered = {}
		for i, l in outfit.layers do
			local kind = (Enum.AccessoryType :: any)[l.kind]
			if kind then
				table.insert(
					layered,
					{ AssetId = l.id, AccessoryType = kind, IsLayered = true, Order = i }
				)
			end
		end
		pcall(function()
			d:SetAccessories(layered, false)
		end)
	end
	return d
end

local function rootHeightOf(model: Model): number
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	return (if hum then hum.HipHeight else 2)
		+ (if root and root:IsA("BasePart") then root.Size.Y / 2 else 1)
end

local function finish(model: Model, role: string, opts: Options): (Model, number)
	model.Name = opts.name or role
	model:SetAttribute("NpcRole", role)
	CollectionService:AddTag(model, NpcFactory.TAG)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = (d == root) and opts.anchored ~= false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- no Animate / Health scripts on scenery
		end
	end
	if root then
		model.PrimaryPart = root
	end
	local height = rootHeightOf(model)
	if opts.cframe and root then
		model:PivotTo(opts.cframe * CFrame.new(0, height, 0))
	end
	model.Parent = opts.parent
	return model, height
end

local function playPose(model: Model, pose: string?)
	local id = pose and (POSES :: any)[pose]
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (id and hum) then
		return
	end
	local animator: Animator? = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	pcall(function()
		local track = (animator :: Animator):LoadAnimation(anim)
		track.Looped = true
		track:Play(0.2)
	end)
end

-- Yields. nil when Roblox cannot build the character (asset or service failure).
function NpcFactory.build(role: string, opts: Options?): (Model?, number)
	local o: Options = opts or {}
	local outfit = NpcOutfits.pick(role, o.seed or math.random(1, 1e6), stormNow(o))
	local model: Model? = nil
	for _, rigidOnly in { false, true } do
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(
				NpcFactory.describe(outfit, rigidOnly),
				Enum.HumanoidRigType.R15
			)
		end)
		if ok and result then
			model = result
			break
		end
		warn(`[NpcFactory] {outfit.name}: R15 build failed ({result})`)
	end
	if not model then
		return nil, 0
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.NameDisplayDistance = 0
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.EvaluateStateMachine = false
	end
	model:SetAttribute("Outfit", outfit.name)
	local m, h = finish(model, role, o)
	playPose(m, o.pose)
	return m, h
end

-- The block-person fallback (feet at the pivot), coloured from the outfit's skin tone.
function NpcFactory.greybox(role: string, opts: Options?): (Model, number)
	local o: Options = opts or {}
	local outfit = NpcOutfits.pick(role, o.seed or math.random(1, 1e6), false)
	local skin = Color3.fromHex(outfit.skin or NpcOutfits.SKIN_TONES[2])
	local model = Instance.new("Model")
	local function part(name: string, size: Vector3, y: number, x: number, color: Color3): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(x, y, 0)
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), 3, 0, skin)
	root.Transparency = 1
	part("Torso", Vector3.new(2, 2, 1), 3.8, 0, Color3.fromRGB(30, 40, 70))
	part("Head", Vector3.new(1.2, 1.2, 1.2), 5.4, 0, skin)
	for side = -1, 1, 2 do
		part("Leg", Vector3.new(0.8, 2.8, 0.8), 1.4, side * 0.5, Color3.fromRGB(30, 30, 40))
		part("Arm", Vector3.new(0.6, 2, 0.6), 3.8, side * 1.3, skin)
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, p
			w.Parent = p
		end
	end
	model:SetAttribute("Greybox", true)
	return finish(model, role, o)
end

-- R15 when Roblox can build it, else the greybox. Yields.
function NpcFactory.spawn(role: string, opts: Options?): (Model, number)
	local m, h = NpcFactory.build(role, opts)
	if m then
		return m, h
	end
	return NpcFactory.greybox(role, opts)
end

return NpcFactory
