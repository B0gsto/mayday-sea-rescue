--!strict
-- Mechanic "hull_knock" (docs/09 section 7 step 5): the hull team works along the upturned hull of
-- the Gale Queen, knocks a pattern of three, then stays still and listens. Survivors in the air
-- pocket answer with taps from inside: loud right over their compartment, faint one compartment
-- away (with a direction), nothing further off. Every reply is a 3D sound, a subtitle and a
-- visual ripple on the hull. The team marks the compartment and radios it.
-- First person on foot: the player's own position along the hull picks the compartment; when the
-- character is not on the hull (in the water, on a boat, or still climbing) A/D walk a cursor along it.
-- Result metrics: rightCompartment (bool), compartment (number, the server can recheck it with
-- HullKnock.pocketCompartment), knocks (patterns knocked), listens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FerryRig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("FerryRig"))
local FerryUi = require(script.Parent:WaitForChild("Ferry"):WaitForChild("FerryUi"))
local HullKnock = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("HullKnock")
)

local C = FerryUi.Theme.Colors

local hull_knock = {}

function hull_knock.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local bin = FerryUi.bin()
	local assist = ctx.isAssist == true
	local opId: string = ctx.operation.id
	local pocket = HullKnock.pocketCompartment(opId)

	-- hull frame: centre, length axis (local Z). The C2 Gale Queen (RescueService) carries a HullAxis attachment
	-- at midships on her roll axis in the asset's orientation, a HullLength attribute and the five ATT_Knock_nn
	-- compartment marks on her up (keel) side; the greybox Hull part is its own frame (Size.Z long).
	local ferry = FerryUi.findFerry(opId)
	local hullPart = ferry and ferry:FindFirstChild("Hull", true)
	local axis = hullPart and hullPart:FindFirstChild("HullAxis")
	local length = 60
	local function hullCFrame(): CFrame
		if axis and axis:IsA("Attachment") then
			return axis.WorldCFrame
		end
		if hullPart and hullPart:IsA("BasePart") then
			return hullPart.CFrame
		end
		return CFrame.new(ctx.operation.position + Vector3.new(0, 3, 0))
	end
	local hullLength = ferry and ferry:GetAttribute("HullLength")
	if type(hullLength) == "number" then
		length = hullLength
	elseif hullPart and hullPart:IsA("BasePart") then
		length = hullPart.Size.Z
	end
	local function compartmentPos(i: number): Vector3
		local mark = ferry and ferry:FindFirstChild(FerryRig.knockName(i), true)
		if mark and mark:IsA("Attachment") then
			return mark.WorldPosition + Vector3.new(0, 1, 0)
		end
		return (hullCFrame() * CFrame.new(0, 0, HullKnock.offsetAlong(i, length))).Position
			+ Vector3.new(0, 3, 0)
	end

	local cursor = 0 -- studs along the hull when the character is off it
	local function along(): (number, boolean)
		local _, root = FerryUi.character()
		if root then
			local rel = hullCFrame():PointToObjectSpace(root.Position)
			if
				math.abs(rel.Z) <= length / 2 + 4
				and Vector3.new(rel.X, rel.Y, 0).Magnitude < 16
			then
				return rel.Z, true
			end
		end
		return cursor, false
	end

	---------------------------------------------------------------- UI

	local gui = bin.add(FerryUi.screen("FerryHullKnock"))
	local panel = FerryUi.frame(gui, UDim2.fromOffset(460, 150), UDim2.new(0.5, -230, 1, -200))
	FerryUi.corner(panel)
	FerryUi.text(
		panel,
		"Hull search",
		UDim2.new(1, -24, 0, 24),
		UDim2.fromOffset(12, 8),
		20,
		C.text,
		FerryUi.Theme.HeaderFont
	)
	local where =
		FerryUi.text(panel, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 36), 17, C.textDim)
	local strip =
		FerryUi.frame(panel, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 62), C.locked, 0)
	FerryUi.corner(strip, 6)
	local cells: { Frame } = {}
	for i = 1, HullKnock.Count do
		local cell = FerryUi.frame(
			strip,
			UDim2.new(1 / HullKnock.Count, -4, 1, -4),
			UDim2.new((i - 1) / HullKnock.Count, 2, 0, 2),
			C.panelLight,
			0.4
		)
		FerryUi.corner(cell, 4)
		FerryUi.text(
			cell,
			HullKnock.Compartments[i].short,
			UDim2.fromScale(1, 1),
			UDim2.new(),
			12,
			C.text
		).TextXAlignment =
			Enum.TextXAlignment.Center
		cells[i] = cell
	end
	local status =
		FerryUi.text(panel, "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 90), 16, C.text)
	local keysHint = FerryUi.text(
		panel,
		`{FerryUi.keyLabel("Click", "A")} Knock    {FerryUi.keyLabel("F", "X")} Mark    {FerryUi.keyLabel(
			"A/D",
			"D-pad"
		)} Move`,
		UDim2.new(1, -24, 0, 18),
		UDim2.fromOffset(12, 118),
		14,
		C.textDim
	)
	keysHint.Visible = not FerryUi.isTouch()

	---------------------------------------------------------------- knock and listen

	local knockTimes: { number } = {}
	local listeningUntil = 0
	local patterns, listens = 0, 0
	local heard: { [number]: string } = {}
	local done = false

	local function current(): number
		local a = along()
		return HullKnock.compartmentAt(a, length)
	end

	local function listen(at: number)
		listens += 1
		listeningUntil = os.clock() + HullKnock.ListenSeconds
		status.Text = "Listening..."
		local _, root = FerryUi.character()
		local startPos = if root then root.Position else nil
		task.delay(1.1, function()
			if done then
				return
			end
			local _, r2 = FerryUi.character()
			if startPos and r2 and (r2.Position - startPos).Magnitude > 3 then
				status.Text = "Too noisy. Knock again"
				return
			end
			local reply = HullKnock.reply(at, pocket)
			if reply.strength > 0 then
				local src = compartmentPos(pocket)
				for k = 0, 2 do
					task.delay(k * 0.45, function()
						if done then
							return
						end
						FerryUi.sound(FerryUi.Sounds.replyTap, src, 0.3 + 0.7 * reply.strength)
						FerryUi.ripple(src, reply.strength, Color3.fromRGB(255, 220, 140))
					end)
				end
			end
			FerryUi.subtitle(gui, HullKnock.subtitle(reply), 3)
			heard[at] = reply.kind
			if assist then
				cells[at].BackgroundColor3 = if reply.kind == "Loud"
					then C.ready
					elseif reply.kind == "Faint" then C.gold
					else C.locked
			end
			status.Text = if reply.kind == "Loud" then "Answer! Mark it" else "Move on"
		end)
	end

	local function knock()
		if done or os.clock() < listeningUntil then
			return
		end
		local at = current()
		FerryUi.playAction("hull_knock")
		local p = compartmentPos(at)
		FerryUi.sound(FerryUi.Sounds.knock, p, 0.9)
		FerryUi.ripple(p, 0.3, Color3.fromRGB(200, 220, 240))
		table.insert(knockTimes, os.clock())
		while #knockTimes > 3 do
			table.remove(knockTimes, 1)
		end
		if #knockTimes < 3 then
			status.Text = string.rep("KNOCK  ", #knockTimes)
			return
		end
		local ok, why = HullKnock.rhythm(knockTimes)
		table.clear(knockTimes)
		if not ok then
			status.Text = if assist then why or "" else "No clear pattern."
			return
		end
		patterns += 1
		listen(at)
	end

	local function markHere()
		if done then
			return
		end
		done = true
		local at = current()
		local right = at == pocket
		FerryUi.playAction("hull_mark_chalk")
		local name = HullKnock.Compartments[at].name
		FerryUi.sound(FerryUi.Sounds.radioClick, nil, 0.5)
		FerryUi.subtitle(gui, `"Survivors: {name}, compartment {at}. Over."`, 3, "PLAYER_M")
		task.delay(1.2, function()
			bin.clean()
			finish({
				metrics = {
					rightCompartment = right,
					compartment = at,
					knocks = patterns,
					listens = listens,
				},
			})
		end)
	end

	local touchDir = 0
	bin.add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			knock()
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
			markHere()
		end
	end))
	if UserInputService.TouchEnabled then
		FerryUi.button(
			panel,
			"Knock",
			UDim2.fromOffset(110, 52),
			UDim2.new(1, -240, 0, -60),
			C.accent,
			knock
		)
		FerryUi.button(
			panel,
			"Mark",
			UDim2.fromOffset(110, 52),
			UDim2.new(1, -120, 0, -60),
			C.panelLight,
			markHere
		)
		-- move along the hull when off it (keyboard A/D, gamepad D-pad)
		for i, arrow in { "<", ">" } do
			local b = FerryUi.button(
				panel,
				arrow,
				UDim2.fromOffset(52, 52),
				UDim2.fromOffset((i - 1) * 60, -60),
				C.panelLight,
				function() end
			)
			local dir = if i == 1 then -1 else 1
			b.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					touchDir = dir
				end
			end)
			b.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					touchDir = 0
				end
			end)
		end
	end

	bin.add(RunService.RenderStepped:Connect(function(dt)
		local a, onHull = along()
		if not onHull then
			local dir = touchDir
			local pad = Enum.UserInputType.Gamepad1
			if UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.DPadLeft) then
				dir -= 1
			end
			if UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.DPadRight) then
				dir += 1
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				dir -= 1
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				dir += 1
			end
			cursor = math.clamp(cursor + dir * 9 * dt, -length / 2, length / 2)
			a = cursor
		end
		local at = HullKnock.compartmentAt(a, length)
		where.Text = HullKnock.Compartments[at].name
		for i, cell in cells do
			cell.BackgroundTransparency = if i == at then 0 else 0.4
		end
	end))

	if Players.LocalPlayer:GetAttribute("OpsAutoStub") == true then
		task.delay(1, function()
			cursor = HullKnock.offsetAlong(pocket, length)
			markHere()
		end)
	end

	return function()
		done = true
		bin.clean()
	end
end

return hull_knock
