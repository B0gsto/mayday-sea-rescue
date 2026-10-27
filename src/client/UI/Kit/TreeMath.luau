--!strict
-- TreeMath: pure layout and navigation math for Kit/TreeView (tests/TreeMath.spec.luau).
-- No Instances: lanes stack vertically, nodes run left to right inside a lane, connectors are
-- drawn between node centres and rotate about their own midpoint, and the gamepad picks the
-- nearest node in a direction. All values are design units (du).
local TreeMath = {}

TreeMath.NODE = Vector2.new(200, 96) -- wide enough for the longest name at the label size
TreeMath.COL_GAP = 72
TreeMath.ROW_GAP = 20
TreeMath.LANE_GAP = 18
TreeMath.HEADER = 46
TreeMath.PAD = 22
TreeMath.MIN_ZOOM = 0.4
TreeMath.MAX_ZOOM = 1.5

-- The radial skill tree (docs/25 F): 0 = up, clockwise, ring 2.75 for the bridges.
TreeMath.RING_RADII = { 0, 150, 245, 340, 435, 520 }
TreeMath.SECTOR_SPREAD = 36
TreeMath.RADIAL_PAD = 28

export type Node = { id: string, col: number, row: number, group: string? }
export type Box = { id: string, pos: Vector2, size: Vector2 }
export type Lane = {
	id: string,
	y: number,
	height: number,
	nodes: { Box },
}
export type Layout = { lanes: { Lane }, size: Vector2 }

export type Opts = {
	node: Vector2?,
	colGap: number?,
	rowGap: number?,
	laneGap: number?,
	header: number?,
	pad: number?,
}

