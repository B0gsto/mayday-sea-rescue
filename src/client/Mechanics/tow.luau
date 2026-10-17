--!strict
-- Tow her home (docs 09 section 6 step 7). The TowLine model runs every frame (Tow/Kit link):
-- ease off when the tow surfs down a wave towards you (the line goes slack and sags into the
-- water), add throttle gently as she climbs; stay under her hull speed. Step the tow out (Q/E,
-- the length buttons, D-pad left/right) until both boats ride the same part of the wave: in a
-- big sea a longer line also absorbs the snatch loads. Wide turns only. A line held in the red
-- or spiked parts: stop, the crew re-passes it. Done at the harbour entrance.
-- Metrics: amberFraction, redEvents (count), inStep (fraction of the tow in step).
local ContextActionService = game:GetService("ContextActionService")

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local TowLine = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Tow")
		:WaitForChild("TowLine")
)

local M = {}

local STEP = 6 -- studs per length change (2 m)
local MIN_LEN, MAX_LEN = 30, 150
local HARBOUR_RANGE = 80 -- studs from a pontoon: the harbour entrance, stop the tow (tune)
local REPASS_SECONDS = 6
local SHARP_TURN = 0.45 -- rad/s yaw rate under load
local LONGER, SHORTER = "TowLengthOut", "TowLengthIn"

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowTow")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { amberFraction = 0.1, redEvents = 0, inStep = 0.6 }) then
		return cleanup
	end
	local rig = Kit.shared(ctx).rig or { lengthStuds = 75, bridle = true, strongPoint = true }
	local link =
		Kit.link(ctx, rig.lengthStuds, { bridle = rig.bridle, strongPoint = rig.strongPoint })
	if not link then
		Kit.brief(gui, "Can't see the casualty or our boat.")
		task.delay(
			2,
			complete,
			{ metrics = { amberFraction = 1, redEvents = 1, inStep = 0 }, failed = true }
		)
		return cleanup
	end
	local l = link :: Kit.Link
	local intensity = Kit.intensity(ctx)
	local swell = intensity >= 0.15
	local hullSpeed = TowLine.hullSpeed(l.hull.Size.Z)
	local safe = TowLine.safeSpeed(hullSpeed, intensity)
	local total, amber, inStepTime = 0, 0, 0
	local redEvents = 0
	local inRed = false
	local repassing = 0
	local lastYaw = l.root.CFrame.LookVector
	local lastCall = 0
	local wasInStep = false
	local setGauge = if ctx.isAssist then Kit.gauge(gui, "Tow line") else nil
	local stepLabel: TextLabel? = nil
	if ctx.isAssist then
		local lbl = Instance.new("TextLabel")
		lbl.Name = "InStep"
		lbl.AnchorPoint = Vector2.new(1, 1)
		lbl.Position = UDim2.new(1, -24, 1, -180)
		lbl.Size = UDim2.fromOffset(240, 18)
		lbl.BackgroundTransparency = 1
		lbl.TextSize = 14
		lbl.TextXAlignment = Enum.TextXAlignment.Right
		lbl.TextColor3 = Color3.fromRGB(220, 230, 235)
		lbl.Parent = gui
		stepLabel = lbl
	end

	Kit.brief(
		gui,
		`Tow her home slowly: under {math.floor(safe / Kit.KNOT + 0.5)} knots, wide turns. Q/E to step the tow out or in.`
	)
	Kit.say(
		gui,
		"Navigator",
		"Coastguard, Haven Lifeboat: tow established, heading for Haven Harbour.",
		4
	)

	local function change(dir: number)
		local len = math.clamp(l.lengthStuds + dir * STEP, MIN_LEN, MAX_LEN)
		if len ~= l.lengthStuds then
			Kit.setLength(l, len)
			Kit.hands(if dir > 0 then "payout_left" else "haul_in")
		end
	end
	local function bind(name: string, dir: number, title: string, ...: any)
		ContextActionService:BindAction(name, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				change(dir)
			end
			return Enum.ContextActionResult.Pass
		end, true, ...)
		ContextActionService:SetTitle(name, title)
	end
	bind(LONGER, 1, "Longer", Enum.KeyCode.E, Enum.KeyCode.DPadRight)
	bind(SHORTER, -1, "Shorter", Enum.KeyCode.Q, Enum.KeyCode.DPadLeft)
	table.insert(bag, function()
		ContextActionService:UnbindAction(LONGER)
		ContextActionService:UnbindAction(SHORTER)
	end)

	l.onUpdate = function(lk: Kit.Link, dt: number)
		local line = lk.line
		local t = line.tension
		if setGauge then
			setGauge(t)
		end
		if repassing > 0 then
			-- the line parted: stop, they haul the end back and make fast again
			if Kit.speed(lk.root) < 4 then
				repassing -= dt
			end
			if repassing <= 0 then
				TowLine.rejoin(line)
				Kit.hands("throw_heaving_line")
				Kit.say(gui, "Crew", "Line's back on. Take the strain gently.", 3)
			end
			return
		end
		total += dt
		if t >= TowLine.GREEN then
			amber += dt
		end
		-- sharp turns under load yaw the tow into the waves
		local look = lk.root.CFrame.LookVector
		local yawRate = math.acos(math.clamp(look:Dot(lastYaw), -1, 1)) / math.max(dt, 1e-3)
		lastYaw = look
		if yawRate > SHARP_TURN and t > 0.3 then
			amber += dt * 0.5
			if os.clock() - lastCall > 4 then
				lastCall = os.clock()
				Kit.say(gui, "Crew", "Wide turns, Helm, she's sheering.", 2.5)
			end
		end
		if t >= TowLine.AMBER and not inRed then
			inRed = true
			redEvents += 1
		elseif t < TowLine.GREEN then
			inRed = false
		end
		if line.parted then
			redEvents += if inRed then 0 else 1
			inRed = false
			Kit.snapSound(lk.ropeA0)
			Kit.hands("duck")
			Kit.say(gui, "Crew", "Line's parted! Heads down! Stop, we'll pass it again.", 4)
			repassing = REPASS_SECONDS
			return
		end
		-- in step: both boats on the same part of the wave (in calm water: a sensible length)
		local good
		if swell then
			good = lk.inStep
		else
			local rec =
				TowLine.recommendedLength(lk.wavelength, intensity, lk.root.Size.Z, lk.hull.Size.Z)
			good = math.abs(lk.lengthStuds - rec) <= rec * 0.35 or lk.lengthStuds >= 40
		end
		if good then
			inStepTime += dt
		end
		if stepLabel then
			stepLabel.Text = if good
				then "In step: riding the waves together"
				else "Out of step: try another length"
		end
		if swell and good and not wasInStep then
			Kit.say(gui, "Crew", "That's it, we're both on the crest together.", 2.5)
		end
		wasInStep = good
		if line.snatch > 0.2 and os.clock() - lastCall > 3 then
			lastCall = os.clock()
			Kit.say(gui, "Skipper", "Whoa! That was a jolt!", 2)
		end
		local speed = Kit.speed(lk.root)
		if speed > hullSpeed and os.clock() - lastCall > 5 then
			lastCall = os.clock()
			Kit.say(gui, "Crew", "Too fast, she's climbing her own bow wave!", 2.5)
		end
		local hx, hz = TowLine.hullPosition(line)
		local _, d = Kit.nearestPad(Vector3.new(hx, 0, hz))
		if d <= HARBOUR_RANGE and total > 5 then
			lk.onUpdate = nil
			Kit.say(
				gui,
				"Navigator",
				"Harbour entrance. Stop the tow, we'll take her alongside.",
				4
			)
			complete({
				metrics = {
					amberFraction = if total > 0 then math.clamp(amber / total, 0, 1) else 0,
					redEvents = redEvents,
					inStep = if total > 0 then math.clamp(inStepTime / total, 0, 1) else 0,
				},
			})
		end
	end
	table.insert(bag, function()
		l.onUpdate = nil
	end)
	return cleanup
end

return M
