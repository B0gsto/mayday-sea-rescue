--!strict
-- Assessment of a disabled vessel (docs 09 section 6 step 3): stand off, drive a slow lap round
-- her at stand-off distance (the ring), hail the skipper with question cards, look her over for
-- hazards (a rope trailing over the stern will foul your propeller later), report POB and decide.
-- Metrics: ringHeld (fraction of the lap inside the ring), questions (key questions asked),
-- pob (the number reported), hazardSpotted (1/0).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local Procedures = require(script.Parent:WaitForChild("Tow"):WaitForChild("Procedures"))

local M = {}

local HAIL_SPEED = 10 -- studs/s: faster than this and they can't hear you over the engine (tune)

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowAssess")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { ringHeld = 0.8, questions = 0.75, pob = 1, hazardSpotted = 1 }) then
		return cleanup
	end
	local scenario = Kit.scenario(ctx)
	local model = Kit.casualtyModel(ctx)
	local hull = model and (model.PrimaryPart or Kit.part(model, "Hull"))

	-- the hazard: a line trailing from her stern, floating in the water (only seen from aft)
	local ropeEnd: Attachment? = nil
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
		Kit.shared(ctx).trailingRope = { a0, a1, beam } :: { Instance }
	end

	local asked: { [string]: boolean } = {}
	local askedCount = 0
	local firstInRing: number? = nil
	local inRingTime, lapTime = 0, 0
	local sectors: { [number]: boolean } = {}
	local spotted = not scenario.trailingRope
	local gaze = 0
	local phase = "lap"
	local warnedFast = false

	Kit.brief(
		gui,
		"Stand off and circle her slowly. Hail the skipper when you're close enough to talk."
	)
	Kit.say(gui, "Skipper", "Ahoy! Thanks for coming. She just won't go.", 4)

	local function sectorCount(): number
		local n = 0
		for _ in sectors do
			n += 1
		end
		return n
	end

	local function finishUp(pob: number, decision: string)
		local right = Procedures.rightDecision(scenario, false)
		local ringHeld = if lapTime > 0 then inRingTime / lapTime else 0
		ringHeld *= math.clamp(sectorCount() / Procedures.RING_SECTORS + 0.1, 0, 1)
		complete({
			metrics = {
				ringHeld = math.clamp(ringHeld, 0, 1),
				questions = Procedures.questionScore(asked),
				pob = pob,
				hazardSpotted = if spotted then 1 else 0,
				decisionRight = decision == right,
			},
		})
	end

	local function decide(pob: number)
		phase = "decide"
		Kit.brief(gui, "Your call: tow her, take the crew off, or have them anchor first.")
		local cancel = Kit.choose(gui, "Decision", {
			{ id = "tow", text = "Tow her in" },
			{ id = "evacuate", text = "Take the crew off" },
			{ id = "anchor", text = "Anchor first" },
		}, function(id)
			finishUp(pob, id)
		end, ctx.isAssist, Procedures.rightDecision(scenario, false))
		table.insert(bag, cancel)
	end

	local function reportPob()
		phase = "pob"
		Kit.hands("radio_handset")
		Kit.brief(gui, "Report persons on board to the Coastguard.")
		local cancel = Kit.choose(gui, "POB to Coastguard", {
			{ id = "1", text = "One aboard" },
			{ id = "2", text = "Two aboard" },
			{ id = "3", text = "Three aboard" },
			{ id = "4", text = "Four aboard" },
		}, function(id)
			local n = tonumber(id) or 0
			Kit.say(
				gui,
				"You",
				`Coastguard, Haven Lifeboat: on scene, {n} POB, preparing to tow.`,
				4
			)
			decide(n)
		end, ctx.isAssist, tostring(scenario.pob))
		table.insert(bag, cancel)
	end

	local cancelCards: (() -> ())? = nil
	local function showQuestions()
		if phase ~= "lap" then
			return
		end
		local choices: { Kit.Choice } = {}
		for _, q in Procedures.QUESTIONS do
			if not asked[q.id] and #choices < (if askedCount >= 2 then 3 else 4) then
				table.insert(choices, { id = q.id, text = q.text })
			end
		end
		if askedCount >= 2 then
			table.insert(choices, { id = "_done", text = "That's all, stand by" })
		end
		local nextKey: string? = nil
		for _, q in Procedures.QUESTIONS do
			if q.key and not asked[q.id] then
				nextKey = q.id
				break
			end
		end
		cancelCards = Kit.choose(gui, "Hail the skipper", choices, function(id)
			cancelCards = nil
			if id == "_done" then
				reportPob()
				return
			end
			local root = Kit.vehicleRoot(ctx)
			local ok = hull ~= nil
				and root ~= nil
				and Procedures.inRing(hull.Position, root.Position)
			local close = hull ~= nil
				and root ~= nil
				and (hull.Position - root.Position).Magnitude <= Procedures.RING_MAX + 12
			if not close then
				Kit.say(gui, "Crew", "They can't hear us from here. Get in closer.", 3)
			elseif root and Kit.speed(root) > HAIL_SPEED then
				Kit.say(gui, "Crew", "Ease off, they can't hear you over the engine.", 3)
			else
				Kit.hands("hail")
				asked[id] = true
				askedCount += 1
				local qText = ""
				for _, q in Procedures.QUESTIONS do
					if q.id == id then
						qText = q.text
					end
				end
				Kit.say(gui, "You", qText, 1.6)
				task.delay(1.6, function()
					if gui.Parent then
						Kit.say(gui, "Skipper", Procedures.answer(scenario, id), 4)
					end
				end)
				if not ok then
					Kit.say(gui, "Crew", "Watch your distance, don't drift down on her.", 3)
				end
			end
			task.delay(1.2, showQuestions)
		end, ctx.isAssist, nextKey)
	end
	showQuestions()
	table.insert(bag, function()
		if cancelCards then
			cancelCards()
		end
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
					Kit.say(gui, "Crew", "Slow lap, Helm. We're throwing wash at her.", 3)
				end
				if sectorCount() >= Procedures.RING_SECTORS then
					Kit.brief(gui, "Lap done. Finish your questions, then report POB.")
				end
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
					Kit.say(
						gui,
						"You",
						"There's a line trailing off your stern! Pull it aboard before we pass the tow.",
						4
					)
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