-- Lanes in first-appearance order; nodes at col/row inside the lane (negative rows are centred
-- against the lane's own minimum). Returns the node boxes and the content size.
function TreeMath.layout(nodes: { Node }, opts: Opts?): Layout
	local o: Opts = opts or {}
	local node = o.node or TreeMath.NODE
	local colGap = o.colGap or TreeMath.COL_GAP
	local rowGap = o.rowGap or TreeMath.ROW_GAP
	local laneGap = o.laneGap or TreeMath.LANE_GAP
	local header = o.header or TreeMath.HEADER
	local pad = o.pad or TreeMath.PAD

	local order: { string } = {}
	local minRow: { [string]: number } = {}
	local maxRow: { [string]: number } = {}
	local maxCol = -1
	for _, n in nodes do
		local group = n.group or ""
		if minRow[group] == nil then
			table.insert(order, group)
			minRow[group] = n.row
			maxRow[group] = n.row
		else
			minRow[group] = math.min(minRow[group], n.row)
			maxRow[group] = math.max(maxRow[group], n.row)
		end
		maxCol = math.max(maxCol, n.col)
	end

	local byGroup: { [string]: { Node } } = {}
	for _, n in nodes do
		local group = n.group or ""
		local list = byGroup[group]
		if not list then
			list = {}
			byGroup[group] = list
		end
		table.insert(list, n)
	end

	local lanes: { Lane } = {}
	local y = pad
	for _, group in order do
		local rows = (maxRow[group] :: number) - (minRow[group] :: number) + 1
		local nodesTop = y + header + 10
		local height = header + 10 + rows * node.Y + (rows - 1) * rowGap
		local boxes: { Box } = {}
		for _, n in byGroup[group] do
			table.insert(boxes, {
				id = n.id,
				pos = Vector2.new(
					pad + n.col * (node.X + colGap),
					nodesTop + (n.row - minRow[group]) * (node.Y + rowGap)
				),
				size = node,
			})
		end
		table.insert(lanes, { id = group, y = y, height = height, nodes = boxes })
		y += height + laneGap
	end
	local bottom = if #lanes > 0 then y - laneGap + pad else 2 * pad
	local width = pad * 2 + (maxCol + 1) * node.X + math.max(maxCol, 0) * colGap
	return { lanes = lanes, size = Vector2.new(width, bottom) }
end

-- A connector Frame: centred on the two nodes' midpoint, `length` long, rotated to the line's
-- angle. Position + AnchorPoint 0.5 means Rotation turns it about its own centre, never an end.
export type Connector = { pos: Vector2, size: Vector2, rotation: number }

function TreeMath.connector(from: Vector2, to: Vector2, thickness: number?): Connector
	local d = to - from
	return {
		pos = from + d * 0.5,
		size = Vector2.new(d.Magnitude, thickness or 10),
		rotation = math.deg(math.atan2(d.Y, d.X)),
	}
end

-- The nearest point from `from` in direction `dir` (screen space, y down), or nil. Points behind
-- or too far off the axis are ignored; along + lateral * 2 prefers the straight-ahead node.
export type Point = { id: string, pos: Vector2 }

function TreeMath.nearest(points: { Point }, from: Vector2, dir: Vector2): string?
	local len = dir.Magnitude
	if len < 1e-3 then
		return nil
	end
	local u = dir / len
	local best: string? = nil
	local bestScore = math.huge
	for _, p in points do
		local d = p.pos - from
		local along = d.X * u.X + d.Y * u.Y
		local lateral = math.abs(d.X * -u.Y + d.Y * u.X)
		if along > 1e-3 and lateral <= along * 1.4 + 24 then
			local score = along + lateral * 2
			if score < bestScore then
				bestScore = score
				best = p.id
			end
		end
	end
	return best
end

-- The free part of the tree viewport: the detail card docks over the rest (root space, du).
export type View = { pos: Vector2, size: Vector2 }

-- Keep the content inside `view`: centred when it is smaller, else pan clamped so no edge shows
-- empty space in the free rect (the card never covers a node).
function TreeMath.clampPanIn(pan: Vector2, view: View, content: Vector2, zoom: number): Vector2
	local shown = content * zoom
	local x = if shown.X <= view.size.X
		then view.pos.X + (view.size.X - shown.X) * 0.5
		else math.clamp(pan.X, view.pos.X + view.size.X - shown.X, view.pos.X)
	local y = if shown.Y <= view.size.Y
		then view.pos.Y + (view.size.Y - shown.Y) * 0.5
		else math.clamp(pan.Y, view.pos.Y + view.size.Y - shown.Y, view.pos.Y)
	return Vector2.new(x, y)
end

-- Keep the content on screen: centred when it is smaller than the viewport, else pan clamped so
-- no edge shows empty space.
function TreeMath.clampPan(pan: Vector2, viewport: Vector2, content: Vector2, zoom: number): Vector2
	return TreeMath.clampPanIn(pan, { pos = Vector2.zero, size = viewport }, content, zoom)
end

-- Zoom about a point: the point stays where it is while the scale changes from `before` to `after`.
function TreeMath.zoomAbout(pan: Vector2, at: Vector2, before: number, after: number): Vector2
	local k = after / math.max(before, 1e-6)
	return at - (at - pan) * k
end

-- The zoom + pan that frame `pts` (content space) in `view` with `pad` du round their bounding box,
-- zoom clamped to [lo, hi] (the radial tree opens on what you can unlock, owner 2026-10-28).
function TreeMath.fitBox(
	pts: { Vector2 },
	view: View,
	pad: number,
	lo: number,
	hi: number
): (number, Vector2)
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in pts do
		x0, y0 = math.min(x0, p.X), math.min(y0, p.Y)
		x1, y1 = math.max(x1, p.X), math.max(y1, p.Y)
	end
	local w, h = x1 - x0 + pad * 2, y1 - y0 + pad * 2
	local zoom = math.clamp(math.min(view.size.X / w, view.size.Y / h), lo, hi)
	local mid = Vector2.new(x0 + x1, y0 + y1) * 0.5
	return zoom, view.pos + view.size * 0.5 - mid * zoom
end

-- The radial skill tree: ring 0 is the centre ("You"), rings 1..5 radiate outward; an angle in
-- degrees, 0 = up and clockwise. Fractional rings interpolate the radius (bridges sit at 2.75).
export type RadialNode = { id: string, ring: number, angle: number }
export type RadialOpts = { rings: { number }?, pad: number? }

function TreeMath.ringRadius(ring: number, rings: { number }?): number
	local list = rings or TreeMath.RING_RADII
	local r = math.max(0, ring)
	local lo = math.clamp(math.floor(r), 0, #list - 1)
	local hi = math.clamp(math.ceil(r), 0, #list - 1)
	local a = list[lo + 1] or 0
	local b = list[hi + 1] or a
	return a + (b - a) * (r - lo)
end

function TreeMath.polar(ring: number, angle: number, opts: RadialOpts?): Vector2
	local radius = TreeMath.ringRadius(ring, opts and opts.rings)
	local t = math.rad(angle)
	return Vector2.new(radius * math.sin(t), -radius * math.cos(t))
end

function TreeMath.radialSize(opts: RadialOpts?): Vector2
	local list = (opts and opts.rings) or TreeMath.RING_RADII
	local pad = (opts and opts.pad) or TreeMath.RADIAL_PAD
	local side = ((list[#list] or 0) + pad) * 2
	return Vector2.new(side, side)
end

-- Node centres in content space, centred in the square radial canvas.
function TreeMath.radialLayout(nodes: { RadialNode }, opts: RadialOpts?): { [string]: Vector2 }
	local centre = TreeMath.radialSize(opts) * 0.5
	local out: { [string]: Vector2 } = {}
	for _, n in nodes do
		out[n.id] = centre + TreeMath.polar(n.ring, n.angle, opts)
	end
	return out
end

return TreeMath
