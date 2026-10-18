--!strict
-- ChandleryRig: the Play-mode (server) port of the Edit-mode look-dev rig
-- assets/review/M_Bld_Chandlery/studio/chandlery.luau, with the light values of
-- art/source/buildings/M_Bld_Chandlery_Ext/layout.py (LIGHTS, LIGHT_KINDS, WARM_2700K, COOL_6500K,
-- ON_EXT / ON_INT / ON_DAY). Where the rig DEF and layout.LIGHTS differ, layout.LIGHTS wins: one
-- PointLight per practical (no extra SpotLight pools under pendants / holophanes / goosenecks),
-- per-kind brightness / range / drop_studs / shadows, the till lamp as a Face-Bottom SpotLight,
-- the bay fill as three shadowless PointLights (no SurfaceLight) and COOL_6500K for the fills.
-- The rig's glass values and Neon glow colours are kept (layout has none).
--
-- Inputs: clones from Server.Assets.AssetLoader (ATT_* markers are Attachments on each model's
-- PrimaryPart; visual parts unanchored, Massless, non-colliding). All four models share ONE pivot
-- (the authored layout origin, upright); model-local studs = (-bx, bz, by) * 3 of layout metres.
-- New light Attachments go on the PrimaryParts, so apply() works before or after the caller
-- anchors and positions the models (moved rigidly, yaw only).
--
--   ChandleryRig.apply(ext, int?, props?, stock?) -> cleanup()
--       glass, Glow parts, 35 practicals / fills, switching by weather preset and clock
--   ChandleryRig.check(ext, int?, props?, stock?) -> { [string]: number }   smoke-report counts
--   ChandleryRig.preset() -> "Clear" | "Overcast" | "Storm" | "Night"
--
-- Preset at run time (the look itself is client-side, WeatherController): "Storm" while
-- Shared.Weather.getState() == "Storm"; else the Lighting attribute WeatherBase ("Clear" /
-- "Calm" -> Clear, "Night", default Overcast as in WeatherController); "Night" whenever the sun is
-- below the horizon (Lighting:GetSunDirection()). Re-evaluated on Weather.changed, Lighting
-- WeatherBase and Lighting.ClockTime changes; no per-frame loop.
--
-- Product shelves (RP-M3, docs/04 section 1.1): apply() also tags the shop's ATT_ markers that
-- ProductShelves lists (ATT_ServiceCards, ATT_Logbook, ATT_Till, ATT_Rack_02, ATT_DogBasket,
-- ATT_SwatchBoard, ATT_HornBoard, ATT_RadioShelf) with the attribute ProductShelf = <shelf id>; the
-- client (UI/ProductCard) adds the prompts and opens the product cards. cleanup() removes the tags.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductShelves =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProductShelves"))
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local ChandleryRig = {}

type Rule = { presets: { string }, dusk: { string }, day: { string } }
type Spec = {
	type: "PointLight" | "SpotLight",
	color: Color3,
	brightness: number,
	range: number,
	shadows: boolean,
	drop: number,
	angle: number?,
	on: "ext" | "int" | "day",
}

local WARM_2700K = Color3.fromRGB(255, 177, 110)
local COOL_6500K = Color3.fromRGB(232, 240, 255)
local GLOW_INT = Color3.fromRGB(255, 196, 132) -- rig DEF.glow_int
local GLOW_EXT = Color3.fromRGB(255, 206, 150) -- rig DEF.glow_ext
local GLOW_OFF = Color3.fromRGB(196, 190, 178) -- rig DEF.glow_off
local GLASS_COLOR = Color3.fromRGB(96, 112, 120)
local GLASS_TRANSPARENCY, GLASS_REFLECTANCE = 0.4, 0.2

local DUSK_FROM, DAY_FROM = 17.0, 7.5 -- dusk: ClockTime >= 17.0 or < 7.5

local RULES: { [string]: Rule } = {
	ext = { presets = { "Night" }, dusk = { "Clear", "Overcast", "Storm" }, day = {} }, -- ON_EXT
	int = { presets = { "Overcast", "Storm", "Night" }, dusk = { "Clear" }, day = {} }, -- ON_INT
	day = { presets = {}, dusk = {}, day = { "Clear", "Overcast", "Storm" } }, -- ON_DAY
}

