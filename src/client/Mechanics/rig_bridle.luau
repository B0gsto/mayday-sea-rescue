--!strict
-- Pass the tow and rig it (docs 09 section 6 step 5). The casualty crew hauls the tow line across
-- on the heaving line while you pay out with a steady two-hand rhythm (left and right click, two
-- pads, or LB/RB): too fast and slack piles up by your stern where it can foul the propeller.
-- Then her crew makes it fast on her bow (turns spun onto the post, a short visual) with a length
-- for the sea; the tow step's Q/E fine-tunes the length.
-- Metrics: slackNearStern (count).
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local Procedures = require(script.Parent:WaitForChild("Tow"):WaitForChild("Procedures"))

local M = {}

local PAY_PER_PULL = 3 -- studs of line per hand-over-hand pull
local HAUL_RATE = 6 -- studs/s the casualty crew hauls it in (tune)
local SLACK_LIMIT = 10 -- studs of loose line in the water by our stern before it is in danger
local LEFT, RIGHT = "TowPayOutLeft", "TowPayOutRight"

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowRig")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { slackNearStern = 1 }) then
		return cleanup
	end
	local shared = Kit.shared(ctx)
	local model = Kit.casualtyModel(ctx)
	local root = Kit.vehicleRoot(ctx)
	local need = 40
	if model and root then
		need = (model:GetPivot().Position - root.Position).Magnitude + 15
	end
	local paid, hauled, slack = 0, 0, 0
	local lastHand: string? = nil
	local slackEvents = 0
	local slackFlag = false
	local phase = "payout"

	Kit.brief(gui, "Pay out" .. Kit.chip("LMB / RMB", "LB / RB"))

	-- slack lying in the water near our stern: a loop of line drawn off the transom
	local loop: Beam? = nil
	if root then
		local hitch = Kit.hitch(root)
		local a1 = Instance.new("Attachment")
		a1.Name = "SlackLoop"
		a1.Parent = root
		a1.Position = hitch.Position + Vector3.new(1.5, -1.2, 3)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = hitch, a1
		b.Width0, b.Width1 = 0.2, 0.2
		b.FaceCamera = true
		b.Color = ColorSequence.new(Color3.fromRGB(236, 120, 40))
		b.Parent = root
		loop = b
		table.insert(bag, function()
			b:Destroy()
			a1:Destroy()
		end)
	end

	-- her crew makes it fast: a few turns of line spun onto her bow post, then all fast
	local function makeFast()
		phase = "fast"
		ContextActionService:UnbindAction(LEFT)
		ContextActionService:UnbindAction(RIGHT)
		Kit.brief(gui, "")
		shared.rig = {
			lengthStuds = Procedures.lengthStuds(Procedures.rightLength(Kit.intensity(ctx))),
			bridle = true,
			strongPoint = true,
		}
		local hull = model and (model.PrimaryPart or Kit.part(model, "Hull"))
		if hull then
			local turns = Instance.new("Part")
			turns.Name = "BowTurns"
			turns.Shape = Enum.PartType.Cylinder
			turns.Size = Vector3.new(0.9, 0.9, 0.9)
			turns.Color = Color3.fromRGB(236, 120, 40)
			turns.Material = Enum.Material.Fabric
			turns.Anchored, turns.CanCollide, turns.CanQuery = true, false, false
			local at = hull.CFrame * CFrame.new(0, hull.Size.Y / 2 + 0.5, -hull.Size.Z / 2 + 1.5)
			turns.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
			turns.Parent = model
			TweenService:Create(
				turns,
				TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 3),
				{
					CFrame = at * CFrame.Angles(0, math.pi, math.rad(90)),
				}
			):Play()
			table.insert(bag, function()
				turns:Destroy()
			end)
		end
		task.delay(2.5, function()
			if not gui.Parent then
				return
			end
			Kit.say(gui, "Skipper", "All fast, standing clear!", 2.5)
			complete({ metrics = { slackNearStern = slackEvents } })
		end)
	end

	local function pull(hand: string)
		if phase ~= "payout" then
			return
		end
		if lastHand == hand then
			Kit.say(gui, "Crew", "Hand over hand: left, right, left...", 1.5)
			return
		end
		lastHand = hand
		paid += PAY_PER_PULL
		slack += PAY_PER_PULL
		Kit.hands(if hand == "L" then "payout_left" else "payout_right")
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
		RunService.Heartbeat:Connect(function(dt)
			if phase ~= "payout" then
				return
			end
			local take = math.min(slack, HAUL_RATE * dt)
			slack -= take
			hauled += take
			if loop then
				local s = math.clamp(slack / SLACK_LIMIT, 0, 1.5)
				loop.CurveSize0 = -1 - s * 4
				loop.CurveSize1 = 1 + s * 3
				loop.Width0 = 0.2 + s * 0.05
				-- a loose bight near the propeller flashes as it swings in the wash
				loop.Transparency =
					NumberSequence.new(if s > 1 and (os.clock() * 4) % 1 < 0.5 then 0.6 else 0)
			end
			if slack > SLACK_LIMIT and not slackFlag then
				slackFlag = true
				slackEvents += 1
				Kit.say(gui, "Crew", "Slack by the prop! Ease off!", 3)
			elseif slack < SLACK_LIMIT * 0.4 then
				slackFlag = false
			end
			if hauled >= need then
				Kit.say(gui, "Skipper", "Got the end! Making fast.", 2.5)
				makeFast()
			end
		end)
	)
	return cleanup
end

return M
