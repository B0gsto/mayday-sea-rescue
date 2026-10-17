--!strict
-- Mechanic "scene_command" (docs/09 section 7 step 2): the first senior unit on scene becomes On
-- Scene Coordinator (the server picks the assignee; an NPC Coastguard officer runs it from shore
-- when nobody takes it: onFail = "npc"). The OSC works a waterproof chart tablet in their hands:
--   1. METHANE: seven report lines, three cards each (keys 1-3), sent over the radio as a sitrep.
--   2. Scene board: pick a unit, then tap its task on the chart (search sectors A, B, C fanned
--      downwind of the hull, casualty reception, hull team, standby). Units are the crews on scene
--      plus NPC lifeboats; "Ask Coastguard" fills empty tasks with NPC units, slowly.
-- Result metrics: reportCorrect, tasksCovered (fractions), assigned (count). Server: elapsed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FerryUi = require(script.Parent:WaitForChild("Ferry"):WaitForChild("FerryUi"))
local SceneBoard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("SceneBoard")
)

local C = FerryUi.Theme.Colors
local BEZEL = Color3.fromRGB(242, 160, 30) -- rugged rubber bumper
local SCREEN = Color3.fromRGB(14, 30, 40)
local SEA = Color3.fromRGB(38, 92, 128)

local NPC_UNITS =
	{ "Lifeboat 17-01", "Haven Patrol", "ILB Two-Two", "ILB Two-Three", "Lifeboat 14-07" }

local function totalCasualties(ctx: { [string]: any }): number
	local ok, n = pcall(function()
		local OpsController = require(
			script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("OpsController")
		) :: any
		local s = OpsController.GetState()
		return s and s.total
	end)
	if ok and type(n) == "number" and n > 0 then
		return n + 2 -- plus the two in the air pocket on the manifest
	end
	return #(ctx.scene and ctx.scene.targets or {}) + 2
end

local scene_command = {}

