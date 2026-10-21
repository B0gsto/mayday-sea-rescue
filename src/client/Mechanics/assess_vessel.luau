--!strict
-- Assessment of a disabled vessel (docs 09 section 6 step 3): stand off, drive a slow lap round
-- her at stand-off distance (the ring), sound the horn near her and her skipper calls back
-- everything (POB, problem, injuries...), and keep your view on a rope trailing over her stern
-- (it will foul your propeller later) to spot it. The decision is always to tow. Ends once the
-- skipper has answered and the lap is done (or after LAP_LIMIT s of lap).
-- Metrics: ringHeld (fraction of the lap inside the ring), hazardSpotted (1/0).
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local Procedures = require(script.Parent:WaitForChild("Tow"):WaitForChild("Procedures"))

local M = {}

local HAIL_SPEED = 10 -- studs/s: slow lap speed (tune)
local LAP_LIMIT = 40 -- s of lap after which a part lap is enough to move on
local HELP_AFTER = 10 -- s before the world nudges (skipper calls, rope flashes)
local HORN = "TowHorn"

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowAssess")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { ringHeld = 0.8, hazardSpotted = 1 }) then
		return cleanup
	end
	local scenario = Kit.scenario(ctx)
	local model = Kit.casualtyModel(ctx)
	local hull = model and (model.PrimaryPart or Kit.part(model, "Hull"))

	-- the hazard: a line trailing from her stern, floating in the water (only seen from aft)
	local ropeEnd: Attachment? = nil
	local ropeBeam: Beam? = nil
	if scenario.trailingRope and hull then
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailingRopeA0"
		a0.Position = Vector3.new(0.8, -0.6, hull.Size.Z / 2)
		a0.Parent = hull
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailingRopeA1"
		a1.Position = Vector3.new(1.6, -1.1, hull.Size.Z / 2 + 11)
		a1.Parent = hull
		local beam = Instance.new("Beam")
		beam.Name = "TrailingRope"
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 0.16, 0.16
		beam.CurveSize0, beam.CurveSize1 = 2, -1.5
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.fromRGB(200, 190, 160))
		beam.Parent = hull
		ropeEnd = a1
		ropeBeam = beam
		Kit.shared(ctx).trailingRope = { a0, a1, beam } :: { Instance }
	end

	local answered = false
	local answeredAt = 0
	local firstInRing: number? = nil
	local inRingTime, lapTime = 0, 0
	local sectors: { [number]: boolean } = {}
	local spotted = not scenario.trailingRope
	local gaze = 0
	local phase = "lap"
	local warnedFast = false
	local nudged = false
	local started = os.clock()

	Kit.brief(gui, "Circle her" .. Kit.chip("H", "L3"))
	Kit.say(gui, "Skipper", "Ahoy! She just won't go.", 4)

	local function sectorCount(): number
		local n = 0
		for _ in sectors do
			n += 1
		end
		return n
	end

	local function finishUp()
		phase = "done"
		local ringHeld = if lapTime > 0 then inRingTime / lapTime else 0
		ringHeld *= math.clamp(sectorCount() / Procedures.RING_SECTORS + 0.1, 0, 1)
		Kit.hands("radio_handset")
		Kit.say(gui, "You", `On scene, {scenario.pob} POB, preparing tow.`, 3)
		task.delay(3, complete, {
			metrics = {
				ringHeld = math.clamp(ringHeld, 0, 1),
				hazardSpotted = if spotted then 1 else 0,
			},
		})
	end

	-- the horn: near her, the skipper calls back everything; far off, nobody answers
	local function horn()
		local root = Kit.vehicleRoot(ctx)
		if answered or not root or not hull then
			return
		end
		AudioController.play("Horn_Tug", root.Position)
		if (hull.Position - root.Position).Magnitude > Procedures.RING_MAX + 12 then
			return
		end
		answered = true
		answeredAt = os.clock()
		Kit.hands("hail")
		for i, id in Procedures.ANSWER_ORDER do
			task.delay(1 + (i - 1) * 2.6, function()
				if gui.Parent then
					Kit.say(gui, "Skipper", Procedures.answer(scenario, id), 2.6)
				end
			end)
		end
	end
	ContextActionService:BindAction(HORN, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			horn()
		end
		return Enum.ContextActionResult.Pass -- a cosmetic horn on H still plays
	end, true, Enum.KeyCode.H, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle(HORN, "Horn")
	table.insert(bag, function()
		ContextActionService:UnbindAction(HORN)
	end)

	table.insert(
		bag,
		RunService.Heartbeat:Connect(function(dt)
			local root = Kit.vehicleRoot(ctx)
			if not root or not hull or not hull.Parent then
				return
			end
			if phase == "lap" then
				local inRing = Procedures.inRing(hull.Position, root.Position)
				if inRing and not firstInRing then
					firstInRing = os.clock()
				end
				if firstInRing then
					lapTime += dt
					if inRing and Kit.speed(root) <= HAIL_SPEED * 1.5 then
						inRingTime += dt
						sectors[Procedures.sector(hull.Position, root.Position)] = true
					end
				end
				if Kit.speed(root) > HAIL_SPEED * 1.8 and not warnedFast then
					warnedFast = true
					Kit.say(gui, "Crew", "Slow down, Helm. Wash!", 3)
				end
				local lapDone = sectorCount() >= Procedures.RING_SECTORS
				if lapDone then
					Kit.brief(gui, if answered then "" else "Horn" .. Kit.chip("H", "L3"))
				end
				if not answered and not nudged and os.clock() - started > HELP_AFTER then
					nudged = true
					Kit.say(gui, "Skipper", "Blast your horn!", 3)
				end
				-- let the skipper finish talking; then the lap (or enough of it) ends the step
				local talked = os.clock() - answeredAt > 1 + #Procedures.ANSWER_ORDER * 2.6
				if answered and talked and (lapDone or lapTime >= LAP_LIMIT) then
					finishUp()
				end
			end
			-- after a while the trailing rope catches the light, so it is easy to spot
			if ropeBeam and not spotted and lapTime > HELP_AFTER then
				ropeBeam.Color = ColorSequence.new(
					if (os.clock() * 2) % 1 < 0.5
						then Color3.fromRGB(255, 200, 80)
						else Color3.fromRGB(200, 190, 160)
				)
			end
			-- spotting the trailing rope: keep your eyes on it from aft for a moment
			if not spotted and ropeEnd then
				local cam = Workspace.CurrentCamera
				local p = ropeEnd.WorldPosition
				local seen = cam ~= nil
					and Procedures.canSeeStern(hull.CFrame, root.Position)
					and (p - root.Position).Magnitude < 60
					and (cam :: Camera).CFrame.LookVector:Dot(
							(p - (cam :: Camera).CFrame.Position).Unit
						)
						> 0.93
				gaze = if seen then gaze + dt else math.max(0, gaze - dt)
				if gaze > 0.8 then
					spotted = true
					Kit.hands("point")
					Kit.say(gui, "You", "Line trailing astern! Pull it in!", 4)
					task.delay(3, function()
						local s = Kit.shared(ctx).trailingRope
						if s then
							for _, inst in s do
								inst:Destroy()
							end
							Kit.shared(ctx).trailingRope = nil
						end
					end)
				end
			end
		end)
	)
	return cleanup
end

return M
