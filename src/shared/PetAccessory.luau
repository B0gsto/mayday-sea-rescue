--!strict
-- PetAccessory: the G48 cosmetic reward at a full bond, code-built Parts (no art yet).
-- A little orange life vest on the animal's body; WildlifeRig.attach keeps it on the rig, so it
-- follows the pet and rides the pens exactly like the animal's own parts.

local WildlifeRig = require(script.Parent.WildlifeRig)

local PetAccessory = {}

local ORANGE = Color3.fromRGB(246, 118, 48)
local WHITE = Color3.fromRGB(242, 238, 226)

function PetAccessory.wear(model: Model): boolean
	if not model.PrimaryPart or model:GetAttribute("PetAccessory") ~= nil then
		return false
	end
	local body = model.PrimaryPart
	local size = body.Size
	local at = WildlifeRig.offsetOf(model, body.Name) or CFrame.new(0, size.Y / 2, 0)
	local ok = true
	local function add(name: string, partSize: Vector3, offset: CFrame, color: Color3)
		if not WildlifeRig.attach(model, name, partSize, offset, color) then
			ok = false
		end
	end
	add(
		"LifeVest_Back",
		Vector3.new(size.X * 1.16, size.Y * 0.86, 0.22),
		at * CFrame.new(0, 0, size.Z * 0.5 + 0.1),
		ORANGE
	)
	add(
		"LifeVest_FrontL",
		Vector3.new(size.X * 0.34, size.Y * 0.74, 0.2),
		at * CFrame.new(-size.X * 0.3, 0, -size.Z * 0.5 - 0.1),
		ORANGE
	)
	add(
		"LifeVest_FrontR",
		Vector3.new(size.X * 0.34, size.Y * 0.74, 0.2),
		at * CFrame.new(size.X * 0.3, 0, -size.Z * 0.5 - 0.1),
		ORANGE
	)
	for _, side in { -1, 1 } do
		add(
			`LifeVest_Strap{side}`,
			Vector3.new(0.18, size.Y * 0.4, size.Z * 1.04),
			at * CFrame.new(side * size.X * 0.5, 0, 0),
			WHITE
		)
	end
	if ok then
		model:SetAttribute("PetAccessory", "Vest")
	end
	return ok
end

return PetAccessory
