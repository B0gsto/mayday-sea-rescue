--!strict
-- SharedSetsRig (I2a H4/H5): the harbourmaster's office and the hospital use shared texture sets (Station Granite,
-- Chandlery Slate, BldTrim Sheet, Cottage Render_White + Slate, Pontoon Kit) that AssetLoader cannot see from
-- each asset's own Appearances folder (only the Details atlas lives there), so their shared-set parts get theirs
-- here from the Appearances model's prebuilt SurfaceAppearances. Called after each shell is placed (Swaps rig). The
-- slipway's library-set parts get plain tinted materials (PLAIN).

local CollectionService = game:GetService("CollectionService")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
-- Rojo builds the shared sets as SurfaceAppearances (map ids cannot be written by a game script)
local appearances =
	script.Parent.Parent:WaitForChild("Assets"):WaitForChild("Appearances") :: Instance

-- asset -> MeshPart token -> shared texture set (each asset's build.py mats)
local SETS: { [string]: { [string]: { string } } } = {
	M_Bld_Hospital = {
		Walls = { "M_Bld_Cottage_Kit", "White" },
		Roof = { "M_Bld_Cottage_Kit", "Slate" },
		Trim = { "M_Bld_TrimSheet", "Sheet" },
		Pontoon = { "M_Hbr_Pontoon", "Kit" },
	},
	M_Bld_Harbourmaster = {
		Stone = { "M_Bld_Station", "Granite" },
		Roof = { "M_Bld_Chandlery_Ext", "Slate" },
		Trim = { "M_Bld_TrimSheet", "Sheet" },
	},
	-- own sets, but several part names do not carry the set name (AssetLoader's only fallback is a single set)
	M_Bld_BoatyardShed = {
		Clad = { "M_Bld_BoatyardShed", "Clad" },
		Roof = { "M_Bld_BoatyardShed", "Clad" },
		RoofLight = { "M_Bld_BoatyardShed", "Details" },
		Inner = { "M_Bld_BoatyardShed", "Details" },
		Doors = { "M_Bld_BoatyardShed", "Details" },
		Signs = { "M_Bld_BoatyardShed", "Details" },
		Glass = { "M_Bld_BoatyardShed", "Details" },
		Steel = { "M_Bld_BoatyardShed", "Metal" },
		Trim = { "M_Bld_BoatyardShed", "Metal" },
		Timber = { "M_Bld_BoatyardShed", "Details" },
		Lit = { "M_Bld_BoatyardShed", "Details" },
	},
}

-- M_Bld_Slipway's shared B02 library sets (Concrete, WeedyConcrete, QuayStone, KelpRock) are MaterialService
-- variants TerrainOnly keeps off Parts, so those parts rendered plain white (docs/17 P1 17): unmapped materials tinted
-- to build.py's base colours (a shade darker: wet) instead.
local PLAIN: { [string]: { [string]: { any } } } = {
	M_Bld_Slipway = {
		Ramp = { Enum.Material.Plaster, Color3.fromRGB(146, 142, 134) },
		Weedy = { Enum.Material.Granite, Color3.fromRGB(84, 92, 70) },
		Wall = { Enum.Material.Granite, Color3.fromRGB(128, 124, 116) },
		Rock = { Enum.Material.Granite, Color3.fromRGB(78, 80, 72) },
	},
}

local function apply(part: MeshPart, asset: string, set: string)
	local folder = appearances:FindFirstChild(asset)
	local maps = folder and folder:FindFirstChild(set)
	if not maps then
		warn(`[SharedSetsRig] {asset}.{set} missing from Appearances`)
		return
	end
	for _, old in part:GetChildren() do
		if old:IsA("SurfaceAppearance") or old.Name == "SurfaceVariants" then
			old:Destroy()
		end
	end
	local dry = maps:FindFirstChild("Dry")
	if dry then
		local sa = dry:Clone()
		sa.Name = "SurfaceAppearance"
		sa.Parent = part
	end
	local wet = maps:FindFirstChild("Wet")
	if wet then
		local variants = Instance.new("Configuration")
		variants.Name = "SurfaceVariants"
		local sa = wet:Clone()
		sa.Name = "SurfaceAppearance_Wet"
		sa.Parent = variants
		variants.Parent = part
		part:SetAttribute("WetState", false)
		CollectionService:AddTag(part, AssetLoader.WET_TAG)
	end
end

local SharedSetsRig = {}

-- H3 cottages: parts are M_Bld_Cottage_<Part>_<NN>_LODk, and Walls / Roof / Trim carry no set name, so AssetLoader
-- left them untextured (plain white). Walls take the variant's render (M_Bld_Cottage_Kit variants.py) or `colour`.
local COTTAGE_RENDER = { "Pink", "Ochre", "White", "Sage", "White", "Blue" }
SharedSetsRig.RENDERS = { "White", "Pink", "Ochre", "Sage", "Blue" }
local SLATES = { -- Delabole greys and blue-greys (TownBuildings.SLATES)
	Color3.fromRGB(72, 78, 86),
	Color3.fromRGB(62, 68, 78),
	Color3.fromRGB(84, 88, 94),
	Color3.fromRGB(58, 64, 72),
	Color3.fromRGB(78, 82, 92),
}
local COTTAGE_SETS: { [string]: { string } } = {
	Trim = { "M_Bld_TrimSheet", "Sheet" },
}

function SharedSetsRig.cottage(shell: Model, colour: string?)
	for _, part in shell:GetDescendants() do
		if part:IsA("MeshPart") then
			local token, n = string.match(part.Name, "^M_Bld_Cottage_(%a+)_(%d%d)_LOD%d$")
			if token == "Walls" then
				apply(
					part,
					"M_Bld_Cottage_Kit",
					colour or COTTAGE_RENDER[tonumber(n) :: number] or "White"
				)
			elseif token == "Roof" then
				-- the Slate atlas reads as rainbow tiles: plain slate-grey RoofShingles, one shade per cottage
				for _, old in part:GetChildren() do
					if old:IsA("SurfaceAppearance") or old.Name == "SurfaceVariants" then
						old:Destroy()
					end
				end
				part.Material = Enum.Material.RoofShingles
				local p = part.Position
				part.Color = SLATES[math.floor(math.abs(p.X * 7 + p.Z * 3)) % #SLATES + 1]
			elseif token and COTTAGE_SETS[token] then
				apply(part, COTTAGE_SETS[token][1], COTTAGE_SETS[token][2])
			end
		end
	end
end

function SharedSetsRig.apply(shell: Model)
	for _, part in shell:GetDescendants() do
		if part:IsA("MeshPart") then
			local asset, token = string.match(part.Name, "^(M_Bld_%a+)_(%a+)_LOD%d$")
			if asset and token then
				local sets = SETS[asset]
				local spec = sets and sets[token]
				local plain = PLAIN[asset] and PLAIN[asset][token]
				if spec then
					apply(part, spec[1], spec[2])
				elseif plain then
					for _, old in part:GetChildren() do
						if old:IsA("SurfaceAppearance") or old.Name == "SurfaceVariants" then
							old:Destroy()
						end
					end
					part.MaterialVariant = ""
					part.Material = plain[1]
					part.Color = plain[2]
				end
			end
		end
	end
end

return SharedSetsRig
