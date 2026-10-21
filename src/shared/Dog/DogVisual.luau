--!strict
-- DogVisual (G82): how the uploaded Bosun mesh maps onto the code rig. Bosun is the low-poly faceted
-- M_Chr_Bosun_LP (docs/14 section 4, decided 2026-10-18: no fur cards, no hero close-up): one static
-- MeshPart per Shared.Dog.BosunRig part, so DogService assembles it on the existing Motor6Ds and
-- Shared.Dog.BosunMotion animates it. The greybox rig stays the fallback when the upload fails.
--
-- Pure helpers (tests/DogVisual.spec.luau).
local DogVisual = {}

DogVisual.LEG_HEIGHT = 1.85 -- the invisible root Body sits this far above the authored ground origin
DogVisual.LP_ASSET = "M_Chr_Bosun_LP"

-- The rig part name behind an uploaded MeshPart name: "M_Chr_Bosun_LP_Torso_LOD0" -> "Torso",
-- "Torso" -> "Torso" (the downloaded uploads carry the short name, the importer the prefixed one).
function DogVisual.shortName(name: string, asset: string): string
	local short = string.gsub(name, "_LOD%d$", "")
	local prefix = asset .. "_"
	if string.sub(short, 1, #prefix) == prefix then
		return string.sub(short, #prefix + 1)
	end
	return short
end

return DogVisual
