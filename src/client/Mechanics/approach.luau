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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Approach = require(script.Parent.PIW.Approach)
local Layout = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Wake =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Boat"):WaitForChild("Wake"))

local Mech = {}

Mech.STOP_HOLD = 1.0 -- s stopped in a good position to complete
Mech.RESET_DISTANCE = 60 -- studs: after an abort, open out this far before the next run
Mech.SWIM_REACH = 12 -- studs: a swimmer this close is alongside (Ways.GRAB_RANGE 8 then grabs)

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
	local s = Step.new(ctx, finish, "Approach", 72)
	if Step.autoStub(s, { overSpeedSec = 0, neutralDistance = 6, fromDownwind = true }) then
		return Step.cleanup(s)
	end
	local state = Approach.new()
	local victim = World.victim(ctx)
	-- a wordless gauge row: wind arrow (screen-relative), speed bar with a green slow zone, the
	-- range in metres and an N lamp for neutral (docs/14 section 2)
	local windIcon =
		Ui.text(s.panel, "💨", UDim2.fromOffset(24, 24), UDim2.fromOffset(12, 38), 18)
	windIcon.TextXAlignment = Enum.TextXAlignment.Center
	local windArrow =
		Ui.text(s.panel, "➤", UDim2.fromOffset(24, 24), UDim2.fromOffset(36, 38), 20, true)
	windArrow.TextXAlignment = Enum.TextXAlignment.Center
	local setMeter = Ui.meter(s.panel, "", UDim2.fromOffset(70, 41), 270)
	local range =
		Ui.text(s.panel, "", UDim2.fromOffset(60, 24), UDim2.fromOffset(350, 38), 18, true)
	range.TextXAlignment = Enum.TextXAlignment.Right
	local lamp =
		Ui.text(s.panel, "N", UDim2.fromOffset(28, 24), UDim2.fromOffset(420, 38), 16, true)
	lamp.TextXAlignment = Enum.TextXAlignment.Center
	lamp.BackgroundTransparency = 0
	lamp.BackgroundColor3 = Ui.Theme.Colors.locked
	Ui.Theme.corner(lamp, 6)
	local stoppedFor = 0
	local resetting = false
	local washes = 0
	local lastCall = math.huge
	local coneParts: { Part } = {}
	local eased = false
	-- first calls (docs/15 section 3): no "go round", any stop beside them counts (still graded)
	local guided = Layout.newPlayer()

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
		local h = World.aboardHull(ctx)
		if not h then
			-- a swimmer (docs/14 section 3, Drag): swim up to them and the recovery step's grab
			-- takes over; on foot the boat icon says "get your boat"
			local char = Players.LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not (hrp and World.afloat()) then
				range.Text = "🚤"
				return
			end
			local d = Units.flatDistance(hrp.Position, World.casualtyPos(ctx, victim))
			range.Text = `{math.floor(d / Units.STUDS_PER_M + 0.5)} m`
			if d <= Mech.SWIM_REACH then
				Step.finish(s, { metrics = Approach.metrics(state) })
			end
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
		local cam = Workspace.CurrentCamera
		if cam then
			local down = Units.windVector(wind)
			local look = Units.flat(cam.CFrame.LookVector)
			local f = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
			local r = Vector3.new(-f.Z, 0, f.X)
			windArrow.Rotation = math.deg(math.atan2(-down:Dot(f), down:Dot(r)))
		end
		if resetting then
			range.Text = "↺"
			if distance > Mech.RESET_DISTANCE then
				resetting = false
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
		range.Text = `{math.floor(distance / Units.STUDS_PER_M + 0.5)} m`
		lamp.BackgroundColor3 = if neutral then Ui.Theme.Colors.ready else Ui.Theme.Colors.locked
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
		if
			not guided
			and (onTop or (where == "astern" and distance < 6) or (drifting and stoppedFor > 1.5))
		then
			Approach.abort(state, drifting or not Approach.isDownwindOf(h.position, cas, wind))
			resetting = true
			stoppedFor = 0
			lastCall = math.huge
			s.say('Crew: "Abort, abort! Go round!"', 3)
			Ui.hands("wave_off")
			return
		end
		local near = distance < (if guided then 14 else 8) -- a first-timer stops "about there"
		if speed < Approach.STOP_SPEED and near and (guided or (ok and not drifting)) then
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
	return Step.cleanup(s)
end

return Mech
