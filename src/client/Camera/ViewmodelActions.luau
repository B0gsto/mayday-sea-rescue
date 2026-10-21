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
	prop: string?, -- a prop shown from this key on (Actions.Props; "" hides it)
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
local V = Vector3.new

-- props the rig can show in a hand (Viewmodel.luau builds and places them)
Actions.Props = { "throwbag", "radio", "torch", "tube", "marker", "phone", "lifebuoy", "blanket" }

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

local Defs = Actions.Defs

---------------------------------------------------------------- boat handling and approach

-- warning another boat off: right hand raised, open palm, waved wide side to side, then down
Defs.wave_off = {
	duration = 2.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.62, 0.2, -1.05), l = L0, grip = 0 },
		{ t = 0.55, r = V(0.3, 0.28, -1.1), l = L0, grip = 0 },
		{ t = 0.8, r = V(0.95, 0.16, -1.0), l = L0, grip = 0 },
		{ t = 1.05, r = V(0.3, 0.28, -1.1), l = L0, grip = 0 },
		{ t = 1.3, r = V(0.95, 0.16, -1.0), l = L0, grip = 0 },
		{ t = 1.55, r = V(0.3, 0.28, -1.1), l = L0, grip = 0 },
		{ t = 1.75, r = V(0.62, 0.2, -1.05), l = L0, grip = 0 },
		{ t = 2.0, r = R0, l = L0, grip = 0 },
	},
}
-- over the bow/side to the casualty: left hand braced on the gunwale, right arm reaches forward
-- and down open, closes on the lifejacket shoulder strap, and draws them in against the hull
Defs.reach_casualty = {
	duration = 2.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.5, -1.15, -1.7), l = V(-0.6, -1.45, -1.0), grip = 0 },
		{ t = 0.7, r = V(0.45, -1.6, -1.65), l = V(-0.6, -1.5, -1.0), grip = 0 },
		{ t = 0.85, r = V(0.45, -1.65, -1.6), l = V(-0.6, -1.5, -1.0), grip = 1 },
		{ t = 1.45, r = V(0.42, -1.25, -1.15), l = V(-0.6, -1.45, -1.0), grip = 1 },
		{ t = 2.0, r = R0, l = L0, grip = 0.4 },
	},
}
-- both hands on the grab handles; a slam jolts them down, they catch and settle
Defs.brace = {
	duration = 1.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.15, r = V(0.55, -1.3, -1.0), l = V(-0.55, -1.3, -1.0), grip = 1 },
		{ t = 0.3, r = V(0.55, -1.45, -0.95), l = V(-0.55, -1.45, -0.95), grip = 1 },
		{ t = 0.55, r = V(0.55, -1.32, -1.0), l = V(-0.55, -1.32, -1.0), grip = 1 },
		{ t = 1.0, r = R0, l = L0, grip = 1 },
	},
}
-- push off the other hull: both arms out straight, palms flat, hold the gap, give
Defs.fend_off = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.45, -0.85, -1.7), l = V(-0.45, -0.85, -1.7), grip = 0 },
		{ t = 0.5, r = V(0.45, -0.85, -1.85), l = V(-0.45, -0.85, -1.85), grip = 0 },
		{ t = 1.0, r = V(0.45, -0.88, -1.75), l = V(-0.45, -0.88, -1.75), grip = 0 },
		{ t = 1.4, r = R0, l = L0, grip = 0 },
	},
}
-- a fender lowered over the side on its lanyard, the left hand feeding the line
Defs.fenders = {
	duration = 1.5,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.3, r = V(0.6, -1.0, -1.0), l = V(0.1, -0.95, -0.9), grip = 1 },
		{ t = 0.8, r = V(1.0, -1.45, -1.25), l = V(0.25, -1.05, -1.0), grip = 1 },
		{ t = 1.1, r = V(1.05, -1.6, -1.3), l = V(0.35, -1.15, -1.05), grip = 1 },
		{ t = 1.5, r = R0, l = L0, grip = 1 },
	},
}
-- lift a line off the cleat and toss it clear of the boat
Defs.cast_off = {
	duration = 1.3,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.4, -1.65, -1.2), l = L0, grip = 0 },
		{ t = 0.45, r = V(0.4, -1.7, -1.2), l = L0, grip = 1 },
		{ t = 0.75, r = V(0.85, -0.85, -1.3), l = L0, grip = 1 },
		{ t = 0.9, r = V(1.1, -0.7, -1.5), l = L0, grip = 0 },
		{ t = 1.3, r = R0, l = L0, grip = 0 },
	},
}
-- kit bag pushed into the locker low ahead and let go
Defs.stow_kit = {
	duration = 1.3,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.35, r = V(0.3, -1.65, -1.3), l = V(-0.3, -1.65, -1.3), grip = 1 },
		{ t = 0.75, r = V(0.3, -1.7, -1.75), l = V(-0.3, -1.7, -1.75), grip = 1 },
		{ t = 0.85, r = V(0.3, -1.7, -1.75), l = V(-0.3, -1.7, -1.75), grip = 0 },
		{ t = 1.3, r = R0, l = L0, grip = 0 },
	},
}
-- calling the other vessel: right hand cupped at the mouth, held, then down
Defs.hail = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.5 },
		{ t = 0.3, r = V(0.16, -0.45, -0.6), l = L0, grip = 0.5 },
		{ t = 1.25, r = V(0.17, -0.44, -0.62), l = L0, grip = 0.5 },
		{ t = 1.6, r = R0, l = L0, grip = 0.5 },
	},
}
-- line parted: forearms snapped up over the head and face, held, lowered
Defs.duck = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.15, r = V(0.3, 0.05, -0.45), l = V(-0.3, 0.05, -0.45), grip = 1 },
		{ t = 1.0, r = V(0.32, 0.02, -0.48), l = V(-0.32, 0.02, -0.48), grip = 1 },
		{ t = 1.4, r = R0, l = L0, grip = 1 },
	},
}
-- torch held up at the casualty, swept slowly across them
Defs.torch = {
	duration = 4.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1, prop = "torch" },
		{ t = 0.4, r = V(0.45, -0.75, -1.4), l = L0, grip = 1 },
		{ t = 1.4, r = V(0.3, -0.78, -1.45), l = L0, grip = 1 },
		{ t = 2.4, r = V(0.6, -0.78, -1.4), l = L0, grip = 1 },
		{ t = 3.5, r = V(0.45, -0.75, -1.4), l = L0, grip = 1 },
		{ t = 4.0, r = R0, l = L0, grip = 1, prop = "" },
	},
}
-- a smoke / dan-buoy marker dropped out over the side
Defs.drop_marker = {
	duration = 1.1,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1, prop = "marker" },
		{ t = 0.3, r = V(0.7, -1.25, -0.8), l = L0, grip = 1 },
		{ t = 0.6, r = V(0.95, -1.0, -1.55), l = L0, grip = 0, prop = "" },
		{ t = 1.1, r = R0, l = L0, grip = 0 },
	},
}

