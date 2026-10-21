--!strict
-- PetSanctuary: the small fenced yard beside the station (docs/15 H4), code-built Parts.
-- Built locally by PetController so each player sees their own animals: a pool, rocks, a fence,
-- six pens and a heart meter over every recovering animal. Walking up to a recovered animal shows
-- the in-world Adopt prompt; there is no menu list.
--
-- The yard is client-only and the server checks the same config position for Pet_Equip, so a
-- remote cannot adopt from across the map.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetAccessory = require(Shared:WaitForChild("PetAccessory"))
local PetSeat = require(Shared:WaitForChild("PetSeat"))
local Wildlife = require(Shared:WaitForChild("Config"):WaitForChild("Wildlife"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

export type PetRow = {
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

export type View = { now: number, treats: number, pets: { PetRow } }

export type Pen = {
	index: number,
	base: CFrame,
	marker: Part,
	prompt: ProximityPrompt,
	petId: number?,
}

export type Resident = {
	row: PetRow,
	pen: Pen,
	model: Model,
	hearts: { TextLabel },
	remaining: number,
	phase: number,
}

export type Yard = {
	model: Model,
	pens: { Pen },
	residents: { [number]: Resident },
	setView: (view: View) -> (),
	step: (dt: number) -> (),
}

local PET_HEARTS = 5
local HEART_ON = Color3.fromRGB(232, 86, 94)
local HEART_OFF = Color3.fromRGB(72, 62, 62)
local HEART_READY = Color3.fromRGB(255, 120, 128)

local PetSanctuary = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function groundAt(x: number, z: number): number
	local filter = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(
		Vector3.new(x, Wildlife.Sanctuary.position.Y + 80, z),
		Vector3.new(0, -160, 0),
		params
	)
	-- never sink the yard under the station ground if the map has not streamed in yet
	return math.max(if hit then hit.Position.Y else 0, Wildlife.Sanctuary.position.Y)
end

function PetSanctuary.hearts(model: Model): { TextLabel }
	local root = model.PrimaryPart
	local hearts = {}
	if not root then
		return hearts
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
		table.insert(hearts, heart)
	end
	return hearts
end

function PetSanctuary.setHearts(hearts: { TextLabel }, filled: number, full: boolean)
	local count = math.clamp(math.floor(filled + 0.5), 0, PET_HEARTS)
	for i, heart in hearts do
		heart.TextColor3 = if full then HEART_READY elseif i <= count then HEART_ON else HEART_OFF
	end
end

function PetSanctuary.pipCount(ready: boolean, progress: number, bond: number): number
	if ready then
		return math.clamp(bond, 0, PET_HEARTS)
	end
	return math.ceil(math.clamp(progress, 0, 1) * PET_HEARTS)
end

local function buildFence(yard: Model, base: CFrame, halfX: number, halfZ: number)
	local wood = Color3.fromRGB(128, 92, 56)
	local postHeight = 2.7
	local gap = 2.4
	local function post(x: number, z: number)
		part(
			yard,
			"FencePost",
			Vector3.new(0.38, postHeight, 0.38),
			base * CFrame.new(x, postHeight / 2, z),
			wood,
			Enum.Material.Wood
		)
	end
	for x = -halfX, halfX, 3 do
		if math.abs(x) > gap then
			post(x, halfZ)
		end
		post(x, -halfZ)
	end
	for z = -halfZ + 3, halfZ - 3, 3 do
		post(-halfX, z)
		post(halfX, z)
	end
	for _, side in { -1, 1 } do
		local z = side * halfZ
		local length = if side < 0 then halfX * 2 else halfX - gap
		local at = if side < 0 then 0 else -(halfX + gap) / 2
		for _, y in { 0.85, 1.7 } do
			part(
				yard,
				"FenceRail",
				Vector3.new(length, 0.12, 0.12),
				base * CFrame.new(at, y, z),
				wood,
				Enum.Material.Wood
			)
			if side > 0 then
				part(
					yard,
					"FenceRail",
					Vector3.new(length, 0.12, 0.12),
					base * CFrame.new(-at, y, z),
					wood,
					Enum.Material.Wood
				)
			end
		end
	end
end

local function buildSign(yard: Model, base: CFrame, halfZ: number)
	part(
		yard,
		"SignPost",
		Vector3.new(0.24, 3.6, 0.24),
		base * CFrame.new(-5, 1.8, halfZ + 1.2),
		Color3.fromRGB(98, 68, 44),
		Enum.Material.Wood
	)
	local board = part(
		yard,
		"SignBoard",
		Vector3.new(3.4, 1.5, 0.18),
		base * CFrame.new(-5, 3.4, halfZ + 1.2),
		Color3.fromRGB(72, 112, 76),
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignFace"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(246, 240, 226)
	label.Text = "♥"
	label.Parent = gui
	board.CFrame = CFrame.lookAt(board.Position, board.Position + base.LookVector)
end

function PetSanctuary.build(onEquip: (number) -> ()): Yard
	local centre = Wildlife.Sanctuary.position
	local ground = groundAt(centre.X, centre.Z)
	local base = CFrame.new(centre.X, ground, centre.Z)
	local halfX = Wildlife.Sanctuary.halfX
	local halfZ = Wildlife.Sanctuary.halfZ

	local yard = Instance.new("Model")
	yard.Name = "LocalPetSanctuary"
	yard.Parent = Workspace

	part(
		yard,
		"YardGround",
		Vector3.new(halfX * 2, 0.45, halfZ * 2),
		base * CFrame.new(0, 0.22, 0),
		Color3.fromRGB(92, 118, 76),
		Enum.Material.Grass
	)
	part(
		yard,
		"PoolRim",
		Vector3.new(0.5, 9.4, 9.4),
		base * CFrame.new(0, 0.45, -2) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(150, 146, 136),
		Enum.Material.Slate,
		Enum.PartType.Cylinder
	)
	part(
		yard,
		"Pool",
		Vector3.new(0.42, 8.4, 8.4),
		base * CFrame.new(0, 0.55, -2) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(72, 146, 176),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	for i, offset in
		{
			Vector3.new(-9, 0, -3),
			Vector3.new(-10, 0, 3),
			Vector3.new(9, 0, 3),
			Vector3.new(10, 0, -3),
		}
	do
		part(
			yard,
			`Rock{i}`,
			Vector3.new(2.1 - i * 0.2, 1.7 - i * 0.15, 1.9 + i * 0.1),
			base * CFrame.new(offset) * CFrame.Angles(0, i * 0.7, 0),
			Color3.fromRGB(128, 130, 128),
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
	end

	buildFence(yard, base, halfX, halfZ)
	buildSign(yard, base, halfZ)

	local pens: { Pen } = {}
	for index, offset in Wildlife.Sanctuary.pens do
		local penBase = base * CFrame.new(offset)
		-- face the entrance (south), where the player walks up: the big eyes read from outside
		local facing =
			CFrame.lookAt(penBase.Position, penBase.Position + Vector3.new(0, 0, 1), Vector3.yAxis)
		penBase = CFrame.new(penBase.Position) * (facing - facing.Position)
		part(
			yard,
			`PenPad{index}`,
			Vector3.new(4.4, 0.16, 4.4),
			penBase * CFrame.new(0, 0.05, 0),
			Color3.fromRGB(176, 166, 148),
			Enum.Material.Ground
		)
		local marker = part(
			yard,
			`Pen{index}`,
			Vector3.new(2, 0.2, 2),
			penBase * CFrame.new(0, 0.5, 0),
			Color3.fromRGB(176, 166, 148),
			Enum.Material.SmoothPlastic
		)
		marker.Transparency = 1
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "AdoptPrompt"
		prompt.ActionText = "Adopt"
		prompt.ObjectText = "Pet"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = marker
		local pen: Pen = {
			index = index,
			base = penBase,
			marker = marker,
			prompt = prompt,
			petId = nil,
		}
		prompt.Triggered:Connect(function()
			if pen.petId then
				onEquip(pen.petId :: number)
			end
		end)
		table.insert(pens, pen)
	end

	local residents: { [number]: Resident } = {}
	local yardState: Yard = {
		model = yard,
		pens = pens,
		residents = residents,
		setView = function() end,
		step = function() end,
	}

	local function penFor(id: number): Pen
		if pens[id] then
			return pens[id]
		end
		for _, pen in pens do
			local used = false
			for _, resident in residents do
				if resident.pen == pen then
					used = true
					break
				end
			end
			if not used then
				return pen
			end
		end
		return pens[1]
	end

	local function removeResident(id: number)
		local resident = residents[id]
		if resident then
			resident.pen.petId = nil
			resident.pen.prompt.Enabled = false
			resident.model:Destroy()
			residents[id] = nil
		end
	end

	local function addResident(row: PetRow)
		local pen = penFor(row.id)
		local model = WildlifeRig.build(row.species, row.rare)
		if not model then
			return
		end
		WildlifeRig.scale(model, PetSeat.scaleFor(row.species))
		if row.accessory then
			PetAccessory.wear(model)
		end
		model.Parent = yard
		WildlifeRig.setCFrame(model, pen.base)
		local resident: Resident = {
			row = row,
			pen = pen,
			model = model,
			hearts = PetSanctuary.hearts(model),
			remaining = row.remaining,
			phase = row.id * 1.7,
		}
		residents[row.id] = resident
		pen.petId = row.id
		pen.prompt.ObjectText = row.label
		pen.prompt.Enabled = row.ready
	end

	function yardState.setView(view: View)
		local seen = {}
		for _, row in view.pets do
			seen[row.id] = true
			if row.active then
				removeResident(row.id)
			else
				local resident = residents[row.id]
				if not resident then
					addResident(row)
					resident = residents[row.id]
				end
				if resident then
					resident.row = row
					resident.remaining = row.remaining
					resident.pen.prompt.ObjectText = row.label
					resident.pen.prompt.Enabled = row.ready
					PetSanctuary.setHearts(
						resident.hearts,
						PetSanctuary.pipCount(row.ready, row.progress, row.bond),
						row.accessory ~= nil
					)
				end
			end
		end
		for id in residents do
			if not seen[id] then
				removeResident(id)
			end
		end
	end

	local clock = 0
	local player = Players.LocalPlayer

	local function playerRoot(): BasePart?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	function yardState.step(dt: number)
		clock += dt
		local root = playerRoot()
		for _, resident in residents do
			local remaining = math.max(0, resident.remaining - dt)
			resident.remaining = remaining
			local progress = 1 - remaining / Wildlife.RecoverySeconds
			local ready = remaining <= 0
			if ready ~= resident.row.ready then
				resident.row.ready = ready
				resident.pen.prompt.Enabled = ready
			end
			PetSanctuary.setHearts(
				resident.hearts,
				PetSanctuary.pipCount(ready, progress, resident.row.bond),
				resident.row.accessory ~= nil
			)
			local penBase = resident.pen.base
			local hop: number
			local target = penBase.Position
			local yaw = 0
			if resident.row.adopted and ready then
				-- an adopted pet wanders its pen and comes to the fence when you walk past
				local near = root and (root.Position - penBase.Position).Magnitude < 14
				local at = if near and root
					then root.Position
					else penBase.Position + Vector3.new(
						math.cos(clock * 0.5 + resident.phase) * 1.2,
						0,
						math.sin(clock * 0.4 + resident.phase) * 1.2
					)
				local dir = Vector3.new(at.X - penBase.Position.X, 0, at.Z - penBase.Position.Z)
				if dir.Magnitude > 0.01 then
					dir = dir.Unit
					local leash = if near
						then 1.7
						else math.min(1.7, (at - penBase.Position).Magnitude)
					target = penBase.Position + dir * leash
					yaw = math.atan2(-dir.X, -dir.Z)
				end
				hop = math.abs(math.sin(clock * (if near then 7 else 2) + resident.phase))
					* (if near then 0.24 else 0.12)
			else
				hop = if ready
					then math.abs(math.sin(clock * 2 + resident.phase)) * 0.2
					else math.sin(clock * 1.8 + resident.phase) * 0.06
			end
			WildlifeRig.setCFrame(
				resident.model,
				CFrame.new(target + Vector3.new(0, hop, 0)) * CFrame.Angles(0, yaw, 0)
			)
		end
	end

	return yardState
end

return PetSanctuary
