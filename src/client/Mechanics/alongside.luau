--!strict
-- Alongside tow (docs 09 section 6 step 8). In the harbour: stop, shorten up and recover the tow
-- line hand over hand (keep it clear of the prop), then come alongside her at dead slow on either
-- side, our stern aft of hers (so our rudder still steers the pair). As she closes, the crew put
-- fenders out on the side she is coming to, and make the lines fast once she touches. The pair
-- then moves as one.
-- Metrics: contactSpeed (studs/s).
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
	if Kit.autoStub(complete, { contactSpeed = 2 }) then
		return cleanup
	end
	local rig = Kit.shared(ctx).rig or { lengthStuds = 60, bridle = true, strongPoint = true }
	local link = Kit.link(ctx, rig.lengthStuds, rig)
	if not link then
		Kit.brief(gui, "No casualty")
		task.delay(2, complete, { metrics = { contactSpeed = 8 }, failed = true })
		return cleanup
	end
	local l = link :: Kit.Link
	-- the side she lies on is the side you bring her to (+1 starboard, -1 port)
	local sign = 1
	local fenderSign = 0 -- the side the crew have fenders out on, 0 none yet
	local contactSpeed = 0
	local phase = "recover"
	local lastHand: string? = nil
	local fenders: { BasePart } = {}
	table.insert(bag, function()
		for _, f in fenders do
			f:Destroy()
		end
	end)

	Kit.brief(gui, "Stop · haul in" .. Kit.chip("LMB / RMB", "LB / RB"))

	local function slot(): CFrame
		local root = l.root
		local width = root.Size.X / 2 + l.hull.Size.X / 2 + (if fenderSign ~= 0 then 1.2 else 0.4)
		-- our stern aft of hers: her centre a little forward of ours
		local fwd = math.max(0, (root.Size.Z - l.hull.Size.Z) / 2) + 1.5
		return root.CFrame * CFrame.new(sign * width, 0, -fwd)
	end

	local function placeFenders(s: number, count: number)
		local root = l.root
		for _, f in fenders do
			f:Destroy()
		end
		table.clear(fenders)
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

	-- the crew make her fast: bow line, stern line, then the springs
	local function lines()
		phase = "lines"
		Kit.brief(gui, "")
		for i, text in { "Bow line on!", "Stern line on!", "Springs on!" } do
			task.delay((i - 1) * 1.2, function()
				if gui.Parent then
					Kit.hands("throw_line")
					Kit.say(gui, "Crew", text, 1.2)
				end
			end)
		end
		task.delay(3.6, function()
			if not gui.Parent then
				return
			end
			Kit.say(gui, "Skipper", "Snug as anything. Thanks!", 3)
			l.lashed = l.root.CFrame:ToObjectSpace(slot())
			Kit.setLength(l, SHORT_LEN)
			complete({ metrics = { contactSpeed = contactSpeed } })
		end)
	end

	local function pull(hand: string)
		if phase ~= "recover" or lastHand == hand then
			return
		end
		lastHand = hand
		if Kit.speed(l.root) > 4 then
			Kit.say(gui, "Crew", "Stop us first, can't haul.", 2)
			return
		end
		Kit.hands(if hand == "L" then "haul_left" else "haul_right")
		Kit.setLength(l, math.max(SHORT_LEN, l.lengthStuds - 4))
		if l.lengthStuds <= SHORT_LEN then
			Kit.say(gui, "Crew", "Line's in. Short line.", 2)
			ContextActionService:UnbindAction(LEFT)
			ContextActionService:UnbindAction(RIGHT)
			phase = "approach"
			Kit.brief(gui, "Alongside · dead slow")
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
			local hullCF = l.hull.CFrame
			local loc = l.root.CFrame:PointToObjectSpace(hullCF.Position)
			sign = if loc.X >= 0 then 1 else -1
			-- as she closes, the crew hang fenders on the side she is coming to
			if fenderSign ~= sign and Vector3.new(loc.X, 0, loc.Z).Magnitude < 25 then
				fenderSign = sign
				placeFenders(sign, 3)
				Kit.hands("fenders")
			end
			local want = slot()
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
				if contactSpeed > 4 then
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
