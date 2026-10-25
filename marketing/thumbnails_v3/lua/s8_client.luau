-- (8) wide establishing shot of the harbour and town from the water, mid-afternoon sun
game.Lighting.ClockTime = 15.5
local eye = Vector3.new(250, 38, 640)
local look = Vector3.new(-30, 4, 40)
pin(function() return CFrame.lookAt(eye, look) end, 36)
pcall(function() plr:RequestStreamAroundAsync(Vector3.new(0, 0, 0)) end)
return "s8 ready"
