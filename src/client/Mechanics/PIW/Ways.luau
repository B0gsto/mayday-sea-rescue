--!strict
-- PIW/Ways: the three ways to get a Person in the Water aboard (docs/14 section 3). Nothing is
-- explained in text; any way works and the player finds them by trying:
--   Drag   close in and grab them (E / X / the touch Grab button); they hold on and come along
--   Throw  hold right click / LT / the touch Throw button to aim: an arc and a ghost bag show
--          where it lands (green when they can reach it); release to throw; they take the line
--          and are pulled in
--   Come   get close and stop: within 10 s they swim to you (the 10 s rule)
-- The server moves the casualty and checks every grab and throw (src/server/Ops/PiwRescue); this
-- side aims, draws and reads the victim's PiwMode attribute. Done once they hold on at the boat,
-- or the swimmer brings them to the boat or ashore.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InputGlyph =
	require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("InputGlyph"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local Step = require(script.Parent.Step)
local Throw = require(script.Parent.Throw)
local Ui = require(script.Parent.Ui)
local Units = require(script.Parent.Units)
local World = require(script.Parent.World)

local Ways = {}

-- shortcut: mirrors src/server/Ops/PiwWays (GAP_*, GRAB_RANGE, THROW_NEAR); keep in step
Ways.GAP_BOAT = 6
Ways.GAP_SWIMMER = 3
Ways.GRAB_RANGE = 8 -- a stud inside the server's 9, so a shown glyph always works
Ways.THROW_NEAR = 7.5 -- inside the server's 8
Ways.AT_BOAT = 14 -- studs: a swimmer this close to their boat has brought them home
Ways.ARC_DOTS = 14
Ways.READY = Color3.fromRGB(110, 230, 120)
Ways.PLAIN = Color3.fromRGB(240, 240, 235)

local function remote(): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild("Net")
	local r = net and net:FindFirstChild("PIW_Rescue")
	return if r and r:IsA("RemoteEvent") then r else nil
end

function Ways.available(ctx: { [string]: any }): boolean
	-- not World.victim: in the cold open the step starts before the victim has replicated
	local m = ctx.step.mechanicId
	return ctx.operation.kind == "PersonInWater"
		and (m == "recover_throwbag" or m == "recover_swimmer")
		and remote() ~= nil
end

-- Like the server: the boat the player sits in, else their character. (position, onBoat)
local function rescuer(): (Vector3?, boolean)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node:GetPivot().Position, true
		end
		node = node.Parent
	end
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil, false
end

local function onLand(): boolean
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil
		and hum.FloorMaterial ~= Enum.Material.Air
		and hum.FloorMaterial ~= Enum.Material.Water
		and hum:GetState() ~= Enum.HumanoidStateType.Swimming
end

local function localPart(bag: Ui.Bag, size: Vector3, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Transparency = transparency
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
		true, false, false, false, false
	p.Parent = World.camera()
	Ui.add(bag, p)
	return p
end

-- A key glyph chip ("RMB" + label); touch players get a hold button instead.
local function chip(parent: Instance, text: string, pos: UDim2): TextLabel
	local l = Ui.text(parent, text, UDim2.fromOffset(120, 34), pos, 18, true)
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.BackgroundTransparency = 0.35
	l.BackgroundColor3 = Color3.fromRGB(20, 26, 32)
	return l
end

function Ways.run(s: Step.S, ctx: { [string]: any }, method: string)
	local r = remote() :: RemoteEvent
	local victim: Model? = World.victim(ctx) -- may still be replicating; found in the heartbeat
	local opId = ctx.operation.id
	local index = (ctx.casualty and ctx.casualty.index) or ctx.step.casualtyIndex or 1
	local wind = ctx.scene and ctx.scene.windDirection or 0
	local windAccel = Units.windVector(wind)
		* (Throw.WIND_ACCEL * (if ctx.operation.storm then 2 else 1))
	local bag = s.bag
	r:FireServer(opId, index, "arm")

	local way = "come"
	local grabbedAt = -math.huge
	local heldAt: number? = nil
	local aiming = false
	local flying = false
	local misses = 0
	local autoAim = false
	local readyAt = 0
	local lastMode = "idle"
	local dragging = false -- the looping drag clip is on
	Ui.add(bag, function()
		if dragging then
			Ui.handsStop()
		end
	end)

	-- aim visuals: arc dots, the ghost bag and a ring where it lands; the thrown bag and line
	local dots: { Part } = {}
	for i = 1, Ways.ARC_DOTS do
		dots[i] = localPart(bag, Vector3.new(0.2, 0.2, 0.2), Ways.PLAIN, 0.45)
		dots[i].Shape = Enum.PartType.Ball
	end
	local ghost = localPart(bag, Vector3.new(0.8, 1.1, 0.8), Color3.fromRGB(200, 30, 30), 0.6)
	local ring = localPart(bag, Vector3.new(0.1, 3.2, 3.2), Ways.PLAIN, 0.5)
	ring.Shape = Enum.PartType.Cylinder
	local thrown = localPart(bag, Vector3.new(0.8, 1.1, 0.8), Color3.fromRGB(200, 30, 30), 1)
	thrown.Material = Enum.Material.Fabric
	local line = localPart(bag, Vector3.new(0.08, 0.08, 1), Color3.fromRGB(255, 220, 40), 1)
	-- in grab reach the casualty gets a green outline: the world says "take hold now"
	local reach = Instance.new("Highlight")
	reach.FillTransparency = 1
	reach.OutlineColor = Ways.READY
	reach.DepthMode = Enum.HighlightDepthMode.Occluded
	reach.Enabled = false
	reach.Parent = World.camera()
	Ui.add(bag, reach)
	local function showAim(on: boolean)
		for _, d in dots do
			d.Transparency = if on then 0.45 else 1
		end
		ghost.Transparency = if on then 0.6 else 1
		ring.Transparency = if on then 0.5 else 1
	end
	showAim(false)

	-- glyphs and touch buttons (short labels only)
	local throwChip = chip(s.gui, "", UDim2.new(0.5, -70, 1, -24))
	local grabChip = chip(s.gui, "", UDim2.new(0.5, 70, 1, -24))
	Ui.add(
		bag,
		InputGlyph.onDevice(function(d)
			throwChip.Text = if d == "Gamepad"
				then "LT  Throw"
				elseif d == "Touch" then ""
				else "RMB  Throw"
			grabChip.Text = if d == "Gamepad"
				then "X  Grab"
				elseif d == "Touch" then ""
				else "E  Grab"
		end)
	)
	throwChip.Visible = not Ui.isTouch()
	local throwBtn = Ui.button(
		s.gui,
		"Throw",
		UDim2.fromOffset(Onboarding.TOUCH.throw, Onboarding.TOUCH.throw),
		UDim2.new(1, -32, 1, -170),
		function() end
	)
	throwBtn.AnchorPoint = Vector2.new(1, 1)
	throwBtn.Visible = Ui.isTouch()
	local grabBtn = Ui.button(
		s.gui,
		"Grab",
		UDim2.fromOffset(Onboarding.TOUCH.grab, Onboarding.TOUCH.grab),
		UDim2.new(1, -208, 1, -170),
		function() end
	)
	grabBtn.AnchorPoint = Vector2.new(1, 1)
	Ui.add(bag, throwBtn)
	Ui.add(bag, grabBtn)

	local function aim(): (Vector3, Vector3, Vector3, number)
		local cf = World.camera().CFrame
		-- from the rescuer's hand, not the camera: the server measures the line from there
		local from = rescuer()
		local o = if from
			then from + Vector3.new(0, 2, 0)
			else cf.Position + cf.LookVector * 1 + Vector3.new(0, -0.7, 0)
		local cas = World.casualtyPos(ctx, victim)
		local waterY = cas.Y
		local dir: Vector3, power: number
		if autoAim then
			-- docs/15: after two misses, put the bag just beyond them and a little upwind
			local to = Units.unitOr(Units.flat(cas - o), Units.flat(cf.LookVector))
			local past = cas + to * 5 - Units.windVector(wind) * 2
			dir = Units.unitOr(Units.flat(past - o), to)
			power = Throw.powerFor(Units.flatDistance(o, past), Workspace.Gravity)
		else
			local target = World.screenToWater(nil, waterY)
			dir = Units.unitOr(
				Units.flat(if target then target - o else cf.LookVector),
				Units.flat(cf.LookVector)
			)
			power = if target
				then Throw.powerFor(Units.flatDistance(o, target), Workspace.Gravity)
				else 1
		end
		local v = Throw.velocity(dir, power)
		local landing, tEnd = Throw.land(o, v, waterY, Workspace.Gravity, windAccel)
		return o, v, landing, tEnd
	end

	local function grab()
		local pos, onBoat = rescuer()
		if not pos then
			return
		end
		local gap = if onBoat then Ways.GAP_BOAT else Ways.GAP_SWIMMER
		if Units.flatDistance(pos, World.casualtyPos(ctx, victim)) <= gap + Ways.GRAB_RANGE then
			grabbedAt = os.clock()
			Ui.hands("grab")
			r:FireServer(opId, index, "grab")
		end
	end

	local function release()
		if not aiming then
			return
		end
		aiming = false
		showAim(false)
		flying = true
		autoAim = Onboarding.throwAssist(misses, s.assist)
		Ui.hands("throw_underarm")
		local o, v, landing, tEnd = aim()
		local t = 0
		thrown.Transparency, line.Transparency = 0, 0
		local conn: RBXScriptConnection? = nil
		conn = RunService.Heartbeat:Connect(function(dt)
			t = math.min(t + dt, tEnd)
			local p = if t >= tEnd
				then landing
				else o + v * t + Units.flat(windAccel) * (0.5 * t * t) - Vector3.new(
					0,
					0.5 * Workspace.Gravity * t * t,
					0
				)
			thrown.Position = p
			line.Size = Vector3.new(0.08, 0.08, math.max(0.1, (p - o).Magnitude))
			line.CFrame = CFrame.lookAt((o + p) / 2, p)
			if t < tEnd then
				return
			end
			if conn then
				conn:Disconnect()
			end
			flying = false
			if Units.flatDistance(landing, World.casualtyPos(ctx, victim)) <= Ways.THROW_NEAR then
				Ui.hands("haul_left")
				r:FireServer(opId, index, "throw", landing)
			else
				readyAt = os.clock() + 1.5 -- recoil the line, throw again
				misses += 1
				autoAim = Onboarding.throwAssist(misses, s.assist)
				Ui.hands("coil_line")
				task.delay(1.2, function()
					if not s.finished and not flying and lastMode ~= "line" then
						thrown.Transparency, line.Transparency = 1, 1
					end
				end)
			end
		end)
		Ui.add(bag, conn)
	end

	local function beginAim()
		if flying or aiming or os.clock() < readyAt or lastMode == "line" or lastMode == "held" then
			return
		end
		aiming = true
		Ui.hands("hold_throwbag")
	end

	Ui.bind(bag, "ThrowAim", function(state)
		if state == "Begin" then
			beginAim()
		elseif state == "End" then
			release()
		end
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	Ui.bind(bag, "Grab", function(state)
		if state == "Begin" then
			grab()
		end
	end, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	throwBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			beginAim()
		end
	end)
	throwBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	grabBtn.Activated:Connect(grab)

	Step.heartbeat(s, function()
		if not (victim and victim.Parent) then
			victim = World.victim(ctx)
		end
		local cas = World.casualtyPos(ctx, victim)
		local pos, onBoat = rescuer()
		local rawMode = victim and victim:GetAttribute("PiwMode")
		local mode: string = if type(rawMode) == "string" then rawMode else "idle"
		if mode ~= lastMode then
			if mode == "line" then
				way = "throw"
			elseif mode == "held" and lastMode ~= "line" and os.clock() - grabbedAt < 1.5 then
				way = "drag"
				dragging = true
				Ui.hands("drag", { loop = true }) -- until they are home (finish) or the step ends
			elseif mode == "swim" then
				Ui.hands("wave") -- calling them in
			end
			if dragging and mode ~= "held" then
				dragging = false
				Ui.handsStop() -- they let go
			end
			heldAt = if mode == "held" then os.clock() else nil
			lastMode = mode
		end
		-- the line runs from the thrower to the casualty while they hold it
		if mode == "line" or (mode == "held" and way == "throw" and not onBoat) then
			local o = (pos or cas) + Vector3.new(0, 1, 0)
			thrown.Transparency, line.Transparency = 0, 0
			thrown.Position = cas + Vector3.new(0.6, 0, 0)
			line.Size = Vector3.new(0.08, 0.08, math.max(0.1, (cas - o).Magnitude))
			line.CFrame = CFrame.lookAt((o + cas) / 2, cas)
		elseif mode == "held" and not flying then
			thrown.Transparency, line.Transparency = 1, 1
		end
		local gap = if onBoat then Ways.GAP_BOAT else Ways.GAP_SWIMMER
		local inReach = pos ~= nil
			and mode ~= "held"
			and Units.flatDistance(pos, cas) <= gap + Ways.GRAB_RANGE
		reach.Adornee = victim
		reach.Enabled = inReach and victim ~= nil
		grabChip.Visible = inReach and not Ui.isTouch()
		grabBtn.Visible = inReach and Ui.isTouch()
		local canThrow = mode ~= "held" and mode ~= "line"
		throwChip.Visible = canThrow and not Ui.isTouch() and not aiming
		throwBtn.Visible = canThrow and Ui.isTouch()
		if aiming then
			local o, v, landing, tEnd = aim()
			local pts = Throw.arc(o, v, Workspace.Gravity, windAccel, tEnd, Ways.ARC_DOTS - 1)
			local hit = Units.flatDistance(landing, cas) <= Ways.THROW_NEAR
			for i, d in dots do
				d.Position = pts[i]
				d.Color = if hit then Ways.READY else Ways.PLAIN
			end
			ghost.Position = landing + Vector3.new(0, 0.4, 0)
			ring.CFrame = CFrame.new(landing) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Color = if hit then Ways.READY else Ways.PLAIN
		end
		-- done: holding on at the boat, or brought to the boat or the shore by a swimmer
		local home = onBoat
			or onLand()
			or (
				pos ~= nil
				and World.vehicle(ctx) ~= nil
				and Units.flatDistance(pos, (World.vehicle(ctx) :: Model):GetPivot().Position)
					<= Ways.AT_BOAT
			)
		if mode == "held" and heldAt and os.clock() - heldAt > 0.8 and home then
			dragging = false
			Ui.hands("lift_aboard")
			-- no method is picked any more (no choice UI): whichever way worked counts as the book one
			local score = (if way == "come" then 0.7 else 1)
				- math.max(0, Step.elapsed(s) - 30) / 90
			Step.finish(s, {
				metrics = {
					method = method,
					score = math.floor(math.clamp(score, 0.2, 1) * 100 + 0.5) / 100,
				},
			})
		end
	end)
end

return Ways
