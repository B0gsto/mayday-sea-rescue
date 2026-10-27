--!strict
-- WorkLoop (docs/25 G): the beats of each Job's work loop at its building, drawn by WorkerController. A beat moves the
-- worker to an offset from its Spot (studs in the Spot's frame: `side` to the right, `back` away from the work),
-- faces the work (a point PIVOT studs ahead of the Spot, so side steps walk round a hull or a bed), plays `anim`
-- (default Idle) holding `prop` ("" empty hands, nil the Job's prop) for about `hold` seconds. jitter() stretches every
-- hold per worker so a crew never moves in step. Pure.

local WorkLoop = {}

export type Beat = {
	side: number?,
	back: number?,
	anim: string?, -- "Swing" | "Point" | "Idle"
	speed: number?, -- the anim's speed (Swing defaults to 0.45)
	prop: string?,
	hold: number,
}

WorkLoop.PIVOT = 4

WorkLoop.BEATS = {
	Build = { -- the workshop bench (and a site with no Depot yet): hammer, the next plank, step back and check
		{ anim = "Swing", hold = 4 },
		{ side = 1.5, anim = "Swing", hold = 3 },
		{ back = 1.2, anim = "Point", prop = "", hold = 1.6 },
	},
	Fish = { -- serve at the counter tile, haul the net in behind the stall, carry the crate back to the counter
		{ anim = "Point", prop = "", hold = 3.5 },
		{ back = 2.5, anim = "Swing", speed = 0.35, prop = "Net", hold = 2.5 },
		{ prop = "Crate", hold = 1.2 },
	},
	Repair = { -- wrench on the hull, walk along it and wrench again, step back and look it over
		{ anim = "Swing", hold = 4 },
		{ side = 2.5, anim = "Swing", hold = 3 },
		{ side = -1.5, back = 1.5, anim = "Point", prop = "", hold = 2 },
	},
	Heal = { -- the clipboard at a bed, the next bed, the other side
		{ anim = "Point", hold = 3.5 },
		{ side = 2.5, hold = 2.5 },
		{ side = -2.5, anim = "Point", hold = 3 },
	},
	Rescue = { -- binoculars, a knock round the boat, step back and look out again
		{ anim = "Point", hold = 4 },
		{ side = 2, anim = "Swing", speed = 0.3, prop = "", hold = 2.5 },
		{ back = 2, hold = 1.8 },
	},
	Gather = {
		{ anim = "Swing", hold = 4 },
		{ side = 1.2, anim = "Swing", hold = 3 },
		{ back = 1, prop = "", hold = 1.5 },
	},
} :: { [string]: { Beat } }

-- A worker's stretch for beat k: 0.75..1.25, fixed per (seed, k), different between neighbouring seeds.
function WorkLoop.jitter(seed: number, k: number): number
	local h = ((seed % 65521) * 31 + k) * 2654435761 % 4294967296 -- small enough to stay exact in a double
	return 0.75 + ((h // 65536) % 1000) / 1998
end

-- The Bunkhouse rooms light up and show "Zzz" between these (Lighting.ClockTime; the boats' nav lights use the same).
WorkLoop.DUSK = 18.5
WorkLoop.DAWN = 6.25
WorkLoop.HOME = 17.5 -- survivors down tools and walk home (DayClock: early in the 90 s dusk)
WorkLoop.LAG = 0.3 -- hours: each worker sets off up to this late, so a crew trickles home / out

function WorkLoop.isNight(clockTime: number): boolean
	return clockTime >= WorkLoop.DUSK or clockTime < WorkLoop.DAWN
end

-- True while the worker with `seed` should be home (walking there or asleep): HOME .. DAWN, each a little late.
function WorkLoop.isHome(clockTime: number, seed: number): boolean
	local c = (clockTime - WorkLoop.LAG * (WorkLoop.jitter(seed, 7) - 0.75) * 2) % 24
	return c >= WorkLoop.HOME or c < WorkLoop.DAWN
end

return WorkLoop
