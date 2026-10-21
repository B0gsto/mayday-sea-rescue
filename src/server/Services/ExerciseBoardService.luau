--!strict
-- ExerciseBoardService (RP-C1b): the station's exercise board and the exercise venues (docs 09
-- section 9.2). A cork notice board on the boat hall's partition wall, next to RP-B1's rescue
-- board (same frame: the M_Bld_Station swap, or its authored pivot from World/Swaps), with one
-- pinned sheet per exercise (title, about how long, what it teaches, the certification it feeds)
-- and a ProximityPrompt (attribute Panel = "ExerciseBoard"). The client (ExerciseBoardController)
-- reads the board up close: each exercise's status for that player, the requirements and Start
-- (Ops_StartExercise -> OperationService.StartExercise). No HUD button.
--
-- Venues (Exercises.Venue): "Slipway" (the manikin on a line off the station slipway, the player
-- at the water's edge), "Pontoon" (the loaner on the slip head, the manikin out in the harbour,
-- the berth on the nearest drop-off pontoon), "StationFloor" (the resus manikin on a mat on the
-- hall floor, built for the exercise and removed after it).
--
-- API (OperationService calls these through pcall):
--   ExerciseBoardService.Venue(venue, exerciseId?) -> { stand: CFrame, casualty: Vector3, launch: CFrame }?
--   ExerciseBoardService.IsNearBoard(player) -> boolean
--   ExerciseBoardService.BeginExercise(opId, venue)   the station-floor manikin
--   ExerciseBoardService.EndExercise(opId)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Exercises =
	require(Shared:WaitForChild("Ops"):WaitForChild("Definitions"):WaitForChild("Exercises"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))

local ExerciseBoardService = {}
ExerciseBoardService.Priority = 75 -- after OperationService (70) is loaded; nothing depends on it

ExerciseBoardService.BoardName = "StationExerciseBoard"
ExerciseBoardService.PromptRange = 8 -- studs
local NEAR_MARGIN = 6 -- studs past the prompt range the server still accepts a Start from

---------------------------------------------------------------- the station frame

