--!strict
-- PetController: the client side of the animal sanctuary (docs/15 section 2, hook H4).
-- Pulls the player's pets (Pet_State / Pet_Get) and, when one is adopted, makes it follow on land
-- (offset behind the player + a ground raycast, a small hop/waddle) or ride on the boat's bow. One
-- active pet at a time. There is no yard (removed 2026-10-22): with no pet out, the first recovered
-- one is adopted automatically (Pet_Equip), never from a list.
--
-- G48: the following pet is a friend, not a prop. Hold its one world glyph to pet it (hearts, a
-- wiggle, its call); with a fish treat in the pocket the same glyph feeds it (bigger spin + hop,
-- one bond pip). It celebrates a finished rescue or an opened crate, greets the player on spawn,
-- naps with "Zz" when the player idles at the station, and sits on the boat bow facing forward.
-- A full bond (five pips) unlocks the code-built life vest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local PetAccessory = require(Shared:WaitForChild("PetAccessory"))
local PetRules = require(Shared:WaitForChild("PetRules"))
local PetSeat = require(Shared:WaitForChild("PetSeat"))
local Wildlife = require(Shared:WaitForChild("Config"):WaitForChild("Wildlife"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))

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
type View = { now: number, treats: number, pets: { PetRow } }

local PET_HEARTS = 5
local HEART_ON = Color3.fromRGB(232, 86, 94)
local HEART_OFF = Color3.fromRGB(72, 62, 62)
local HEART_READY = Color3.fromRGB(255, 120, 128)

local PetController = {}
PetController.Priority = 72

local player = Players.LocalPlayer

local stateRemote: RemoteEvent? = nil
local getRemote: RemoteFunction? = nil
local equipRemote: RemoteFunction? = nil
local treatRemote: RemoteFunction? = nil

local active: PetRow? = nil
local activeModel: Model? = nil
local activeHearts: { TextLabel } = {}
local treats = 0
local petCF: CFrame? = nil
local petYaw = 0
local hopT = 0
local clock = 0
local ring: Model? = nil
local adoptingId: number? = nil
local nextVoice = 0

local petSpot: Part? = nil
local petPrompt: ProximityPrompt? = nil
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

local RING_COLOUR = Color3.fromRGB(255, 232, 180)
local RING_RADIUS = 3.2
local RING_PARTS = 20
local PROMPT_RANGE = 7
local STATION_RANGE = 70 -- studs from the sanctuary centre: "at the station"

local function clearRing()
	local old = ring
	ring = nil
	if old then
		old:Destroy()
	end
end

local function ensureRing(): Model
	local existing = ring
	if existing and existing.Parent then
		return existing
	end
	local model = Instance.new("Model")
	model.Name = "PetRing"
	for i = 0, RING_PARTS - 1 do
		local theta = i / RING_PARTS * math.pi * 2
		local part = Instance.new("Part")
		part.Name = "Ring"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = RING_COLOUR
		part.Transparency = 0.72
		part.Size = Vector3.new(0.3, 0.08, 1.1)
		part.CFrame = CFrame.new(math.cos(theta) * RING_RADIUS, 0, math.sin(theta) * RING_RADIUS)
			* CFrame.Angles(0, -theta, 0)
		part.Parent = model
	end
	model.Parent = Workspace
	ring = model
	return model
end

