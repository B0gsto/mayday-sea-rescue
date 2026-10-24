--!strict
-- FireScene (server): the burning motor cruiser of the Vessel Fire operation (docs/09 8.2, docs/16 K1).
-- Spectacle only: a motor cruiser (textured mesh via AssetLoader) at anchor with fire and smoke on the stern; the fire grows over
-- the call and the smoke drifts downwind. Her two people are already in the water beside her
-- (RescueService survivors). OperationService calls Spawn on activate and Cleanup when it closes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))

local FireScene = {}

FireScene.GROW_SECONDS = 180 -- the fire reaches full size this long after the call starts -- tune

-- rescue variant -> textured hull (existing meshes); the meshes carry their own look, so RescueDressing's Part extras
-- (sized for the old 6 x 14 block cruiser) are not added
local HULLS = {
	default = "M_Veh_Tidewalker", -- motor cruiser
	CharterBoat = "M_Veh_MooredBoat_02", -- the crabber as a charter fishing boat
}
local DRAFT = { M_Veh_Tidewalker = 1.6, M_Veh_MooredBoat_02 = 0 } -- pivot depth below the sea surface
local FIRE_AT = { -- the fire's seat in the hull's pivot space (forward is -Z: the aft deck is +Z)
	M_Veh_Tidewalker = CFrame.new(0, 8, 12), -- the cockpit sole among the sofas
	M_Veh_MooredBoat_02 = CFrame.new(0, 4.5, 9),
}
AssetLoader.preload({ HULLS.default, HULLS.CharterBoat })

local function wind(): number
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local w = folder and folder:GetAttribute("WindDirection")
	return if type(w) == "number" then w else 0
end

local function key(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end

local function flame(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	Flipbooks.apply(e, "FX_Flare_Head") -- emissive fire loop; stock fire sheet until uploaded
	e.Name = "FireFlames"
	e.Rate = 16
	e.Lifetime = NumberRange.new(0.6, 1.3)
	e.Speed = NumberRange.new(2, 4.5)
	e.SpreadAngle = Vector2.new(20, 20)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 5, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-80, 80)
	e.Size = NumberSequence.new({ key(0, 4.5), key(1, 1.8) })
	e.Transparency = NumberSequence.new({ key(0, 0.1), key(1, 0.75) })
	e.Color = ColorSequence.new(Color3.fromRGB(255, 176, 70), Color3.fromRGB(255, 84, 18))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function smoke(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	Flipbooks.apply(e, "FX_Smoke_Orange") -- the billowing smoke sheet, pushed dark
	e.Name = "FireSmoke"
	e.Rate = 10
	e.Lifetime = NumberRange.new(6, 10)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-18, 18)
	e.Size = NumberSequence.new({ key(0, 3), key(1, 15) })
	e.Transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(46, 46, 52), Color3.fromRGB(96, 96, 104))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Parent = parent
	return e
end

function FireScene.Spawn(scene: any)
	if scene.fire then
		return
	end
	local callProps = Workspace:FindFirstChild("CallProps") or Workspace
	local model = Instance.new("Model")
	model.Name = "BurningCruiser"
	model:SetAttribute("CallId", scene.opId)
	model.Parent = callProps
	scene.fire = model
	-- the first load yields (LoadAsset); the call starts without waiting for it
	task.spawn(function()
		local asset = HULLS[scene.variant] or HULLS.default
		local hull = AssetLoader.cloneStatic(asset, "LOD0", false)
		if scene.fire ~= model then
			if hull then
				hull:Destroy()
			end
			return
		end
		if not hull then
			warn(`[FireScene] {asset} did not load: no hull this call`)
			return
		end
		hull.Parent = model
		-- at anchor, listing a little, low in the water (the pivot is the keel)
		local base = CFrame.new(scene.position.X, -DRAFT[asset], scene.position.Z)
			* CFrame.Angles(0, math.rad(25), math.rad(6))
		hull:PivotTo(base)
		-- the fire sits on the aft deck; an invisible anchor carries it (the mesh's own primary part is off-centre)
		local root = Instance.new("Part")
		root.Name = "FireRoot"
		root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
		root.Transparency = 1
		root.Size = Vector3.one
		root.CFrame = base * FIRE_AT[asset]
		root.Parent = model
		model.PrimaryPart = root
		local stern = Instance.new("Attachment")
		stern.Name = "FireBase"
		stern.Parent = root
		local flames = flame(stern)
		local plume = smoke(stern)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 130, 50)
		light.Range = 34
		light.Brightness = 2
		light.Shadows = false
		light.Parent = stern
		local started = os.clock()
		while scene.fire == model and model.Parent do
			local grown = math.clamp((os.clock() - started) / FireScene.GROW_SECONDS, 0, 1)
			flames.Rate = 14 + 22 * grown
			plume.Rate = 8 + 16 * grown
			plume.Acceleration = Vector3.new(math.cos(wind()), 0, math.sin(wind()))
					* (2.5 + 5 * grown)
				+ Vector3.new(0, 1.2, 0)
			light.Brightness = 2 + 2 * grown
			task.wait(1)
		end
	end)
end

function FireScene.Cleanup(scene: any)
	local model: Model? = scene.fire
	scene.fire = nil
	if model then
		model:Destroy()
	end
end

return FireScene
