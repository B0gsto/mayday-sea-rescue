--!strict
-- DevController: the client half of the dev board (DevService). Inert until the server sends
-- Dev_Grant (only to allowed players). Then: F8, chat "/dev", gamepad L1 + R1 + Select, or the
-- small corner button on touch toggles the panel (UI/DevBoard). Fly, noclip, walk speed and
-- click-teleport aim run here (the character is client-owned); everything else is a Dev_Action
-- the server re-checks.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DevBoard = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("DevBoard"))

local DevController = {}
DevController.Priority = 200

local player = Players.LocalPlayer
local board: DevBoard.Board? = nil
local action: RemoteFunction? = nil
local targetId = player.UserId

local fly, noclip, clickTp = false, false, false
local flySpeed, walkSpeed = 80, nil :: number?
local flyParts: { Instance } = {}

local function call(name: string, args: { any }): (boolean, string, any)
	local remote = action
	if not remote then
		return false, "", nil
	end
	local ok, success, text, data = pcall(remote.InvokeServer, remote, name, args)
	local result = if ok then success == true else false
	local msg = if ok then tostring(text or "") else "Error"
	if board then
		board.setStatus(`{if result then "✅" else "❌"} {name}: {msg}`)
	end
	return result, msg, data
end

local function humanoidRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"),
		character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stopFly()
	for _, p in flyParts do
		p:Destroy()
	end
	flyParts = {}
	local humanoid = humanoidRoot()
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startFly()
	stopFly()
	local humanoid, root = humanoidRoot()
	if not (humanoid and root) then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "DevFly"
	att.Parent = root
	local vel = Instance.new("LinearVelocity")
	vel.Attachment0 = att
	vel.MaxForce = math.huge
	vel.VectorVelocity = Vector3.zero
	vel.RelativeTo = Enum.ActuatorRelativeTo.World
	vel.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.RigidityEnabled = true
	align.Parent = root
	flyParts = { att, vel, align }
	humanoid.PlatformStand = true
end

local function flyStep()
	local humanoid, root = humanoidRoot()
	local vel = flyParts[2] :: any
	local align = flyParts[3] :: any
	if not (humanoid and root and vel and align and vel.Parent) then
		if fly then
			startFly() -- respawned: pick it back up
		end
		return
	end
	local cam = Workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local right = Vector3.new(-flat.Z, 0, flat.X)
	-- MoveDirection is the thumbstick / WASD / touch stick in world space, flat
	local move = humanoid.MoveDirection
	local forward, side = move:Dot(flat), move:Dot(right)
	local up = 0
	if
		UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	then
		up += 1
	end
	if
		UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.Q)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB)
	then
		up -= 1
	end
	local dir = look * forward + cam.CFrame.RightVector * side + Vector3.yAxis * up
	vel.VectorVelocity = if dir.Magnitude > 0.01 then dir.Unit * flySpeed else Vector3.zero
	align.CFrame = CFrame.lookAt(Vector3.zero, flat)
end

local function targetName(): string
	if targetId == player.UserId then
		return "Me"
	end
	local p = Players:GetPlayerByUserId(targetId)
	return if p then p.DisplayName else "Me"
end

local function toggle()
	local b = board
	if b then
		b.setVisible(not b.visible())
	end
end

