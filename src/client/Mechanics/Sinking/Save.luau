--!strict
-- sinking_save (docs/09 section 8.1): keep her afloat. Three world actions, all of them right:
-- run the salvage pump on the after deck, plug the swirl on her quarter, or take the crew off
-- the cabin roof before she goes. The pump is a rhythm (press on the pulsing ring; the water
-- falls while the beat is kept, rises when it stops); the bung is a hold (the jet weakens as it
-- goes in, and the progress never resets). Whichever is used first ends the step. No menu, no
-- explanation. Keyboard E, gamepad A, mouse/touch on the ring and bung.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent.Parent
local Find = require(script.Parent:WaitForChild("Find"))
local InputGlyph = require(Client:WaitForChild("UI"):WaitForChild("InputGlyph"))
local SinkingVessel =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SinkingVessel"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))

local Save = {}

Save.BEAT_SECONDS = SinkingVessel.Rates.Beat
Save.PUMP_STROKES = SinkingVessel.Rates.PumpStrokes
Save.PLUG_SECONDS = SinkingVessel.Rates.PlugSeconds

local RING_X, RING_Y, RING_SIZE = 380, 196, 88

local function effortRemote(): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("Sinking_Effort")
	return if remote and remote:IsA("RemoteEvent") then remote else nil
end

