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
local PetRules = require(Shared:WaitForChild("PetRules"))
local PetSeat = require(Shared:WaitForChild("PetSeat"))
local RingLayout = require(Shared:WaitForChild("Config"):WaitForChild("RingLayout"))
local Wildlife = require(Shared:WaitForChild("Config"):WaitForChild("Wildlife"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))

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
type View = { now: number, pets: { PetRow } }

local PetController = {}
PetController.Priority = 72

local player = Players.LocalPlayer

local stateRemote: RemoteEvent? = nil
local getRemote: RemoteFunction? = nil
local equipRemote: RemoteFunction? = nil

local active: PetRow? = nil
local activeModel: Model? = nil
local petCF: CFrame? = nil
local petYaw = 0
local hopT = 0
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
	elseif name == "Greet" then
		return 0, math.abs(math.sin(p * math.pi)) * 0.5, math.sin(clock * 16) * 0.08
	end
	return 0, 0, 0
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
	stateRemote = if event then event :: RemoteEvent else nil
	getRemote = if get then get :: RemoteFunction else nil
	equipRemote = if equipFn then equipFn :: RemoteFunction else nil
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
