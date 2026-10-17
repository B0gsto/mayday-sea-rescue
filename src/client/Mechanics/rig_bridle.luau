--!strict
-- Pass the tow and rig it (docs 09 section 6 step 5). The casualty crew hauls the tow line across
-- on the heaving line while you pay out with a steady two-hand rhythm (left and right click, two
-- pads, or LB/RB): too fast and slack piles up by your stern where it can foul the propeller.
-- Then pick the attachment from what you can see on her bow (samson post, or both bow cleats with
-- a bridle; never the rail), the tow length for the sea, and check how her crew made it fast.
-- Metrics: slackNearStern (count), strongPoint (1/0), lengthOk (1/0).
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

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
	if Kit.autoStub(complete, { slackNearStern = 1, strongPoint = 1, lengthOk = 1 }) then
		return cleanup
	end
	local scenario = Kit.scenario(ctx)
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
	local strongPoint, bridle, lengthOk = 0, false, 0

	Kit.brief(
		gui,
		"Pay out the tow line hand over hand, steady, as they haul it across. Keep the slack clear of our stern."
	)

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

	local function nextChoices()
		phase = "attach"
		ContextActionService:UnbindAction(LEFT)
		ContextActionService:UnbindAction(RIGHT)
		local bowText = if scenario.bow == "samson"
			then "Her bow: a stout samson post on the foredeck, two small cleats."
			else "Her bow: two bow cleats, a guard rail, no central post."
		Kit.brief(gui, bowText)
		local rightAttach = if scenario.bow == "samson" then "samson" else "bridle"
		local cancel = Kit.choose(gui, "Make fast to", {
			{ id = "samson", text = "Samson post" },
			{ id = "bridle", text = "Bridle, both cleats" },
			{ id = "cleat", text = "One bow cleat" },
			{ id = "rail", text = "Bow rail" },
		}, function(id)
			local strong, b = Procedures.attachResult(scenario, id)
			if id == "samson" and scenario.bow ~= "samson" then
				Kit.say(gui, "Skipper", "There's no post here, mate!", 3)
			end
			strongPoint = if strong then 1 else 0
			bridle = b
			Kit.hands(if id == "bridle" then "rig_bridle" else "point")
			local intensity = Kit.intensity(ctx)
			local rightLen = Procedures.rightLength(intensity)
			Kit.brief(gui, "How much tow line? Longer in a big sea, so you ride the waves in step.")
			local c2 = Kit.choose(gui, "Tow length", {
				{ id = "short", text = "Short (15 m)" },
				{ id = "medium", text = "Medium (25 m)" },
				{ id = "long", text = "Long (40 m)" },
			}, function(len)
				lengthOk = if len == rightLen then 1 else 0
				shared.rig = {
					lengthStuds = Procedures.lengthStuds(len),
					bridle = bridle,
					strongPoint = strongPoint == 1,
				}
				-- check the casualty crew's work before you take any load
				local seen = Procedures.faultText(scenario.crewFault)
				Kit.brief(gui, `You look at their bow. {seen}`)
				local _, fix = Procedures.faultText(scenario.crewFault)
				local choices = {
					{ id = "ok", text = "Looks good" },
					{ id = "fix", text = fix },
				}
				local c3 = Kit.choose(gui, "Check their work", choices, function(call)
					Kit.hands("hail")
					if scenario.crewFault ~= "none" and call == "ok" then
						-- it will tear out or slip at the first load
						strongPoint = 0
						shared.rig.strongPoint = false
					elseif scenario.crewFault == "none" and call == "fix" then
						Kit.say(gui, "Skipper", "It's done right, honest!", 2.5)
					else
						Kit.say(gui, "Skipper", "Right you are. All fast, standing clear!", 2.5)
					end
					complete({
						metrics = {
							slackNearStern = slackEvents,
							strongPoint = strongPoint,
							lengthOk = lengthOk,
						},
					})
				end, ctx.isAssist, if scenario.crewFault == "none" then "ok" else "fix")
				table.insert(bag, c3)
			end, ctx.isAssist, rightLen)
			table.insert(bag, c2)
		end, ctx.isAssist, rightAttach)
		table.insert(bag, cancel)
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
				Kit.say(gui, "Crew", "Slack by the prop! Ease off, let them take it in.", 3)
			elseif slack < SLACK_LIMIT * 0.4 then
				slackFlag = false
			end
			if hauled >= need then
				Kit.say(gui, "Skipper", "Got the end! Where do you want it?", 3)
				nextChoices()
			end
		end)
	)
	return cleanup
end

return M