---------------------------------------------------------------- lines

-- heaving line, overarm: coils in the left hand, the monkey's fist drawn back past the right
-- shoulder and hurled forward and up, the left hand opening to let the coils run
Defs.throw_heaving_line = {
	duration = 1.3,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.3, r = V(0.85, -0.25, -0.15), l = V(-0.4, -1.1, -1.0), grip = 1 },
		{ t = 0.5, r = V(0.9, -0.2, -0.05), l = V(-0.4, -1.1, -1.0), grip = 1 },
		{ t = 0.68, r = V(0.4, -0.3, -1.9), l = V(-0.35, -1.05, -1.3), grip = 0 },
		{ t = 0.9, r = V(0.35, -0.55, -1.95), l = V(-0.3, -1.0, -1.45), grip = 0 },
		{ t = 1.3, r = R0, l = L0, grip = 0.3 },
	},
}
-- coils made up in the left hand: the right draws out an arm's length and lays a loop, twice
Defs.coil_line = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.25, r = V(-0.2, -1.15, -0.95), l = V(-0.35, -1.2, -0.9), grip = 1 },
		{ t = 0.6, r = V(0.6, -1.4, -1.6), l = V(-0.35, -1.2, -0.9), grip = 1 },
		{ t = 0.9, r = V(-0.2, -1.15, -0.95), l = V(-0.35, -1.2, -0.9), grip = 1 },
		{ t = 1.2, r = V(0.6, -1.4, -1.6), l = V(-0.35, -1.2, -0.9), grip = 1 },
		{ t = 1.6, r = V(-0.2, -1.15, -0.95), l = V(-0.35, -1.2, -0.9), grip = 1 },
	},
}
-- line ready to throw: throwing coils low by the right hip, the standing part in the left
Defs.ready_heaving_line = {
	duration = 1.2,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.4, r = V(0.75, -1.2, -0.6), l = V(-0.35, -1.1, -1.0), grip = 1 },
		{ t = 0.8, r = V(0.8, -1.25, -0.45), l = V(-0.35, -1.1, -1.0), grip = 1 },
		{ t = 1.2, r = V(0.75, -1.2, -0.6), l = V(-0.35, -1.1, -1.0), grip = 1 },
	},
}
-- catching a thrown line: right hand up and out open, closes, pulls it in, the left takes it
Defs.take_line = {
	duration = 1.2,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.25, r = V(0.4, -0.6, -1.8), l = L0, grip = 0 },
		{ t = 0.35, r = V(0.4, -0.62, -1.78), l = L0, grip = 1 },
		{ t = 0.75, r = V(0.5, -1.2, -0.9), l = V(-0.2, -1.1, -1.4), grip = 1 },
		{ t = 1.2, r = V(0.5, -1.3, -0.8), l = V(-0.25, -1.2, -1.2), grip = 1 },
	},
}
-- one long pull on the line with both hands (hand over hand once)
Defs.haul_in = {
	duration = 1.2,
	keys = {
		{ t = 0, r = V(0.3, -1.1, -2.0), l = V(-0.3, -1.4, -0.9), grip = 1 },
		{ t = 0.6, r = V(0.3, -1.4, -0.9), l = V(-0.3, -1.1, -2.0), grip = 1 },
		{ t = 1.2, r = V(0.3, -1.1, -2.0), l = V(-0.3, -1.4, -0.9), grip = 1 },
	},
}
-- one arm's-length pull with the right hand, the left holding the slack by the body
Defs.haul_right = {
	duration = 0.7,
	keys = {
		{ t = 0, r = V(0.3, -1.1, -2.0), l = V(-0.3, -1.4, -0.85), grip = 1 },
		{ t = 0.45, r = V(0.4, -1.4, -0.8), l = V(-0.3, -1.4, -0.85), grip = 1 },
		{ t = 0.7, r = V(0.35, -1.25, -1.4), l = V(-0.3, -1.4, -0.85), grip = 1 },
	},
}
-- easing the line out through the right hand (half-closed so it runs), the left steadying
Defs.payout_right = {
	duration = 0.8,
	keys = {
		{ t = 0, r = V(0.35, -1.2, -1.0), l = V(-0.3, -1.3, -0.8), grip = 0.5 },
		{ t = 0.6, r = V(0.35, -1.15, -1.7), l = V(-0.3, -1.3, -0.8), grip = 0.5 },
		{ t = 0.8, r = V(0.35, -1.2, -1.3), l = V(-0.3, -1.3, -0.8), grip = 0.5 },
	},
}
-- tow bridle at the bow: both hands low ahead working a shackle, the right twisting the pin
Defs.rig_bridle = {
	duration = 2.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.6 },
		{ t = 0.4, r = V(0.18, -1.6, -1.5), l = V(-0.15, -1.62, -1.5), grip = 0.8 },
		{ t = 0.7, r = V(0.15, -1.52, -1.52), l = V(-0.15, -1.62, -1.5), grip = 1 },
		{ t = 1.0, r = V(0.18, -1.6, -1.5), l = V(-0.15, -1.62, -1.5), grip = 0.8 },
		{ t = 1.3, r = V(0.15, -1.52, -1.52), l = V(-0.15, -1.62, -1.5), grip = 1 },
		{ t = 2.0, r = R0, l = L0, grip = 0.6 },
	},
}

