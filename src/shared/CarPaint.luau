--!strict
-- CarPaint (docs/22): colour variety for the M_Road_ParkedCar_01..03 meshes without new albedos.
-- SurfaceAppearance.Color multiplies the body's ColorMap: _01 (pale blue) and _03 (white van) take any paint,
-- _02's paint is baked red, so it only darkens (red, maroon).
-- shortcut: a tint over the baked albedo, until the WP-4 albedo variants (white, navy, silver, teal, cream) land.
local CarPaint = {}

CarPaint.LIGHT = {
	Color3.fromRGB(255, 255, 255), -- as baked
	Color3.fromRGB(62, 80, 138), -- navy
	Color3.fromRGB(176, 178, 182), -- silver
	Color3.fromRGB(86, 168, 158), -- teal
	Color3.fromRGB(255, 236, 196), -- cream
	Color3.fromRGB(70, 104, 76), -- bottle green
	Color3.fromRGB(64, 64, 70), -- charcoal
}
CarPaint.RED = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 120, 120) }

function CarPaint.pick(asset: string, seed: number): Color3
	local list = if string.find(asset, "_02", 1, true) then CarPaint.RED else CarPaint.LIGHT
	return list[math.abs(math.floor(seed)) % #list + 1]
end

-- Tints the body panels of a parked-car model (the Body mesh's SurfaceAppearance).
function CarPaint.apply(model: Instance, asset: string, seed: number)
	local paint = CarPaint.pick(asset, seed)
	for _, d in model:GetDescendants() do
		if
			d:IsA("SurfaceAppearance")
			and d.Parent
			and string.find(d.Parent.Name, "_Body_", 1, true)
		then
			d.Color = paint
		end
	end
end

return CarPaint