local function fill(b: DevBoard.Board)
	local lists = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DevConfig")
	) :: any
	local function me(): number
		return player.UserId
	end
	local function tgt(): number
		if not Players:GetPlayerByUserId(targetId) then
			targetId = player.UserId
		end
		return targetId
	end
	b.onTarget(function()
		local items = {}
		for _, p in Players:GetPlayers() do
			table.insert(items, {
				text = if p == player then `{p.DisplayName} (me)` else p.DisplayName,
				value = p.UserId,
			})
		end
		DevBoard.pick(b, items, function(id)
			targetId = id
			b.setTarget(targetName())
		end)
	end)

	-- Move
	local page = b.tab("🏃 Move")
	local g = DevBoard.section(page, "Me")
	DevBoard.toggle(g, "🕊 Fly", function(on)
		fly = on
		if on then
			startFly()
		else
			stopFly()
		end
	end)
	DevBoard.toggle(g, "👻 Noclip", function(on)
		noclip = on
	end)
	DevBoard.toggle(g, "🛡 God", function(on)
		call("god", { on })
	end)
	DevBoard.toggle(g, "👁 Invisible", function(on)
		call("invisible", { on })
	end)
	DevBoard.slider(page, "Fly speed", 10, 400, flySpeed, function(v)
		flySpeed = v
	end)
	DevBoard.slider(page, "Walk speed", 4, 200, 16, function(v)
		walkSpeed = v
	end)
	g = DevBoard.section(page, "Walk")
	DevBoard.button(g, "🚶 Normal walk", function()
		walkSpeed = nil
		local humanoid = humanoidRoot()
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end)

	-- Teleport
	page = b.tab("📍 Teleport")
	g = DevBoard.section(page, "Players")
	DevBoard.button(g, "👉 To target", function()
		call("tpPlayer", { tgt() })
	end)
	DevBoard.button(g, "🧲 Bring target", function()
		call("bring", { tgt() })
	end)
	DevBoard.toggle(g, "🖱 Click teleport", function(on)
		clickTp = on
	end)
	g = DevBoard.section(page, "Spots")
	for _, id in lists.SpotOrder do
		DevBoard.button(g, `📍 {lists.Spots[id].label}`, function()
			call("tpSpot", { id })
		end)
	end

	-- Spawn
	page = b.tab("🚤 Spawn")
	g = DevBoard.section(page, "Vehicles (target)")
	for _, id in lists.Vehicles do
		DevBoard.button(g, `🚤 {id}`, function()
			call("vehicle", { tgt(), id })
		end)
	end
	g = DevBoard.section(page, "Pets (target)")
	DevBoard.button(g, "🐕 Bosun here", function()
		call("bosun", { tgt() })
	end)
	for _, id in lists.Species do
		DevBoard.button(g, `🐾 {id}`, function()
			call("pet", { tgt(), id })
		end)
	end

	-- Ops
	page = b.tab("🆘 Ops")
	g = DevBoard.section(page, "Current (target)")
	DevBoard.button(g, "✅ Complete", function()
		call("opEnd", { tgt(), true })
	end)
	DevBoard.button(g, "❌ Cancel", function()
		call("opEnd", { tgt(), false })
	end)
	g = DevBoard.section(page, "Start (target)")
	for _, id in lists.Ops do
		DevBoard.button(g, `🆘 {id}`, function()
			call("op", { tgt(), id })
		end)
	end

	-- World
	page = b.tab("🌩 World")
	g = DevBoard.section(page, "Weather")
	DevBoard.button(g, "🌧 Storm", function()
		call("storm", { "Storm" })
	end)
	DevBoard.button(g, "🌪 Great storm", function()
		call("storm", { "GreatStorm" })
	end)
	DevBoard.button(g, "🌤 Clear", function()
		call("storm", { "Calm" })
	end)
	DevBoard.slider(page, "Time", 0, 24, 14, function(v)
		call("clock", { math.floor(v * 4 + 0.5) / 4 })
	end)
	g = DevBoard.section(page, "Events")
	for _, id in lists.Events do
		DevBoard.button(g, `🟢 {id}`, function()
			call("event", { id, true })
		end)
		DevBoard.button(g, `🔴 {id}`, function()
			call("event", { id, false })
		end)
	end
	g = DevBoard.section(page, "Lighthouses (target)")
	for _, id in lists.Lights do
		DevBoard.button(g, `💡 Relight {id}`, function()
			call("light", { tgt(), id, true })
		end)
		DevBoard.button(g, `🌑 Reset {id}`, function()
			call("light", { tgt(), id, false })
		end)
	end

	-- Progress
	page = b.tab("⭐ Progress")
	g = DevBoard.section(page, "Give (target)")
	for _, n in { 1000, 10000, 100000 } do
		DevBoard.button(g, `💰 +{n} Cash`, function()
			call("award", { tgt(), n, 0 })
		end)
		DevBoard.button(g, `⭐ +{n} Rep`, function()
			call("award", { tgt(), 0, n })
		end)
	end
	DevBoard.button(g, "🔓 Unlock all", function()
		call("unlockAll", { tgt() })
	end)
	g = DevBoard.section(page, "Rank (target)")
	for i = 1, lists.RankCount do
		DevBoard.button(g, `🎖 Rank {i}`, function()
			call("rank", { tgt(), i })
		end)
	end
	g = DevBoard.section(page, "Certifications (target)")
	for _, id in lists.Certs do
		DevBoard.button(g, `📜 {id}`, function()
			call("cert", { tgt(), id })
		end)
	end
	g = DevBoard.section(page, "Passes, test owned (target)")
	for _, id in lists.Passes do
		DevBoard.button(g, `🎟 {id}`, function()
			call("pass", { tgt(), id })
		end)
	end
	g = DevBoard.section(page, "Start from scratch (hold)")
	DevBoard.hold(g, "🧨 Reset me", function()
		call("reset", { me() })
	end)
	DevBoard.hold(g, "🧨 Reset target", function()
		call("reset", { tgt() })
	end)

	-- Server
	page = b.tab("🖥 Server")
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, -8, 0, 0)
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.TextColor3 = Color3.fromHex("ECEDEA")
	info.Font = Enum.Font.BuilderSans
	info.TextSize = 16
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Text = ""
	info.LayoutOrder = -1
	info.Parent = page
	g = DevBoard.section(page, "Actions")
	DevBoard.button(g, "🔄 Refresh", function()
		local ok, _, data = call("stats", {})
		if ok and type(data) == "table" then
			local names = {}
			for _, p in data.players do
				table.insert(names, `{p.name}{if p.dev then " (dev)" else ""}`)
			end
			info.Text = table.concat({
				`Players {#data.players}/{data.maxPlayers}: {table.concat(names, ", ")}`,
				`Memory {data.memoryMb} MB, heartbeat {data.fps} fps`,
				`Uptime {data.uptime // 60} min, place v{data.placeVersion}{if data.studio
					then " (Studio)"
					else ""}`,
				`Job {data.jobId}`,
			}, "\n")
		end
	end)
	DevBoard.hold(g, "👢 Kick target", function()
		call("kick", { tgt() })
	end)
	b.setTarget(targetName())