-- The pump/bung controls: a round target with a pulse inside it (the pump) or a fill (the bung).
local function roundButton(parent: Instance, name: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromOffset(RING_X, RING_Y)
	b.Size = UDim2.fromOffset(RING_SIZE, RING_SIZE)
	b.BackgroundColor3 = Ui.Theme.Colors.panelLight
	b.BackgroundTransparency = 0.25
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.Visible = false
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ui.Theme.Colors.gold
	stroke.Thickness = 2
	stroke.Transparency = 0.45
	stroke.Parent = b
	return b
end

function Save.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "SinkingSave", 244)
	if Step.autoStub(s, { pump = 1, saved = 1 }) then
		return Step.cleanup(s)
	end
	local scene = Find.scene(ctx)
	local hull = Find.part(scene, "Hull")
	local meter = Ui.meter(s.panel, "Waterline", UDim2.fromOffset(12, 78), 420)
	local line = Step.line(s, "Pump · plug · crew off", 56)
	local tilt = Instance.new("Frame")
	tilt.AnchorPoint = Vector2.new(0.5, 0.5)
	tilt.Position = UDim2.fromOffset(74, 150)
	tilt.Size = UDim2.fromOffset(86, 10)
	tilt.BackgroundColor3 = Color3.fromRGB(230, 230, 225)
	tilt.BorderSizePixel = 0
	tilt.Rotation = 0
	tilt.Parent = s.panel
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BackgroundColor3 = Color3.fromRGB(230, 90, 60)
	dot.BorderSizePixel = 0
	dot.Parent = tilt

	-- pump: the ring pulses on the beat; press it there.
	local ring = roundButton(s.panel, "PumpBeat")
	local pulse = Instance.new("Frame")
	pulse.AnchorPoint = Vector2.new(0.5, 0.5)
	pulse.Position = UDim2.fromScale(0.5, 0.5)
	pulse.Size = UDim2.fromScale(0.42, 0.42)
	pulse.BackgroundTransparency = 1
	pulse.Parent = ring
	local pulseCorner = Instance.new("UICorner")
	pulseCorner.CornerRadius = UDim.new(1, 0)
	pulseCorner.Parent = pulse
	local pulseStroke = Instance.new("UIStroke")
	pulseStroke.Color = Ui.Theme.Colors.gold
	pulseStroke.Thickness = 4
	pulseStroke.Transparency = 0.55
	pulseStroke.Parent = pulse
	local dotMark = Instance.new("Frame")
	dotMark.AnchorPoint = Vector2.new(0.5, 0.5)
	dotMark.Position = UDim2.fromScale(0.5, 0.5)
	dotMark.Size = UDim2.fromOffset(10, 10)
	dotMark.BackgroundColor3 = Ui.Theme.Colors.gold
	dotMark.BorderSizePixel = 0
	dotMark.Parent = ring
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dotMark
	Ui.add(s.bag, ring)
	local chip = InputGlyph.chip(ring, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 1, 6)

	-- plug: hold the round target; the fill shows how far the bung is in.
	local bung = roundButton(s.panel, "PlugHold")
	bung.BackgroundColor3 = Ui.Theme.Colors.accent
	bung.BackgroundTransparency = 0.4
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Ui.Theme.Colors.gold
	fill.BackgroundTransparency = 0.35
	fill.BorderSizePixel = 0
	fill.Parent = bung
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	Ui.add(s.bag, bung)
	local bungChip = InputGlyph.chip(bung, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
	bungChip.AnchorPoint = Vector2.new(0.5, 0)
	bungChip.Position = UDim2.new(0.5, 0, 1, 6)

	local done = false
	local pumpPrompt: ProximityPrompt? = nil
	local leakPrompt: ProximityPrompt? = nil

	local function send(action: string, value: any?)
		local remote = effortRemote()
		local opId = ctx.operation and ctx.operation.id
		if remote and type(opId) == "string" then
			remote:FireServer(opId, action, value)
		end
	end

	local function finishSave(metrics: { [string]: any })
		if done then
			return
		end
		done = true
		Ui.handsStop()
		Step.finish(s, { metrics = metrics })
	end

	-- Pump rhythm state.
	local pumping = false
	local strokes = 0
	local beatT0 = 0
	local lastHit = -1
	local lastPulse = -1
	local pulseAt = -10
	local hitAt = -10

	local function startPump()
		if pumping or done then
			return
		end
		pumping = true
		if pumpPrompt then
			pumpPrompt.Enabled = false
		end
		if leakPrompt then
			leakPrompt.Enabled = false
		end
		strokes = 0
		lastHit = -1
		lastPulse = -1
		beatT0 = os.clock() + 1.6
		ring.Visible = true
		bung.Visible = false
		line.Text = "On the beat"
		Ui.hands("pump", { loop = true })
		send("start")
	end

	local function hit()
		if not pumping or done then
			return
		end
		local now = os.clock()
		local k = (now - beatT0) / Save.BEAT_SECONDS
		local index = math.floor(k + 0.5)
		local off = (k - index) * Save.BEAT_SECONDS
		if index < 0 or index <= lastHit or math.abs(off) > Save.BEAT_SECONDS * 0.34 then
			return -- a miss only costs time: the water rises, nothing resets
		end
		lastHit = index
		strokes += 1
		hitAt = now
		send("beat")
		if strokes >= Save.PUMP_STROKES then
			pumping = false
			ring.Visible = false
			finishSave({ pump = 1, saved = 1, pumpStrokes = strokes })
		end
	end

	ring.Activated:Connect(hit)
	Ui.bind(s.bag, "PumpBeat", function(state)
		if state == "Begin" then
			hit()
		end
	end, Enum.KeyCode.E, Enum.KeyCode.ButtonA)

	-- Bung hold state.
	local plugging = false
	local holding = false
	local setBung: ((number) -> ())? = nil

	local function setHold(on: boolean)
		if not plugging or done then
			return
		end
		if on == holding then
			return
		end
		holding = on
		send("plug", on)
		if on then
			Ui.hands("plug", { loop = true })
		else
			Ui.handsStop()
		end
	end

	local function startPlug()
		if plugging or done then
			return
		end
		plugging = true
		if pumpPrompt then
			pumpPrompt.Enabled = false
		end
		if leakPrompt then
			leakPrompt.Enabled = false
		end
		ring.Visible = false
		bung.Visible = true
		local bungMeter = Ui.meter(s.panel, "Bung", UDim2.fromOffset(12, 116), 420)
		setBung = function(value: number)
			bungMeter(math.clamp(value, 0, 1))
			fill.Size = UDim2.fromScale(1, math.clamp(value, 0, 1))
		end
		line.Text = "Push the bung"
	end

	bung.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			setHold(true)
		end
	end)
	bung.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			setHold(false)
		end
	end)
	Ui.bind(s.bag, "PlugHold", function(state)
		if state == "Begin" then
			setHold(true)
		elseif state == "End" then
			setHold(false)
		end
	end, Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)

	-- attach the three world prompts once the scene is there (it arrives with the operation)
	local attaching = true
	task.spawn(function()
		local pump: BasePart? = nil
		local leak: BasePart? = nil
		local crew: { Model } = {}
		local taken: { [Model]: boolean } = {}
		local takenCount = 0
		while attaching and not s.finished do
			if not scene or not scene.Parent then
				scene = Find.scene(ctx)
			end
			if scene then
				if not pump then
					pump = Find.part(scene, "SalvagePump")
					if pump then
						local prompt = Ui.add(s.bag, Find.prompt(pump, "Run the pump", 0.5))
						pumpPrompt = prompt
						prompt.Triggered:Connect(startPump)
					end
				end
				if not leak then
					leak = Find.part(scene, "LeakPoint")
					if leak then
						local prompt = Ui.add(s.bag, Find.prompt(leak, "Plug the leak", 0.5))
						leakPrompt = prompt
						prompt.Triggered:Connect(startPlug)
					end
				end
				if #crew == 0 then
					crew = Find.crew(scene)
					for _, member in crew do
						local point = member.PrimaryPart
						if not point then
							continue
						end
						local prompt = Ui.add(s.bag, Find.prompt(point, "Take them off", 0.4))
						prompt.Triggered:Connect(function()
							if taken[member] then
								return
							end
							taken[member] = true
							takenCount += 1
							prompt.Enabled = false
							for _, p in member:GetDescendants() do
								if p:IsA("BasePart") then
									p.Transparency = 1
									p.CanQuery = false
								end
							end
							if takenCount >= #crew then
								Ui.hands("drag")
								finishSave({ evacuated = 1, saved = 1 })
							end
						end)
					end
				end
			end
			task.wait(0.4)
		end
	end)
	Ui.add(s.bag, function()
		attaching = false
	end)

	Step.heartbeat(s, function()
		local now = os.clock()
		if pumping then
			local index = math.floor((now - beatT0) / Save.BEAT_SECONDS + 0.5)
			if index > lastPulse and index >= 0 then
				lastPulse = index
				pulseAt = beatT0 + index * Save.BEAT_SECONDS
			end
			local k = (now - pulseAt) / 0.45
			if k >= 0 and k <= 1 then
				local grow = 0.45 + 0.7 * k
				pulse.Size = UDim2.fromScale(grow, grow)
				pulseStroke.Transparency = 0.2 + 0.75 * k
			else
				pulse.Size = UDim2.fromScale(0.42, 0.42)
				pulseStroke.Transparency = 0.6
			end
			ring.BackgroundColor3 = if now - hitAt < 0.16
				then Ui.Theme.Colors.gold
				else Ui.Theme.Colors.panelLight
		end
		if plugging then
			if not scene or not scene.Parent then
				scene = Find.scene(ctx)
			end
			local progress = if scene then scene:GetAttribute("Plug") else nil
			if type(progress) == "number" then
				if setBung then
					setBung(progress)
				end
				if progress >= 0.999 then
					plugging = false
					holding = false
					bung.Visible = false
					Ui.handsStop()
					finishSave({ plugged = 1, saved = 1, plugProgress = 1 })
				end
			end
		end
		if hull and hull.Parent then
			local flood = hull:GetAttribute("Flood")
			if type(flood) == "number" then
				meter(math.clamp(flood, 0, 1))
			end
			local list = hull:GetAttribute("List")
			if type(list) == "number" then
				tilt.Rotation = -list
			end
			if hull:GetAttribute("Sunk") == true and not done then
				done = true
				Ui.handsStop()
				Step.finish(s, { failed = true })
			end
		else
			hull = Find.part(scene, "Hull")
		end
	end)
	return Step.cleanup(s)
end

return Save
