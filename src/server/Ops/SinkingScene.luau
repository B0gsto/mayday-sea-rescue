--!strict
-- SinkingScene (server): the fishing boat of the Sinking Vessel operation (docs/09 section 8.1, docs/16 K1).
-- Spectacle only: a trawler (textured mesh via AssetLoader) lists and settles over the call, with the swirl where the water
-- comes in and a waterline that climbs her side. Her crew are already in the water beside her
-- (RescueService survivors). OperationService calls Spawn on activate and Cleanup when it closes.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))

local SinkingScene = {}

SinkingScene.SINK_SECONDS = 480 -- she is nearly gone this long after the call starts -- tune
SinkingScene.LIST_START = math.rad(6)
SinkingScene.LIST_MAX = math.rad(20)
SinkingScene.SETTLE_MAX = 4.5 -- studs the hull drops by the end

-- rescue variant -> textured hull (existing moored-boat meshes, pivot on the waterline); the meshes carry their own gear,
-- so RescueDressing's Part extras (sized for the old 24 x 52 block hull) are not added
local HULLS = {
	default = "M_Veh_MooredBoat_03", -- trawler
	Tugboat = "M_Veh_MooredBoat_02", -- the crabber reads as the stubbier workboat
}
AssetLoader.preload({ HULLS.default, HULLS.Tugboat })

type Rec = { folder: Folder, conn: RBXScriptConnection? }

local live: { [any]: Rec } = setmetatable({}, { __mode = "k" }) :: any

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function SinkingScene.Spawn(scene: any)
	if live[scene] then
		return
	end
	local callProps = Workspace:FindFirstChild("CallProps")
	if not callProps then
		callProps = Instance.new("Folder")
		callProps.Name = "CallProps"
		callProps.Parent = Workspace
	end
	local folder = Instance.new("Folder")
	folder.Name = `Sinking_{scene.opId}`
	folder.Parent = callProps

	local rec: Rec = { folder = folder }
	live[scene] = rec
	folder:SetAttribute("OpId", scene.opId)
	-- the first load yields (LoadAsset); the call starts without waiting for it
	task.spawn(function()
		local asset = HULLS[scene.variant] or HULLS.default
		local model = AssetLoader.cloneStatic(asset, "LOD0", false)
		if live[scene] ~= rec then
			if model then
				model:Destroy()
			end
			return
		end
		if not model then
			warn(`[SinkingScene] {asset} did not load: no hull this call`)
			return
		end
		model.Name = "SinkingBoat"
		local pivot = model:GetPivot() -- the authored pivot is the waterline
		local _, size = model:GetBoundingBox()
		model.Parent = folder

		-- where the water comes in: a bright swirl and bubbles on the starboard quarter
		local leak = part(
			model,
			"LeakPoint",
			Vector3.new(2.2, 2.2, 2.2),
			pivot * CFrame.new(size.X / 2 + 0.2, 0.4, 6),
			Color3.fromRGB(225, 245, 255),
			Enum.Material.Neon
		)
		leak.Shape = Enum.PartType.Ball
		leak.Transparency = 0.25
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Name = "LeakSwirl"
		bubbles.Rate = 22
		bubbles.Lifetime = NumberRange.new(0.4, 0.9)
		bubbles.Speed = NumberRange.new(1, 3)
		bubbles.SpreadAngle = Vector2.new(18, 18)
		bubbles.Size = NumberSequence.new(0.5, 0.1)
		bubbles.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
		bubbles.Transparency = NumberSequence.new(0.2, 1)
		bubbles.Parent = leak

		-- the sea's edge on her side: a fixed white line the hull settles through
		local foam = part(
			folder,
			"Waterline",
			Vector3.new(size.X + 6, 0.12, size.Z + 6),
			CFrame.new(scene.position.X, 0.22, scene.position.Z) * CFrame.Angles(0, math.rad(18), 0),
			Color3.fromRGB(245, 250, 252),
			Enum.Material.SmoothPlastic
		)
		foam.Transparency = 0.65

		local base = CFrame.new(scene.position.X, 0, scene.position.Z)
			* CFrame.Angles(0, math.rad(18), 0)
		model:PivotTo(base)
		local started = os.clock()
		rec.conn = RunService.Heartbeat:Connect(function()
			local f = math.clamp((os.clock() - started) / SinkingScene.SINK_SECONDS, 0, 1)
			local list = SinkingScene.LIST_START
				+ (SinkingScene.LIST_MAX - SinkingScene.LIST_START) * f
			model:PivotTo(
				base * CFrame.new(0, -SinkingScene.SETTLE_MAX * f, 0) * CFrame.Angles(0, 0, list)
			)
		end)
	end)
end

function SinkingScene.Cleanup(scene: any)
	local rec = live[scene]
	if not rec then
		return
	end
	live[scene] = nil
	if rec.conn then
		rec.conn:Disconnect()
	end
	rec.folder:Destroy()
end

return SinkingScene
