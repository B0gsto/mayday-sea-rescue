--!strict
-- Art (server): puts an uploaded land-vehicle body on an existing greybox chassis.
--
-- The Builder model keeps everything gameplay uses: the invisible Chassis root (mass, forces),
-- the raycast wheel parts, DriverSeat / Seat2..n, the lamp parts and the light-bar Beacons. The
-- uploaded model is a visual body: every art part is welded to the root (massless, non-colliding)
-- and the greybox body panels are hidden. Wheels are the exception: each art wheel is welded to its
-- greybox Wheel_* part (named after Chassis.prepare) so steering and spin keep working; the greybox
-- tyre/rim is hidden. Seats, beacons, lamps and the tow hitch move to the art's ATT_* points.
--
-- If the asset failed to load the caller never calls apply and the greybox stays as built.
local ArtLayout = require(script.Parent.ArtLayout)
local LandVehicleConfig = require(script.Parent.Parent.Config.LandVehicleConfig)

type Spec = LandVehicleConfig.Spec
type Markers = { [string]: Vector3 }

local Art = {}

local SMALL_LAMP = Vector3.new(0.5, 0.18, 0.12)
local BEACON_SIZE = Vector3.new(0.32, 0.14, 0.24)

-- Marker positions in the model's authored (pivot) space: the primary part is not at the pivot (the
-- ambulance's is its box, 4.8 studs up), so its attachment offsets alone float the art.
local function markerTable(visual: Model, primary: BasePart): Markers
	local out = {}
	local pivot = visual:GetPivot()
	for _, d in primary:GetChildren() do
		if d:IsA("Attachment") and string.sub(d.Name, 1, 4) == "ATT_" then
			out[d.Name] = pivot:PointToObjectSpace(d.WorldPosition)
		end
	end
	return out
end