end

local function onGrant(payload: any)
	if board then
		if type(payload) == "table" and payload.toggle then
			toggle()
		end
		return
	end
	local b = DevBoard.build(player:WaitForChild("PlayerGui"), {
		"🏃 Move",
		"📍 Teleport",
		"🚤 Spawn",
		"🆘 Ops",
		"🌩 World",
		"⭐ Progress",
		"🖥 Server",
	})
	board = b
	fill(b)
	if UserInputService.TouchEnabled then
		local corner = Instance.new("ScreenGui")
		corner.Name = "DevBoardButton"
		corner.ResetOnSpawn = false
		corner.DisplayOrder = 59
		corner.Parent = player:WaitForChild("PlayerGui")
		local button = Instance.new("TextButton")
		button.Text = "🛠"
		button.TextSize = 18
		button.BackgroundColor3 = Color3.fromHex("26323A")
		button.BackgroundTransparency = 0.3
		button.Size = UDim2.fromOffset(36, 36)
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -8, 0, 52)
		button.Parent = corner
		button.Activated:Connect(toggle)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.F8 and not processed then
			toggle()
		elseif
			clickTp
			and not processed
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local cam = Workspace.CurrentCamera
			local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { player.Character :: Instance }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hit = Workspace:Raycast(ray.Origin, ray.Direction * 4000, params)
			if hit then
				call("tpPos", { hit.Position })
			end
		end
	end)
	-- gamepad: L1 + R1 + Select (Select alone still opens the map)
	ContextActionService:BindActionAtPriority("DevBoardPad", function(_, state)
		local pad = Enum.UserInputType.Gamepad1
		if
			state == Enum.UserInputState.Begin
			and UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.ButtonL1)
			and UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.ButtonR1)
		then
			toggle()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonSelect)
	RunService.Stepped:Connect(function()
		local character = player.Character
		if noclip and character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		if fly then
			flyStep()
		end
		local speed = walkSpeed
		local humanoid = humanoidRoot()
		if speed and humanoid and humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end)
end

function DevController.Init()
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Net")
		local grant = net:WaitForChild("Dev_Grant", 60) :: RemoteEvent?
		action = net:WaitForChild("Dev_Action", 60) :: RemoteFunction?
		if grant then
			grant.OnClientEvent:Connect(onGrant)
		end
	end)
end

return DevController
