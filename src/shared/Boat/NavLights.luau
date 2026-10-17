--!strict
-- NavLights: switches a built vehicle's navigation lights (Builder: NavPort, NavStarboard,
-- NavMasthead, NavStern, each with a light named NavLight and a NavColor attribute).
-- Lights show from sunset to sunrise and in restricted visibility (COLREGs rule 20): here at night
-- or once the storm intensity passes STORM_INTENSITY.

local NavLights = {}

NavLights.NAMES = { "NavPort", "NavStarboard", "NavMasthead", "NavStern" }
NavLights.DUSK = 18.5 -- Lighting.ClockTime -- tune
NavLights.DAWN = 6.25 -- tune
NavLights.STORM_INTENSITY = 0.3 -- Weather.getIntensity -- tune

function NavLights.shouldBeOn(clockTime: number, stormIntensity: number): boolean
	return clockTime >= NavLights.DUSK
		or clockTime < NavLights.DAWN
		or stormIntensity >= NavLights.STORM_INTENSITY
end

function NavLights.apply(model: Model, on: boolean)
	if model:GetAttribute("NavLightsOn") == on then
		return
	end
	model:SetAttribute("NavLightsOn", on)
	for _, name in NavLights.NAMES do
		local lamp = model:FindFirstChild(name)
		if lamp and lamp:IsA("BasePart") then
			local color = lamp:GetAttribute("NavColor")
			if typeof(color) == "Color3" then
				lamp.Color = if on then color else color:Lerp(Color3.fromRGB(45, 48, 54), 0.6)
			end
			lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local light = lamp:FindFirstChild("NavLight")
			if light and light:IsA("Light") then
				light.Enabled = on
			end
		end
	end
end

return NavLights