local function showRing(x: number, y: number, z: number)
	ensureRing():PivotTo(CFrame.new(x, y + 0.06, z))
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
		local heart = Instance.new("TextLabel")
		heart.Name = `Heart{i}`
		heart.AnchorPoint = Vector2.new(0.5, 0.5)
		heart.Position = UDim2.fromOffset(65 + (i - (count + 1) / 2) * 10, 70)
		heart.Size = UDim2.fromOffset(22, 22)
		heart.BackgroundTransparency = 1
		heart.Font = Enum.Font.GothamBold
		heart.TextSize = 22
		heart.TextColor3 = Color3.fromRGB(246, 96, 110)
		heart.Text = "♥"
		heart.Parent = gui
		local rise = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(heart, rise, {
			Position = UDim2.fromOffset(heart.Position.X.Offset, 8),
			TextTransparency = 1,
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

local function trickPose(): (number, number, number)
	local name = trickName
	if not name then
		return 0, 0, 0
	end
	if clock >= trickUntil then
		trickName = nil
		return 0, 0, 0
	end
	local p = math.clamp((clock - trickStart) / math.max(0.01, trickUntil - trickStart), 0, 1)
	if name == "Celebrate" then
		return math.pi * 4 * p, math.sin(p * math.pi) * 1.3, math.sin(clock * 20) * 0.08
	elseif name == "Treat" then
		return math.pi * 2 * p, math.sin(p * math.pi) * 1.2, math.sin(clock * 22) * 0.16
	elseif name == "Pet" then
		return 0, math.abs(math.sin(clock * 14)) * 0.18, math.sin(clock * 20) * 0.14
	elseif name == "Greet" then
		return 0, math.abs(math.sin(p * math.pi)) * 0.5, math.sin(clock * 16) * 0.08
	end
	return 0, 0, 0
end

local function refreshPrompt()
	local prompt = petPrompt
	if not prompt then
		return
	end
	local pet = active
	prompt.Enabled = pet ~= nil and activeModel ~= nil
	if not pet then
		return
	end
	prompt.ObjectText = pet.label
	prompt.ActionText = if treats > 0
			and (pet.bond or 0) < (pet.bondMax or PetRules.BOND_MAX)
		then "Treat"
		else "Pet"
end

local function petAction()
	local pet = active
	local model = activeModel
	if not (pet and model) then
		return
	end
	local feeding = treats > 0 and (pet.bond or 0) < (pet.bondMax or PetRules.BOND_MAX)
	if feeding then
		treats -= 1
		startTrick("Treat", 1.5)
		heartBurst(model, 6)
		playVoice(pet.species, model:GetPivot().Position + Vector3.new(0, 2, 0))
		local remote = treatRemote
		if remote then
			task.spawn(function()
				local ok, allowed = pcall(function()
					return (remote :: RemoteFunction):InvokeServer(pet.id)
				end)
				if not ok or allowed ~= true then
					treats += 1 -- rejected: the pocket did not lose it
					refreshPrompt()
				end
			end)
		end
	else
		startTrick("Pet", 1.0)
		heartBurst(model, 3)
		playVoice(pet.species, model:GetPivot().Position + Vector3.new(0, 2, 0))
		Telemetry.once("PetPetted") -- G64: the hold-to-pet action was used
	end
	refreshPrompt()
end

local function buildPrompt()
	local spot = Instance.new("Part")
	spot.Name = "PetSpot"
	spot.Size = Vector3.new(1.2, 1.2, 1.2)
	spot.Transparency = 1
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.CastShadow = false
	spot.Parent = Workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetPrompt"
	prompt.ActionText = "Pet"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = spot
	prompt.Triggered:Connect(petAction)
	petSpot = spot
	petPrompt = prompt
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

-- the five-heart bond meter over the active pet
local function hearts(model: Model): { TextLabel }
	local root = model.PrimaryPart
	local out = {}
	if not root then
		return out
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetHearts"
	billboard.Size = UDim2.fromOffset(112, 24)
	billboard.StudsOffset = Vector3.new(0, WildlifeRig.height(model) + 0.7, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = root
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = billboard
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = row
	for i = 1, PET_HEARTS do
		local heart = Instance.new("TextLabel")
		heart.Name = `Heart{i}`
		heart.LayoutOrder = i
		heart.Size = UDim2.fromOffset(20, 20)
		heart.BackgroundTransparency = 1
		heart.Font = Enum.Font.GothamBold
		heart.TextSize = 18
		heart.TextColor3 = HEART_OFF
		heart.Text = "♥"
		heart.Parent = row
		table.insert(out, heart)
	end
	return out
end

local function setHearts(list: { TextLabel }, filled: number, full: boolean)
	local count = math.clamp(math.floor(filled + 0.5), 0, PET_HEARTS)
	for i, heart in list do
		heart.TextColor3 = if full then HEART_READY elseif i <= count then HEART_ON else HEART_OFF
	end
end

local function pipCount(ready: boolean, progress: number, bond: number): number
	if ready then
		return math.clamp(bond, 0, PET_HEARTS)
	end
	return math.ceil(math.clamp(progress, 0, 1) * PET_HEARTS)
end

local function applyView(next: View)
	if type(next) ~= "table" or type(next.pets) ~= "table" then
		return
	end
	treats = tonumber(next.treats) or 0
	local during: PetRow? = nil
	local recovered: PetRow? = nil
	for _, row in next.pets do
		if row.active then
			during = row
		elseif row.ready and not recovered then
			recovered = row
		end
	end
	if not during and recovered and adoptingId == nil then
		task.spawn(equip, recovered.id)
	end
	local previous = active
	local changed = previous == nil
		or during == nil
		or during.id ~= previous.id
		or during.species ~= previous.species
		or during.rare ~= previous.rare
	if changed then
		if activeModel then
			activeModel:Destroy()
			activeModel = nil
		end
		activeHearts = {}
		clearRing()
		clearZz()
		petCF = nil
		trickName = nil
		if during then
			local model = WildlifeRig.build(during.species, during.rare)
			activeModel = model
			if model then
				WildlifeRig.scale(model, PetSeat.scaleFor(during.species))
				if during.accessory then
					PetAccessory.wear(model)
				end
				model.Parent = Workspace
				activeHearts = hearts(model)
				if adoptingId == during.id then
					adoptingId = nil
					playVoice(during.species, model:GetPivot().Position + Vector3.new(0, 2, 0))
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
		setHearts(
			activeHearts,
			pipCount(during.ready, during.progress, during.bond),
			during.accessory ~= nil
		)
	end
	refreshPrompt()
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

local function groundY(x: number, z: number): number
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
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else 0
end

local function stepBoat()
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
	-- land vehicles have no deck seat: the pet rides on the rear of the roof / load bed
	if vehicle:GetAttribute("LandVehicle") == true then
		local box, size = vehicle:GetBoundingBox()
		local base = box * PetSeat.landSeat(size)
		petCF = base
		petYaw = yawOf(box)
		local spin, lift, roll = trickPose()
		local cf = base * CFrame.new(0, lift, 0) * CFrame.Angles(0, spin, roll)
		WildlifeRig.setCFrame(boat, cf)
		showRing(cf.Position.X, cf.Position.Y, cf.Position.Z)
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
	local spin, lift, roll = trickPose()
	local cf = anchor.WorldCFrame
		* CFrame.new(offset)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.new(0, bob + lift, 0)
		* CFrame.Angles(0, spin, roll)
	petCF = cf
	petYaw = yawOf(cf)
	WildlifeRig.setCFrame(boat, cf)
	showRing(cf.Position.X, cf.Position.Y, cf.Position.Z)
end

local function stepLand(dt: number)
	local boat = activeModel
	if not (boat and active) then
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

	if napping and petCF then
		local cf = petCF :: CFrame
		local shown = CFrame.new(cf.Position + Vector3.new(0, math.sin(clock * 1.3) * 0.06, 0))
			* CFrame.Angles(0, petYaw, math.sin(clock * 1.1) * 0.05)
		WildlifeRig.setCFrame(boat, shown)
		showRing(cf.Position.X, cf.Position.Y, cf.Position.Z)
		return
	end

	local at = root.CFrame * CFrame.new(-Wildlife.Follow.side, 0, Wildlife.Follow.behind)
	local target = Vector3.new(at.X, groundY(at.X, at.Z), at.Z)
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming or root.Position.Y < 1 then
		target = Vector3.new(target.X, math.max(target.Y, 0), target.Z)
	end

	local current = petCF
	if not current or (target - current.Position).Magnitude > Wildlife.Follow.snap then
		petYaw = yawOf(root.CFrame)
		local snapped = CFrame.new(target) * CFrame.Angles(0, petYaw, 0)
		petCF = snapped
		hopT = 0
		local spin, lift, roll = trickPose()
		WildlifeRig.setCFrame(boat, snapped * CFrame.new(0, lift, 0) * CFrame.Angles(0, spin, roll))
		showRing(snapped.Position.X, snapped.Position.Y, snapped.Position.Z)
		return
	end
	local delta = target - current.Position
	local alpha = 1 - math.exp(-dt * Wildlife.Follow.speed)
	if delta.Magnitude > 0.02 then
		petYaw += shortest(petYaw, math.atan2(-delta.X, -delta.Z)) * alpha
	end
	local pos = current.Position:Lerp(target, alpha)
	hopT += dt
	local hop = if delta.Magnitude > 0.02
		then math.abs(math.sin(hopT * 7)) * Wildlife.Follow.hop
		else 0
	local walked = CFrame.new(pos + Vector3.new(0, hop, 0))
		* CFrame.Angles(0, petYaw, math.sin(hopT * 9) * 0.06)
	petCF = walked
	local spin, lift, roll = trickPose()
	WildlifeRig.setCFrame(boat, walked * CFrame.new(0, lift, 0) * CFrame.Angles(0, spin, roll))
	showRing(pos.X, pos.Y, pos.Z)
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
	local atStation = (root.Position - Wildlife.Sanctuary.position).Magnitude <= STATION_RANGE
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

function PetController.Init()
	local net = ReplicatedStorage:WaitForChild("Net", 30)
	if not net then
		return
	end
	local event = awaitChild(net, "Pet_State", "RemoteEvent")
	local get = awaitChild(net, "Pet_Get", "RemoteFunction")
	local equipFn = awaitChild(net, "Pet_Equip", "RemoteFunction")
	local treatFn = awaitChild(net, "Pet_Treat", "RemoteFunction")
	stateRemote = if event then event :: RemoteEvent else nil
	getRemote = if get then get :: RemoteFunction else nil
	equipRemote = if equipFn then equipFn :: RemoteFunction else nil
	treatRemote = if treatFn then treatFn :: RemoteFunction else nil
	if stateRemote then
		stateRemote.OnClientEvent:Connect(applyView)
	end
end

function PetController.Start()
	buildPrompt()
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
		local prompt = petPrompt
		local spot = petSpot
		if prompt and spot then
			spot.CFrame = CFrame.new(
				model:GetPivot().Position + Vector3.new(0, WildlifeRig.height(model) + 0.8, 0)
			)
			refreshPrompt()
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
			stepBoat()
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
