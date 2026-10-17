--!strict
-- passage (docs 09 step 3, Passage and ETA): the Navigator gives the Coastguard an ETA, then the
-- Helm drives. Quartering the waves and easing off on crests keeps speed without slamming.
-- Metrics: routeRatio (time / best route time, >= 1), etaError (fraction of the real time).
-- Controls: ETA cards (1-3 / tap / A B X), then normal driving; the step ends inside the search
-- area (about 85 m from the datum).
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Passage = {}

Passage.ARRIVE = 260 -- studs from the datum: on scene, start the search
Passage.HARD_SLAM = 9 -- telemetry slam strength that a crew feels as a bang

function Passage.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Passage", 120)
	if Step.autoStub(s, { routeRatio = 1.1, etaError = 0.1 }) then
		return Step.cleanup(s)
	end
	local datum: Vector3 = ctx.operation.position
	local vehicle = World.vehicle(ctx)
	local cruise = Step.cruiseSpeed(vehicle)
	local function here(): Vector3?
		local h = World.hull(World.vehicle(ctx))
		if h then
			return h.position
		end
		local char = game:GetService("Players").LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root and root.Position
	end
	local start = here() or datum
	local distance = math.max(0, Units.flatDistance(start, datum) - Passage.ARRIVE)
	local options, right = Units.etaOptions(distance, cruise, Units.hash01(ctx.operation.id, 7))
	local info = Step.line(s, "Give the Coastguard your ETA.", 54)
	local chosen: number? = nil
	local driveStart = 0
	local slams = 0

	local function drive()
		driveStart = os.clock()
		info.Text = `ETA {chosen} min. Quarter the waves, ease off on the crests.`
		local slamLine = Step.line(s, "", 76)
		Step.heartbeat(s, function()
			local p = here()
			if World.slam() > Passage.HARD_SLAM then
				slams += 1
				slamLine.Text = `Slams: {slams} (each one costs time)`
			end
			if p and Units.flatDistance(p, datum) <= Passage.ARRIVE then
				local elapsed = os.clock() - driveStart
				Step.finish(s, {
					metrics = {
						routeRatio = math.floor(
							Units.routeRatio(elapsed, distance, cruise) * 100 + 0.5
						) / 100,
						etaError = math.floor(
							Units.etaError(elapsed, (chosen or 1) * 60) * 100 + 0.5
						) / 100,
					},
				})
			end
		end)
	end

	if distance <= 1 then
		chosen = 1
		Ui.add(s.bag, task.delay(0.6, drive))
		return Step.cleanup(s)
	end
	local labels = {}
	for _, m in options do
		table.insert(labels, `{m} min`)
	end
	local cards: Frame? = nil
	cards = Ui.cards(s.bag, s.gui, {
		title = "ETA to the Coastguard",
		cue = `Datum {math.floor(distance / 3 + 0.5)} m off; cruising about {math.floor(
			cruise / Units.KNOT + 0.5
		)} knots.`,
		options = labels,
		answer = right,
		assist = s.assist,
	}, function(i)
		chosen = options[i]
		if cards then
			cards:Destroy()
		end
		s.say(`"Haven Rescue, on passage, ETA {chosen} minutes."`)
		drive()
	end)
	Ui.add(s.bag, cards)
	return Step.cleanup(s)
end

return Passage
