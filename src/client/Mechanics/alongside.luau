--!strict
-- Alongside tow (docs 09 section 6 step 8). In the harbour: stop, shorten up and recover the tow
-- line hand over hand (keep it clear of the prop), put fenders out on the touching side, come
-- alongside her at dead slow with our stern aft of hers (so our rudder still steers the pair),
-- then make fast bow line, stern line and springs in order. The pair then moves as one.
-- Metrics: contactSpeed (studs/s), fendersRight (1/0), lineOrderRight (1/0).
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local Procedures = require(script.Parent:WaitForChild("Tow"):WaitForChild("Procedures"))

local M = {}

local SHORT_LEN = 9
local SLOT_TOLERANCE = 5 -- studs
local LEFT, RIGHT = "TowRecoverLeft", "TowRecoverRight"

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowAlongside")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { contactSpeed = 2, fendersRight = 1, lineOrderRight = 1 }) then
		return cleanup
	end
	local rig = Kit.shared(ctx).rig or { lengthStuds = 60, bridle = true, strongPoint = true }
	local link = Kit.link(ctx, rig.lengthStuds, rig)
	if not link then
		Kit.brief(gui, "Can't see the casualty or our boat.")
		task.delay(
			2,
			complete,
			{ metrics = { contactSpeed = 8, fendersRight = 0, lineOrderRight = 0 }, failed = true }
		)
		return cleanup
	end
	local l = link :: Kit.Link
	-- the pontoon side decides ours: she goes on the side away from the pontoon
	local side = if Procedures.seedOf(l.opId) % 2 == 0 then "starboard" else "port"
	local sign = if side == "starboard" then 1 else -1
	local fenderSide: string? = nil
	local fenderCount = 0
	local contactSpeed = 0
	local phase = "recover"
	local lastHand: string? = nil
	local fenders: { BasePart } = {}
	table.insert(bag, function()
		for _, f in fenders do
			f:Destroy()
		end
	end)

	Kit.brief(
		gui,
		"Stop the tow and shorten up: recover the line hand over hand, keep it clear of the prop."
	)
	Kit.say(gui, "Crew", `We'll take her on our {side} side.`, 3)

	local function slot(): CFrame
		local root = l.root
		local width = root.Size.X / 2 + l.hull.Size.X / 2 + (if fenderCount > 0 then 1.2 else 0.4)
		-- our stern aft of hers: her centre a little forward of ours
		local fwd = math.max(0, (root.Size.Z - l.hull.Size.Z) / 2) + 1.5
		return root.CFrame * CFrame.new(sign * width, 0, -fwd)
	end

	local function placeFenders(where: string, count: number)
		local root = l.root
		local s = if where == "starboard" then 1 else -1
		for i = 1, count do
			local f = Instance.new("Part")
			f.Name = "Fender"
			f.Shape = Enum.PartType.Cylinder
			f.Size = Vector3.new(1.6, 0.7, 0.7)
			f.Color = Color3.fromRGB(30, 60, 140)
			f.Material = Enum.Material.SmoothPlastic
			f.CanCollide, f.CanQuery, f.Massless = false, false, true
			f.CFrame = root.CFrame
				* CFrame.new(s * (root.Size.X / 2 + 0.35), -0.2, (i - (count + 1) / 2) * 3)
				* CFrame.Angles(0, 0, math.rad(90))
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, f
			w.Parent = f
			f.Parent = root.Parent
			table.insert(fenders, f)
		end
	end

	local order: { string } = {}
	local function lines()
		phase = "lines"
		local remaining = { "stern", "aftSpring", "bow", "fwdSpring" }
		Kit.brief(gui, "Make her fast: pick the lines in the order you'd put them on.")
		local function nextLine()
			local choices: { Kit.Choice } = {}
			for _, id in remaining do
				table.insert(choices, { id = id, text = Procedures.LINE_TEXT[id] })
			end
			local cancel = Kit.choose(gui, `Line {#order + 1}`, choices, function(id)
				table.insert(order, id)
				table.remove(remaining, table.find(remaining, id) :: number)
				Kit.hands("throw_line")
				Kit.say(gui, "Crew", `{Procedures.LINE_TEXT[id]} on!`, 1.5)
				if #remaining > 0 then
					nextLine()
					return
				end
				local right = Procedures.orderScore(order, Procedures.ALONGSIDE_ORDER) >= 1
				if not right then
					Kit.say(gui, "Crew", "She's swinging, we got the order wrong. Sorted now.", 3)
				else
					Kit.say(gui, "Skipper", "Snug as anything. Thanks!", 3)
				end
				l.lashed = l.root.CFrame:ToObjectSpace(slot())
				Kit.setLength(l, SHORT_LEN)
				complete({
					metrics = {
						contactSpeed = contactSpeed,
						fendersRight = if Procedures.fendersRight(fenderSide, side, fenderCount)
							then 1
							else 0,
						lineOrderRight = if right then 1 else 0,
					},
				})
			end, ctx.isAssist, Procedures.ALONGSIDE_ORDER[#order + 1])
			table.insert(bag, cancel)
		end
		nextLine()
	end

	local function fenderCards()
		phase = "fenders"
		ContextActionService:UnbindAction(LEFT)
		ContextActionService:UnbindAction(RIGHT)
		Kit.brief(gui, "Fenders out before you go alongside.")
		local cancel = Kit.choose(gui, "Fenders", {
			{ id = "starboard3", text = "Three, starboard side" },
			{ id = "port3", text = "Three, port side" },
			{ id = `{side}1`, text = `One, {side} side` },
			{ id = "none", text = "No fenders" },
		}, function(id)
			if id ~= "none" then
				fenderSide = if string.sub(id, 1, 4) == "port" then "port" else "starboard"
				fenderCount = tonumber(string.sub(id, -1)) or 0
				placeFenders(fenderSide :: string, fenderCount)
				Kit.hands("fenders")
			end
			phase = "approach"
			Kit.brief(
				gui,
				`Come alongside her at dead slow, our {side} side to her, our stern aft of hers.`
			)
		end, ctx.isAssist, `{side}3`)
		table.insert(bag, cancel)
	end

	local function pull(hand: string)
		if phase ~= "recover" or lastHand == hand then
			return
		end
		lastHand = hand
		if Kit.speed(l.root) > 4 then
			Kit.say(gui, "Crew", "Stop us first, I can't haul against the boat.", 2)
			return
		end
		Kit.hands(if hand == "L" then "haul_left" else "haul_right")
		Kit.setLength(l, math.max(SHORT_LEN, l.lengthStuds - 4))
		if l.lengthStuds <= SHORT_LEN then
			Kit.say(gui, "Crew", "Line's in. She's on a short line.", 2)
			fenderCards()
		end
	end
	local function bind(name: string, hand: string, ...: any)
		ContextActionService:BindAction(name, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				pull(hand)
			end
			return Enum.ContextActionResult.Pass
		end, true, ...)
		ContextActionService:SetTitle(name, if hand == "L" then "Left" else "Right")
	end
	bind(LEFT, "L", Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonL1)
	bind(RIGHT, "R", Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR1)
	table.insert(bag, function()
		ContextActionService:UnbindAction(LEFT)
		ContextActionService:UnbindAction(RIGHT)
	end)

	table.insert(
		bag,
		RunService.Heartbeat:Connect(function()
			if phase ~= "approach" then
				return
			end
			local want = slot()
			local hullCF = l.hull.CFrame
			local d = Vector3.new(
				hullCF.Position.X - want.Position.X,
				0,
				hullCF.Position.Z - want.Position.Z
			).Magnitude
			local aligned = math.abs(hullCF.LookVector:Dot(l.root.CFrame.LookVector)) > 0.9
			if d <= SLOT_TOLERANCE and aligned then
				local rel = l.root.AssemblyLinearVelocity
				local normal = (hullCF.Position - l.root.Position)
				contactSpeed = Procedures.contactSpeed(-rel, normal)
					+ Vector3.new(rel.X, 0, rel.Z).Magnitude * 0.3
				if fenderCount == 0 or fenderSide ~= side then
					Kit.say(gui, "Skipper", "Ooh, that's my gelcoat!", 2.5)
				elseif contactSpeed > 4 then
					Kit.say(gui, "Crew", "Bit firm there.", 2)
				else
					Kit.say(gui, "Crew", "Lovely, kissed her alongside.", 2)
				end
				Kit.hands("fend_off")
				phase = "contact"
				-- she lies against us now while the lines go on
				l.lashed = l.root.CFrame:ToObjectSpace(slot())
				task.delay(0.8, lines)
			end
		end)
	)
	return cleanup
end

return M
