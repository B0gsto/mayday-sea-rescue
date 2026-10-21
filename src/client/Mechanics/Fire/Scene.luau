--!strict
-- Fire/Scene: the burning cruiser as the fire mechanics find it (docs/09 8.2, docs/13 LU-3).
-- src/server/Ops/FireScene tags the boat model `VesselFire` and hangs the `FireBase`,
-- `FireBoundary_NN` and `BowPoint` attachments on the hull; everything here reads those and the
-- weather. Client-only.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FireSpread = require(Shared:WaitForChild("Ops"):WaitForChild("FireSpread"))
local Weather = require(Shared:WaitForChild("Weather"))

local Scene = {}

function Scene.wind(): number
	return Weather.getWindDirection()
end

function Scene.burning(): Model?
	for _, m in CollectionService:GetTagged("VesselFire") do
		if m:IsA("Model") and m.Parent and m:GetAttribute("FireActive") == true then
			return m
		end
	end
	return nil
end

local function find(model: Model?, name: string): Attachment?
	local a = model and model:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

function Scene.base(model: Model?): Attachment?
	return find(model, "FireBase")
end

function Scene.bow(model: Model?): Attachment?
	return find(model, "BowPoint")
end

function Scene.boundary(model: Model?): { Attachment }
	local out = {}
	for i = 1, FireSpread.PANELS do
		local a = find(model, `FireBoundary_{i}`)
		if a then
			table.insert(out, a)
		end
	end
	return out
end

function Scene.people(model: Model?): number
	local n = model and model:GetAttribute("FirePeople")
	return if type(n) == "number" then n else 0
end

function Scene.inPlume(fire: Vector3, position: Vector3): (boolean, number)
	return FireSpread.inPlume(Scene.wind(), fire, position, 25, 140)
end

function Scene.upwind(fire: Vector3, position: Vector3): boolean
	return FireSpread.upwind(Scene.wind(), fire, position)
end

return Scene
