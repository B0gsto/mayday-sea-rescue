-- G82 Bosun mesh visuals: upload part names map onto the code rig.
return function(t)
	local V = t.load("src/shared/Dog/DogVisual.luau")

	t.test("short names match the rig with or without the asset prefix and LOD suffix", function()
		t.expect(V.shortName("Torso", "M_Chr_Bosun_LP")).toBe("Torso")
		t.expect(V.shortName("M_Chr_Bosun_LP_Torso", "M_Chr_Bosun_LP")).toBe("Torso")
		t.expect(V.shortName("M_Chr_Bosun_LP_Torso_LOD0", "M_Chr_Bosun_LP")).toBe("Torso")
	end)
end
