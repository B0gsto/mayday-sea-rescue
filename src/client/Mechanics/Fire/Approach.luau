--!strict
-- fire_approach (docs/09 8.2, Approach): come in from upwind with the smoke blowing away, stop
-- at a firefighting stand-off and hold there. Downwind the plume crosses the deck and the crew
-- calls the boat back out; smoke in the boat is graded. Metrics: upwind (bool), smokeSeconds,
-- standOff (studs, for the debrief), elapsed (server).
-- Controls: ordinary driving (W/S A/D, stick, RT/LT).
local Scene = require(script.Parent:WaitForChild("Scene"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))
local Units = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Units"))
local World = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("World"))

local Approach = {}

Approach.MIN_STANDOFF = 24 -- studs: outside the heat
Approach.MAX_STANDOFF = 90 -- studs: inside the monitor's reach
Approach.HOLD = 2.5 -- s in a good position

function Approach.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "FireApproach", 58, true)
	if Step.autoStub(s, { upwind = true, smokeSeconds = 0, standOff = 40 }) then
		return Step.cleanup(s)
	end
	-- one icon and at most three words: the status is the whole panel (docs/14 section 2)
	s.panel.Size = UDim2.fromOffset(300, 58)
	local _, status = Ui.hint(s.panel, "Get under way", true, "🔥")
	local hold = 0
	local smokeSeconds = 0
	local bestDownwind = false

	Step.heartbeat(s, function(dt)
		local model = Scene.burning()
		local hull = World.hull(World.vehicle(ctx))
		local fire = Scene.base(model)
		if not (model and hull and fire) then
			status.Text = "Get under way"
			status.TextColor3 = Ui.Theme.Colors.accent
			hold = 0
			return
		end
		local firePos = fire.WorldPosition
		local distance = Units.flatDistance(hull.position, firePos)
		local upwind = Scene.upwind(firePos, hull.position)
		local inPlume = Scene.inPlume(firePos, hull.position)
		if inPlume then
			smokeSeconds += dt
		end
		bestDownwind = not upwind
		local good = upwind
			and not inPlume
			and distance >= Approach.MIN_STANDOFF
			and distance <= Approach.MAX_STANDOFF
		if good then
			hold += dt
		else
			hold = 0
		end
		status.Text = if inPlume
			then "Smoke! Go round"
			elseif not upwind then "Go upwind"
			elseif distance < Approach.MIN_STANDOFF then "Back off"
			elseif distance > Approach.MAX_STANDOFF then `Upwind {math.floor(
				distance / Units.STUDS_PER_M + 0.5
			)} m`
			else "Hold here"
		status.TextColor3 = if good then Ui.Theme.Colors.textDim else Ui.Theme.Colors.accent
		if hold >= Approach.HOLD then
			Step.finish(s, {
				metrics = {
					upwind = not bestDownwind,
					smokeSeconds = math.floor(smokeSeconds * 10 + 0.5) / 10,
					standOff = math.floor(distance * 10 + 0.5) / 10,
				},
			})
		end
	end)
	return Step.cleanup(s)
end

return Approach
