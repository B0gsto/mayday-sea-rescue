--!strict
-- Berth and release (docs 09 section 6 step 9). Steer the lashed pair (heavier, slower to stop
-- and turn) onto the pontoon at a shallow angle and under the slow mark, pass lines to the
-- harbour staff, then release in the right order: the casualty made fast to the pontoon first,
-- our lashings off, and the tow line coiled and stowed (no line left in the water).
-- Metrics: contactSpeed (studs/s), lineInWater (0/1), lineOrderRight (1/0).
-- With nothing in tow (ctx.step.noTow, the boat-handling exercise's "alongside the pontoon") the
-- tow-line parts are skipped: no lashed-pair drag, and the step ends once the lines are on, graded
-- on the contact speed and the berthing line order (Procedures.noTowBerthMetrics).
local RunService = game:GetService("RunService")

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local Procedures = require(script.Parent:WaitForChild("Tow"):WaitForChild("Procedures"))

local M = {}

local SLOW_MARK = 2 * 1.543 -- studs/s (2 knots)
local CONTACT_GAP = 3.5 -- studs from the pontoon edge
local PAIR_DRAG = 0.6 -- extra drag per unit mass from the lashed hull (tune)

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowBerth")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { contactSpeed = 2, lineInWater = 0, lineOrderRight = 1 }) then
		return cleanup
	end
	local root = Kit.vehicleRoot(ctx)
	if not root then
		task.delay(2, complete, { metrics = { contactSpeed = 8, lineInWater = 1 }, failed = true })
		return cleanup
	end
	local r = root :: BasePart
	local noTow = type(ctx.step) == "table" and ctx.step.noTow == true
	local link = if noTow then nil else Kit.getLink(ctx)
	local pad = Kit.nearestPad(r.Position)
	local phase = "approach"
	local contactSpeed = 0
	local speedLabel: TextLabel? = nil

	-- the casualty's weight alongside: a drag on our hull so the pair carries way and turns wide
	local drag = Instance.new("VectorForce")
	drag.Name = "PairDrag"
	drag.RelativeTo = Enum.ActuatorRelativeTo.World
	drag.ApplyAtCenterOfMass = true
	local att = Instance.new("Attachment")
	att.Parent = r
	drag.Attachment0 = att
	drag.Parent = r
	table.insert(bag, function()
		drag:Destroy()
		att:Destroy()
	end)
	if ctx.isAssist then
		local lbl = Instance.new("TextLabel")
		lbl.AnchorPoint = Vector2.new(1, 1)
		lbl.Position = UDim2.new(1, -24, 1, -140)
		lbl.Size = UDim2.fromOffset(240, 18)
		lbl.BackgroundTransparency = 1
		lbl.TextSize = 14
		lbl.TextXAlignment = Enum.TextXAlignment.Right
		lbl.TextColor3 = Color3.fromRGB(220, 230, 235)
		lbl.Parent = gui
		speedLabel = lbl
	end
	if noTow then
		Kit.brief(
			gui,
			"Bring her alongside the pontoon at a shallow angle, under the slow mark, and let her kiss it."
		)
		Kit.say(gui, "Chief Aggie", "Alongside the pontoon to finish. Gently does it.", 4)
	else
		Kit.brief(
			gui,
			"Bring her onto the pontoon at a shallow angle, dead slow. She's heavy now: start slowing early."
		)
		Kit.say(gui, "Haven Harbour", "Berth on the visitors' pontoon, we'll take your lines.", 4)
	end

	local function release()
		phase = "release"
		local remaining = { "springs", "coil", "casualtyFast", "bow", "stern" }
		local order: { string } = {}
		Kit.brief(gui, "Release her: pick the order.")
		local function nextStep()
			local choices: { Kit.Choice } = {}
			for _, id in remaining do
				if #choices < 4 then
					table.insert(choices, { id = id, text = Procedures.RELEASE_TEXT[id] })
				end
			end
			local cancel = Kit.choose(gui, `Step {#order + 1}`, choices, function(id)
				table.insert(order, id)
				table.remove(remaining, table.find(remaining, id) :: number)
				Kit.hands(if id == "coil" then "coil_line" else "cast_off")
				if id == "casualtyFast" and #order > 1 then
					Kit.say(gui, "Skipper", "We're drifting off! Grab the pontoon!", 2.5)
				end
				if #remaining > 0 then
					nextStep()
					return
				end
				local coilLast = order[#order] == "coil"
				local right = Procedures.orderScore(order, Procedures.RELEASE_ORDER) >= 1
				if link then
					link.lashed = nil
					Kit.release(link)
				end
				local trailing = Kit.shared(ctx).trailingRope
				if trailing then
					for _, inst in trailing do
						inst:Destroy()
					end
					Kit.shared(ctx).trailingRope = nil
				end
				Kit.say(gui, "Skipper", "Thank you so much. Drinks are on me.", 3)
				complete({
					metrics = {
						contactSpeed = contactSpeed,
						lineInWater = if coilLast then 0 else 1,
						lineOrderRight = if right then 1 else 0,
					},
				})
			end, ctx.isAssist, Procedures.RELEASE_ORDER[#order + 1])
			table.insert(bag, cancel)
		end
		nextStep()
	end

	local function passLines()
		phase = "lines"
		local remaining = { "stern", "bow", "aftSpring", "fwdSpring" }
		local given: { string } = {}
		Kit.brief(gui, "Pass your lines to the harbour staff.")
		local function nextLine()
			local choices: { Kit.Choice } = {}
			for _, id in remaining do
				table.insert(choices, { id = id, text = Procedures.LINE_TEXT[id] })
			end
			local cancel = Kit.choose(gui, `Line {#given + 1}`, choices, function(id)
				table.insert(given, id)
				table.remove(remaining, table.find(remaining, id) :: number)
				Kit.hands("throw_line")
				Kit.say(
					gui,
					"Haven Harbour",
					`Got your {string.lower(Procedures.LINE_TEXT[id])}.`,
					1.5
				)
				if #remaining > 0 then
					nextLine()
				elseif noTow then
					Kit.say(gui, "Chief Aggie", "Made fast. That'll do nicely.", 2.5)
					complete({ metrics = Procedures.noTowBerthMetrics(contactSpeed, given) })
				else
					release()
				end
			end, ctx.isAssist, Procedures.BERTH_ORDER[#given + 1])
			table.insert(bag, cancel)
		end
		nextLine()
	end

	table.insert(
		bag,
		RunService.Heartbeat:Connect(function()
			local v = r.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z)
			drag.Force = if noTow then Vector3.zero else -flat * r.AssemblyMass * PAIR_DRAG
			if phase ~= "approach" then
				drag.Force = -flat * r.AssemblyMass * 2
				return
			end
			if speedLabel then
				speedLabel.Text =
					`{string.format("%.1f", flat.Magnitude / 1.543)} kn  (slow mark 2 kn)`
			end
			if not pad then
				pad = Kit.nearestPad(r.Position)
				return
			end
			local p = pad :: BasePart
			-- the outer hull: whichever of us or the lashed casualty is nearer the pontoon
			local probe = r.Position
			if
				link
				and (link.hull.Position - p.Position).Magnitude < (probe - p.Position).Magnitude
			then
				probe = link.hull.Position
			end
			local loc = p.CFrame:PointToObjectSpace(probe)
			local half = p.Size / 2
			local gapX = math.abs(loc.X) - half.X
			local gapZ = math.abs(loc.Z) - half.Z
			local gap = math.max(gapX, gapZ)
			if gap <= CONTACT_GAP then
				contactSpeed = flat.Magnitude
				local along = if half.X >= half.Z then p.CFrame.RightVector else p.CFrame.LookVector
				local angle =
					math.deg(math.acos(math.clamp(math.abs(r.CFrame.LookVector:Dot(along)), 0, 1)))
				if contactSpeed > SLOW_MARK * 2 then
					Kit.say(
						gui,
						"Haven Harbour",
						"Steady! You'll have the pontoon off its piles.",
						3
					)
				elseif angle > 35 then
					Kit.say(gui, "Crew", "Bit steep on the approach, but we're on.", 2.5)
				else
					Kit.say(gui, "Haven Harbour", "Nicely done. Lines please.", 2.5)
				end
				Kit.hands("fend_off")
				passLines()
			end
		end)
	)
	return cleanup
end

return M