-- M_Bld_Station layout metres (build.py: X across, -Y the sea front, Z up) -> the asset frame in
-- studs, as LeaderboardService and WorldDressingService do (STATION_DY: Swaps' recentring).
local STATION_DY = 0.175
local function toLocal(x: number, y: number, z: number): Vector3
	return Vector3.new(-x * 3, z * 3, (y + STATION_DY) * 3)
end

-- the hall face of the partition wall (x -1.0 m), seaward of the rescue board (y 2.6..7.2 m),
-- clear of the boat on ATT_BoatHall (x -5.25, y 0): centre 2.5 m up, facing into the hall
local WALL_X, BOARD_Y, BOARD_Z = -1.0, 0.6, 2.5
local W, H, T = 5.1, 3.6, 0.1 -- studs: 1.7 x 1.2 m as laid out, board thickness
local SCALE = 2 -- hung at twice the layout (3.4 x 2.4 m): readable from the third-person camera
local FRAME, FRAME_D = 0.24, 0.18
-- the resus manikin's mat on the hall floor, between the boat and the board
local MAT_X, MAT_Y = -2.4, -1.4 -- metres

local OAK = Color3.fromRGB(122, 86, 52)
local CORK = Color3.fromRGB(166, 122, 78)
local PAPER = Color3.fromRGB(236, 232, 220)
local INK = Color3.fromRGB(34, 38, 44)
local INK_DIM = Color3.fromRGB(84, 88, 92)
local RNLI_RED = Color3.fromRGB(172, 44, 38)
local PIN_COLOURS =
	{ Color3.fromRGB(196, 48, 40), Color3.fromRGB(40, 92, 168), Color3.fromRGB(226, 182, 48) }
local TYPE = Font.new("rbxasset://fonts/families/SourceSansPro.json")

local pivot: CFrame? = nil
local boardPart: BasePart? = nil
local manikins: { [string]: Model } = {}

local function stationPivot(): CFrame?
	local dressing = Workspace:FindFirstChild("Dressing")
	local shell = dressing and dressing:FindFirstChild("Station")
	-- the swap names the loaded model by its LOD (M_Bld_Station_LOD0)
	local asset = shell
		and (shell:FindFirstChild("M_Bld_Station") or shell:FindFirstChild("M_Bld_Station_LOD0"))
	if asset and asset:IsA("Model") then
		return asset:GetPivot()
	end
	return nil
end

local function authoredPivot(): CFrame?
	local ok, swaps = pcall(function()
		return (require :: any)(script.Parent.Parent:WaitForChild("World"):WaitForChild("Swaps"))
	end)
	local spec = ok and swaps and swaps.Station
	return if spec then spec.pivot else nil
end

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
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function text(
	parent: Instance,
	value: string,
	size: number,
	color: Color3,
	weight: Enum.FontWeight,
	y: number,
	h: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = value
	l.TextSize = size
	l.TextColor3 = color
	l.FontFace = Font.new(TYPE.Family, weight)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Size = UDim2.new(1, 0, 0, h)
	l.Position = UDim2.fromOffset(0, y)
	l.Parent = parent
	return l
end

-- a printed A5 sheet pinned to the cork: a SurfaceGui with typed text, a drawing pin at the top
local function sheet(
	m: Model,
	name: string,
	face: CFrame,
	x: number,
	y: number,
	w: number,
	h: number,
	pin: Color3
): (Part, Frame)
	local cf = face
		* CFrame.new(x, y, -T - 0.015)
		* CFrame.Angles(0, 0, math.rad((#name % 5 - 2) * 0.6))
	local p = part(m, name, Vector3.new(w, h, 0.01), cf, PAPER, Enum.Material.SmoothPlastic)
	p.CastShadow = false
	local head = part(
		m,
		name .. "Pin",
		Vector3.new(0.09, 0.12, 0.12),
		cf * CFrame.new(0, h / 2 - 0.14, -0.04) * CFrame.Angles(0, math.pi / 2, 0),
		pin,
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Cylinder
	head.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Print"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 150
	gui.LightInfluence = 1 -- paper under the hall lights, not a screen
	gui.MaxDistance = 40
	gui.ClipsDescendants = true
	gui.Parent = p
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -24, 1, -20)
	body.Position = UDim2.fromOffset(12, 14)
	body.Parent = gui
	return p, body
end

local function buildBoard(stationCf: CFrame): Model
	local at = toLocal(WALL_X, BOARD_Y, BOARD_Z)
	-- LookVector out of the wall (+X studs in the asset frame), up = +Y
	local face = stationCf * CFrame.fromMatrix(at, Vector3.zAxis, Vector3.yAxis, -Vector3.xAxis)
	local m = Instance.new("Model")
	m.Name = ExerciseBoardService.BoardName
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local back = part(
		m,
		"Board",
		Vector3.new(W, H, T),
		face * CFrame.new(0, 0, -T / 2),
		CORK,
		Enum.Material.Fabric
	)
	m.PrimaryPart = back
	local ox, oy = W / 2 - FRAME / 2, H / 2 - FRAME / 2
	local z = -T - FRAME_D / 2 + 0.03
	part(
		m,
		"FrameTop",
		Vector3.new(W, FRAME, FRAME_D),
		face * CFrame.new(0, oy, z),
		OAK,
		Enum.Material.Wood
	)
	part(
		m,
		"FrameBottom",
		Vector3.new(W, FRAME, FRAME_D),
		face * CFrame.new(0, -oy, z),
		OAK,
		Enum.Material.Wood
	)
	part(
		m,
		"FrameLeft",
		Vector3.new(FRAME, H - 2 * FRAME, FRAME_D),
		face * CFrame.new(-ox, 0, z),
		OAK,
		Enum.Material.Wood
	)
	part(
		m,
		"FrameRight",
		Vector3.new(FRAME, H - 2 * FRAME, FRAME_D),
		face * CFrame.new(ox, 0, z),
		OAK,
		Enum.Material.Wood
	)

	-- header strip: the station's training notice
	local _, hb = sheet(m, "Header", face, 0, H / 2 - 0.55, W - 0.9, 0.62, PIN_COLOURS[2])
	local t1 = text(hb, "TRAINING EXERCISES", 30, RNLI_RED, Enum.FontWeight.Bold, 0, 32)
	t1.TextXAlignment = Enum.TextXAlignment.Center
	local t2 = text(
		hb,
		"See Chief Aggie. Any time, any crew. Book on at the board.",
		17,
		INK_DIM,
		Enum.FontWeight.Regular,
		32,
		22
	)
	t2.TextXAlignment = Enum.TextXAlignment.Center

	-- one sheet per exercise, two rows of two
	local sw, sh = (W - 0.9) / 2 - 0.1, 1.1
	for i, id in Exercises.Order do
		local e = Exercises.Defs[id]
		local col, row = (i - 1) % 2, (i - 1) // 2
		local x = (col - 0.5) * (sw + 0.2)
		local y = H / 2 - 1.5 - row * (sh + 0.12)
		local _, b =
			sheet(m, `Sheet_{id}`, face, x, y, sw, sh, PIN_COLOURS[(i - 1) % #PIN_COLOURS + 1])
		local cert = if e.certification
			then ProgressionConfig.Certifications[e.certification]
			else nil
		text(b, string.upper(e.def.displayName), 19, INK, Enum.FontWeight.Bold, 0, 22)
		local mins = if e.minutes < 1 then "under a minute" else `about {math.ceil(e.minutes)} min`
		text(
			b,
			`{mins}  |  {if cert then `for {cert.displayName}` else "optional"}`,
			15,
			RNLI_RED,
			Enum.FontWeight.SemiBold,
			22,
			18
		)
		text(b, e.summary, 15, INK, Enum.FontWeight.Regular, 42, 52)
		local req = if cert
			then `Certificate: pass this, then {cert.live.count} live {cert.live.label} at {cert.live.minGrade}.`
			else "No certificate. Cannot be failed."
		if cert and #cert.needs > 0 then
			local names = {}
			for _, need in cert.needs do
				local d = ProgressionConfig.Certifications[need]
				table.insert(names, if d then d.displayName else need)
			end
			req ..= ` Needs {table.concat(names, ", ")} first.`
		end
		text(b, req, 14, INK_DIM, Enum.FontWeight.Regular, 96, 34)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExerciseBoardPrompt"
	prompt.ActionText = "Read the board"
	prompt.ObjectText = "Training exercises"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ExerciseBoardService.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("Panel", "ExerciseBoard")
	prompt.Parent = back
	m:ScaleTo(SCALE)
	for _, g in m:GetDescendants() do
		if g:IsA("SurfaceGui") then
			g.PixelsPerStud /= SCALE -- same text layout on the bigger sheets
		end
	end
	return m
end

local function placeBoard()
	local cf: CFrame? = nil
	for _ = 1, 90 do -- WorldDressingService swaps the station in once its assets load
		cf = stationPivot()
		if cf then
			break
		end
		task.wait(2)
	end
	if not cf then
		cf = authoredPivot()
		if not cf then
			warn("[ExerciseBoardService] no station to hang the board in")
			return
		end
		warn("[ExerciseBoardService] station not swapped in: board placed from the authored pivot")
	end
	pivot = cf
	local board = buildBoard(cf :: CFrame)
	board.Parent = Workspace
	boardPart = board.PrimaryPart
end

---------------------------------------------------------------- venues

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, 1)
end

-- open water at `from + dir * dist`, pulled in until nothing solid stands above the sea there
local function openWater(from: Vector3, dir: Vector3, dist: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = Players:GetPlayers()
	local d = dist
	for _ = 1, 5 do
		local p = Vector3.new(from.X, 0, from.Z) + dir * d
		local hit = Workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -64, 0), params)
		if not hit or hit.Position.Y < 0.5 or hit.Material == Enum.Material.Water then
			return p
		end
		d *= 0.75
	end
	return Vector3.new(from.X, 0, from.Z) + dir * d
end

-- the station slipway: its head on the quay, its toe under the sea, the downhill direction
local function slipway(): (Vector3?, Vector3?, Vector3?)
	local map = Workspace:FindFirstChild("Map")
	local slips = map and map:FindFirstChild("Slipways")
	local ramp = slips and slips:FindFirstChild("StationSlipway")
	if not (ramp and ramp:IsA("BasePart")) then
		return nil, nil, nil
	end
	local half = ramp.Size / 2
	-- the ramp's local -Z end is the top, at the quay (VehicleService.slipwaySpots)
	local top = (ramp.CFrame * CFrame.new(0, half.Y, -half.Z)).Position
	local toe = (ramp.CFrame * CFrame.new(0, half.Y, half.Z)).Position
	return top, toe, flat(toe - top)
end

-- where the ramp meets the sea (y 0), or the toe if it never does
local function waterline(top: Vector3, toe: Vector3): Vector3
	if top.Y <= 0 or toe.Y >= 0 then
		return toe
	end
	return top:Lerp(toe, top.Y / (top.Y - toe.Y))
end

function ExerciseBoardService.Venue(venue: string, exerciseId: string?): { [string]: any }?
	if venue == "StationFloor" then
		local cf = pivot or stationPivot() or authoredPivot()
		if not cf then
			return nil
		end
		local mat = (cf :: CFrame) * toLocal(MAT_X, MAT_Y, 0.08)
		local towardWall = flat((cf :: CFrame):VectorToWorldSpace(Vector3.new(-1, 0, 0)))
		-- kneel-side: between the mat and the boat, facing the manikin
		local standAt = mat - towardWall * 3.2 + Vector3.new(0, 3, 0)
		return {
			stand = CFrame.lookAt(standAt, Vector3.new(mat.X, standAt.Y, mat.Z)),
			casualty = mat,
			launch = CFrame.new(standAt),
		}
	end
	local top, toe, down = slipway()
	if not (top and toe and down) then
		return nil
	end
	local edge = waterline(top, toe)
	local launchAt = top + down * 8 + Vector3.new(0, 2.5, 0)
	local out = if venue == "Pontoon"
		then 110
		elseif exerciseId == "ExerciseSwimTest" then 22
		else 13
	local standAt = edge - down * 4 + Vector3.new(0, 3, 0)
	return {
		stand = CFrame.lookAt(standAt, standAt + down),
		casualty = openWater(edge, down, out),
		launch = CFrame.lookAt(launchAt, launchAt + down),
	}
end

function ExerciseBoardService.IsNearBoard(player: Player): boolean
	local board = boardPart
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (board and root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - board.Position).Magnitude
		<= ExerciseBoardService.PromptRange + NEAR_MARGIN
end

---------------------------------------------------------------- the resus manikin

local function buildManikin(at: Vector3, along: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "TrainingManikin"
	local base = CFrame.lookAt(at, at + along)
	local mat = part(
		m,
		"Mat",
		Vector3.new(2.6, 0.12, 6),
		base * CFrame.new(0, 0.06, 0),
		Color3.fromRGB(38, 70, 120),
		Enum.Material.Fabric
	)
	m.PrimaryPart = mat
	local skin = Color3.fromRGB(226, 196, 172)
	-- a resus torso and head lying face up, in a red training jacket
	part(
		m,
		"Torso",
		Vector3.new(1.35, 0.62, 2.0),
		base * CFrame.new(0, 0.43, 0.5),
		RNLI_RED,
		Enum.Material.Fabric
	)
	part(
		m,
		"Chest",
		Vector3.new(1.0, 0.06, 0.9),
		base * CFrame.new(0, 0.76, 0.2),
		skin,
		Enum.Material.SmoothPlastic
	)
	part(
		m,
		"Neck",
		Vector3.new(0.38, 0.36, 0.3),
		base * CFrame.new(0, 0.42, -0.62),
		skin,
		Enum.Material.SmoothPlastic
	)
	local head = part(
		m,
		"Head",
		Vector3.new(0.78, 0.78, 0.78),
		base * CFrame.new(0, 0.5, -1.05),
		skin,
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	for _, sx in { -1, 1 } do
		part(
			m,
			"Arm",
			Vector3.new(0.34, 0.34, 1.7),
			base * CFrame.new(sx * 0.86, 0.3, 0.75),
			RNLI_RED,
			Enum.Material.Fabric
		)
	end
	-- the kit bag Aggie brought: oxygen and the defib
	part(
		m,
		"KitBag",
		Vector3.new(1.2, 0.7, 0.7),
		base * CFrame.new(1.9, 0.35, -0.6),
		Color3.fromRGB(196, 52, 36),
		Enum.Material.Fabric
	)
	part(
		m,
		"OxygenCylinder",
		Vector3.new(0.32, 0.32, 1.5),
		base * CFrame.new(1.8, 0.16, 0.6),
		Color3.fromRGB(232, 232, 228),
		Enum.Material.Metal
	)
	return m
end

function ExerciseBoardService.BeginExercise(opId: string, venue: string)
	if venue ~= "StationFloor" or manikins[opId] then
		return
	end
	local v = ExerciseBoardService.Venue(venue)
	local cf = pivot or stationPivot() or authoredPivot()
	if not (v and cf) then
		return
	end
	local along = flat((cf :: CFrame):VectorToWorldSpace(Vector3.new(0, 0, 1)))
	local m = buildManikin(v.casualty, along)
	m.Parent = Workspace
	manikins[opId] = m
end

function ExerciseBoardService.EndExercise(opId: string)
	local m = manikins[opId]
	manikins[opId] = nil
	if m then
		m:Destroy()
	end
end

function ExerciseBoardService.Init() end

function ExerciseBoardService.Start()
	task.spawn(placeBoard)
end

return ExerciseBoardService