-- layout.LIGHTS (glazing_glow's "on" equals ON_EXT)
local SPEC: { [string]: Spec } = {
	ext_lamp = {
		type = "PointLight",
		color = WARM_2700K,
		brightness = 1.1,
		range = 16,
		shadows = true,
		drop = 0.6,
		on = "ext",
	},
	pendant = {
		type = "PointLight",
		color = WARM_2700K,
		brightness = 0.55,
		range = 15,
		shadows = true,
		drop = 0.35,
		on = "int",
	},
	holophane = {
		type = "PointLight",
		color = WARM_2700K,
		brightness = 0.65,
		range = 16,
		shadows = true,
		drop = 0.35,
		on = "int",
	},
	wall = {
		type = "PointLight",
		color = WARM_2700K,
		brightness = 0.35,
		range = 12,
		shadows = true,
		drop = 0.35,
		on = "int",
	},
	bulkhead = {
		type = "PointLight",
		color = WARM_2700K,
		brightness = 0.3,
		range = 10,
		shadows = false,
		drop = 0.2,
		on = "int",
	},
	till = {
		type = "SpotLight",
		color = WARM_2700K,
		brightness = 0.9,
		range = 7,
		shadows = true,
		drop = 0.1,
		angle = 70,
		on = "int",
	},
	bay_fill = {
		type = "PointLight",
		color = COOL_6500K,
		brightness = 0.2,
		range = 12,
		shadows = false,
		drop = 0,
		on = "day",
	},
	skylight_fill = {
		type = "SpotLight",
		color = COOL_6500K,
		brightness = 0.35,
		range = 14,
		shadows = false,
		drop = 0,
		angle = 90,
		on = "day",
	},
	glazing_glow = {
		type = "PointLight",
		color = WARM_2700K,
		brightness = 0.4,
		range = 10,
		shadows = false,
		drop = 0,
		on = "ext",
	},
}
ChandleryRig.SPEC = SPEC

-- layout positions (metres: bx along the frontage, by front -> back, bz up)
local Y0 = -6.0
local POSITIONS: { [string]: { { number } } } = {
	bay_fill = { { -2.5, Y0 - 0.3, 2.3 }, { 1.7, Y0 - 0.3, 2.3 }, { 5.9, Y0 - 0.3, 2.3 } },
	skylight_fill = { { -2.5, 3.85, 6.6 } },
	glazing_glow = {
		{ -2.5, Y0 + 0.35, 2.2 },
		{ 1.7, Y0 + 0.35, 2.2 },
		{ 5.9, Y0 + 0.35, 2.2 },
		{ -6.45, Y0 + 0.9, 4.9 },
		{ -1.0, Y0 + 0.9, 4.9 },
		{ 4.45, Y0 + 0.9, 4.9 },
	},
}

local function toLocal(m: { number }): Vector3
	return Vector3.new(-m[1] * 3, m[3] * 3, m[2] * 3)
end

-- layout.LIGHT_KINDS: ATT_Light_01..07 pendant, 08..09 holophane, 10..16 wall, 17..21 bulkhead
local function kindOfIndex(i: number): string?
	if i >= 1 and i <= 7 then
		return "pendant"
	elseif i >= 8 and i <= 9 then
		return "holophane"
	elseif i >= 10 and i <= 16 then
		return "wall"
	elseif i >= 17 and i <= 21 then
		return "bulkhead"
	end
	return nil
end

-- fallback for markers outside LIGHT_KINDS: the rig's classification by model-local studs
local function kindOfPosition(lp: Vector3): string
	local wallD = math.min(28.35 - math.abs(lp.X), 16.35 - math.abs(lp.Z))
	if lp.Y > 9.5 then
		return "wall"
	elseif wallD < 1.5 then
		return "bulkhead"
	elseif lp.X > -22.5 and lp.X < -1.5 and lp.Z > 1.0 and lp.Z < 4.5 then
		return "holophane"
	end
	return "pendant"
end

local function isDusk(clock: number): boolean
	return clock >= DUSK_FROM or clock < DAY_FROM
end

local function ruleOn(rule: Rule, preset: string, clock: number): boolean
	if table.find(rule.presets, preset) then
		return true
	elseif table.find(rule.dusk, preset) then
		return isDusk(clock)
	elseif table.find(rule.day, preset) then
		return not isDusk(clock)
	end
	return false
end

function ChandleryRig.preset(): string
	if Weather.getState() == "Storm" then
		return "Storm"
	end
	local base = Lighting:GetAttribute("WeatherBase")
	local name = if base == "Clear" or base == "Calm"
		then "Clear"
		elseif base == "Night" then "Night"
		else "Overcast"
	if Lighting:GetSunDirection().Y < 0 then
		name = "Night"
	end
	return name
end

-- strips the PBR look (and the wet swap) so Material / Color show
local function plain(p: BasePart)
	for _, c in p:GetChildren() do
		if
			c:IsA("SurfaceAppearance") or (c:IsA("Configuration") and c.Name == "SurfaceVariants")
		then
			c:Destroy()
		end
	end
	CollectionService:RemoveTag(p, "HasWetVariant")
end

local function isGlass(name: string): boolean
	return string.find(name, "_Glass_LOD", 1, true) ~= nil
		or string.find(name, "_DoorGlass_LOD", 1, true) ~= nil
end

local function isGlow(name: string): boolean
	return string.find(name, "_Glow_LOD", 1, true) ~= nil
end

local RIG_ATTR = "ChandleryRig" -- on every Instance this module creates
local KIND_ATTR = "ChandKind" -- on every Light: the layout.LIGHTS kind

local active: { [Model]: () -> () } = {}

function ChandleryRig.apply(ext: Model, int: Model?, props: Model?, stock: Model?): () -> ()
	local previous = active[ext]
	if previous then
		previous()
	end
	local models: { Model } = {}
	for _, m in { ext, int, props, stock } :: { Model? } do
		if m then
			table.insert(models, m)
		end
	end
	local created: { Instance } = {}
	local connections: { RBXScriptConnection } = {}

	-- shopfront glass (ext): Glass, 0.4 / 0.2, cool tint; DoorGlass welded to Door
	local door: BasePart?, doorGlass: BasePart? = nil, nil
	for _, d in ext:GetDescendants() do
		if d:IsA("BasePart") then
			if isGlass(d.Name) then
				plain(d)
				d.Material = Enum.Material.Glass
				d.Color = GLASS_COLOR
				d.Transparency = GLASS_TRANSPARENCY
				d.Reflectance = GLASS_REFLECTANCE
				d.CastShadow = false
				if string.find(d.Name, "_DoorGlass_LOD", 1, true) then
					doorGlass = d
				end
			elseif string.match(d.Name, "_Door_LOD%d$") then
				door = d
			end
		end
	end
	if door and doorGlass then
		local w = Instance.new("WeldConstraint")
		w.Name = "DoorGlassWeld"
		w.Part0, w.Part1 = door, doorGlass
		w:SetAttribute(RIG_ATTR, true)
		w.Parent = door
		table.insert(created, w)
	end

	-- Glow parts: exterior lamp glass follows ON_EXT, everything indoors ON_INT
	local glowExt: { BasePart }, glowInt: { BasePart } = {}, {}
	for _, m in models do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and isGlow(d.Name) then
				plain(d)
				d.CastShadow = false
				table.insert(if m == ext then glowExt else glowInt, d)
			end
		end
	end

	-- lights: on Attachments aligned with the shared pivot (yaw only), so Face Bottom is down
	local base = int or ext
	local pivot = base:GetPivot()
	local rot = pivot.Rotation
	local down = -pivot.UpVector
	local byRule: { [string]: { Light } } = { ext = {}, int = {}, day = {} }

	local function addLight(kind: string, host: BasePart, name: string, worldPos: Vector3)
		local s = SPEC[kind]
		local a = Instance.new("Attachment")
		a.Name = name
		a:SetAttribute(RIG_ATTR, true)
		a.Parent = host
		a.WorldCFrame = CFrame.new(worldPos + down * s.drop) * rot
		local l: Light
		if s.type == "SpotLight" then
			local sl = Instance.new("SpotLight")
			sl.Range = s.range
			sl.Angle = s.angle or 90
			sl.Face = Enum.NormalId.Bottom
			l = sl
		else
			local pl = Instance.new("PointLight")
			pl.Range = s.range
			l = pl
		end
		l.Name = "Chand_" .. kind
		l.Color = s.color
		l.Brightness = s.brightness
		l.Shadows = s.shadows
		l.Enabled = false
		l:SetAttribute(KIND_ATTR, kind)
		l:SetAttribute(RIG_ATTR, true)
		l.Parent = a
		table.insert(created, a)
		table.insert(byRule[s.on], l)
	end

	-- markers: ATT_Light_NN (interior practicals), ATT_Light_Till (stock), ATT_Lamp_NN (ext)
	for _, m in models do
		for _, d in m:GetDescendants() do
			if d:IsA("Attachment") and d:GetAttribute(RIG_ATTR) == nil then
				local host = d.Parent
				if host and host:IsA("BasePart") then
					local n = d.Name
					local idx = string.match(n, "^ATT_Light_(%d+)$")
					local kind: string? = nil
					if idx then
						kind = kindOfIndex(tonumber(idx) :: number)
							or kindOfPosition(pivot:PointToObjectSpace(d.WorldPosition))
					elseif n == "ATT_Light_Till" then
						kind = "till"
					elseif string.match(n, "^ATT_Lamp_%d+$") then
						kind = "ext_lamp"
					end
					if kind then
						addLight(kind, host, n .. "_Light", d.WorldPosition)
					end
				end
			end
		end
	end

	-- product shelves (RP-M3): tag the ATT_ markers the client turns into product-card prompts
	local shelfOf = ProductShelves.attachmentShelves()
	local tagged: { Attachment } = {}
	for _, m in models do
		for _, d in m:GetDescendants() do
			local shelf = if d:IsA("Attachment") then shelfOf[d.Name] else nil
			if shelf and d:IsA("Attachment") and d:GetAttribute("ProductShelf") == nil then
				d:SetAttribute("ProductShelf", shelf)
				table.insert(tagged, d)
			end
		end
	end

	-- positional lights (no marker): fills and the glazing glow, hosted on the base PrimaryPart
	local host = base.PrimaryPart
	if host then
		for _, kind in { "bay_fill", "skylight_fill", "glazing_glow" } do
			for i, p in POSITIONS[kind] do
				addLight(kind, host, `Chand_{kind}_{i}`, pivot:PointToWorldSpace(toLocal(p)))
			end
		end
	else
		warn("[ChandleryRig] no PrimaryPart on", base:GetFullName(), "- fills skipped")
	end

	-- switching
	local state: { [string]: boolean? } = {}
	local function setGlow(list: { BasePart }, on: boolean, c: Color3)
		for _, p in list do
			p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Color = if on then c else GLOW_OFF
		end
	end
	local function refresh()
		local preset = ChandleryRig.preset()
		local clock = Lighting.ClockTime
		for key, rule in RULES do
			local on = ruleOn(rule, preset, clock)
			if state[key] ~= on then
				state[key] = on
				for _, l in byRule[key] do
					l.Enabled = on
				end
				if key == "ext" then
					setGlow(glowExt, on, GLOW_EXT)
				elseif key == "int" then
					setGlow(glowInt, on, GLOW_INT)
				end
			end
		end
	end
	refresh()
	table.insert(connections, Weather.changed:Connect(refresh))
	table.insert(connections, Lighting:GetAttributeChangedSignal("WeatherBase"):Connect(refresh))
	table.insert(connections, Lighting:GetPropertyChangedSignal("ClockTime"):Connect(refresh))
	table.insert(
		connections,
		Lighting:GetPropertyChangedSignal("GeographicLatitude"):Connect(refresh)
	)

	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		if active[ext] == cleanup then
			active[ext] = nil
		end
		for _, c in connections do
			c:Disconnect()
		end
		for _, inst in created do
			inst:Destroy()
		end
		table.clear(created)
		for _, a in tagged do
			a:SetAttribute("ProductShelf", nil)
		end
		table.clear(tagged)
	end
	for _, m in models do
		table.insert(connections, m.Destroying:Connect(cleanup))
	end
	active[ext] = cleanup
	return cleanup
end

function ChandleryRig.check(
	ext: Model,
	int: Model?,
	props: Model?,
	stock: Model?
): { [string]: number }
	local out: { [string]: number } = {
		lights = 0,
		lit = 0,
		shadowed = 0,
		neon = 0,
		glow = 0,
		glass = 0,
		attachments = 0,
	}
	for _, m in { ext, int, props, stock } :: { Model? } do
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("Light") and d:GetAttribute(RIG_ATTR) then
					out.lights += 1
					if d.Enabled then
						out.lit += 1
					end
					if d.Shadows then
						out.shadowed += 1
					end
					local kind = d:GetAttribute(KIND_ATTR)
					if type(kind) == "string" then
						local key = "kind_" .. kind
						out[key] = (out[key] or 0) + 1
					end
				elseif d:IsA("Attachment") and d:GetAttribute(RIG_ATTR) then
					out.attachments += 1
				elseif d:IsA("BasePart") then
					if isGlow(d.Name) then
						out.glow += 1
						if d.Material == Enum.Material.Neon then
							out.neon += 1
						end
					elseif m == ext and isGlass(d.Name) and d.Material == Enum.Material.Glass then
						out.glass += 1
					end
				end
			end
		end
	end
	local preset = ChandleryRig.preset()
	local clock = Lighting.ClockTime
	for key, rule in RULES do
		out["on_" .. key] = if ruleOn(rule, preset, clock) then 1 else 0
	end
	out.clock = clock
	return out
end

return ChandleryRig
