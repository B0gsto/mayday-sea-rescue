--!strict
-- LeaderboardService: weekly and all-time rescue boards (docs/03 section 9.1: rescues only, never Cash
-- or Robux; weekly boards reset Monday 00:00 UTC) on OrderedDataStores, shown on a physical service board
-- at the hub's rescuer monument (docs/23 (l): a varnished, signwritten board on two posts beside the statue, lit
-- by a brass picture lamp; no HUD panel).
--
-- Credit: every helper of a finished operation gets its saved count (Shared.LeaderboardRules.credit).
-- Increments are batched per player and written every BadgeConfig.Leaderboard.flushSeconds, on leave and at
-- shutdown (IncrementAsync, request budget checked). The board re-reads the top rows every refreshSeconds;
-- when the stores are unreachable (Studio without API access) it shows this server's own tally instead.
--
--   LeaderboardService.GetBoard(key) -> { LeaderboardRules.Entry }   the rows last shown for a board
--   LeaderboardService.Credit(player, increments)                    add rescue credit (other systems)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BadgeConfig = require(Shared:WaitForChild("Config"):WaitForChild("BadgeConfig"))
local HubLayout = require(Shared:WaitForChild("Config"):WaitForChild("HubLayout"))
local LeaderboardRules = require(Shared:WaitForChild("LeaderboardRules"))

type Entry = LeaderboardRules.Entry

local LeaderboardService = {}
LeaderboardService.Priority = 60

local CFG = BadgeConfig.Leaderboard
local pending: { [number]: { [string]: number } } = {} -- userId -> board key -> not yet written
local tally: { [string]: { [number]: number } } = {} -- this server's own counts (offline fallback)
local shown: { [string]: { Entry } } = {}
local names: { [number]: string } = {}
local storesOk = true
local warned: { [string]: boolean } = {}

local function warnOnce(kind: string, msg: string)
	if not warned[kind] then
		warned[kind] = true
		warn(`[LeaderboardService] {msg} (further {kind} errors are silent)`)
	end
end

---------------------------------------------------------------- stores

local function storeFor(board: BadgeConfig.Board): OrderedDataStore
	return DataStoreService:GetOrderedDataStore(
		LeaderboardRules.storeName(board, LeaderboardRules.weekIndex(os.time()))
	)
end

local function budget(kind: Enum.DataStoreRequestType): number
	local ok, n = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, kind)
	return if ok then n else 0
end

local function flushUser(userId: number)
	local mine = pending[userId]
	if not mine then
		return
	end
	for _, board in BadgeConfig.Boards do
		local n = mine[board.key]
		if n and n > 0 then
			if budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) < 1 then
				return -- keep the rest for the next flush
			end
			local ok, err = pcall(function()
				storeFor(board):IncrementAsync(tostring(userId), n)
			end)
			if ok then
				mine[board.key] = nil
			else
				storesOk = false
				warnOnce("write", `{board.key} +{n} for {userId}: {err}`)
				return
			end
		end
	end
	if next(mine) == nil then
		pending[userId] = nil
	end
end

local function flushAll()
	for userId in table.clone(pending) do
		flushUser(userId)
	end
end

function LeaderboardService.Credit(player: Player, inc: { [string]: number })
	if next(inc) == nil then
		return
	end
	local mine = pending[player.UserId] or {}
	pending[player.UserId] = mine
	LeaderboardRules.merge(mine, inc)
	for key, n in inc do
		local t = tally[key] or {}
		tally[key] = t
		t[player.UserId] = (t[player.UserId] or 0) + n
	end
	names[player.UserId] = player.DisplayName
end

local function onOperationCompleted(snap: any, helpers: { Player })
	if snap.reason ~= "Complete" then
		return
	end
	for _, p in helpers do
		if p.Parent then
			LeaderboardService.Credit(
				p,
				LeaderboardRules.credit(snap.saved or 0, snap.isBig == true, true)
			)
		end
	end
end

local function localTop(key: string): { Entry }
	local out: { Entry } = {}
	local t: { [number]: number } = tally[key] or {}
	for userId, value in t do
		table.insert(out, { userId = userId, value = value })
	end
	table.sort(out, function(a, b)
		return a.value > b.value
	end)
	return out
end

local function readTop(board: BadgeConfig.Board): { Entry }?
	if budget(Enum.DataStoreRequestType.GetSortedAsync) < 1 then
		return nil
	end
	local ok, result = pcall(function()
		local page = storeFor(board):GetSortedAsync(false, CFG.rows):GetCurrentPage()
		local out: { Entry } = {}
		for _, item in page do
			local id = tonumber(item.key)
			if id then
				table.insert(out, { userId = id, value = item.value })
			end
		end
		return out
	end)
	if not ok then
		storesOk = false
		warnOnce("read", `read {board.key}: {result}`)
		return nil
	end
	storesOk = true
	return result
end

