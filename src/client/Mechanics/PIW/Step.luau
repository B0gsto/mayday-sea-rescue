--!strict
-- PIW/Step: the scaffold every Person in the Water mechanic shares: one cleanup bag, a compact
-- panel low on the screen, a crew call-out line, finish-exactly-once, and the smoke-run shortcut
-- (the OpsAutoStub player attribute makes a mechanic finish by itself with a stub result).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OpsStepCard =
	require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("OpsStepCard"))
local Ui = require(script.Parent.Ui)

local Step = {}

export type S = {
	ctx: { [string]: any },
	bag: Ui.Bag,
	gui: ScreenGui,
	panel: Frame,
	say: (string, number?) -> (),
	assist: boolean,
	t0: number,
	finished: boolean,
	finishFn: (result: { [string]: any }) -> (),
}

function Step.new(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> (),
	name: string,
	height: number?,
	compact: boolean?
): S
	local bag = Ui.bag()
	local gui = Ui.screen(bag, name)
	local panel = Ui.panel(
		gui,
		UDim2.fromOffset(460, height or 96),
		UDim2.new(0, 24, 1, -24),
		Vector2.new(0, 1)
	)
	if not compact then
		-- icon + 1-3 words, like the objective chip (docs/14 section 2): no sentence, no jargon
		local id = ctx.step.id
		Ui.header(panel, `{OpsStepCard.iconFor(id)}  {OpsStepCard.shortFor(id, ctx.step.label)}`)
	end
	local s: S = {
		ctx = ctx,
		bag = bag,
		gui = gui,
		panel = panel,
		say = Ui.callout(bag, gui),
		assist = ctx.isAssist ~= false,
		t0 = os.clock(),
		finished = false,
		finishFn = finish,
	}
	return s
end

function Step.elapsed(s: S): number
	return os.clock() - s.t0
end

function Step.finish(s: S, result: { [string]: any })
	if s.finished then
		return
	end
	s.finished = true
	Ui.clean(s.bag)
	-- the server rejects a result under the step's minSeconds (TooFast) and restarts the step: a
	-- launch accepted while already seated looped there for good, the strip stuck on "Go" (playtest 2)
	local early = (s.ctx.step and s.ctx.step.minSeconds or 0.5) + 0.15 - Step.elapsed(s)
	if early > 0 then
		task.delay(early, s.finishFn, result)
	else
		s.finishFn(result)
	end
end

function Step.cleanup(s: S): () -> ()
	return function()
		s.finished = true
		Ui.clean(s.bag)
	end
end

function Step.heartbeat(s: S, fn: (number) -> ())
	Ui.add(
		s.bag,
		RunService.Heartbeat:Connect(function(dt)
			if not s.finished then
				fn(dt)
			end
		end)
	)
end

-- Returns true (and finishes with the stub) on smoke runs.
function Step.autoStub(s: S, metrics: { [string]: any }?): boolean
	if Players.LocalPlayer:GetAttribute("OpsAutoStub") ~= true then
		-- the smoke driver may switch the stub on mid-step (e.g. the cold open's first step)
		Ui.add(
			s.bag,
			Players.LocalPlayer:GetAttributeChangedSignal("OpsAutoStub"):Connect(function()
				if Players.LocalPlayer:GetAttribute("OpsAutoStub") == true then
					Step.finish(s, { metrics = metrics or {}, stub = true, grade = "Silver" })
				end
			end)
		)
		return false
	end
	Ui.add(
		s.bag,
		task.delay(1, function()
			Step.finish(s, { metrics = metrics or {}, stub = true, grade = "Silver" })
		end)
	)
	return true
end

-- Body text line under the header, returned so the mechanic can update it.
function Step.line(s: S, text: string, y: number?): TextLabel
	return Ui.text(s.panel, text, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, y or 54))
end

-- The vehicle's cruise speed (studs/s) for ETA and route time: 80% of its top speed.
function Step.cruiseSpeed(vehicle: Model?): number
	local ok, speed = pcall(function()
		local cfg = (require :: any)(
			ReplicatedStorage:WaitForChild("Shared")
				:WaitForChild("Config")
				:WaitForChild("VehicleConfig")
		)
		local id = vehicle and (vehicle:GetAttribute("VehicleId") or vehicle.Name) or "RIB"
		for _, key in cfg.Order do
			if string.find(string.lower(tostring(id)), string.lower(key)) then
				return cfg[key].topSpeed * 0.8
			end
		end
		return cfg.RIB.topSpeed * 0.8
	end)
	return if ok and type(speed) == "number" then speed else 45
end

return Step
