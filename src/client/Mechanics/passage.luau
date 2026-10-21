--!strict
-- passage (docs 09 step 3, Passage and ETA): the Navigator calls the ETA to the Coastguard by
-- itself, then the Helm drives. Quartering the waves and easing off on crests keeps speed without
-- slamming. Metrics: routeRatio (time / best route time, >= 1). Controls: normal driving; the
-- step ends inside the search area (about 85 m from the datum), afloat (aboard or swimming).
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
	s.panel.Visible = false -- the objective strip already shows the step (no duplicate centre box)
	if Step.autoStub(s, { routeRatio = 1.1 }) then
		return Step.cleanup(s)
	end
	local datum: Vector3 = ctx.operation.position
	local vehicle = World.vehicle(ctx)
	local cruise = Step.cruiseSpeed(vehicle)
	local function here(): Vector3?
		local h = World.aboardHull(ctx)
		if h then
			return h.position
		end
		local char = game:GetService("Players").LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root and root.Position
	end
	local start = here() or datum
	local distance = math.max(0, Units.flatDistance(start, datum) - Passage.ARRIVE)
	-- the Navigator calls the ETA itself: the honest estimate at cruise
	local eta = math.max(1, math.floor(distance / math.max(1, cruise) / 60 * 1.15 + 0.5))

	local function drive()
		local driveStart = os.clock()
		Step.heartbeat(s, function()
			local p = here()
			-- on scene means on the water: standing on the quay near the datum is not "there"
			if p and World.afloat() and Units.flatDistance(p, datum) <= Passage.ARRIVE then
				local elapsed = os.clock() - driveStart
				Step.finish(s, {
					metrics = {
						routeRatio = math.floor(
							Units.routeRatio(elapsed, distance, cruise) * 100 + 0.5
						) / 100,
					},
				})
			end
		end)
	end

	if distance > 1 then
		s.say(`Navigator: "On passage, ETA {eta} minutes."`)
	end
	Ui.add(s.bag, task.delay(0.6, drive))
	return Step.cleanup(s)
end

return Passage
