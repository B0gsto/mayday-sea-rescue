--!strict
-- Berth and release (docs 09 section 6 step 9). Steer the lashed pair (heavier, slower to stop
-- and turn) onto the pontoon at a shallow angle and under the slow mark. The harbour staff take
-- the lines, then the crew release her: her lines on the pontoon, our lashings off, the tow line
-- coiled and stowed.
-- Metrics: contactSpeed (studs/s).
-- With nothing in tow (ctx.step.noTow, the boat-handling exercise's "alongside the pontoon") there
-- is no lashed-pair drag and no release: the step ends once the lines are on.
local RunService = game:GetService("RunService")

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))

local M = {}

local SLOW_MARK = 2 * 1.543 -- studs/s (2 knots)
local CONTACT_GAP = 3.5 -- studs from the pontoon edge
local PAIR_DRAG = 0.6 -- extra drag per unit mass from the lashed hull (tune)

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowBerth")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { contactSpeed = 2 }) then
		return cleanup
	end
	local root = Kit.vehicleRoot(ctx)
	if not root then
		task.delay(2, complete, { metrics = { contactSpeed = 8 }, failed = true })
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
		Kit.brief(gui, "Pontoon · shallow · slow")
		Kit.say(gui, "Chief Aggie", "Pontoon to finish. Gently.", 4)
	else
		Kit.brief(gui, "Pontoon · shallow · dead slow")
		Kit.say(gui, "Haven Harbour", "Visitors' pontoon. We'll take lines.", 4)
	end

	-- a few spoken beats with the crew's hands, then `after`
	local function beats(list: { { string } }, after: () -> ())
		for i, b in list do
			task.delay((i - 1) * 1.4, function()
				if gui.Parent then
					Kit.hands(b[3])
					Kit.say(gui, b[1], b[2], 1.4)
				end
			end)
		end
		task.delay(#list * 1.4, function()
			if gui.Parent then
				after()
			end
		end)
	end

	local function release()
		phase = "release"
		beats({
			{ "Skipper", "Our lines are on the pontoon.", "cast_off" },
			{ "Crew", "Lashings off!", "cast_off" },
			{ "Crew", "Tow line coiled and stowed.", "coil_line" },
		}, function()
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
			Kit.say(gui, "Skipper", "Thank you! Drinks on me.", 3)
			complete({ metrics = { contactSpeed = contactSpeed } })
		end)
	end

	local function passLines()
		phase = "lines"
		Kit.brief(gui, "")
		beats({
			{ "Haven Harbour", "Got your bow line.", "throw_line" },
			{ "Haven Harbour", "Stern line and springs on.", "throw_line" },
		}, function()
			if noTow then
				Kit.say(gui, "Chief Aggie", "Made fast. That'll do nicely.", 2.5)
				complete({ metrics = { contactSpeed = contactSpeed } })
			else
				release()
			end
		end)
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
					Kit.say(gui, "Haven Harbour", "Steady! Easy on the pontoon.", 3)
				elseif angle > 35 then
					Kit.say(gui, "Crew", "Bit steep, but we're on.", 2.5)
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
