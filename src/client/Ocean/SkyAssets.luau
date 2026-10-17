--!strict
-- SkyAssets: uploaded Roblox image ids for the five weather skyboxes (art direction doc 05, section 6.2).
-- Generated procedurally by art/ocean/bake_skies.py (pure numpy, no photographs or third-party imagery, so no
-- third-party licence applies). Sources: assets/ocean/sky/<Preset>_<Face>.png, 1024x1024. Faces follow the Roblox
-- Sky convention documented in the script header (Ft looks -Z, Lf looks +X, Up top edge borders Lf).
-- No sun or moon disc is baked in; Roblox draws those.

export type SkyFaces = { Bk: string, Dn: string, Ft: string, Lf: string, Rt: string, Up: string }

local SkyAssets: { [string]: SkyFaces } = table.freeze({
	Clear = table.freeze({
		Bk = "rbxassetid://80342858122314",
		Dn = "rbxassetid://88889272739087",
		Ft = "rbxassetid://71997081960782",
		Lf = "rbxassetid://116268322822329",
		Rt = "rbxassetid://134673607013939",
		Up = "rbxassetid://99172177613919",
	}),
	Calm = table.freeze({
		Bk = "rbxassetid://100291769636759",
		Dn = "rbxassetid://115175404339979",
		Ft = "rbxassetid://131411609174500",
		Lf = "rbxassetid://90529622685444",
		Rt = "rbxassetid://135987725675158",
		Up = "rbxassetid://85711236115085",
	}),
	Overcast = table.freeze({
		Bk = "rbxassetid://123349681431061",
		Dn = "rbxassetid://88973431308289",
		Ft = "rbxassetid://90084106530161",
		Lf = "rbxassetid://104787622096528",
		Rt = "rbxassetid://91203490210863",
		Up = "rbxassetid://123293123366570",
	}),
	Storm = table.freeze({
		Bk = "rbxassetid://112308644811840",
		Dn = "rbxassetid://114439439243334",
		Ft = "rbxassetid://81112023800180",
		Lf = "rbxassetid://93516722756696",
		Rt = "rbxassetid://95191368988574",
		Up = "rbxassetid://134222112821358",
	}),
	Night = table.freeze({
		Bk = "rbxassetid://73184372276070",
		Dn = "rbxassetid://108887836477278",
		Ft = "rbxassetid://78150281042462",
		Lf = "rbxassetid://129849147616705",
		Rt = "rbxassetid://128128601276557",
		Up = "rbxassetid://127578886417365",
	}),
})

return SkyAssets
