--!strict
-- ViewmodelActions: the first-person arm actions as data (pure; tests/CameraViewmodel.spec.luau).
-- Every key gives the wrist targets of both hands in camera space (X right, Y up, -Z ahead; studs,
-- 1 m = 3 studs) and a grip (0 open .. 1 fist). Viewmodel.luau solves the arms by two-bone IK.
-- Hands at REST sit below the frame, so arms rise into view when an action starts.
export type Key = {
	t: number, -- seconds from the start
	r: Vector3, -- right wrist
	l: Vector3, -- left wrist
	grip: number?, -- 0..1
	prop: string?, -- a prop shown from this key on ("radio", "throwbag"; "" hides it)
}
export type Action = {
	duration: number,
	loop: boolean?, -- loops until stopped (haul, cpr, steer)
	keys: { Key },
}

local Actions = {}

Actions.REST_R = Vector3.new(0.75, -2.6, -0.9)
Actions.REST_L = Vector3.new(-0.75, -2.6, -0.9)

local R0, L0 = Actions.REST_R, Actions.REST_L

Actions.Defs = {
	-- throw bag, underarm: bag drawn back low, swung forward and up, released at 0.55 s while the
	-- left hand keeps hold of the line end
	throw = {
		duration = 1.2,
		keys = {
			{ t = 0, r = R0, l = L0, grip = 1, prop = "throwbag" },
			{
				t = 0.25,
				r = Vector3.new(0.7, -1.5, -0.5),
				l = Vector3.new(-0.35, -1.0, -1.1),
				grip = 1,
			},
			{
				t = 0.4,
				r = Vector3.new(0.75, -1.7, -0.2),
				l = Vector3.new(-0.35, -1.0, -1.1),
				grip = 1,
			},
			{
				t = 0.55,
				r = Vector3.new(0.45, -0.6, -1.9),
				l = Vector3.new(-0.35, -1.0, -1.2),
				grip = 0,
				prop = "",
			},
			{
				t = 0.8,
				r = Vector3.new(0.35, -0.2, -2.1),
				l = Vector3.new(-0.35, -1.0, -1.2),
				grip = 0,
			},
			{ t = 1.2, r = R0, l = L0, grip = 0.3 },
		},
	},
	-- hand over hand on a line (a throw-bag line or a heaving line), loops
	haul = {
		duration = 1.2,
		loop = true,
		keys = {
			{
				t = 0,
				r = Vector3.new(0.3, -1.1, -2.1),
				l = Vector3.new(-0.3, -1.4, -0.9),
				grip = 1,
			},
			{
				t = 0.6,
				r = Vector3.new(0.3, -1.4, -0.9),
				l = Vector3.new(-0.3, -1.1, -2.1),
				grip = 1,
			},
			{
				t = 1.2,
				r = Vector3.new(0.3, -1.1, -2.1),
				l = Vector3.new(-0.3, -1.4, -0.9),
				grip = 1,
			},
		},
	},
	-- both hands down over the side to the casualty's lifejacket shoulders, then lift
	grab = {
		duration = 1.0,
		keys = {
			{ t = 0, r = R0, l = L0, grip = 0 },
			{
				t = 0.35,
				r = Vector3.new(0.35, -1.8, -1.9),
				l = Vector3.new(-0.35, -1.8, -1.9),
				grip = 0,
			},
			{
				t = 0.5,
				r = Vector3.new(0.3, -1.85, -1.85),
				l = Vector3.new(-0.3, -1.85, -1.85),
				grip = 1,
			},
			{
				t = 1.0,
				r = Vector3.new(0.35, -1.1, -1.2),
				l = Vector3.new(-0.35, -1.1, -1.2),
				grip = 1,
			},
		},
	},
	-- handheld VHF up to the mouth (left hand, thumb on the press-to-talk), held, then down
	radio = {
		duration = 1.8,
		keys = {
			{ t = 0, r = R0, l = L0, grip = 1, prop = "radio" },
			{ t = 0.35, r = R0, l = Vector3.new(-0.3, -0.45, -0.75), grip = 1 },
			{ t = 1.45, r = R0, l = Vector3.new(-0.28, -0.42, -0.72), grip = 1 },
			{ t = 1.8, r = R0, l = L0, grip = 1, prop = "" },
		},
	},
	-- chest compressions: hands stacked, 5 cm deep at 110 a minute (one cycle = 0.545 s), loops
	cpr = {
		duration = 0.545,
		loop = true,
		keys = {
			{
				t = 0,
				r = Vector3.new(0.02, -1.55, -1.25),
				l = Vector3.new(-0.02, -1.5, -1.25),
				grip = 0.4,
			},
			{
				t = 0.27,
				r = Vector3.new(0.02, -1.7, -1.25),
				l = Vector3.new(-0.02, -1.65, -1.25),
				grip = 0.4,
			},
			{
				t = 0.545,
				r = Vector3.new(0.02, -1.55, -1.25),
				l = Vector3.new(-0.02, -1.5, -1.25),
				grip = 0.4,
			},
		},
	},
	-- three firm knocks on an upturned hull ahead (listen for a reply between them)
	knock = {
		duration = 1.5,
		keys = {
			{ t = 0, r = R0, l = L0, grip = 1 },
			{ t = 0.3, r = Vector3.new(0.35, -0.6, -1.3), l = L0, grip = 1 },
			{ t = 0.42, r = Vector3.new(0.3, -0.55, -1.75), l = L0, grip = 1 },
			{ t = 0.6, r = Vector3.new(0.35, -0.6, -1.3), l = L0, grip = 1 },
			{ t = 0.72, r = Vector3.new(0.3, -0.55, -1.75), l = L0, grip = 1 },
			{ t = 0.9, r = Vector3.new(0.35, -0.6, -1.3), l = L0, grip = 1 },
			{ t = 1.02, r = Vector3.new(0.3, -0.55, -1.75), l = L0, grip = 1 },
			{ t = 1.5, r = R0, l = L0, grip = 1 },
		},
	},
	-- spotter's point: arm straight at the casualty and held (never take your eyes off them)
	point = {
		duration = 1.6,
		keys = {
			{ t = 0, r = R0, l = L0, grip = 0.6 },
			{ t = 0.3, r = Vector3.new(0.4, -0.4, -2.15), l = L0, grip = 0.6 },
			{ t = 1.3, r = Vector3.new(0.4, -0.38, -2.15), l = L0, grip = 0.6 },
			{ t = 1.6, r = R0, l = L0, grip = 0.6 },
		},
	},
	-- hands on the jet ski's handlebars (Viewmodel.setSteer turns them), loops as a base pose
	steer = {
		duration = 1,
		loop = true,
		keys = {
			{
				t = 0,
				r = Vector3.new(0.68, -1.15, -1.35),
				l = Vector3.new(-0.68, -1.15, -1.35),
				grip = 1,
			},
			{
				t = 1,
				r = Vector3.new(0.68, -1.15, -1.35),
				l = Vector3.new(-0.68, -1.15, -1.35),
				grip = 1,
			},
		},
	},
} :: { [string]: Action }

Actions.Names = { "throw", "haul", "grab", "radio", "cpr", "knock", "point", "steer" }

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

-- Samples an action at time t (seconds; loops wrap). Returns right wrist, left wrist, grip and
-- the prop showing at that time ("" for none).
function Actions.sample(action: Action, t: number): (Vector3, Vector3, number, string)
	local keys = action.keys
	local time = if action.loop then t % action.duration else math.clamp(t, 0, action.duration)
	local prop = ""
	local prev = keys[1]
	for _, key in keys do
		if key.t <= time and key.prop ~= nil then
			prop = key.prop :: string
		end
	end
	for i = 2, #keys do
		local key = keys[i]
		if time <= key.t then
			local span = key.t - prev.t
			local f = if span > 0 then ease((time - prev.t) / span) else 1
			local g0, g1 = prev.grip or 0, key.grip or prev.grip or 0
			return prev.r:Lerp(key.r, f), prev.l:Lerp(key.l, f), g0 + (g1 - g0) * f, prop
		end
		prev = key
	end
	local last = keys[#keys]
	return last.r, last.l, last.grip or 0, prop
end

return Actions