function scene_command.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local bin = FerryUi.bin()
	local player = Players.LocalPlayer
	local assist = ctx.isAssist == true
	local hullPos: Vector3 = ctx.operation.position
	local wind: number = ctx.scene and ctx.scene.windDirection or 0
	local seed = math.floor(os.clock() * 10) % 97
	local lines = SceneBoard.methane({
		zoneName = ctx.operation.zoneName or "Harbour approaches",
		bearing = "half a mile "
			.. SceneBoard.compass(hullPos - Vector3.new(0, 0, 0))
			.. " of the harbour mouth",
		casualties = totalCasualties(ctx),
		storm = ctx.operation.storm == true,
	}, seed)
	local answers: { [number]: number } = {}
	local lineIdx = 1
	local assign: { [string]: string } = {}
	local selected: string? = nil
	local done = false
	local callsign = `Haven Rescue {player.DisplayName}`

	-- units on scene: my crew first, then other players near the hull, then NPC lifeboats
	local units: { string } = { "My boat" }
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if
			p ~= player
			and root
			and root:IsA("BasePart")
			and (root.Position - hullPos).Magnitude < 900
		then
			table.insert(units, `Haven {p.DisplayName}`)
		end
	end
	for _, n in NPC_UNITS do
		table.insert(units, `{n} (NPC)`)
	end

	---------------------------------------------------------------- tablet

	local gui = bin.add(FerryUi.screen("FerrySceneCommand"))
	local tablet =
		FerryUi.frame(gui, UDim2.fromOffset(820, 500), UDim2.new(0.5, -410, 0.5, -250), BEZEL, 0)
	FerryUi.corner(tablet, 26)
	local screen =
		FerryUi.frame(tablet, UDim2.new(1, -36, 1, -36), UDim2.fromOffset(18, 18), SCREEN, 0)
	FerryUi.corner(screen, 12)
	FerryUi.text(
		screen,
		"GALE ISLES SAR · SCENE BOARD · OSC",
		UDim2.new(1, -24, 0, 24),
		UDim2.fromOffset(12, 8),
		20,
		C.text,
		FerryUi.Theme.HeaderFont
	)
	local sub =
		FerryUi.text(screen, "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 34), 15, C.textDim)

	local function tap()
		FerryUi.sound(FerryUi.Sounds.tabletTap, nil, 0.3)
	end

	---------------------------------------------------------------- METHANE page

	local methPage =
		FerryUi.frame(screen, UDim2.new(1, -24, 1, -70), UDim2.fromOffset(12, 60), SCREEN, 1)
	local boardPage =
		FerryUi.frame(screen, UDim2.new(1, -24, 1, -70), UDim2.fromOffset(12, 60), SCREEN, 1)
	boardPage.Visible = false

	local summary =
		FerryUi.text(methPage, "", UDim2.fromScale(0.42, 1), UDim2.fromScale(0.58, 0), 15, C.text)
	local question = FerryUi.text(
		methPage,
		"",
		UDim2.new(0.55, 0, 0, 30),
		UDim2.new(),
		22,
		C.text,
		FerryUi.Theme.BoldFont
	)
	local optionButtons: { TextButton } = {}

	local showBoard: () -> ()

	local function refreshMethane()
		local out = {}
		for i, l in lines do
			local a = answers[i]
			table.insert(out, `{l.letter}  {l.label}: {if a then l.options[a] else "..."}`)
		end
		summary.Text = table.concat(out, "\n")
		local l = lines[lineIdx]
		if not l then
			return
		end
		question.Text = `{l.letter} · {l.label}`
		for k, b in optionButtons do
			b.Text = `{k}  {l.options[k]}`
		end
		sub.Text = "Send METHANE first: pick each line from what you see on scene."
	end

	local function pickOption(k: number)
		if done or not methPage.Visible then
			return
		end
		tap()
		FerryUi.playAction("tablet_tap")
		answers[lineIdx] = k
		lineIdx += 1
		if lineIdx > #lines then
			refreshMethane()
			-- the sitrep goes out on the radio line by line
			methPage.Visible = false
			local sitrep = SceneBoard.sitrep(callsign, lines, answers)
			FerryUi.sound(FerryUi.Sounds.radioClick, nil, 0.5)
			FerryUi.playAction("radio_ptt")
			for i, text in sitrep do
				task.delay((i - 1) * 0.9, function()
					if not done then
						FerryUi.subtitle(gui, `[Radio] {text}`, 1.2)
					end
				end)
			end
			task.delay(#sitrep * 0.9, function()
				if not done then
					showBoard()
				end
			end)
			return
		end
		refreshMethane()
	end

	for k = 1, 3 do
		local b = FerryUi.button(
			methPage,
			"",
			UDim2.new(0.55, 0, 0, 60),
			UDim2.fromOffset(0, 40 + (k - 1) * 70),
			C.panelLight,
			function()
				pickOption(k)
			end
		)
		b.TextXAlignment = Enum.TextXAlignment.Left
		optionButtons[k] = b
	end
	FerryUi.button(
		methPage,
		"Back a line",
		UDim2.fromOffset(150, 40),
		UDim2.new(0, 0, 1, -44),
		C.locked,
		function()
			if lineIdx > 1 then
				lineIdx -= 1
				answers[lineIdx] = nil
				refreshMethane()
			end
		end
	)

	---------------------------------------------------------------- scene board page

	local chart = FerryUi.frame(boardPage, UDim2.fromOffset(400, 370), UDim2.new(), SEA, 0)
	FerryUi.corner(chart, 8)
	local range = 140
	local centres = SceneBoard.sectorCentres(hullPos, wind, range)
	local scale = 170 / (range * 1.6)
	local function toChart(p: Vector3): UDim2
		local d = p - hullPos
		return UDim2.fromOffset(200 + d.X * scale, 185 + d.Z * scale)
	end
	-- hull icon and wind arrow (wind arrow points downwind, as the spray streaks run)
	local hullIcon = FerryUi.frame(
		chart,
		UDim2.fromOffset(46, 12),
		toChart(hullPos),
		Color3.fromRGB(196, 48, 40),
		0
	)
	hullIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	hullIcon.Rotation = 20
	FerryUi.corner(hullIcon, 6)
	local dw = SceneBoard.downwind(wind)
	local arrow = FerryUi.text(
		chart,
		"WIND >>>",
		UDim2.fromOffset(110, 20),
		UDim2.fromOffset(10, 10),
		14,
		C.text,
		FerryUi.Theme.BoldFont
	)
	arrow.Rotation = math.deg(math.atan2(dw.Z, dw.X))
	FerryUi.text(chart, "N ^", UDim2.fromOffset(40, 20), UDim2.new(1, -46, 0, 8), 14, C.text)

	local taskSlots: { [string]: TextButton } = {}
	local unitButtons: { [string]: TextButton } = {}
	local covered = FerryUi.text(
		boardPage,
		"",
		UDim2.fromOffset(360, 22),
		UDim2.new(0, 412, 1, -100),
		16,
		C.text
	)

	local function refreshBoard()
		for id, slot in taskSlots do
			local names = {}
			for u, tid in assign do
				if tid == id then
					table.insert(names, u)
				end
			end
			local def
			for _, t in SceneBoard.Tasks do
				if t.id == id then
					def = t
				end
			end
			slot.Text = `{def.short}\n{if #names > 0 then table.concat(names, ", ") else "(empty)"}`
			slot.BackgroundColor3 = if #names > 0
				then C.ready:Lerp(SEA, 0.4)
				elseif def.required then C.accent:Lerp(SEA, 0.5)
				else C.locked
		end
		for u, b in unitButtons do
			b.BackgroundColor3 = if selected == u
				then C.accent
				elseif assign[u] then C.panelLight
				else C.locked
		end
		covered.Text = `Tasks covered: {math.floor(SceneBoard.tasksCovered(assign) * 100 + 0.5)}%`
	end

	for _, t in SceneBoard.Tasks do
		local slot = FerryUi.button(
			chart,
			t.short,
			UDim2.fromOffset(104, 46),
			toChart(centres[t.id]),
			C.locked,
			function()
				if selected then
					tap()
					FerryUi.playAction("tablet_drag")
					assign[selected] = t.id
					selected = nil
					refreshBoard()
				end
			end
		)
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.TextSize = 13
		slot.BackgroundTransparency = 0.15
		taskSlots[t.id] = slot
	end

	local list =
		FerryUi.frame(boardPage, UDim2.new(0, 360, 1, -110), UDim2.fromOffset(412, 0), SCREEN, 1)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	for _, u in units do
		local b = FerryUi.button(list, u, UDim2.new(1, 0, 0, 34), UDim2.new(), C.locked, function()
			tap()
			selected = if selected == u then nil else u
			refreshBoard()
		end)
		b.TextSize = 15
		unitButtons[u] = b
	end

	local filling = false
	FerryUi.button(
		boardPage,
		"Ask Coastguard to fill gaps",
		UDim2.fromOffset(176, 52),
		UDim2.new(0, 412, 1, -60),
		C.panelLight,
		function()
			if filling or done then
				return
			end
			filling = true
			FerryUi.subtitle(
				gui,
				'[Radio] Coastguard: "Stand by, OSC, working out the NPC units..."',
				3
			)
			task.delay(8, function()
				if done then
					return
				end
				local covers: { [string]: boolean } = {}
				for _, tid in assign do
					covers[tid] = true
				end
				local free = {}
				for _, u in units do
					if not assign[u] and string.find(u, "(NPC)", 1, true) then
						table.insert(free, u)
					end
				end
				for _, t in SceneBoard.Tasks do
					if t.required and not covers[t.id] and #free > 0 then
						assign[table.remove(free, 1) :: string] = t.id
					end
				end
				filling = false
				refreshBoard()
			end)
		end
	)

	local function send()
		if done then
			return
		end
		done = true
		FerryUi.sound(FerryUi.Sounds.radioClick, nil, 0.5)
		FerryUi.playAction("radio_ptt")
		local n = 0
		for _ in assign do
			n += 1
		end
		FerryUi.subtitle(
			gui,
			`[Radio] "All units, OSC. Tasks are on the board. Radio silence except for this incident."`,
			2.5
		)
		task.delay(1.5, function()
			bin.clean()
			finish({
				metrics = {
					reportCorrect = SceneBoard.reportScore(lines, answers),
					tasksCovered = SceneBoard.tasksCovered(assign),
					assigned = n,
				},
			})
		end)
	end
	FerryUi.button(
		boardPage,
		"Send tasks",
		UDim2.fromOffset(170, 52),
		UDim2.new(0, 600, 1, -60),
		C.accent,
		send
	)

	function showBoard()
		boardPage.Visible = true
		sub.Text = if assist
			then "Pick a unit, then tap its task. Cover every sector downwind of the hull."
			else "Assign every unit."
		refreshBoard()
	end

	bin.add(FerryUi.keys({
		[Enum.KeyCode.One] = function()
			pickOption(1)
		end,
		[Enum.KeyCode.Two] = function()
			pickOption(2)
		end,
		[Enum.KeyCode.Three] = function()
			pickOption(3)
		end,
		[Enum.KeyCode.Return] = function()
			if boardPage.Visible then
				send()
			end
		end,
	}))

	FerryUi.playAction("tablet_raise")
	refreshMethane()

	if player:GetAttribute("OpsAutoStub") == true then
		task.delay(1, function()
			for i, l in lines do
				answers[i] = l.answer
			end
			assign = SceneBoard.autoAssign(units)
			send()
		end)
	end

	return function()
		done = true
		bin.clean()
	end
end

return scene_command