---------------------------------------------------------------- person in the water

-- throw bag held ready: bag low by the right hip, the line end gripped in the left hand
Defs.hold_throwbag = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1, prop = "throwbag" },
		{ t = 0.4, r = V(0.65, -1.3, -0.7), l = V(-0.3, -1.05, -1.0), grip = 1 },
		{ t = 1.6, r = V(0.66, -1.32, -0.68), l = V(-0.3, -1.05, -1.0), grip = 1 },
	},
}
-- winding up: the bag swung back and forward like a pendulum, twice, still held
Defs.windup_throw = {
	duration = 1.4,
	keys = {
		{ t = 0, r = V(0.65, -1.3, -0.7), l = V(-0.3, -1.05, -1.0), grip = 1, prop = "throwbag" },
		{ t = 0.35, r = V(0.75, -1.7, -0.2), l = V(-0.3, -1.05, -1.0), grip = 1 },
		{ t = 0.7, r = V(0.6, -1.0, -1.3), l = V(-0.3, -1.05, -1.05), grip = 1 },
		{ t = 1.05, r = V(0.75, -1.7, -0.2), l = V(-0.3, -1.05, -1.0), grip = 1 },
		{ t = 1.4, r = V(0.65, -1.3, -0.7), l = V(-0.3, -1.05, -1.0), grip = 1 },
	},
}
-- both hands down to the lifejacket shoulders at the sponson, gripped and held for the lift
Defs.grip_sponson = {
	duration = 2.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.35, r = V(0.35, -1.75, -1.8), l = V(-0.35, -1.75, -1.8), grip = 0 },
		{ t = 0.5, r = V(0.32, -1.8, -1.78), l = V(-0.32, -1.8, -1.78), grip = 1 },
		{ t = 2.4, r = V(0.32, -1.8, -1.76), l = V(-0.32, -1.8, -1.76), grip = 1 },
	},
}
-- the lift aboard: from the sponson grip, up and back over the tube, then let go
Defs.lift_aboard = {
	duration = 1.3,
	keys = {
		{ t = 0, r = V(0.32, -1.8, -1.76), l = V(-0.32, -1.8, -1.76), grip = 1 },
		{ t = 0.5, r = V(0.35, -1.05, -1.1), l = V(-0.35, -1.05, -1.1), grip = 1 },
		{ t = 0.8, r = V(0.4, -1.35, -0.9), l = V(-0.4, -1.35, -0.9), grip = 1 },
		{ t = 1.3, r = R0, l = L0, grip = 0.3 },
	},
}
-- hands wide under the back and the knees, palms up, a slow level lift (hypothermia: horizontal)
Defs.lift_horizontal = {
	duration = 1.8,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.3 },
		{ t = 0.45, r = V(0.6, -1.75, -1.5), l = V(-0.6, -1.75, -1.5), grip = 0.6 },
		{ t = 1.3, r = V(0.58, -1.2, -1.1), l = V(-0.58, -1.2, -1.1), grip = 0.6 },
		{ t = 1.8, r = R0, l = L0, grip = 0.3 },
	},
}
-- swimmer entry: hands over the face and mask for the jump, then arms spread to stabilise
Defs.swimmer_entry = {
	duration = 1.3,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.5 },
		{ t = 0.2, r = V(0.2, -0.5, -0.5), l = V(-0.2, -0.5, -0.5), grip = 0.5 },
		{ t = 0.6, r = V(0.2, -0.48, -0.5), l = V(-0.2, -0.48, -0.5), grip = 0.5 },
		{ t = 0.9, r = V(1.2, -1.05, -1.0), l = V(-1.2, -1.05, -1.0), grip = 0 },
		{ t = 1.3, r = R0, l = L0, grip = 0 },
	},
}
-- heads-up front crawl towards the casualty: alternate arms reach in and pull through
Defs.swim_out = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.4, -0.9, -1.9), l = V(-0.7, -1.5, -0.5), grip = 0 },
		{ t = 0.7, r = V(0.7, -1.5, -0.5), l = V(-0.4, -0.9, -1.9), grip = 0 },
		{ t = 1.1, r = V(0.4, -0.9, -1.9), l = V(-0.7, -1.5, -0.5), grip = 0 },
		{ t = 1.6, r = R0, l = L0, grip = 0 },
	},
}
-- talking them down: right palm out at arm's length, patting the air down, slow
Defs.talk_calm = {
	duration = 1.8,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.4, -0.85, -1.4), l = L0, grip = 0 },
		{ t = 0.65, r = V(0.42, -1.05, -1.42), l = L0, grip = 0 },
		{ t = 1.0, r = V(0.4, -0.85, -1.4), l = L0, grip = 0 },
		{ t = 1.35, r = V(0.42, -1.05, -1.42), l = L0, grip = 0 },
		{ t = 1.8, r = R0, l = L0, grip = 0 },
	},
}
-- the casualty lunges and grabs: hands jerk up defensively and are dragged down
Defs.grabbed = {
	duration = 0.9,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.5 },
		{ t = 0.12, r = V(0.4, -0.6, -0.7), l = V(-0.4, -0.6, -0.7), grip = 0.5 },
		{ t = 0.45, r = V(0.3, -1.2, -1.1), l = V(-0.35, -1.25, -1.0), grip = 1 },
		{ t = 0.9, r = V(0.3, -1.3, -1.15), l = V(-0.35, -1.35, -1.05), grip = 1 },
	},
}
-- ducking free: both palms drive up against their arms and sweep out and away
Defs.duck_free = {
	duration = 1.0,
	keys = {
		{ t = 0, r = V(0.3, -1.0, -0.9), l = V(-0.3, -1.0, -0.9), grip = 0 },
		{ t = 0.25, r = V(0.35, -0.3, -1.6), l = V(-0.35, -0.3, -1.6), grip = 0 },
		{ t = 0.55, r = V(1.0, -1.0, -1.3), l = V(-1.0, -1.0, -1.3), grip = 0 },
		{ t = 1.0, r = R0, l = L0, grip = 0 },
	},
}
-- rescue tube pushed out ahead to them at arm's length, held there
Defs.present_tube = {
	duration = 1.8,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1, prop = "tube" },
		{ t = 0.35, r = V(0.3, -0.9, -1.75), l = V(-0.1, -1.0, -1.35), grip = 1 },
		{ t = 1.8, r = V(0.3, -0.92, -1.78), l = V(-0.1, -1.0, -1.38), grip = 1 },
	},
}
-- clipping the tube round them: both hands bring the ends together in front and snap the clip
Defs.clip_tube = {
	duration = 1.2,
	keys = {
		{ t = 0, r = V(0.55, -1.1, -1.3), l = V(-0.55, -1.1, -1.3), grip = 1, prop = "tube" },
		{ t = 0.5, r = V(0.08, -1.15, -1.4), l = V(-0.08, -1.15, -1.4), grip = 1 },
		{ t = 0.6, r = V(0.05, -1.15, -1.45), l = V(-0.05, -1.15, -1.45), grip = 1 },
		{ t = 1.2, r = R0, l = L0, grip = 0.3, prop = "" },
	},
}