local function hide(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function weld(part: BasePart, root: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = root
	joint.Part1 = part
	joint.Parent = part
end

-- art MeshPart name -> wheel token (FL / L1 / ...), nil for a body part
local function wheelToken(name: string, asset: string): string?
	local base = string.gsub(name, "_LOD%d+$", "")
	local prefix = asset .. "_Wheel_"
	if string.sub(base, 1, #prefix) ~= prefix then
		return nil
	end
	local token = string.sub(base, #prefix + 1)
	return if string.match(token, "^%u%u?%d?$") then token else nil
end

local function partsNamed(model: Model, name: string): { BasePart }
	local out = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name == name then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a.Position.X < b.Position.X
	end)
	return out
end

-- One lamp part per art marker, matched left / right by x order.
local function moveLamps(model: Model, name: string, positions: Markers, size: Vector3)
	local parts = partsNamed(model, name)
	local markers = {
		positions[`ATT_{name}_L`],
		positions[`ATT_{name}_R`],
	}
	for i, part in parts do
		local at = markers[i] or markers[1]
		if at then
			part.CFrame = CFrame.new(at)
			part.Size = size
			part.CanCollide = false
			part.CastShadow = false
		end
	end
end

-- Moves the functional seats onto the art's seat points and makes them invisible.
local function moveSeats(model: Model, positions: Markers)
	-- Player cars are left-hand drive; the art was authored right-hand drive, so swap the front pair
	-- when the driver marker sits right (+X) of the passenger's.
	local driverAt: Vector3?, passengerAt: Vector3? = positions.ATT_DriverSeat, positions.ATT_Seat2
	local root = model.PrimaryPart
	local swap = driverAt ~= nil
		and passengerAt ~= nil
		and root ~= nil
		and root.CFrame:PointToObjectSpace(driverAt).X
			> root.CFrame:PointToObjectSpace(passengerAt).X
	for _, d in model:GetChildren() do
		if not (d:IsA("Seat") or d:IsA("VehicleSeat")) then
			continue
		end
		local seat = d :: BasePart
		local at: Vector3? = positions[`ATT_{d.Name}`]
		if swap and d.Name == "DriverSeat" then
			at = passengerAt
		elseif swap and d.Name == "Seat2" then
			at = driverAt
		end
		if at then
			seat.CFrame = CFrame.new(at)
		end
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CastShadow = false
		local eye = seat:FindFirstChild("EyePoint")
		local eyeAt = positions.ATT_EyePoint
		if eye and eye:IsA("Attachment") and eyeAt then
			local offset = eyeAt - (driverAt or seat.CFrame.Position)
			eye.Position = if swap then offset * Vector3.new(-1, 1, 1) else offset
		end
	end
end

local function moveBeacons(model: Model, positions: Markers)
	local beacons = partsNamed(model, "Beacon")
	local bar = positions.ATT_LightBar
	for i, part in beacons do
		local at = positions[string.format("ATT_Beacon_%02d", i)]
			or if bar then bar + Vector3.new((i - (#beacons + 1) / 2) * 0.7, 0, 0) else nil
		if at then
			part.CFrame = CFrame.new(at)
			part.Size = BEACON_SIZE
			part.Transparency = 0.15
			part.CanCollide = false
			part.CastShadow = false
		end
	end
end

local function moveFloodlights(model: Model, positions: Markers)
	local at = positions.ATT_Floodlight
	local lights = partsNamed(model, "Floodlight")
	for i, part in lights do
		if at then
			part.CFrame = CFrame.new(at + Vector3.new((i - (#lights + 1) / 2) * 0.9, 0, 0))
		end
		part.Transparency = 0.1
		part.CanCollide = false
		part.CastShadow = false
	end
end

-- Builder root attachments (no ATT_ prefix) move onto the art's points, then every ATT_* marker is
-- exposed on the root for other systems (seats, board, lockers, handover, ...).
local ROOT_MARKERS: { [string]: string } = {
	ATT_TowHitch = "TowHitch",
	ATT_Coupler = "Coupler",
	ATT_Cradle = "Cradle",
	ATT_HandoverPoint = "HandoverPoint",
}

local function moveRootMarkers(root: BasePart, positions: Markers)
	for marker, rootName in ROOT_MARKERS do
		local at = positions[marker]
		if not at then
			continue
		end
		local existing = root:FindFirstChild(rootName)
		if existing and existing:IsA("Attachment") then
			existing.Position = at
		else
			local a = Instance.new("Attachment")
			a.Name = rootName
			a.Position = at
			a.Parent = root
		end
	end
	for name, at in positions do
		if name == "ATT_DriveAttachment" then
			continue
		end
		local existing = root:FindFirstChild(name)
		if not existing then
			local a = Instance.new("Attachment")
			a.Name = name
			a.Position = at
			a.Parent = root
		end
	end
end

local function hideGreybox(model: Model)
	for _, d in model:GetChildren() do
		if not d:IsA("BasePart") or d.Name == "Chassis" or string.match(d.Name, "^Wheel_") then
			continue
		elseif
			d:IsA("Seat")
			or d:IsA("VehicleSeat")
			or d.Name == "Beacon"
			or d.Name == "Floodlight"
		then
			continue
		elseif
			d.Name == "Headlamp"
			or d.Name == "TailLamp"
			or d.Name == "BrakeLamp"
			or d.Name == "ReverseLamp"
		then
			continue
		end
		hide(d)
	end
end

-- Puts `visual` (an AssetLoader clone) on the greybox model. The model must still be at its build
-- position (root CFrame identity). Returns false for a model with no chassis / visual.
function Art.apply(model: Model, spec: Spec, visual: Model): boolean
	local root = model.PrimaryPart
	local primary = visual.PrimaryPart
	if not primary then
		primary = visual:FindFirstChildWhichIsA("BasePart", true)
	end
	if not root or not primary then
		return false
	end
	local asset = visual:GetAttribute("Asset")
	local assetName: string = if type(asset) == "string" then asset else visual.Name
	local markers = markerTable(visual, primary)
	local origin = ArtLayout.origin(spec, markers)
	visual:PivotTo(CFrame.new(origin))
	local positions: Markers = {}
	for name, at in markers do
		positions[name] = origin + at
	end

	hideGreybox(model)
	moveSeats(model, positions)
	moveBeacons(model, positions)
	moveFloodlights(model, positions)
	for _, name in { "Headlamp", "TailLamp", "BrakeLamp", "ReverseLamp" } do
		moveLamps(
			model,
			name,
			positions,
			if name == "Headlamp" then SMALL_LAMP else Vector3.new(0.42, 0.16, 0.1)
		)
	end
	moveRootMarkers(root, positions)

	local trailer = spec.class == "Trailer"
	for _, d in visual:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local token = wheelToken(d.Name, assetName)
		local partName = token and ArtLayout.wheelPart(token, trailer)
		local tyre = partName and model:FindFirstChild("Wheel_" .. partName)
		if tyre and tyre:IsA("BasePart") then
			local at = positions[`ATT_Wheel_{token}`]
			if at then
				d.CFrame += tyre.Position - root.CFrame:PointToWorldSpace(at)
			end
			hide(tyre)
			for _, child in tyre:GetChildren() do
				if child:IsA("BasePart") then
					hide(child)
				end
			end
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			local joint = Instance.new("WeldConstraint")
			joint.Part0 = tyre
			joint.Part1 = d
			joint.Parent = d
		else
			weld(d, root)
		end
	end
	visual.Parent = model
	model:SetAttribute("Visual", assetName)
	return true
end

return Art