local function nameOf(userId: number): string?
	if names[userId] then
		return names[userId]
	end
	local here = Players:GetPlayerByUserId(userId)
	if here then
		names[userId] = here.DisplayName
		return here.DisplayName
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and type(n) == "string" then
		names[userId] = n
		return n
	end
	return nil
end

---------------------------------------------------------------- the monument board

local W, H, T = 13.8, 8.4, 0.12 -- studs: 4.6 x 2.8 m (readable from the third-person camera), board thickness
local PPS = 50 -- SurfaceGui pixels per stud: the text layout below fills the panel at this density
local FRAME, FRAME_D = 0.33, 0.24 -- moulding width and depth

local NAVY = Color3.fromRGB(26, 36, 52) -- signwriter's dark blue, painted on timber
local MAHOGANY = Color3.fromRGB(74, 40, 26)
local GOLD = Color3.fromRGB(214, 176, 96) -- gilt lettering
local CREAM = Color3.fromRGB(232, 222, 198) -- painted names
local BRASS = Color3.fromRGB(176, 140, 72)
local SERIF = "rbxasset://fonts/families/Merriweather.json"

local valueLabels: { [string]: { { name: TextLabel, value: TextLabel } } } = {}
local footer: TextLabel? = nil

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
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(
	parent: Instance,
	text: string,
	size: number,
	color: Color3,
	weight: Enum.FontWeight
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.FontFace = Font.new(SERIF, weight)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function buildGui(panel: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ServiceBoard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 1 -- paint, not a screen: it is only as bright as the hall light on it
	gui.MaxDistance = 70
	gui.ClipsDescendants = true
	gui.Parent = panel

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 26)
	pad.PaddingRight = UDim.new(0, 26)
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = gui

	local head = label(gui, "GALE ISLES COASTGUARD", 30, GOLD, Enum.FontWeight.Bold)
	head.Size = UDim2.new(1, 0, 0, 36)
	local sub = label(gui, "RESCUE BOARD", 17, GOLD, Enum.FontWeight.Regular)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Position = UDim2.fromOffset(0, 36)
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = GOLD
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.Position = UDim2.fromOffset(0, 62)
	rule.Parent = gui

	local cols = #BadgeConfig.Boards
	for i, board in BadgeConfig.Boards do
		local col = Instance.new("Frame")
		col.Name = board.key
		col.BackgroundTransparency = 1
		col.Size = UDim2.new(1 / cols, -16, 1, -104)
		col.Position = UDim2.new((i - 1) / cols, 8, 0, 72)
		col.Parent = gui
		local t = label(col, board.title:upper(), 15, GOLD, Enum.FontWeight.SemiBold)
		t.Size = UDim2.new(1, 0, 0, 24)
		local cells = {}
		for r = 1, CFG.rows do
			local y = 28 + (r - 1) * 31
			local place = label(col, `{r}.`, 19, CREAM, Enum.FontWeight.Regular)
			place.TextXAlignment = Enum.TextXAlignment.Right
			place.Size = UDim2.fromOffset(26, 28)
			place.Position = UDim2.fromOffset(0, y)
			local name = label(col, "", 19, CREAM, Enum.FontWeight.Regular)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Size = UDim2.new(1, -96, 0, 28)
			name.Position = UDim2.fromOffset(34, y)
			local value = label(col, "", 19, CREAM, Enum.FontWeight.Regular)
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.Size = UDim2.fromOffset(60, 28)
			value.Position = UDim2.new(1, -60, 0, y)
			table.insert(cells, { name = name, value = value })
		end
		valueLabels[board.key] = cells
		if i < cols then
			local div = Instance.new("Frame")
			div.BorderSizePixel = 0
			div.BackgroundColor3 = GOLD
			div.BackgroundTransparency = 0.45
			div.Size = UDim2.new(0, 1, 1, -110)
			div.Position = UDim2.new(i / cols, 0, 0, 76)
			div.Parent = gui
		end
	end
	local foot = label(gui, "", 14, GOLD, Enum.FontWeight.Regular)
	foot.Size = UDim2.new(1, 0, 0, 18)
	foot.Position = UDim2.new(0, 0, 1, -18)
	foot.TextTransparency = 0.15
	footer = foot
end

-- face: the board centre, LookVector out of its front, up = +Y
local function buildBoard(face: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "StationRescueBoard"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local back = part(
		m,
		"Board",
		Vector3.new(W, H, T),
		face * CFrame.new(0, 0, -T / 2),
		NAVY,
		Enum.Material.Wood
	)
	m.PrimaryPart = back
	local panel = part(
		m,
		"Panel",
		Vector3.new(W - 2 * FRAME, H - 2 * FRAME, 0.02),
		face * CFrame.new(0, 0, -T - 0.01),
		NAVY,
		Enum.Material.Wood
	)
	panel.CastShadow = false
	local ox, oy = W / 2 - FRAME / 2, H / 2 - FRAME / 2
	local z = -T - FRAME_D / 2 + 0.02
	part(
		m,
		"FrameTop",
		Vector3.new(W, FRAME, FRAME_D),
		face * CFrame.new(0, oy, z),
		MAHOGANY,
		Enum.Material.Wood
	)
	part(
		m,
		"FrameBottom",
		Vector3.new(W, FRAME, FRAME_D),
		face * CFrame.new(0, -oy, z),
		MAHOGANY,
		Enum.Material.Wood
	)
	part(
		m,
		"FrameLeft",
		Vector3.new(FRAME, H - 2 * FRAME, FRAME_D),
		face * CFrame.new(-ox, 0, z),
		MAHOGANY,
		Enum.Material.Wood
	)
	part(
		m,
		"FrameRight",
		Vector3.new(FRAME, H - 2 * FRAME, FRAME_D),
		face * CFrame.new(ox, 0, z),
		MAHOGANY,
		Enum.Material.Wood
	)
	-- brass fixing screws in the moulding corners
	for _, s in { Vector2.new(-1, -1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(1, 1) } do
		local screw = part(
			m,
			"Screw",
			Vector3.new(0.03, 0.09, 0.09),
			face
				* CFrame.new(s.X * ox, s.Y * oy, -T - FRAME_D + 0.01)
				* CFrame.Angles(0, math.pi / 2, 0),
			BRASS,
			Enum.Material.Metal
		)
		screw.Shape = Enum.PartType.Cylinder
		screw.CastShadow = false
	end
	-- brass picture lamp over the board: two wall arms and a hood, light washing down the face
	local hoodCf = face * CFrame.new(0, H / 2 + 0.28, -0.75)
	local hood =
		part(m, "LampHood", Vector3.new(W * 0.55, 0.16, 0.28), hoodCf, BRASS, Enum.Material.Metal)
	hood.Reflectance = 0.1
	for _, sx in { -1, 1 } do
		part(
			m,
			"LampArm",
			Vector3.new(0.07, 0.07, 0.78),
			face * CFrame.new(sx * W * 0.2, H / 2 + 0.24, -0.39),
			BRASS,
			Enum.Material.Metal
		).CastShadow =
			false
	end
	local att = Instance.new("Attachment")
	att.Name = "LampLight"
	att.Parent = hood
	att.WorldCFrame = CFrame.lookAt(
		hood.Position - hoodCf.UpVector * 0.1,
		hood.Position - hoodCf.UpVector + face.LookVector * -0.35
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(255, 205, 150) -- 2900 K tungsten
	light.Brightness = 1.1
	light.Range = 14
	light.Angle = 95
	light.Shadows = false
	light.Parent = att

	buildGui(panel)
	return m
end

---------------------------------------------------------------- refresh

local function show(key: string, entries: { Entry })
	shown[key] = entries
	local cells = valueLabels[key]
	if not cells then
		return
	end
	local rowNames: { [number]: string } = {}
	for i = 1, math.min(#entries, CFG.rows) do
		local n = nameOf(entries[i].userId)
		if n then
			rowNames[entries[i].userId] = n
		end
	end
	for i, row in LeaderboardRules.rows(entries, rowNames, CFG.rows) do
		cells[i].name.Text = row.name
		cells[i].value.Text = row.value
	end
end

local function paintFooter()
	if footer then
		local reset = LeaderboardRules.resetText(os.time())
		footer.Text = if storesOk
			then `Weekly boards reset Mondays, 00:00 UTC   ·   {reset}`
			else `This station's tally   ·   {reset}`
	end
end

local function refresh()
	for _, board in BadgeConfig.Boards do
		local entries = readTop(board)
		show(board.key, entries or localTop(board.key))
	end
	paintFooter()
end

local function placeBoard()
	-- on the monument's board posts (map/Build.luau buildHub): 5 studs right of the lot centre, 2.5 behind
	local lot = HubLayout.Hub.lots.Monument.cframe
	local board = buildBoard(lot * CFrame.new(5, 1.5 + H / 2, 2.5 - 0.6))
	board.Parent = Workspace
	for key, entries in shown do
		show(key, entries)
	end
	paintFooter()
end

function LeaderboardService.GetBoard(key: string): { Entry }
	return shown[key] or {}
end

function LeaderboardService.Init()
	Players.PlayerRemoving:Connect(function(p)
		task.spawn(flushUser, p.UserId)
	end)
	game:BindToClose(function()
		local deadline = os.clock() + 5
		local t = task.spawn(flushAll)
		while coroutine.status(t) ~= "dead" and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function LeaderboardService.Start()
	local OperationService: any = require(script.Parent:WaitForChild("OperationService"))
	OperationService.OperationCompleted:Connect(onOperationCompleted)
	task.spawn(placeBoard)
	task.spawn(function()
		local lastFlush = os.clock()
		while true do
			refresh()
			local untilRefresh = os.clock() + CFG.refreshSeconds
			while os.clock() < untilRefresh do
				task.wait(5)
				if os.clock() - lastFlush >= CFG.flushSeconds then
					lastFlush = os.clock()
					flushAll()
				end
			end
		end
	end)
end

return LeaderboardService
