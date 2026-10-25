--!strict
-- DockBuild (docs/23 (j) rule 4, WP-14d): the pure math behind the build tablet's top-down camera and the
-- spot each card outlines. Client-side only, no services (tests/DockBuild.spec.luau). `camera` frames the
-- whole island from the bridge side, tilted down, so the lots read like a build plate; `spot` maps an item
-- to its lot CFrame (berth frame) and footprint. The outline itself is drawn by DockController.
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(script.Parent:WaitForChild("Marina"))

local DockBuild = {}

DockBuild.ISLAND_RADIUS = 172 -- the plateau (160) plus a little beach, from HubLayout.IslandRadius
DockBuild.PITCH = math.rad(58) -- down from horizontal: high enough to read the lots, low enough to see fronts
DockBuild.FOV = 45 -- camera FieldOfView
DockBuild.MARGIN = 1.12 -- breathing room round the island
DockBuild.MAX_DISTANCE = 1600

-- Camera distance that fits `radius` in both axes for the given viewport aspect and FOV.
function DockBuild.distance(radius: number, aspect: number, fov: number?): number
	local vf = math.tan(math.rad(fov or DockBuild.FOV) / 2)
	local hf = vf * math.max(aspect, 0.3)
	return math.min(radius * DockBuild.MARGIN / math.min(vf, hf), DockBuild.MAX_DISTANCE)
end

-- The build-mode camera CFrame in the berth frame. `aim` (world) pulls the look target toward a selected
-- item's spot; without it the island centre is framed. The camera sits inland of the island (the bridge
-- side), looking out over the lots to the sea.
function DockBuild.camera(frame: CFrame, radius: number, aspect: number, aim: Vector3?): CFrame
	local d = DockBuild.distance(radius, aspect)
	local centre = (frame * Marina.ISLAND).Position
	local look = if aim then centre:Lerp(aim, 0.35) else centre
	local pos = centre
		+ Vector3.new(0, d * math.sin(DockBuild.PITCH), 0)
		- frame.LookVector * (d * math.cos(DockBuild.PITCH))
	return CFrame.lookAt(pos, look)
end

-- Where an item would stand, in the berth frame, and the footprint to outline -> CFrame, Vector2.
function DockBuild.spot(item: any): (CFrame, Vector2)
	if item.kind == "Building" then
		local b = DockConfig.Buildings[item.key]
		return b.spot, b.size
	elseif item.kind == "Blueprint" then
		local bp = DockConfig.Blueprints[item.key]
		return Marina.LOTS[bp.lot].cf, Marina.LOTS[bp.lot].size
	elseif item.kind == "Decor" then
		local d = DockConfig.Decorations[item.key]
		return DockConfig.decorSpot(item.key, CFrame.identity) or CFrame.identity, d.size
	end
	return CFrame.identity, Vector2.new(8, 8)
end

DockBuild.PAPER_LIFT = 0.3 -- the paper blueprint's centre above its lot (clear of the plate, no z-fight)

-- WP-14e: the paper blueprint of an item, in world space, turned to the berth frame so its drawing reads
-- upright from the build camera (lots turned 90 degrees swap their footprint) -> CFrame, size (x, z).
function DockBuild.paper(item: any, frame: CFrame): (CFrame, Vector2)
	local spot, size = DockBuild.spot(item)
	if math.abs(spot.LookVector.X) > 0.7 then
		size = Vector2.new(size.Y, size.X)
	end
	return frame * CFrame.new(spot.Position + Vector3.new(0, DockBuild.PAPER_LIFT, 0)), size
end

DockBuild.FOCUS_ROOM = 1.7 -- footprint radius x this = what the focus view fits
DockBuild.FOCUS_MIN = 45 -- never closer than this (small decor)
DockBuild.FOCUS_SHIFT = Vector2.new(0.3, 0.2) -- spot off-centre (viewport halves): left of the list, above the strip

-- The focused view of a lot: same pitch and heading as the island view, close enough to fit the footprint,
-- panned so the spot sits left of the right-hand list and above the bottom strip.
function DockBuild.focus(frame: CFrame, at: Vector3, size: Vector2, aspect: number): CFrame
	local r = math.max(size.X, size.Y) / 2
	local d = math.max(DockBuild.distance(r * DockBuild.FOCUS_ROOM, aspect), DockBuild.FOCUS_MIN)
	local pos = at
		+ Vector3.new(0, d * math.sin(DockBuild.PITCH), 0)
		- frame.LookVector * (d * math.cos(DockBuild.PITCH))
	local cam = CFrame.lookAt(pos, at)
	local vf = math.tan(math.rad(DockBuild.FOV) / 2)
	local pan = cam.RightVector * (DockBuild.FOCUS_SHIFT.X * d * vf * math.max(aspect, 0.3))
		- cam.UpVector * (DockBuild.FOCUS_SHIFT.Y * d * vf)
	return cam + pan
end

return DockBuild
