--!strict
-- Swaps: greybox -> production Package swaps placed at run time by WorldDressingService (I1, docs/12 section 3.2).
-- One entry per building. map/Build.luau still builds the greybox (tagged GREYBOX, attribute AssetSwap = <key>);
-- when every asset of an entry loads, the greybox is destroyed and the Packages take its place, else it stays.
--
--   greybox   path under Workspace.Map of the greybox model it replaces
--   pivot     the shared authored pivot of all the entry's assets (they are built in one frame)
--   shell     assets of the exterior model  (Workspace.Dressing.<key>, ModelStreamingMode Atomic)
--   interior  assets of the interior model  (Workspace.Dressing.<key>Interior, Atomic, streams on its own)
--   door      optional auto door: parts swung about a hinge attachment when a character comes near
--             (roll = true: a roller door, the parts roll up into their head instead of swinging)
--   hide      true: the greybox is kept as an invisible collider instead of destroyed (other services read it)
--   rig       optional module in this folder: rig.apply(shell1, interior1, interior2, interior3) (lights, glass)

export type Swap = {
	greybox: { string },
	pivot: CFrame,
	shell: { string },
	interior: { string }?,
	door: {
		asset: string,
		parts: { string },
		hinge: string,
		trigger: string,
		angle: number,
		roll: boolean?,
	}?,
	hide: boolean?,
	ground: number?, -- the pivot Y follows the highest terrain within this many studs (WorldDressingService)
	pad: { number }?, -- {x0, y0, x1, y1} asset-frame metres (Blender X, Y): terrain filled up to the pivot under it
	rig: string?,
	lod: string?,
	collide: boolean?, -- false: the uploads' _COL hulls stay off (single-mesh hulls fill door gaps)
	colliders: { { number } }?, -- invisible boxes {x0, y0, z0, x1, y1, z1} in the asset frame, metres
	ramps: { { number } }?, -- {x0, x1, yLow, zLow, yHigh, zHigh}: a stair ramp across x, metres
}

-- The H1 station swap (M_Bld_Station on the old hub HQ lot, its colliders and StationRig) is in git history before
-- WP-21a (docs/23 (l)), for a player island; the hub itself went in docs/23 (p).
local Swaps: { [string]: Swap } = {}

return Swaps
