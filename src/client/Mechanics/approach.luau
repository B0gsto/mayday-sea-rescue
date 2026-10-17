--!strict
-- approach (docs 09 step 5): come in from downwind, heading into wind and sea, dead slow (under
-- 3 knots in the last 30 m), shift to neutral at 3 to 8 studs and glide; stop with the casualty
-- alongside or at the bow, forward of the propeller. The boat's own wake (shared/Boat/Wake)
-- pushes the casualty away and washes over them when you come in fast. Coming down on them
-- from upwind, or putting them near the propeller, makes the crew call "Abort, go round".
-- Metrics: overSpeedSec, neutralDistance (studs), fromDownwind (bool), assistEase (true when the
-- cold open's Assist ease braked the hull: BoatController's AssistEase attribute; the server
-- caps the grade at Silver); events: wash (cap 2).
-- Controls: normal driving (W/S A/D, stick, RT/LT), neutral X / B / the slider's neutral notch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Approach = require(script.Parent.PIW.Approach)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Wake =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Boat"):WaitForChild("Wake"))

local Mech = {}

Mech.STOP_HOLD = 1.0 -- s stopped in a good position to complete
Mech.RESET_DISTANCE = 60 -- studs: after an abort, open out this far before the next run

local function windNow(ctx: { [string]: any }): number
	local ok, w = pcall(function()
		local Weather = (require :: any)(
			ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather")
		)
		return Weather.getWindDirection()
	end)
	if ok and type(w) == "number" then
		return w
	end
	return ctx.scene and ctx.scene.windDirection or 0
end

function Mech.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Approach", 140)
	if Step.autoStub(s, { overSpeedSec = 0, neutralDistance = 6, fromDownwind = true }) then
		return Step.cleanup(s)
	end
	local state = Approach.new()
	local victim = World.victim(ctx)
	local info = Step.line(s, "Come round downwind of them, bow into the wind.", 54)
	local speedLine = Step.line(s, "", 76)
	local setMeter = Ui.meter(s.panel, "Speed (slow mark)", UDim2.fromOffset(12, 98), 436)
	local stoppedFor = 0
	local resetting = false
	local washes = 0
	local lastCall = math.huge
	local coneParts: { Part } = {}
	local eased = false

	-- Assist: the approach cone on the water, from the casualty downwind (no glow; thin lines)
	local function drawCone(cas: Vector3, wind: number)
		for _, p in coneParts do
			p:Destroy()
		end
		table.clear(coneParts)
		if not s.assist then
			return
		end
		local down = Units.windVector(wind)
		for _, side in { -1, 1 } do
			local a = math.rad(30) * side
			local dir = Vector3.new(
				down.X * math.cos(a) - down.Z * math.sin(a),
				0,
				down.X * math.sin(a) + down.Z * math.cos(a)
			)
			table.insert(
				coneParts,
				World.line(
					s.bag,
					cas + dir * 8,
					cas + dir * Approach.FINAL_RUN,
					Color3.fromRGB(240, 240, 230),
					0.2
				)
			)
		end
	end
	local coneAt = Vector3.zero

	Step.heartbeat(s, function(dt)
		local vehicle = World.vehicle(ctx)
		local h = World.hull(vehicle)
		if not h then
			info.Text = "Get aboard your boat."
			return
		end
		if vehicle and vehicle:GetAttribute("AssistEase") == true then
			eased = true
		end
		local wind = windNow(ctx)
		local base = World.casualtyPos(ctx, victim)
		local cas = base + state.offset -- the wake has pushed them this far
		if (cas - coneAt).Magnitude > 6 then
			coneAt = cas
			drawCone(cas, wind)
		end
		local distance = math.max(0, Units.flatDistance(h.position, cas) - h.beam / 2)
		local speed = Units.flat(h.velocity).Magnitude
		local push, height = Wake.at(cas, {
			position = h.position,
			velocity = h.velocity,
			forward = h.forward,
			length = h.length,
			beam = h.beam,
		})
		local neutral = World.isNeutral(vehicle)
		if resetting then
			info.Text = "Open out, then come round again from downwind."
			if distance > Mech.RESET_DISTANCE then
				resetting = false
				info.Text = "Come round downwind of them, bow into the wind."
			end
			return
		end
		local washed = Approach.sample(state, dt, {
			distance = distance,
			speed = speed,
			forward = h.forward,
			boatPos = h.position,
			casualtyPos = cas,
			windDirection = wind,
			neutral = neutral,
			wakeHeight = height,
			wakePush = push,
		})
		if washed then
			washes += 1
			s.say('Crew: "You\'ve washed them! Slow down!"')
		end
		local knots = speed / Units.KNOT
		speedLine.Text = `{string.format("%.1f", knots)} kn   {math.floor(
			distance / Units.STUDS_PER_M + 0.5
		)} m` .. (if neutral then "   NEUTRAL" else "")
		setMeter(math.clamp(speed / (Approach.SLOW * 3), 0, 1), 0, 1 / 3)
		-- the crew calls the distance in the last 10 m (real practice: bow crew calls it)
		local metres = math.floor(distance / Units.STUDS_PER_M)
		if distance < 30 and metres < lastCall and metres % 2 == 0 then
			lastCall = metres
			s.say(`Crew: "{metres} metres..."`, 1.2)
		end
		-- abort: on top of them, drifting down onto them from upwind, or near the propeller
		local localPos = h.cframe:PointToObjectSpace(cas)
		local ok, where = Approach.stopPosition(localPos, h.length, h.beam)
		local onTop = distance < Approach.CONTACT and speed > 2
		local drifting = distance < 6
			and not Approach.isDownwindOf(h.position, cas, wind)
			and speed < 2
		if onTop or (where == "astern" and distance < 6) or (drifting and stoppedFor > 1.5) then
			Approach.abort(state, drifting or not Approach.isDownwindOf(h.position, cas, wind))
			resetting = true
			stoppedFor = 0
			lastCall = math.huge
			s.say('Crew: "Abort, abort! Go round!"', 3)
			Ui.hands("wave_off")
			return
		end
		if speed < Approach.STOP_SPEED and distance < 8 and ok and not drifting then
			stoppedFor += dt
			if stoppedFor >= Mech.STOP_HOLD then
				Ui.hands("reach_casualty")
				s.say(
					if where == "bow"
						then 'Crew: "At the bow, got them."'
						else 'Crew: "Alongside, got them."'
				)
				local metrics: { [string]: any } = Approach.metrics(state)
				if eased then
					metrics.assistEase = true
				end
				Step.finish(s, {
					metrics = metrics,
					events = if washes > 0 then { wash = washes } else nil,
				})
			end
		else
			stoppedFor = if drifting then stoppedFor + dt else 0
		end
	end)
	Ui.hint(s.panel, "Under the slow mark for the last 30 m, neutral at a few metres.", s.assist)
	return Step.cleanup(s)
end

return Mech
