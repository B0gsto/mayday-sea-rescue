--!strict
-- transport (docs 09 step 9, section 5.7): pick the destination on the radio, then bring them in
-- with a ride comfort needle that jumps on every hard landing. Hard slams hurt a cold casualty
-- (the server turns `slam` events into condition, cap 6). The server grades conditionAtEnd when
-- the boat reaches a pad; this client reports when it is slow and close to one.
-- Extra metric: destinationRight (bool, not banded yet). Controls: destination cards, then drive.
local Workspace = game:GetService("Workspace")

local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Transport = {}

Transport.HARD_SLAM = 9 -- telemetry slam strength felt as a hard landing -- tune
Transport.PAD_RANGE = 60 -- studs from a drop-off pad, slow: alongside

local function nearestPad(p: Vector3): (Vector3?, number)
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs")
	local best: Vector3?, bestD = nil, math.huge
	if folder then
		for _, pad in folder:GetChildren() do
			if pad:IsA("BasePart") and pad:GetAttribute("DropOff") ~= nil then
				local d = Units.flatDistance(pad.Position, p)
				if d < bestD then
					best, bestD = pad.Position, d
				end
			end
		end
	end
	return best, bestD
end

function Transport.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Transport", 120)
	if Step.autoStub(s) then
		return Step.cleanup(s)
	end
	local profile = Record.profile(ctx)
	local band = ctx.casualty and ctx.casualty.band or "Stable"
	local needsHeli = profile.notBreathing or band == "Critical" or band == "Serious"
	local cold = profile.state == "VeryCold"
		or profile.state == "Unresponsive"
		or profile.state == "Exhausted"
	local info = Step.line(s, "Where are they going?", 54)
	local destinationRight = true
	local slams = 0
	local comfort = 0

	local function drive()
		local setMeter = Ui.meter(s.panel, "Ride comfort (casualty)", UDim2.fromOffset(12, 76), 436)
		Step.heartbeat(s, function(dt)
			local slam = World.slam()
			if slam > Transport.HARD_SLAM then
				slams += 1
				comfort = math.min(1, comfort + 0.35)
				if cold then
					s.say(
						if slams == 1
							then 'Medic: "Easy! They\'re very cold."'
							else 'Medic: "Ease off on the crests!"'
					)
				end
				Ui.hands("brace")
			elseif slam > Transport.HARD_SLAM * 0.5 then
				comfort = math.min(1, comfort + 0.08)
			end
			comfort = math.max(0, comfort - 0.12 * dt)
			setMeter(1 - comfort, 0.6, 1)
			local h = World.hull(World.vehicle(ctx))
			if h then
				local _, d = nearestPad(h.position)
				if d <= Transport.PAD_RANGE and h.velocity.Magnitude < 8 then
					Step.finish(s, {
						metrics = { destinationRight = destinationRight },
						events = if slams > 0 then { slam = slams } else nil,
					})
				end
			end
		end)
	end

	local cards: Frame? = nil
	cards = Ui.cards(s.bag, s.gui, {
		title = "Destination",
		cue = if needsHeli
			then "They're getting worse. Who can get them to hospital fastest?"
			else "Talking, warming up slowly.",
		options = { "Station slipway (ambulance)", "Hospital pontoon", "Request Rescue Gale One" },
		answer = if needsHeli then 3 else 1,
		assist = s.assist,
	}, function(i)
		destinationRight = (i == 3) == needsHeli
		if cards then
			cards:Destroy()
		end
		if i == 3 then
			s.say('Coastguard: "Rescue Gale One will meet you at the station."', 3)
		end
		info.Text = if cold
			then "Cold casualty: quarter the waves, ease off on every crest."
			else "Bring them home."
		drive()
	end)
	Ui.add(s.bag, cards)
	return Step.cleanup(s)
end

return Transport
