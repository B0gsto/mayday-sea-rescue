-- Spike 1 play-mode probe: source of a Script put in ServerScriptService (runs at normal game-script identity).
-- Tries runtime SurfaceAppearance edits and the wet-state swap, writes results as attributes on workspace.Spike1.
local f = workspace:WaitForChild("Spike1")
task.wait(2)
local function rec(k, ok, e)
	f:SetAttribute(k, if ok then "ok" else tostring(e))
end
local p1 = f:WaitForChild("Plane1024"):FindFirstChildWhichIsA("MeshPart", true)
local sa = p1:FindFirstChildOfClass("SurfaceAppearance")
rec("rt_ColorMap", pcall(function() (sa :: any).ColorMap = "rbxassetid://113981166754593" end))
rec("rt_ColorMapContent", pcall(function() (sa :: any).ColorMapContent = Content.fromAssetId(113981166754593) end))
rec("rt_NormalMap", pcall(function() (sa :: any).NormalMap = "rbxassetid://76902494683852" end))
rec("rt_Color", pcall(function() (sa :: any).Color = Color3.new(1, 0.9, 0.9) end))
rec("rt_AlphaMode", pcall(function() sa.AlphaMode = Enum.AlphaMode.Transparency end))
rec("rt_NewSAColorMap", pcall(function()
	local n = Instance.new("SurfaceAppearance");
	(n :: any).ColorMap = "rbxassetid://133497070455294"
end))
rec("rt_ReadColorMap", pcall(function() return (sa :: any).ColorMap end))
-- wet-state method: swap the SurfaceAppearance child for a stored one
local p2 = f:WaitForChild("Plane2048"):FindFirstChildWhichIsA("MeshPart", true)
rec("rt_Swap", pcall(function()
	local old = p2:FindFirstChildOfClass("SurfaceAppearance")
	old.Parent = game:GetService("ServerStorage")
	local c = game:GetService("ServerStorage"):WaitForChild("Spike1Alt"):Clone()
	c.Name = "Swapped"
	c.Parent = p2
end))
rec("rt_SwapColorTint", pcall(function() (p2:FindFirstChild("Swapped") :: any).Color = Color3.new(1, 0.15, 0.15) end))
f:SetAttribute("rt_done", true)