---------------------------------------------------------------- casualty care

-- primary survey: tap both shoulders, then hands sweep down the body checking for injury
Defs.survey_check = {
	duration = 2.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.38, -1.55, -1.5), l = V(-0.38, -1.55, -1.5), grip = 0 },
		{ t = 0.42, r = V(0.38, -1.65, -1.5), l = V(-0.38, -1.65, -1.5), grip = 0 },
		{ t = 0.54, r = V(0.38, -1.55, -1.5), l = V(-0.38, -1.55, -1.5), grip = 0 },
		{ t = 0.66, r = V(0.38, -1.65, -1.5), l = V(-0.38, -1.65, -1.5), grip = 0 },
		{ t = 1.5, r = V(0.3, -1.7, -0.95), l = V(-0.3, -1.7, -0.95), grip = 0.2 },
		{ t = 2.0, r = R0, l = L0, grip = 0 },
	},
}
-- one chest compression (the mechanic plays one per beat): from the top, 5 cm down, back up
Defs.cpr_compress = {
	duration = 0.5,
	keys = {
		{ t = 0, r = V(0.02, -1.55, -1.25), l = V(-0.02, -1.5, -1.25), grip = 0.4 },
		{ t = 0.2, r = V(0.02, -1.7, -1.25), l = V(-0.02, -1.65, -1.25), grip = 0.4 },
		{ t = 0.5, r = V(0.02, -1.55, -1.25), l = V(-0.02, -1.5, -1.25), grip = 0.4 },
	},
}
-- rescue breath: head tilt (left hand on the forehead), chin lift (right fingers), held
Defs.cpr_breath = {
	duration = 2.2,
	keys = {
		{ t = 0, r = V(0.02, -1.55, -1.25), l = V(-0.02, -1.5, -1.25), grip = 0.4 },
		{ t = 0.35, r = V(0.15, -1.62, -1.45), l = V(-0.15, -1.48, -1.3), grip = 0.5 },
		{ t = 1.9, r = V(0.15, -1.6, -1.45), l = V(-0.15, -1.48, -1.3), grip = 0.5 },
		{ t = 2.2, r = V(0.02, -1.55, -1.25), l = V(-0.02, -1.5, -1.25), grip = 0.4 },
	},
}
-- handing over: both hands out, palms up, offering (the casualty, the notes) to the paramedic
Defs.handover = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.3 },
		{ t = 0.35, r = V(0.3, -1.0, -1.5), l = V(-0.3, -1.0, -1.5), grip = 0.3 },
		{ t = 1.0, r = V(0.32, -0.98, -1.55), l = V(-0.32, -0.98, -1.55), grip = 0.3 },
		{ t = 1.4, r = R0, l = L0, grip = 0.3 },
	},
}
-- shelter: arms spread wide, holding a jacket up between them and the wind
Defs.treat_shelter = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.45, r = V(1.0, -0.6, -1.3), l = V(-1.0, -0.6, -1.3), grip = 1 },
		{ t = 1.2, r = V(1.0, -0.62, -1.32), l = V(-1.0, -0.62, -1.32), grip = 1 },
		{ t = 1.6, r = R0, l = L0, grip = 1 },
	},
}
-- keep them flat: palms on the shoulders, gently easing them back down
Defs.treat_horizontal = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.35, r = V(0.4, -1.5, -1.45), l = V(-0.4, -1.5, -1.45), grip = 0 },
		{ t = 0.9, r = V(0.4, -1.65, -1.45), l = V(-0.4, -1.65, -1.45), grip = 0 },
		{ t = 1.4, r = R0, l = L0, grip = 0 },
	},
}
-- casualty bag: the sides gathered from wide and low and drawn up and closed over them
Defs.treat_casualtyBag = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.35, r = V(0.7, -1.7, -1.7), l = V(-0.7, -1.7, -1.7), grip = 0 },
		{ t = 0.45, r = V(0.7, -1.7, -1.7), l = V(-0.7, -1.7, -1.7), grip = 1 },
		{ t = 1.1, r = V(0.12, -1.35, -1.35), l = V(-0.12, -1.35, -1.35), grip = 1 },
		{ t = 1.6, r = R0, l = L0, grip = 0.3 },
	},
}
-- hat: both hands carry it forward and draw it down over their head
Defs.treat_hat = {
	duration = 1.2,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.7 },
		{ t = 0.35, r = V(0.25, -1.3, -1.6), l = V(-0.25, -1.3, -1.6), grip = 0.7 },
		{ t = 0.75, r = V(0.22, -1.5, -1.8), l = V(-0.22, -1.5, -1.8), grip = 0.7 },
		{ t = 1.2, r = R0, l = L0, grip = 0.3 },
	},
}
-- oxygen: mask lowered on to the face with both hands, the elastic drawn over, held
Defs.treat_oxygen = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.6 },
		{ t = 0.4, r = V(0.12, -1.4, -1.6), l = V(-0.12, -1.4, -1.6), grip = 0.6 },
		{ t = 0.8, r = V(0.12, -1.55, -1.65), l = V(-0.35, -1.5, -1.85), grip = 0.6 },
		{ t = 1.2, r = V(0.12, -1.55, -1.65), l = V(-0.3, -1.52, -1.8), grip = 0.6 },
		{ t = 1.6, r = R0, l = L0, grip = 0.4 },
	},
}
-- recovery position: one hand at the far shoulder, one at the far hip, rolled towards you
Defs.treat_recovery = {
	duration = 1.8,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.5 },
		{ t = 0.4, r = V(0.5, -1.7, -1.65), l = V(-0.4, -1.7, -1.45), grip = 1 },
		{ t = 1.2, r = V(0.45, -1.5, -1.15), l = V(-0.4, -1.55, -1.0), grip = 1 },
		{ t = 1.8, r = R0, l = L0, grip = 0.5 },
	},
}
-- warm drink: cup to their lips in the right hand, the left supporting their head
Defs.treat_drink = {
	duration = 1.8,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.8 },
		{ t = 0.4, r = V(0.15, -1.3, -1.55), l = V(-0.2, -1.45, -1.7), grip = 0.8 },
		{ t = 1.4, r = V(0.14, -1.25, -1.6), l = V(-0.2, -1.45, -1.7), grip = 0.8 },
		{ t = 1.8, r = R0, l = L0, grip = 0.8 },
	},
}
-- dressing: the left hand holds the pad on, the right winds the bandage round twice
Defs.treat_dressing = {
	duration = 1.8,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.6 },
		{ t = 0.3, r = V(0.25, -1.45, -1.45), l = V(-0.05, -1.55, -1.5), grip = 0.6 },
		{ t = 0.6, r = V(0.05, -1.7, -1.7), l = V(-0.05, -1.55, -1.5), grip = 0.6 },
		{ t = 0.9, r = V(-0.2, -1.45, -1.45), l = V(-0.05, -1.55, -1.5), grip = 0.6 },
		{ t = 1.2, r = V(0.25, -1.45, -1.45), l = V(-0.05, -1.55, -1.5), grip = 0.6 },
		{ t = 1.5, r = V(0.05, -1.7, -1.7), l = V(-0.05, -1.55, -1.5), grip = 0.6 },
		{ t = 1.8, r = R0, l = L0, grip = 0.6 },
	},
}
-- start CPR: hands to the centre of the chest, heel of one stacked on the other, arms locked
Defs.treat_cpr = {
	duration = 1.0,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.5, r = V(0.2, -1.5, -1.3), l = V(-0.2, -1.5, -1.3), grip = 0.2 },
		{ t = 1.0, r = V(0.02, -1.55, -1.25), l = V(-0.02, -1.5, -1.25), grip = 0.4 },
	},
}
-- rubbing the limbs: hands scrub back and forth, out of step
Defs.treat_rub = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.2 },
		{ t = 0.3, r = V(0.35, -1.6, -1.7), l = V(-0.35, -1.6, -1.3), grip = 0.2 },
		{ t = 0.6, r = V(0.35, -1.6, -1.25), l = V(-0.35, -1.6, -1.75), grip = 0.2 },
		{ t = 0.9, r = V(0.35, -1.6, -1.7), l = V(-0.35, -1.6, -1.3), grip = 0.2 },
		{ t = 1.2, r = V(0.35, -1.6, -1.25), l = V(-0.35, -1.6, -1.75), grip = 0.2 },
		{ t = 1.6, r = R0, l = L0, grip = 0.2 },
	},
}
-- hot packs: one under each armpit, placed and pressed in turn
Defs.treat_hotpack = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.6 },
		{ t = 0.35, r = V(0.32, -1.6, -1.55), l = V(-0.35, -1.45, -1.2), grip = 0.6 },
		{ t = 0.55, r = V(0.32, -1.68, -1.55), l = V(-0.35, -1.45, -1.2), grip = 0 },
		{ t = 0.85, r = V(0.3, -1.45, -1.2), l = V(-0.35, -1.68, -1.5), grip = 0 },
		{ t = 1.4, r = R0, l = L0, grip = 0 },
	},
}
-- sitting them up: hands under the shoulders, lifted to sitting
Defs.treat_sitUp = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0.5 },
		{ t = 0.35, r = V(0.38, -1.75, -1.7), l = V(-0.38, -1.75, -1.7), grip = 0.7 },
		{ t = 1.0, r = V(0.35, -1.1, -1.3), l = V(-0.35, -1.1, -1.3), grip = 0.7 },
		{ t = 1.4, r = R0, l = L0, grip = 0.5 },
	},
}
-- abdominal thrusts from behind: fist wrapped in the other hand, three sharp thrusts in and up
Defs.treat_thrusts = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1 },
		{ t = 0.3, r = V(0.06, -1.05, -1.0), l = V(-0.06, -1.05, -1.0), grip = 1 },
		{ t = 0.45, r = V(0.06, -0.88, -0.8), l = V(-0.06, -0.88, -0.8), grip = 1 },
		{ t = 0.65, r = V(0.06, -1.05, -1.0), l = V(-0.06, -1.05, -1.0), grip = 1 },
		{ t = 0.8, r = V(0.06, -0.88, -0.8), l = V(-0.06, -0.88, -0.8), grip = 1 },
		{ t = 1.0, r = V(0.06, -1.05, -1.0), l = V(-0.06, -1.05, -1.0), grip = 1 },
		{ t = 1.15, r = V(0.06, -0.88, -0.8), l = V(-0.06, -0.88, -0.8), grip = 1 },
		{ t = 1.6, r = R0, l = L0, grip = 1 },
	},
}

