--!strict
-- fire_crew_off (docs/09 8.2, Take the crew off first): bring the lifeboat alongside the burning
-- cruiser's bow, where the two people are waiting clear of the smoke, slowly enough to hold
-- there; they step across. Metrics: contactSpeed (studs/s), peopleOff (count), elapsed (server).
-- Controls: ordinary driving (W/S A/D, stick, RT/LT).
local Scene = require(script.Parent:WaitForChild("Scene"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))
local Units = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Units"))
local World = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("World"))

local CrewOff = {}

CrewOff.REACH = 18 -- studs from the boat's hull to the bow
CrewOff.SLOW = 3 -- studs/s alongside
CrewOff.HOLD = 1.5 -- s held alongside

function CrewOff.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "FireCrewOff", 100)
	if Step.autoStub(s, { contactSpeed = 0.5, peopleOff = 2 }) then
		return Step.cleanup(s)
	end
	local info = Step.line(s, "", 54)
	local range = Step.line(s, "", 76)
	local hold = 0

	Step.heartbeat(s, function(dt)
		local model = Scene.burning()
		local hull = World.hull(World.vehicle(ctx))
		local bow = Scene.bow(model)
		if not (model and hull and bow) then
			info.Text = "Get alongside the bow"
			range.Text = ""
			hold = 0
			return
		end
		local distance = Units.flatDistance(hull.position, bow.WorldPosition)
		local speed = hull.velocity.Magnitude
		local good = distance <= CrewOff.REACH and speed <= CrewOff.SLOW
		if good then
			hold += dt
		else
			hold = 0
		end
		info.Text = if distance > CrewOff.REACH
			then "Alongside the bow"
			elseif speed > CrewOff.SLOW then "Ease off"
			else "Hold her steady"
		info.TextColor3 = if good then Ui.Theme.Colors.ready else Ui.Theme.Colors.text
		range.Text = `{math.floor(distance / Units.STUDS_PER_M + 0.5)} m · {string.format(
			"%.1f",
			speed / Units.KNOT
		)} kn`
		if hold >= CrewOff.HOLD then
			Step.finish(s, {
				metrics = {
					contactSpeed = math.floor(speed * 10 + 0.5) / 10,
					peopleOff = Scene.people(model),
				},
			})
		end
	end)
	return Step.cleanup(s)
end

return CrewOff
