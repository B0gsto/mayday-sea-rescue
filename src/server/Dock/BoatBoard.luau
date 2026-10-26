--!strict
-- BoatBoard (docs/23 d.3, WP-5; WP-10b): the in-world vehicle boards on your own plot. Each board is a rack of
-- scale models (ReplicatedStorage.VehiclePreviews, shrunk) built while its plot has an owner (berth attribute
-- Owner, DockService) and, for a building's board, while the berth's building attribute is true:
--   Boat board    every VehicleConfig.Order craft no building claims; the crane over the berth
--   Hangar board  RescueHelicopter (onto the helipad), in the hangar
--   Sub board     Submarine, on the jetty beside the sub pen; lowered into the pen on the gantry hook
-- The models are decoration. One owner-only prompt per board (BoardOpen, on the backboard; Roblox shows one
-- prompt at a time, so a prompt per model hid the back row) opens the client's board panel (UI/Panels/Board):
-- a card per craft. Launch there fires Net BoardLaunch (board name, id): the beat plays, then the craft spawns
-- at its spot, you in its seat (VehicleService.DockLaunch). An id VehicleConfig does not know yet shows as a
-- grey silhouette (pad attribute Silhouette). The client lights owned models and dims locked ones; the server
-- checks owner, reach and ownership again here. Racks: tag "BoatBoard", attributes Owner (UserId), PlotIndex,
-- Vehicles (the craft ids in order, comma-joined).
--   BoatBoard.start(launch)  VehicleService.Start passes DockLaunch(player, id, target?) (no require cycle)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local DockPieces = require(Shared:WaitForChild("DockPieces"))
local Marina = require(Shared:WaitForChild("Marina"))
local Net = require(Shared:WaitForChild("Net"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local Services = script.Parent.Parent:WaitForChild("Services")
local DockService = require(Services:WaitForChild("DockService"))

local BoatBoard = {}

local SLOT = 4.4 -- studs between models
local MODEL_LEN = 3.6 -- a scale model's longest side
local SHELF_H = 2.6
-- With the boathouse: the boat board stands in it (DockConfig.BOARD_SLOT, 17 studs between its walls): rows of
-- ROW_N, each STEP higher and further back
local ROW_N, ROW_SLOT, STEP_UP, STEP_BACK = 4, 4, 1.8, 1.4
local CRANE = Vector3.new(-13, 0, -12) -- the boat crane post, on the jetty finger (berth frame)
local JIB_Y = 24
local AFLOAT = 1.5 -- a lowered craft's pivot over the water at the end of the beat
local DROP_TIME = 1.4
local REACH = 18 -- BoardLaunch: studs from the backboard (the prompt's reach plus a step back)

local WOOD = Color3.fromRGB(84, 62, 44)
local NAVY = Color3.fromRGB(30, 40, 58)
local BLUE = Color3.fromRGB(40, 96, 208) -- WP-25 Lego brick colours
local YELLOW = Color3.fromRGB(250, 208, 40)
local TITLES = { BoatBoard = "Boats", HangarBoard = "Helicopter", SubBoard = "Submarine" }
local STEEL = Color3.fromRGB(242, 240, 232) -- the crane's white post (WP-25 r7: navy and white, calmer than yellow)
local SILHOUETTE = Color3.fromRGB(120, 124, 130)

type Launch = (Player, string, CFrame?) -> (boolean, any)

-- One kind of board, in the berth frame (sea level). `targets[id]` = where that craft spawns in that frame (nil:
-- the berth); the beat moves a copy from `from` (in the craft's frame) to its rest spot, on a hook from `hook`
-- studs over it when set.
type Def = {
	name: string,
	building: string?, -- berth attribute (DockConfig.Buildings key); nil = always (the boat board)
	vehicles: { string },
	rack: CFrame,
	targets: { [string]: CFrame },
	from: Vector3,
	hook: number?,
	ground: boolean?, -- rests on a floor (bounding box on the target), not afloat
	boathouse: boolean?, -- moves into the boathouse once it stands (the boat board)
	launch: (Player, string, CFrame?) -> (boolean, any),
}

type Board = { def: Def, rack: Model, back: BasePart?, hook: Part?, rope: Part?, busy: boolean }

local boards: { [string]: { [BasePart]: Board } } = {}
local launchFn: Launch? = nil
local defs: { Def } = {}

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
			or d:IsA("Light") -- a full-size headlight on a toy-sized model blew out the cove (WP-25 r6)
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

local function displayName(id: string): string?
	local spec: any = VehicleConfig.get(id)
	return if spec then spec.displayName else nil
end

-- the shared placeholder builders give a not-yet-registered craft its shape (grey, no prompts)
local function silhouette(id: string): Model?
	local ok, m = pcall(function(): Model?
		if id == "RescueHelicopter" then
			return (require :: any)(Shared:WaitForChild("Heli"):WaitForChild("Builder")).build(id)
		elseif id == "Submarine" then
			return (require :: any)(Shared:WaitForChild("Sub"):WaitForChild("Builder")).build(id)
		end
		return nil
	end)
	local model: Model? = if ok then m else nil
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = SILHOUETTE
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	return model
end

local function frameOf(_def: Def, berth: BasePart): CFrame
	return berth.CFrame - Vector3.new(0, 0.2, 0)
end

-- the hook hangs at `at`, its rope up to world height `top`
local function setHook(board: Board, at: CFrame, top: number)
	local hook, rope = board.hook, board.rope
	if not (hook and rope) then
		return
	end
	hook.CFrame = at
	local len = top - at.Y - 0.5
	rope.Size = Vector3.new(0.25, math.max(len, 0.1), 0.25)
	rope.CFrame = at * CFrame.new(0, 0.5 + len / 2, 0)
end

-- the beat: a full-size copy of the craft moves into its spot (down the hook, up the lift, out of the
-- hangar), then the real one takes its place
local function play(board: Board, berth: BasePart, player: Player, id: string)
	local def = board.def
	local frame = frameOf(def, berth)
	local offset = def.targets[id]
	local target = if offset then frame * offset else nil
	if not target then
		-- the berth or the pontoon spot; the hulls this launch replaces go first, so the copy never
		-- comes down on them (required here: VehicleService requires this module)
		target = (require(Services:WaitForChild("VehicleService")) :: any).DockSpot(player, id)
		if not target then
			return
		end
	end
	local spot = target or berth.CFrame
	local previews = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	local source = previews and previews:FindFirstChild(id)
	local dummy = if source and source:IsA("Model") then inert(source) else nil
	local rest = spot * CFrame.new(0, AFLOAT, 0)
	if dummy then
		dummy.Parent = board.rack
		if def.ground then
			dummy:PivotTo(spot)
			local box, size = dummy:GetBoundingBox()
			rest = spot + Vector3.new(0, spot.Y - (box.Y - size.Y / 2), 0)
		end
	end
	local start = rest * CFrame.new(def.from)
	local top = (frame * CFrame.new(0, def.hook or 0, 0)).Y
	local t = Instance.new("NumberValue")
	local function at(a: number)
		local cf = start:Lerp(rest, a)
		if dummy then
			dummy:PivotTo(cf)
		end
		setHook(board, cf * CFrame.new(0, 3, 0), top)
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
	local ok, why = def.launch(player, id, target) -- the heli: Craft.heliLaunch hovers it over the pad
	if not ok then
		warn(`[BoatBoard] {player.Name} could not launch {id}: {why}`)
	end
	if dummy then
		dummy:Destroy()
		dummy = nil
	end
	if board.hook then -- the empty hook goes back up
		local up = TweenService:Create(t, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Value = 0 })
		up:Play()
		up.Completed:Wait()
	end
	t:Destroy()
end

local function onLaunch(board: Board, berth: BasePart, player: Player, id: string)
	if board.busy or berth:GetAttribute("Owner") ~= player.UserId then
		return
	end
	-- required here, not at load: VehicleService requires this module while the services load
	local progression = require(Services:WaitForChild("ProgressionService")) :: any
	if not progression.CanUseVehicle(player, id) then
		return -- locked: the client shows the buy card
	end
	board.busy = true
	local ok, err = pcall(play :: any, board, berth, player, id)
	board.busy = false
	if not ok then
		warn(`[BoatBoard] {err}`)
	end
end

-- the boat board's own crane: a post on the jetty, a jib over the berth
local function crane(rack: Model, b: CFrame)
	local post = b * CFrame.new(CRANE)
	part(
		rack,
		"CranePost",
		Vector3.new(2, JIB_Y - Marina.DECK_TOP + 1, 2),
		post * CFrame.new(0, (JIB_Y + Marina.DECK_TOP) / 2, 0),
		STEEL,
		Enum.Material.SmoothPlastic
	)
	part(
		rack,
		"CraneJib",
		Vector3.new(math.abs(CRANE.X) + 1.5, 1.4, 1.4),
		b * CFrame.new(CRANE.X / 2, JIB_Y, CRANE.Z),
		NAVY,
		Enum.Material.SmoothPlastic
	)
	part(
		rack,
		"CraneTie",
		Vector3.new(1.4, 1.4, math.abs(CRANE.Z) + 1),
		b * CFrame.new(0, JIB_Y, CRANE.Z / 2),
		NAVY,
		Enum.Material.SmoothPlastic
	)
end

local function build(def: Def, berth: BasePart)
	local frame = frameOf(def, berth)
	local rack = Instance.new("Model")
	rack.Name = def.name
	rack:SetAttribute("Owner", berth:GetAttribute("Owner"))
	rack:SetAttribute("PlotIndex", berth:GetAttribute("PlotIndex"))
	rack:SetAttribute("Vehicles", table.concat(def.vehicles, ","))

	-- the rack: shelves on legs (stepped rows in the boathouse) with a navy backboard
	local order = def.vehicles
	local inside = def.boathouse == true and berth:GetAttribute("Boathouse") == true
	local perRow = if inside then ROW_N else #order
	local step = if inside then ROW_SLOT else SLOT
	local rows = math.ceil(#order / perRow)
	local width = perRow * step + 1
	local base = frame * (if inside then DockConfig.BOARD_SLOT else def.rack)
	for r = 0, rows - 1 do
		local row = base * CFrame.new(0, r * STEP_UP, r * STEP_BACK)
		part(
			rack,
			"Shelf",
			Vector3.new(width, 0.4, 3),
			row * CFrame.new(0, SHELF_H - 0.2, 0),
			WOOD,
			Enum.Material.Wood
		)
		for _, dx in { -width / 2 + 0.4, width / 2 - 0.4 } do
			part(
				rack,
				"Leg",
				Vector3.new(0.5, SHELF_H + r * STEP_UP, 2.6),
				base * CFrame.new(dx, (SHELF_H + r * STEP_UP) / 2 - 0.2, r * STEP_BACK),
				WOOD,
				Enum.Material.Wood
			)
		end
	end
	-- the backboard (WP-25): a blue Lego brick with a yellow name strip, facing the player
	local back = part(
		rack,
		"Back",
		Vector3.new(width, 4, 0.3),
		base * CFrame.new(0, SHELF_H + 1.8 + (rows - 1) * STEP_UP, 1.4 + (rows - 1) * STEP_BACK),
		BLUE,
		Enum.Material.SmoothPlastic
	)
	local strip = part(
		rack,
		"BackName",
		Vector3.new(math.min(width - 1, 9), 1.4, 0.2),
		back.CFrame * CFrame.new(0, 1, -0.25),
		YELLOW,
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = strip
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = NAVY
	label.Text = TITLES[def.name] or ""
	label.Parent = gui

	local open = Instance.new("ProximityPrompt")
	open.Name = "BoardOpen"
	open.ActionText = TITLES[def.name] or "Boats"
	open.KeyboardKeyCode = Enum.KeyCode.E
	open.GamepadKeyCode = Enum.KeyCode.ButtonX
	open.HoldDuration = 0
	open.MaxActivationDistance = 10
	open.RequiresLineOfSight = false
	open:SetAttribute("FootOnly", true)
	open.Parent = back

	local board: Board = { def = def, rack = rack, back = back, busy = false }
	if def.hook then
		if not def.building then
			crane(rack, berth.CFrame)
		end
		local hook = part(
			rack,
			"Hook",
			Vector3.new(1.4, 1, 1.4),
			frame,
			Color3.fromRGB(60, 60, 64),
			Enum.Material.Metal
		)
		local rope = part(
			rack,
			"Rope",
			Vector3.new(0.25, 1, 0.25),
			frame,
			Color3.fromRGB(40, 40, 40),
			Enum.Material.Fabric
		)
		for _, p in { hook, rope } do
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
		board.hook, board.rope = hook, rope
		-- idle: the hook rides over the first craft's spot
		local spot = def.targets[order[1]]
		local idle = (if spot then frame * spot else berth.CFrame) * CFrame.new(def.from)
		setHook(board, idle * CFrame.new(0, AFLOAT + 3, 0), (frame * CFrame.new(0, def.hook, 0)).Y)
	end

	for i, id in order do
		local r, c = (i - 1) // perRow, (i - 1) % perRow + 1
		local n = math.min(perRow, #order - r * perRow)
		local slot = base
			* CFrame.new((c - (n + 1) / 2) * step, SHELF_H + r * STEP_UP, r * STEP_BACK)
		local pad = part(
			rack,
			`Pad_{id}`,
			Vector3.new(step - 0.6, 0.1, 2.6),
			slot * CFrame.new(0, 0.05, 0),
			NAVY,
			Enum.Material.SmoothPlastic
		)
		pad.CanCollide = false
		pad:SetAttribute("VehicleId", id)
		local real = displayName(id) ~= nil
		if not real then
			pad:SetAttribute("Silhouette", true)
		end
		task.defer(function() -- deferred: the rack is parented by then
			local source: Model? = nil
			if real then
				local previews = ReplicatedStorage:WaitForChild("VehiclePreviews", 60)
				local found = previews and previews:WaitForChild(id, 60)
				source = if found and found:IsA("Model") then found else nil
			end
			local m = if source then inert(source) else silhouette(id)
			if not (m and rack.Parent) then
				return
			end
			if not source then
				m = inert(m)
			end
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
	boards[def.name][berth] = board
end

local function sync(def: Def, berth: BasePart)
	local board = boards[def.name][berth]
	if board then
		boards[def.name][berth] = nil
		board.rack:Destroy()
	end
	if
		berth:GetAttribute("Owner") ~= nil
		and (def.building == nil or berth:GetAttribute(def.building) == true)
	then
		build(def, berth)
	end
end

local function water(player: Player, id: string, target: CFrame?): (boolean, any)
	local launch = launchFn
	if not launch then
		return false, "NotReady"
	end
	return launch(player, id, target)
end

local function boats(): { string }
	local out = {}
	for _, id in VehicleConfig.Order do
		if not DockConfig.buildingOf(id) then
			table.insert(out, id)
		end
	end
	return out
end

-- the board panel's Launch: your own board of that name, standing by it, a craft it carries
local function onBoardLaunch(player: Player, name: any, id: any)
	if type(name) ~= "string" or type(id) ~= "string" or not boards[name] then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for berth, board in boards[name] do
		local back = board.back
		if
			berth:GetAttribute("Owner") == player.UserId
			and table.find(board.def.vehicles, id)
			and back
			and root
			and root:IsA("BasePart")
			and (root.Position - back.Position).Magnitude <= REACH
		then
			task.spawn(onLaunch, board, berth, player, id)
			return
		end
	end
end

function BoatBoard.start(launch: Launch)
	launchFn = launch
	Net.event("BoardLaunch").OnServerEvent:Connect(onBoardLaunch)
	local B = DockPieces.Buildings
	defs = {
		{
			name = "BoatBoard",
			vehicles = boats(),
			rack = CFrame.new(4, Marina.DECK_TOP, 69), -- on the quay at the cove's head, facing the berth
			targets = {},
			from = Vector3.new(0, 14.5, 0),
			hook = JIB_Y,
			boathouse = true,
			launch = water,
		},
		{
			name = "HangarBoard",
			building = "Hangar",
			vehicles = DockConfig.Buildings.Hangar.vehicles :: { string },
			rack = B.Hangar.board,
			targets = B.Hangar.targets,
			from = Vector3.new(0, 0, 10),
			ground = true,
			launch = water,
		},
		{
			name = "SubBoard",
			building = "SubPen",
			vehicles = DockConfig.Buildings.SubPen.vehicles :: { string },
			rack = B.SubPen.board,
			targets = B.SubPen.targets,
			from = Vector3.new(0, 8, 0),
			hook = B.SubPen.hook,
			launch = water,
		},
	}
	for _, def in defs do
		boards[def.name] = {}
		for _, berth in DockService.Berths() do
			local function resync()
				sync(def, berth)
			end
			berth:GetAttributeChangedSignal("Owner"):Connect(resync)
			if def.building then
				berth:GetAttributeChangedSignal(def.building):Connect(resync)
			end
			if def.boathouse then
				berth:GetAttributeChangedSignal("Boathouse"):Connect(resync)
			end
			resync()
		end
	end
end

return BoatBoard