-- the same action done with the other hand: wrists swap sides and mirror across X = 0
local function mirrored(action: Action): Action
	local keys = {}
	for _, key in action.keys do
		table.insert(keys, {
			t = key.t,
			r = V(-key.l.X, key.l.Y, key.l.Z),
			l = V(-key.r.X, key.r.Y, key.r.Z),
			grip = key.grip,
			prop = key.prop,
		})
	end
	return { duration = action.duration, loop = action.loop, keys = keys }
end

Defs.haul_left = mirrored(Defs.haul_right)
Defs.payout_left = mirrored(Defs.payout_right)

---------------------------------------------------------------- everyday and docs/14 §4 clips

-- a friendly wave: right hand up by the face, open palm, a quick side to side, then down
Defs.wave = {
	duration = 1.6,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 0 },
		{ t = 0.3, r = V(0.55, 0.05, -1.1), l = L0, grip = 0 },
		{ t = 0.5, r = V(0.35, 0.12, -1.15), l = L0, grip = 0 },
		{ t = 0.7, r = V(0.7, 0.08, -1.1), l = L0, grip = 0 },
		{ t = 0.9, r = V(0.35, 0.12, -1.15), l = L0, grip = 0 },
		{ t = 1.1, r = V(0.7, 0.08, -1.1), l = L0, grip = 0 },
		{ t = 1.6, r = R0, l = L0, grip = 0 },
	},
}
-- the phone held low in the left hand, the right forefinger tapping it; loops while it is open
Defs.phone = {
	duration = 1.2,
	loop = true,
	keys = {
		{ t = 0, r = V(0.15, -1.0, -1.15), l = V(-0.2, -1.15, -1.05), grip = 0.7, prop = "phone" },
		{ t = 0.3, r = V(0.05, -1.08, -1.08), l = V(-0.2, -1.15, -1.05), grip = 0.7 },
		{ t = 0.45, r = V(0.15, -1.0, -1.15), l = V(-0.2, -1.15, -1.05), grip = 0.7 },
		{ t = 0.8, r = V(0.0, -1.1, -1.1), l = V(-0.2, -1.15, -1.05), grip = 0.7 },
		{ t = 1.2, r = V(0.15, -1.0, -1.15), l = V(-0.2, -1.15, -1.05), grip = 0.7 },
	},
}
-- lifebuoy, two hands: swung back to the right hip, flung forward and up, released at 0.6 s
Defs.throw_lifebuoy = {
	duration = 1.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1, prop = "lifebuoy" },
		{ t = 0.25, r = V(0.65, -1.2, -0.9), l = V(-0.1, -1.1, -1.1), grip = 1 },
		{ t = 0.45, r = V(0.9, -1.4, -0.4), l = V(0.2, -1.3, -0.7), grip = 1 },
		{ t = 0.6, r = V(0.4, -0.5, -1.9), l = V(-0.3, -0.6, -1.8), grip = 0, prop = "" },
		{ t = 0.9, r = V(0.35, -0.3, -2.0), l = V(-0.35, -0.4, -1.9), grip = 0 },
		{ t = 1.4, r = R0, l = L0, grip = 0.3 },
	},
}
-- dragging a casualty backwards by the lifejacket: both hands low ahead, heave and reset; loops
Defs.drag = {
	duration = 1.4,
	loop = true,
	keys = {
		{ t = 0, r = V(0.3, -1.9, -1.5), l = V(-0.3, -1.9, -1.5), grip = 1 },
		{ t = 0.7, r = V(0.32, -1.6, -0.95), l = V(-0.32, -1.6, -0.95), grip = 1 },
		{ t = 1.4, r = V(0.3, -1.9, -1.5), l = V(-0.3, -1.9, -1.5), grip = 1 },
	},
}
-- foil blanket: held open by two corners, laid over the casualty and tucked round them
Defs.wrap_blanket = {
	duration = 2.4,
	keys = {
		{ t = 0, r = R0, l = L0, grip = 1, prop = "blanket" },
		{ t = 0.4, r = V(0.7, -0.9, -1.3), l = V(-0.7, -0.9, -1.3), grip = 1 },
		{ t = 0.9, r = V(0.75, -1.6, -1.7), l = V(-0.75, -1.6, -1.7), grip = 1 },
		{ t = 1.4, r = V(0.3, -1.85, -1.6), l = V(-0.3, -1.85, -1.6), grip = 1 },
		{ t = 1.8, r = V(0.25, -1.9, -1.45), l = V(-0.25, -1.9, -1.45), grip = 0, prop = "" },
		{ t = 2.4, r = R0, l = L0, grip = 0.3 },
	},
}
-- names the mechanics use for an existing clip
Defs.hold_bars = Defs.steer -- the jet ski handlebars (also the VehicleFP base pose)
Defs.throw_underarm = Defs.throw -- the throw bag throw is underarm
Defs.throw_line = Defs.throw_heaving_line -- a mooring line goes overarm in coils, the same way
Defs.radio_handset = Defs.radio -- the boat's handset to the mouth, as the handheld

