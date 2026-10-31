--!strict
-- PetController: the client side of the animal sanctuary (docs/15 section 2, hook H4).
-- Pulls the player's pets (Pet_State / Pet_Get) and, when one is adopted, makes it follow on land
-- (offset behind the player + a ground raycast, a small hop/waddle) or ride on the boat's bow. One
-- companion at a time (owner, 2026-10-24): Bosun or one pet. A newly recovered pet (never adopted)
-- becomes the companion automatically (Pet_Equip); switching back lives in the Pet panel (UI/Panels/Companion:
-- PetController.view / choose / onChange, id 0 = Bosun). DogController draws the pet's guide
-- point via PetController.companion / voice.
--
-- G48: the following pet is a friend, not a prop. It celebrates a finished rescue or an opened
-- crate, greets the player on spawn, naps with "Zz" when the player idles at the station, and sits
-- on the boat bow facing forward. A saved full bond still wears the code-built life vest. Petting,
-- fish treats and the bond-heart meter were removed (owner, 2026-10-24).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local PetAccessory = require(Shared:WaitForChild("PetAccessory"))
local PetMotion = require(Shared:WaitForChild("PetMotion"))
local PetRules = require(Shared:WaitForChild("PetRules"))
local PetSeat = require(Shared:WaitForChild("PetSeat"))
local RingLayout = require(Shared:WaitForChild("Config"):WaitForChild("RingLayout"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local Wildlife = require(Shared:WaitForChild("Config"):WaitForChild("Wildlife"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

type PetRow = {
	id: number,
	species: string,
	rare: boolean,
	label: string,
	ready: boolean,
	progress: number,
	remaining: number,
	active: boolean,
	bond: number,
	bondMax: number,
	adopted: boolean,
	accessory: string?,
}
type View = { now: number, variant: string?, variants: { string }, pets: { PetRow } }

local PetController = {}
PetController.Priority = 72

local player = Players.LocalPlayer

local stateRemote: RemoteEvent? = nil
local getRemote: RemoteFunction? = nil
local equipRemote: RemoteFunction? = nil
local variantRemote: RemoteFunction? = nil

local active: PetRow? = nil
local activeModel: Model? = nil
local activeVariant: string? = nil
local petCF: CFrame? = nil
local petYaw = 0
local motion: PetMotion.State? = nil
local petScale = 1
local velocity = Vector3.zero
local followYaw = 0
local stuck = 0
local clock = 0
local adoptingId: number? = nil
local nextVoice = 0
local lastView: View? = nil
local changedEvent = Instance.new("BindableEvent")

local trickName: string? = nil
local trickStart = 0
local trickUntil = 0
local napping = false
local idleSeconds = 0
local zz: BillboardGui? = nil
local riding = false
local seatVehicle: Model? = nil
local seatAnchor: Attachment? = nil
local seatOffset = Vector3.zero
local seatYaw = 0

local VOICE: { [string]: string } = {
	SealPup = "Pet_Seal",
	Puffin = "Pet_Puffin",
	Otter = "Pet_Otter",
	Gull = "Pet_Gull",
	Turtle = "Pet_Turtle",
}

local STATION_RANGE = 70 -- studs from your island's station lot: "at the station"
local PERSONAL = 2.4 -- studs: the pet never walks into the player
local STUCK_SECONDS = 2 -- behind a wall while the player walks off: pop back to the slot

-- Spin-wheel variants (docs/24 D). Every variant is Rare+, so the model also gets a small rarity
-- aura; Galaxy adds its own sparkle ring. Rainbow repaints from the heartbeat.
local VARIANT_STYLE = {
	Golden = {
		color = Color3.fromRGB(255, 198, 64),
		material = Enum.Material.Metal,
		aura = Color3.fromRGB(255, 214, 100),
	},
	Neon = {
		color = Color3.fromRGB(70, 255, 220),
		material = Enum.Material.Neon,
		aura = Color3.fromRGB(90, 255, 230),
	},
	Rainbow = {
		color = Color3.fromRGB(255, 90, 190),
		material = Enum.Material.Neon,
		aura = Color3.fromRGB(255, 120, 220),
	},
	Galaxy = {
		color = Color3.fromRGB(46, 32, 84),
		material = Enum.Material.SmoothPlastic,
		aura = Color3.fromRGB(170, 140, 255),
	},
}
local rainbowParts: { BasePart } = {}

local function tintSurface(part: BasePart, color: Color3)
	local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if appearance then
		appearance.Color = color
	end
end

local function paintRarity(model: Model, color: Color3, galaxy: boolean)
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not body then
		return
	end
	local old = model:FindFirstChild("PetRarityAura")
	if old then
		old:Destroy()
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "PetRarityAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Rate = if galaxy then 7 else 3
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Speed = NumberRange.new(0.8, 1.8)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new(if galaxy then 0.22 else 0.14)
	aura.Color = ColorSequence.new(color)
	aura.LightEmission = 0.5
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.Parent = body
end

local function applyVariant(model: Model, variant: string?)
	model:SetAttribute("PetVariant", variant)
	table.clear(rainbowParts)
	local style: any = if variant then VARIANT_STYLE[variant] else nil
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if not style then
			continue
		end
		d.Material = style.material
		d.Color = style.color
		tintSurface(d, style.color)
		d.Reflectance = if variant == "Golden" then 0.15 else 0
		if variant == "Rainbow" then
			table.insert(rainbowParts, d)
		end
	end
	if style then
		paintRarity(model, style.aura, variant == "Galaxy")
	end
end

local function cycleRainbow()
	if #rainbowParts == 0 then
		return
	end
	local hue = (clock * 0.12) % 1
	for i, part in rainbowParts do
		local c = Color3.fromHSV((hue + i * 0.03) % 1, 0.75, 1)
		part.Color = c
		tintSurface(part, c)
	end
end

local function awaitChild(parent: Instance, name: string, class: string): Instance?
	local child = parent:WaitForChild(name, 30)
	return if child and child.ClassName == class then child else nil
end

local function playVoice(species: string, at: Vector3)
	local clip = VOICE[species]
	if clip then
		AudioController.play(clip, at, 1, 1)
	end
end

local function heartBurst(model: Model, count: number)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetHeartsFx"
	gui.Size = UDim2.fromOffset(130, 92)
	gui.StudsOffset = Vector3.new(0, WildlifeRig.height(model) + 0.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = body
	for i = 1, count do
		local heart = Instance.new("ImageLabel")
		heart.Name = `Heart{i}`
		heart.AnchorPoint = Vector2.new(0.5, 0.5)
		heart.Position = UDim2.fromOffset(65 + (i - (count + 1) / 2) * 34, 70 + (i % 2) * 12) -- staggered, apart
		heart.Size = UDim2.fromOffset(40, 40)
		heart.BackgroundTransparency = 1
		heart.Image = UiImages.Badges.Heart
		heart.ScaleType = Enum.ScaleType.Fit
		heart.Parent = gui
		local rise = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(heart, rise, {
			Position = UDim2.fromOffset(heart.Position.X.Offset, 16),
			ImageTransparency = 1,
		}):Play()
	end
	task.delay(1.4, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function clearZz()
	local old = zz
	zz = nil
	if old then
		old:Destroy()
	end
end

local function ensureZz(model: Model)
	if zz and zz.Parent then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetZz"
	gui.Size = UDim2.fromOffset(70, 80)
	gui.StudsOffset = Vector3.new(0, WildlifeRig.height(model) + 0.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.Parent = body
	for i = 1, 3 do
		local z = Instance.new("TextLabel")
		z.Name = `Z{i}`
		z.AnchorPoint = Vector2.new(0.5, 0.5)
		z.Position = UDim2.fromOffset(26 + i * 7, 66 - i * 8)
		z.Size = UDim2.fromOffset(18, 18)
		z.BackgroundTransparency = 1
		z.Font = Enum.Font.FredokaOne
		z.TextSize = 20 - i * 3
		z.TextColor3 = Color3.fromRGB(232, 238, 244)
		z.Text = if i == 1 then "Z" else "z"
		z.Parent = gui
		TweenService:Create(
			z,
			TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, i * 0.45),
			{ Position = UDim2.fromOffset(38 + i * 7, 8), TextTransparency = 0.75 }
		):Play()
	end
	zz = gui
end

local function startTrick(name: string?, seconds: number)
	if not name then
		return
	end
	napping = false
	clearZz()
	trickName = name
	trickStart = clock
	trickUntil = clock + seconds
end

-- (cheer, greet): 0..1 through the running trick, for PetMotion
local function trickProgress(): (number?, number?)
	local name = trickName
	if not name then
		return nil, nil
	end
	if clock >= trickUntil then
		trickName = nil
		return nil, nil
	end
	local p = math.clamp((clock - trickStart) / math.max(0.01, trickUntil - trickStart), 0, 1)
	return if name == "Celebrate" then p else nil, if name == "Greet" then p else nil
end

local function equip(id: number)
	local remote = equipRemote
	if not remote then
		return
	end
	adoptingId = id
	pcall(function()
		remote:InvokeServer(id)
	end)
	task.delay(3, function()
		if adoptingId == id then
			adoptingId = nil
		end
	end)
end

local function applyView(next: View)
	if type(next) ~= "table" or type(next.pets) ~= "table" then
		return
	end
	lastView = next
	changedEvent:Fire()
	local during: PetRow? = nil
	local recovered: PetRow? = nil
	for _, row in next.pets do
		if row.active then
			during = row
		elseif row.ready and not row.adopted and not recovered then
			recovered = row -- just recovered: the exciting moment, it comes out at once
		end
	end
	if recovered and adoptingId == nil then
		task.spawn(equip, recovered.id)
	end
	local previous = active
	local variant = next.variant
	local variantChanged = variant ~= activeVariant
	activeVariant = variant
	local changed = previous == nil
		or during == nil
		or during.id ~= previous.id
		or during.species ~= previous.species
		or during.rare ~= previous.rare
		or variantChanged
	if changed then
		if activeModel then
			activeModel:Destroy()
			activeModel = nil
		end
		clearZz()
		petCF = nil
		trickName = nil
		motion = nil
		if during then
			local model = WildlifeRig.build(during.species, during.rare)
			activeModel = model
			motion = PetMotion.new(during.species)
			petScale = PetSeat.scaleFor(during.species)
			if model then
				applyVariant(model, variant)
				WildlifeRig.scale(model, petScale)
				if during.accessory then
					PetAccessory.wear(model)
				end
				model.Parent = Workspace
				if adoptingId == during.id then
					adoptingId = nil
					playVoice(during.species, model:GetPivot().Position + Vector3.new(0, 2, 0))
					local root = player.Character
						and player.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then -- the new friend arrives in a Lego puff by you
						VFXKit.play(
							"buy_pop",
							root.CFrame * CFrame.new(2, -3, -2),
							{ radius = 1.5, height = 4 }
						)
					end
				end
				task.delay(0.8, function()
					if activeModel == model then
						startTrick(PetRules.trickFor("Spawn"), 1.1)
						playVoice(during.species, model:GetPivot().Position + Vector3.new(0, 2, 0))
					end
				end)
			end
			nextVoice = clock
				+ math.random(AudioConfig.Mix.petVoiceMinGap, AudioConfig.Mix.petVoiceMaxGap)
		end
	end
	active = during
	if activeModel and during then
		if during.accessory and activeModel:GetAttribute("PetAccessory") == nil then
			PetAccessory.wear(activeModel)
		end
	end
end

local function vehicleSeat(humanoid: Humanoid): Model?
	local node: Instance? = humanoid.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function yawOf(cf: CFrame): number
	local y, _, _ = cf:ToEulerAnglesYXZ()
	return y
end

local function shortest(a: number, b: number): number
	return math.atan2(math.sin(b - a), math.cos(b - a))
end

local function castParams(): RaycastParams
	local filter = {}
	if player.Character then
		table.insert(filter, player.Character)
	end
	if activeModel then
		table.insert(filter, activeModel)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	return params
end

-- Moves the pet to cf with this frame's PetMotion pose (gait, look, tricks) on its parts.
local function place(
	model: Model,
	cf: CFrame,
	dt: number,
	mode: PetMotion.Mode,
	speed: number,
	lookYaw: number?
)
	local m = motion
	if not m then
		WildlifeRig.setCFrame(model, cf)
		return
	end
	local cheer, greet = trickProgress()
	local pose = PetMotion.step(m, {
		dt = dt,
		speed = speed,
		mode = mode,
		lookYaw = lookYaw,
		cheer = cheer,
		greet = greet,
	})
	local head = model:FindFirstChild("Head")
	local headAt = WildlifeRig.offsetOf(model, "Head")
	local neck = if head
			and head:IsA("BasePart")
			and headAt
		then headAt.Position + Vector3.new(0, -0.35 * head.Size.Y, 0.3 * head.Size.Z)
		else Vector3.zero
	WildlifeRig.setCFrame(model, cf, function(part: BasePart, offset: CFrame): CFrame
		return PetMotion.partDelta(pose, part.Name, offset, part.Size, neck, petScale)
	end)
end

local function stepBoat(dt: number)
	local boat = activeModel
	if not (boat and active) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local vehicle = if humanoid then vehicleSeat(humanoid) else nil
	if not vehicle then
		return
	end
	-- the recursive anchor lookup walks the whole hull: once per boarding, not per frame
	if seatVehicle ~= vehicle then
		seatVehicle = vehicle
		local id = vehicle:GetAttribute("VehicleId")
		local anchorName, offset, yaw = PetSeat.choose(
			if type(id) == "string" then id else vehicle.Name,
			function(name: string): boolean
				return vehicle:FindFirstChild(name, true) ~= nil
			end
		)
		local found = vehicle:FindFirstChild(anchorName, true)
		seatAnchor = if found and found:IsA("Attachment") then found else nil
		seatOffset, seatYaw = offset, yaw
	end
	local anchor = seatAnchor
	local offset, yaw = seatOffset, seatYaw
	if not (anchor and anchor.Parent) then
		seatVehicle = nil -- the hull may still be swapping in: look again next frame
		return
	end
	local bob = math.sin(clock * 1.4) * Wildlife.Boat.bob
	local cf = anchor.WorldCFrame
		* CFrame.new(offset)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.new(0, bob, 0)
	petCF = cf
	petYaw = yawOf(cf)
	place(boat, cf, dt, "ride", 0, math.sin(clock * 0.35) * 0.6) -- watches the sea go by
end

local function stepLand(dt: number)
	local model = activeModel
	if not (model and active) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	if vehicleSeat(humanoid) then
		return -- stepBoat handles it
	end
	local current = petCF
	if napping and current then
		place(model, current, dt, "nap", 0, nil)
		return
	end

	-- the slot behind the player turns with a lag, so a turn on the spot doesn't send the pet racing
	local rootPos = root.Position
	followYaw += shortest(followYaw, yawOf(root.CFrame)) * (1 - math.exp(-dt * 3))
	local slot = rootPos
		+ CFrame.Angles(0, followYaw, 0)
			:VectorToWorldSpace(Vector3.new(-Wildlife.Follow.side, 0, Wildlife.Follow.behind))
	local params = castParams()
	local pos: Vector3
	if
		not current
		or (slot - current.Position).Magnitude > Wildlife.Follow.snap
		or stuck > STUCK_SECONDS
	then
		petYaw = yawOf(root.CFrame)
		followYaw = petYaw
		velocity = Vector3.zero
		stuck = 0
		pos = Vector3.new(slot.X, rootPos.Y - 3, slot.Z)
	else
		pos = current.Position
		local flat = Vector3.new(slot.X - pos.X, 0, slot.Z - pos.Z)
		local dist = flat.Magnitude
		local top = humanoid.WalkSpeed * 1.5 + 4
		-- a small dead zone: settled at the slot it stands still instead of creeping and jittering
		local want = if dist > 0.8
			then flat.Unit * math.min((dist - 0.8) * 2.5, top)
			else Vector3.zero
		velocity = velocity:Lerp(want, 1 - math.exp(-dt * 8))
		local move = velocity * dt
		if move.Magnitude > 1e-3 then
			local wall = Workspace:Raycast(
				pos + Vector3.new(0, 0.8 * petScale, 0),
				move.Unit * (move.Magnitude + 0.7 * petScale),
				params
			)
			if wall and wall.Normal.Y < 0.6 then -- slide along walls, never through them
				local n = Vector3.new(wall.Normal.X, 0, wall.Normal.Z).Unit
				velocity -= n * math.min(0, velocity:Dot(n))
				move = velocity * dt
			end
		end
		pos += move
		local away = Vector3.new(pos.X - rootPos.X, 0, pos.Z - rootPos.Z)
		if away.Magnitude < PERSONAL and away.Magnitude > 1e-3 then
			pos += away.Unit * (PERSONAL - away.Magnitude) * math.min(1, dt * 10)
		end
		stuck = if dist > 10 and velocity.Magnitude < 1 then stuck + dt else 0
	end

	-- ground under the pet itself, cast from just above the player so roofs never catch it
	local sea = WorldConfig.SeaLevel
	local from = math.max(rootPos.Y, pos.Y) + 3
	local hit = Workspace:Raycast(Vector3.new(pos.X, from, pos.Z), Vector3.new(0, -60, 0), params)
	local swimming = not hit or hit.Position.Y < sea - 0.3
	local floorY = if hit and not swimming
		then hit.Position.Y
		else sea - PetMotion.sink(active.species) * WildlifeRig.height(model)
	local y = if current and math.abs(floorY - pos.Y) < 6
		then pos.Y + (floorY - pos.Y) * (1 - math.exp(-dt * 14))
		else floorY
	pos = Vector3.new(pos.X, y, pos.Z)

	local speed = velocity.Magnitude
	local toPlayer = math.atan2(-(rootPos.X - pos.X), -(rootPos.Z - pos.Z))
	if speed > 0.6 then
		petYaw += shortest(petYaw, math.atan2(-velocity.X, -velocity.Z)) * (1 - math.exp(-dt * 10))
	else
		petYaw += shortest(petYaw, toPlayer) * (1 - math.exp(-dt * 1.5))
	end
	local cf = CFrame.new(pos) * CFrame.Angles(0, petYaw, 0)
	petCF = cf
	place(model, cf, dt, if swimming then "swim" else "walk", speed, shortest(petYaw, toPlayer))
end

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function stepIdle(dt: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local root = rootOf()
	if not (root and humanoid) then
		idleSeconds = 0
		napping = false
		clearZz()
		return
	end
	if humanoid.MoveDirection.Magnitude > 0.1 then
		idleSeconds = 0
	else
		idleSeconds += dt
	end
	local plot = player:GetAttribute("DockPlot")
	local isle = if type(plot) == "number" then RingLayout.Islands[plot] else nil
	local atStation = isle ~= nil
		and (root.Position - isle.lots.Station.cframe.Position).Magnitude <= STATION_RANGE
	local busy = trickName ~= nil and clock < trickUntil
	local due = PetRules.napDue(idleSeconds, atStation)
		and vehicleSeat(humanoid) == nil
		and not busy
	napping = due
	local model = activeModel
	if napping and model then
		ensureZz(model)
	elseif not napping then
		clearZz()
	end
end

local function watchMoment(attribute: string, signal: string)
	local last = player:GetAttribute(attribute)
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local value = player:GetAttribute(attribute)
		local old = last
		last = value
		if old == nil or value == nil or value == old then
			return
		end
		if active and activeModel then
			startTrick(PetRules.trickFor(signal), 1.6)
			playVoice(active.species, activeModel:GetPivot().Position + Vector3.new(0, 2, 0))
			heartBurst(activeModel, 2)
		end
	end)
end

-- The Companion panel ---------------------------------------------------------------------------

function PetController.view(): View?
	return lastView
end

-- 0 = Bosun (PetRules.BOSUN), else a recovered pet's id
function PetController.choose(id: number)
	task.spawn(equip, id)
end

-- Wear an owned spin-wheel variant (nil = natural colours; Pet_Variant checks ownership).
function PetController.chooseVariant(id: string?)
	if variantRemote then
		task.spawn(function()
			pcall(function()
				(variantRemote :: RemoteFunction):InvokeServer(id)
			end)
		end)
	end
end

function PetController.onChange(fn: () -> ()): RBXScriptConnection
	return changedEvent.Event:Connect(fn)
end

-- The pet out now (nil while Bosun is the companion), for DogController's guide point.
function PetController.companion(): (Model?, string?)
	return activeModel, if active then active.species else nil
end

function PetController.voice(species: string, at: Vector3)
	playVoice(species, at)
end

function PetController.Init()
	local net = ReplicatedStorage:WaitForChild("Net", 30)
	if not net then
		return
	end
	local event = awaitChild(net, "Pet_State", "RemoteEvent")
	local get = awaitChild(net, "Pet_Get", "RemoteFunction")
	local equipFn = awaitChild(net, "Pet_Equip", "RemoteFunction")
	local variantFn = awaitChild(net, "Pet_Variant", "RemoteFunction")
	stateRemote = if event then event :: RemoteEvent else nil
	getRemote = if get then get :: RemoteFunction else nil
	equipRemote = if equipFn then equipFn :: RemoteFunction else nil
	variantRemote = if variantFn then variantFn :: RemoteFunction else nil
	if stateRemote then
		stateRemote.OnClientEvent:Connect(applyView)
	end
end

function PetController.Start()
	if getRemote then
		task.spawn(function()
			local ok, result = pcall(function()
				return (getRemote :: RemoteFunction):InvokeServer()
			end)
			if ok and type(result) == "table" then
				applyView(result)
			end
		end)
	end
	watchMoment("OpsCompleted", "RescueDone")
	watchMoment("StreakClaim", "CrateOpen")
	player.CharacterAdded:Connect(function()
		idleSeconds = 0
		napping = false
		clearZz()
		task.delay(1.2, function()
			if active and activeModel and not napping then
				startTrick(PetRules.trickFor("Spawn"), 1.1)
				playVoice(active.species, activeModel:GetPivot().Position + Vector3.new(0, 2, 0))
			end
		end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		stepIdle(dt)
		if not active or not activeModel then
			return
		end
		local model = activeModel
		if activeVariant == "Rainbow" then
			cycleRainbow()
		end
		if clock >= nextVoice and not napping then
			nextVoice = clock
				+ math.random(AudioConfig.Mix.petVoiceMinGap, AudioConfig.Mix.petVoiceMaxGap)
			playVoice(active.species, model:GetPivot().Position + Vector3.new(0, 2, 0))
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and vehicleSeat(humanoid) then
			riding = true
			stepBoat(dt)
		else
			if riding then
				riding = false
				petCF = nil -- hop off: snap back to the ground at the player's side
				seatVehicle = nil
			end
			stepLand(dt)
		end
	end)
end

return PetController
