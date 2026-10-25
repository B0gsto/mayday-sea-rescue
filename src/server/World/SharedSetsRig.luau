--!strict
-- SharedSetsRig (I2a): buildings whose parts use shared texture sets AssetLoader cannot see from each asset's own
-- Appearances folder (only the Details atlas lives there) get theirs here from the Appearances model's prebuilt
-- SurfaceAppearances (SETS), and cottages get their render and slate (SharedSetsRig.cottage).

local CollectionService = game:GetService("CollectionService")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
-- Rojo builds the shared sets as SurfaceAppearances (map ids cannot be written by a game script)
local appearances =
	script.Parent.Parent:WaitForChild("Assets"):WaitForChild("Appearances") :: Instance

-- asset -> MeshPart token -> shared texture set (each asset's build.py mats)
local SETS: { [string]: { [string]: { string } } } = {
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
				if spec then
					apply(part, spec[1], spec[2])
				end
			end
		end
	end
end

return SharedSetsRig