Actions.Names = {
	-- the original clips
	"throw",
	"haul",
	"grab",
	"radio",
	"cpr",
	"knock",
	"point",
	"steer",
	-- boat handling and approach
	"wave_off",
	"reach_casualty",
	"brace",
	"fend_off",
	"fenders",
	"cast_off",
	"stow_kit",
	"hail",
	"duck",
	"torch",
	"drop_marker",
	-- lines
	"throw_heaving_line",
	"throw_line",
	"coil_line",
	"ready_heaving_line",
	"take_line",
	"haul_in",
	"haul_left",
	"haul_right",
	"payout_left",
	"payout_right",
	"rig_bridle",
	"radio_handset",
	-- person in the water
	"throw_underarm",
	"hold_throwbag",
	"windup_throw",
	"grip_sponson",
	"lift_aboard",
	"lift_horizontal",
	"swimmer_entry",
	"swim_out",
	"talk_calm",
	"grabbed",
	"duck_free",
	"present_tube",
	"clip_tube",
	-- casualty care
	"survey_check",
	"cpr_compress",
	"cpr_breath",
	"handover",
	"treat_shelter",
	"treat_horizontal",
	"treat_casualtyBag",
	"treat_hat",
	"treat_oxygen",
	"treat_recovery",
	"treat_drink",
	"treat_dressing",
	"treat_cpr",
	"treat_rub",
	"treat_hotpack",
	"treat_sitUp",
	"treat_thrusts",
	-- everyday and docs/14 §4 clips
	"wave",
	"phone",
	"hold_bars",
	"throw_lifebuoy",
	"drag",
	"wrap_blanket",
}

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

-- Lifts a wrist target that would sit below the frame back into the lower band of the view, so a
-- low action (CPR, the bars, a drag, the phone) still shows the hands. tanHalf is tan(FOV / 2).
function Actions.inView(p: Vector3, tanHalf: number): Vector3
	if p.Z > -0.8 then
		return p -- a near-face gesture; its height was deliberate
	end
	local floorY = -0.65 * -p.Z * tanHalf
	if p.Y < floorY then
		return Vector3.new(p.X, floorY, p.Z)
	end
	return p
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
