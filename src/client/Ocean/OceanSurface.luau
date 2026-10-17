--!strict
-- OceanSurface: the photoreal water material for every ocean MeshPart (ocean spike, round 1).
--
-- SurfaceAppearance templates are authored as Rojo model files next to this module (texture
-- properties are not script-writable at runtime, so the client clones them):
--   SurfaceCalm   tiling FFT chop normal map, roughness ~0.07, Overlay colour map ~transparent
--   SurfaceStorm  same normal map, roughness ~0.24, Overlay colour map with faint foam streaks
--   SurfaceFoam   white foam with alpha (AlphaMode Transparency) for the crest foam overlay mesh
-- In Overlay mode the MeshPart's Color shows wherever the colour map is transparent, so the water
-- tint is just part.Color (script-writable, set per preset by OceanController).
-- Textures are baked by art/ocean/bake_ocean_textures.py (Blender headless, exactly periodic),
-- sources in assets/ocean/, uploaded with tools/assets.py (manifest: assets/manifest.json):
--   normal 100074060791737, overlay calm 78801810128121, overlay storm 128698395814673,
--   foam 107434961132990, roughness calm 112645743621029, roughness storm 73380362915176.
-- If a template is missing, parts fall back to SmoothPlastic with a little Reflectance.

local OceanSurface = {}

-- Studs covered by one normal-map tile. Snap steps (16/18/20) need not divide it: UVs are
-- recomputed from the world position on every snap. -- tune
OceanSurface.TILE_STUDS = 64

local SA_NAME = "OceanSurface"

function OceanSurface.attach(part: BasePart, kind: string)
	local old = part:FindFirstChild(SA_NAME)
	if old and old:GetAttribute("Kind") == kind then
		return
	end
	local template = script.Parent:FindFirstChild("Surface" .. kind)
	if template and template:IsA("SurfaceAppearance") then
		local sa = template:Clone()
		sa.Name = SA_NAME
		sa:SetAttribute("Kind", kind)
		sa.Parent = part
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.08 -- tune
	end
	if old then
		old:Destroy()
	end
end

return OceanSurface
