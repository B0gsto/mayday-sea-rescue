--!strict
-- BoatBoard (docs/23 d.3, WP-5): the rack of scale models on your own jetty and the crane over your berth.
-- Built on a plot while it has an owner (berth attribute Owner, DockService), one scale model per
-- VehicleConfig.Order craft (ReplicatedStorage.VehiclePreviews, shrunk). Each model's pad carries two
-- owner-only prompts:
--   BoardLaunch (E)  owned: the crane lowers that craft into your berth (VehicleService.DockLaunch: docked,
--                    afloat, not seated). Locked: the client opens the buy card (BoatBoardController).
--   BoardCard (F)    owned crafts with upgrades: the client opens the same card (upgrades).
-- The client lights owned models and puts the padlock and price chips on locked ones; the server checks
-- ownership again here. Rack tag "BoatBoard", attributes Owner (UserId) and PlotIndex.
--   BoatBoard.start(launch)  VehicleService.Start passes DockLaunch (no require cycle)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Marina = require(Shared:WaitForChild("Marina"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local Services = script.Parent.Parent:WaitForChild("Services")
local DockService = require(Services:WaitForChild("DockService"))

local BoatBoard = {}

-- Berth frame (Marina): the rack stands at the shore end of the deck, facing the water (-Z).
-- TODO(WP-4): at dock level >= 3 read DockConfig.BOARD_SLOT (the boathouse wall) instead of RACK.
local RACK = CFrame.new(4, Marina.DECK_TOP, 46)
local SLOT = 4.4 -- studs between models
local MODEL_LEN = 3.6 -- a scale model's longest side
local SHELF_H = 2.6
local CRANE = Vector3.new(17, 0, -12) -- the crane post, on the jetty's outer edge
local JIB_Y = 24
local DROP_FROM, DROP_TO = 16, 1.5 -- the craft's pivot height over the berth, start and end of the lowering
local HOOK_IDLE = DROP_FROM + 3 -- the hook rides 3 studs over the craft's pivot
local DROP_TIME = 1.4

local WOOD = Color3.fromRGB(84, 62, 44)
local NAVY = Color3.fromRGB(30, 40, 58)
local STEEL = Color3.fromRGB(226, 178, 52) -- crane yellow

type Board = { rack: Model, hook: Part, rope: Part, busy: boolean }

local boards: { [BasePart]: Board } = {}
local launchFn: ((Player, string) -> (boolean, any))? = nil

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
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- an inert copy of a preview: anchored, no collisions, no seats or prompts
local function inert(source: Model): Model
	local m = source:Clone()
	for _, d in m:GetDescendants() do
		if
			d:IsA("BaseScript")
			or d:IsA("ProximityPrompt")
			or d:IsA("Seat")
			or d:IsA("VehicleSeat")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	return m
end

local function prompt(
	pad: BasePart,
	name: string,
	action: string,
	key: Enum.KeyCode,
	button: Enum.KeyCode,
	id: string
)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = (VehicleConfig.get(id) :: any).displayName
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = button
	p.HoldDuration = 0
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p:SetAttribute("VehicleId", id)
	p:SetAttribute("FootOnly", true)
	p.Parent = pad
	return p
end

-- the hook and its rope hang from the jib end over the berth centre
local function setHook(board: Board, berth: BasePart, y: number)
	board.hook.CFrame = berth.CFrame * CFrame.new(0, y, 0)
	local len = JIB_Y - y - 0.5
	board.rope.Size = Vector3.new(0.25, math.max(len, 0.1), 0.25)
	board.rope.CFrame = berth.CFrame * CFrame.new(0, y + 0.5 + len / 2, 0)
end

-- the beat: a full-size copy of the craft comes down on the hook, then the real one takes its place
local function lower(board: Board, berth: BasePart, player: Player, id: string)
	local previews = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	local source = previews and previews:FindFirstChild(id)
	local dummy = if source and source:IsA("Model") then inert(source) else nil
	local b = berth.CFrame
	if dummy then
		dummy.Parent = board.rack
	end
	local t = Instance.new("NumberValue")
	local function at(a: number)
		local y = DROP_FROM + (DROP_TO - DROP_FROM) * a
		if dummy then
			dummy:PivotTo(b * CFrame.new(0, y, 0))
		end
		setHook(board, berth, y + 3)
	end
	at(0)
	t.Changed:Connect(at)
	local tween = TweenService:Create(
		t,
		TweenInfo.new(DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	local launch = launchFn
	local ok, why = false, "NotReady"
	if launch then
		ok, why = launch(player, id)
	end
	if not ok then
		warn(`[BoatBoard] {player.Name} could not launch {id}: {why}`)
	end
	if dummy then
		dummy:Destroy()
		dummy = nil
	end
	local up = TweenService:Create(t, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Value = 0 })
	up:Play()
	up.Completed:Wait()
	t:Destroy()
	setHook(board, berth, HOOK_IDLE)
end

local function onLaunch(berth: BasePart, player: Player, id: string)
	local board = boards[berth]
	if not board or board.busy or berth:GetAttribute("Owner") ~= player.UserId then
		return
	end
	-- required here, not at load: VehicleService requires this module while the services load
	local progression = require(Services:WaitForChild("ProgressionService")) :: any
	if not progression.CanUseVehicle(player, id) then
		return -- locked: the client shows the buy card
	end
	board.busy = true
	local ok, err = pcall(lower :: any, board, berth, player, id)
	board.busy = false
	if not ok then
		warn(`[BoatBoard] {err}`)
	end
end

local function build(berth: BasePart)
	local b = berth.CFrame
	local rack = Instance.new("Model")
	rack.Name = "BoatBoard"
	rack:SetAttribute("Owner", berth:GetAttribute("Owner"))
	rack:SetAttribute("PlotIndex", berth:GetAttribute("PlotIndex"))

	-- the rack: a shelf on legs with a navy backboard
	local order = VehicleConfig.Order
	local width = #order * SLOT + 1
	local base = b * RACK
	part(
		rack,
		"Shelf",
		Vector3.new(width, 0.4, 3),
		base * CFrame.new(0, SHELF_H - 0.2, 0),
		WOOD,
		Enum.Material.Wood
	)
	for _, dx in { -width / 2 + 0.4, width / 2 - 0.4 } do
		part(
			rack,
			"Leg",
			Vector3.new(0.5, SHELF_H, 2.6),
			base * CFrame.new(dx, SHELF_H / 2 - 0.2, 0),
			WOOD,
			Enum.Material.Wood
		)
	end
	part(
		rack,
		"Back",
		Vector3.new(width, 4, 0.3),
		base * CFrame.new(0, SHELF_H + 1.8, 1.4),
		NAVY,
		Enum.Material.SmoothPlastic
	)

	-- the crane: a post on the jetty, a jib over the berth, a hook on a rope
	local post = b * CFrame.new(CRANE)
	part(
		rack,
		"CranePost",
		Vector3.new(1.2, JIB_Y - Marina.DECK_TOP + 1, 1.2),
		post * CFrame.new(0, (JIB_Y + Marina.DECK_TOP) / 2, 0),
		STEEL,
		Enum.Material.Metal
	)
	part(
		rack,
		"CraneJib",
		Vector3.new(CRANE.X + 1.5, 1, 1),
		b * CFrame.new(CRANE.X / 2, JIB_Y, CRANE.Z),
		STEEL,
		Enum.Material.Metal
	)
	part(
		rack,
		"CraneTie",
		Vector3.new(1, 1, math.abs(CRANE.Z) + 1),
		b * CFrame.new(0, JIB_Y, CRANE.Z / 2),
		STEEL,
		Enum.Material.Metal
	)
	local hook = part(
		rack,
		"Hook",
		Vector3.new(1.4, 1, 1.4),
		b,
		Color3.fromRGB(60, 60, 64),
		Enum.Material.Metal
	)
	local rope = part(
		rack,
		"Rope",
		Vector3.new(0.25, 1, 0.25),
		b,
		Color3.fromRGB(40, 40, 40),
		Enum.Material.Fabric
	)
	for _, p in { hook, rope } do
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	local board: Board = { rack = rack, hook = hook, rope = rope, busy = false }
	setHook(board, berth, HOOK_IDLE)

	for i, id in order do
		local slot = base * CFrame.new((i - (#order + 1) / 2) * SLOT, SHELF_H, 0)
		local pad = part(
			rack,
			`Pad_{id}`,
			Vector3.new(SLOT - 0.6, 0.1, 2.6),
			slot * CFrame.new(0, 0.05, 0),
			NAVY,
			Enum.Material.SmoothPlastic
		)
		pad.CanCollide = false
		pad:SetAttribute("VehicleId", id)
		prompt(pad, "BoardLaunch", "Launch", Enum.KeyCode.E, Enum.KeyCode.ButtonX, id).Triggered:Connect(
			function(player)
				task.spawn(onLaunch, berth, player, id)
			end
		)
		if VehicleUpgrades.Vehicles[id] then
			prompt(pad, "BoardCard", "Upgrade", Enum.KeyCode.F, Enum.KeyCode.ButtonY, id)
		end
		task.spawn(function()
			local previews = ReplicatedStorage:WaitForChild("VehiclePreviews", 60)
			local source = previews and previews:WaitForChild(id, 60)
			if not (source and source:IsA("Model") and rack.Parent) then
				return
			end
			local m = inert(source)
			m.Name = "Model"
			local size = m:GetExtentsSize()
			m:ScaleTo(m:GetScale() * MODEL_LEN / math.max(size.X, size.Z, 0.1))
			-- side on to the player, sitting on the pad
			m:PivotTo(slot * CFrame.Angles(0, math.pi / 2, 0))
			local cf, box = m:GetBoundingBox()
			m:PivotTo(m:GetPivot() + Vector3.new(0, slot.Y + 0.1 - (cf.Y - box.Y / 2), 0))
			m.Parent = pad
		end)
	end
	rack.Parent = berth.Parent
	CollectionService:AddTag(rack, "BoatBoard")
	boards[berth] = board
end

local function sync(berth: BasePart)
	local board = boards[berth]
	if board then
		boards[berth] = nil
		board.rack:Destroy()
	end
	if berth:GetAttribute("Owner") ~= nil then
		build(berth)
	end
end

function BoatBoard.start(launch: (Player, string) -> (boolean, any))
	launchFn = launch
	for _, berth in DockService.Berths() do
		berth:GetAttributeChangedSignal("Owner"):Connect(function()
			sync(berth)
		end)
		sync(berth)
	end
end

return BoatBoard
