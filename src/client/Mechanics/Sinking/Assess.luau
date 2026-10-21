--!strict
-- sinking_assess (docs/09 section 8.1): read her from the world. Look at the swirl where the
-- water comes in and ask the crew still on the cabin roof; the list and the waterline climbing
-- her side tell the rest. Two world actions, no cards. Ends when both are done.
local Find = require(script.Parent:WaitForChild("Find"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))

local Assess = {}

function Assess.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "SinkingAssess", 140)
	if Step.autoStub(s, { found = 1 }) then
		return Step.cleanup(s)
	end
	local scene = Find.scene(ctx)
	local hull = Find.part(scene, "Hull")
	local meter = Ui.meter(s.panel, "Waterline", UDim2.fromOffset(12, 78), 420)
	Step.line(s, "Look and ask", 56)

	local seenLeak, askedCrew = false, false
	local function check()
		if seenLeak and askedCrew and not s.finished then
			task.delay(0.5, function()
				Ui.handsStop()
				Step.finish(s, { metrics = { found = 1 } })
			end)
		end
	end

	local attaching = true
	task.spawn(function()
		local leak, crewPoint: BasePart? = nil, nil
		while attaching and not s.finished do
			if not scene or not scene.Parent then
				scene = Find.scene(ctx)
			end
			if scene then
				if not leak then
					leak = Find.part(scene, "LeakPoint")
					if leak then
						local prompt = Ui.add(s.bag, Find.prompt(leak, "Look at the leak", 0.7))
						prompt.Triggered:Connect(function()
							seenLeak = true
							prompt.Enabled = false
							Ui.hands("point")
							task.delay(1.2, function()
								if not s.finished then
									Step.line(s, "Water in her quarter", 56)
								end
							end)
							check()
						end)
					end
				end
				if not crewPoint then
					local crew = Find.crew(scene)
					crewPoint = if crew[1] then crew[1].PrimaryPart else nil
					if crewPoint then
						local prompt = Ui.add(s.bag, Find.prompt(crewPoint, "Ask the crew", 0.7))
						prompt.Triggered:Connect(function()
							askedCrew = true
							prompt.Enabled = false
							Ui.hands("radio_handset")
							task.delay(1.2, function()
								if not s.finished then
									Step.line(s, "Three aboard, all on", 56)
								end
							end)
							check()
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
		if hull and hull.Parent then
			local flood = hull:GetAttribute("Flood")
			if type(flood) == "number" then
				meter(math.clamp(flood, 0, 1))
			end
		else
			hull = Find.part(scene, "Hull")
		end
	end)
	return Step.cleanup(s)
end

return Assess
