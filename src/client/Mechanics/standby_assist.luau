--!strict
-- standby_assist (docs 09 section 2.5): the Coastguard takes over; stand by and assist. In a boat:
-- hold station head to wind under the helicopter while the winchman works (a 12 m circle,
-- dead slow, bow into the wind). On foot or as crew: keep a light on the casualty (reticle on
-- them). Metric: steady (0..1, the share of the lift spent steady).
-- Controls: throttle / steer (W A S D, stick, RT/LT) or look at them (mouse, drag, right stick).
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Standby = {}

Standby.LIFT_SECONDS = 20
Standby.RADIUS = 12 * Units.STUDS_PER_M / 3 -- 12 studs (4 m)
Standby.SLOW = 2.5 -- studs/s
Standby.LIGHT_DEG = 7

function Standby.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Standby", 120)
	if Step.autoStub(s, { steady = 0.9 }) then
		return Step.cleanup(s)
	end
	local victim = World.victim(ctx)
	local vehicle = World.vehicle(ctx)
	local driving = World.isDriver(vehicle)
	local wind = ctx.scene and ctx.scene.windDirection or 0
	local anchor = World.hull(vehicle)
	local centre = if anchor then anchor.position else World.casualtyPos(ctx, victim)
	local info = Step.line(s, if driving then "Steady · head to wind" else "Light on casualty", 54)
	local setMeter = Ui.meter(s.panel, "Steady", UDim2.fromOffset(12, 78), 436)
	Ui.hint(s.panel, if driving then "Small throttle" else "Keep centred", s.assist)
	if not driving then
		Ui.hands("torch")
	end
	local t, good = 0, 0
	Step.heartbeat(s, function(dt)
		t += dt
		local steady: boolean
		if driving then
			local h = World.hull(World.vehicle(ctx))
			steady = h ~= nil
				and Units.flatDistance(h.position, centre) <= Standby.RADIUS
				and h.velocity.Magnitude <= Standby.SLOW
				and h.forward:Dot(-Units.windVector(wind)) > 0.5
		else
			steady = World.lookError(World.casualtyPos(ctx, victim)) <= Standby.LIGHT_DEG
		end
		if steady then
			good += dt
		end
		setMeter(good / math.max(t, 1e-3), 0.8, 1)
		local left = math.ceil(Standby.LIFT_SECONDS - t)
		info.Text = if left > 0 then `Winch · {left}s` else "Aboard"
		if t >= Standby.LIFT_SECONDS then
			Step.finish(s, { metrics = { steady = math.floor(good / t * 100 + 0.5) / 100 } })
		end
	end)
	return Step.cleanup(s)
end

return Standby
