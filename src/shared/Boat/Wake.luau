--!strict
-- Wake: the push a boat's own wake gives a floating casualty (or any scripted floater) at a point.
-- OperationService / RescueService add the returned velocity to a casualty's scripted drift, and
-- can grade "too fast, washed over the casualty" from the wake height (docs 09, approach step).
--
--   Wake.at(point, boat): (push: Vector3, height: number)    pure, one hull (tests run it in Lune)
--   Wake.fromModel(model, point): (Vector3, number)           one spawned vehicle model
--   Wake.pushAt(point, ignore?): (Vector3, number)            summed over Workspace.Vehicles
--
-- push is a horizontal velocity in studs/s (add it to the casualty's drift, it is not a force);
-- height is the wake wave height (studs, crest to trough) at the point.
--
-- Model (real ship-wave physics, simplified):
--   * Kelvin wake: behind the hull, inside a wedge whose half-angle is 19.47 deg for displacement
--     speeds and narrows as 1 / (sqrt(2 pi) Fr) at high Froude number (Rabaud and Moisy 2013).
--     Wave height peaks near hull speed (Fr_L about 0.5, the "hump") and drops to about a quarter
--     of that on the plane; it decays with distance astern as (L / (L + s))^(1/3) and is highest
--     on the wedge arms. The push points outward and forward, the way diverging waves travel.
--   * Bow and side wash: alongside the hull, a push straight out from it that grows with speed.
--   * Prop / jet wash: a narrow stream straight astern while the hull is moving ahead.

local Wake = {}

export type Hull = {
	position: Vector3,
	velocity: Vector3,
	forward: Vector3, -- unit, horizontal (hull -Z)
	length: number, -- studs
	beam: number, -- studs
}

local G = 29.43 -- studs/s^2 (docs 02 section 4.2)
local KELVIN = math.asin(1 / 3) -- 19.47 deg
Wake.HEIGHT_PER_BEAM = 0.22 -- peak wake height at the hump, fraction of the beam -- tune
Wake.PUSH_PER_HEIGHT = 1.6 -- studs/s of drift per stud of wake height -- tune
Wake.RANGE_LENGTHS = 30 -- the wake fades out this many hull lengths astern -- tune
Wake.SIDE_WASH = 0.18 -- of hull speed, pushed out from the hull alongside it -- tune
Wake.PROP_WASH = 0.25 -- of hull speed, straight astern in the prop stream -- tune
Wake.MIN_SPEED = 0.3 -- studs/s, a hull this slow makes no wake

-- Wave height factor 0..1 for a length Froude number: peaks at 0.5, about 0.25 on the plane.
function Wake.heightFactor(froude: number): number
	local x = froude / 0.5
	return 2 * x * x / (1 + x * x * x)
end

-- Half-angle (radians) of the wake wedge for a length Froude number.
function Wake.halfAngle(froude: number): number
	if froude <= 0.6 then
		return KELVIN
	end
	return math.min(KELVIN, math.atan(1 / (math.sqrt(2 * math.pi) * froude)))
end

function Wake.at(point: Vector3, hull: Hull): (Vector3, number)
	local forward = hull.forward
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local v = Vector3.new(hull.velocity.X, 0, hull.velocity.Z):Dot(forward)
	local speed = math.abs(v)
	if speed < Wake.MIN_SPEED then
		return Vector3.zero, 0
	end
	local dir = if v >= 0 then forward else -forward -- direction of travel
	local sideDir = if v >= 0 then right else -right
	local rel = Vector3.new(point.X - hull.position.X, 0, point.Z - hull.position.Z)
	local ahead = rel:Dot(dir) -- + ahead of the hull centre
	local side = rel:Dot(sideDir)
	local L, B = hull.length, hull.beam
	local halfL, halfB = L / 2, B / 2
	local froude = speed / math.sqrt(G * L)
	local h0 = Wake.HEIGHT_PER_BEAM * B * Wake.heightFactor(froude)
	local out = if side >= 0 then sideDir else -sideDir
	local push = Vector3.zero
	local height = 0

	-- alongside the hull: bow and side wash, straight out from the hull
	if ahead > -halfL and ahead < halfL + B then
		local gap = math.abs(side) - halfB
		if gap < B then
			local fall = 1 - math.clamp(gap / B, 0, 1)
			push += out * (Wake.SIDE_WASH * speed * fall)
			height = math.max(height, h0 * fall)
		end
	end

	-- astern: the Kelvin wedge (s = distance astern of the transom)
	local s = -ahead - halfL
	if s > 0 and s < Wake.RANGE_LENGTHS * L then
		local alpha = Wake.halfAngle(froude)
		local arm = halfB + s * math.tan(alpha) -- lateral distance of the wedge arm
		local width = 0.5 * L + 0.15 * s -- the arm's crest band widens as it spreads
		local offArm = math.abs(side) - arm
		local profile = if offArm <= 0
			then 0.35 + 0.65 * math.exp(-(offArm * offArm) / (width * width))
			else math.exp(-(offArm * offArm) / (width * width))
		local decay = (L / (L + s)) ^ (1 / 3)
		local fade = 1 - s / (Wake.RANGE_LENGTHS * L)
		local hw = h0 * profile * decay * fade
		if hw > 0 then
			local waveDir = (out * math.cos(alpha) + dir * 0.6).Unit
			push += waveDir * (Wake.PUSH_PER_HEIGHT * hw)
			height = math.max(height, hw)
		end
		-- prop / jet wash straight astern (only when moving ahead)
		if v > 0 and math.abs(side) < B and s < 4 * L then
			local fall = (1 - math.abs(side) / B) * (1 - s / (4 * L))
			push += -dir * (Wake.PROP_WASH * speed * fall)
		end
	end
	return push, height
end

local function hullOf(model: Model): Hull?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local size = root.Size
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	return {
		position = root.Position,
		velocity = root.AssemblyLinearVelocity,
		forward = flat.Unit,
		length = size.Z,
		beam = size.X,
	}
end

function Wake.fromModel(model: Model, point: Vector3): (Vector3, number)
	local hull = hullOf(model)
	if not hull then
		return Vector3.zero, 0
	end
	return Wake.at(point, hull)
end

-- Summed push and the highest wake at a point from every vehicle in Workspace.Vehicles.
-- ignore: a model to skip (for example the casualty's own towed boat).
function Wake.pushAt(point: Vector3, ignore: Model?): (Vector3, number)
	local folder = game:GetService("Workspace"):FindFirstChild("Vehicles")
	if not folder then
		return Vector3.zero, 0
	end
	local push, height = Vector3.zero, 0
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child ~= ignore then
			local p, h = Wake.fromModel(child, point)
			push += p
			height = math.max(height, h)
		end
	end
	return push, height
end

return Wake
