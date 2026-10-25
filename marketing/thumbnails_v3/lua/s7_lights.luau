local a = { dev("op", me(), "CliffCasualty") }
task.wait(1)
local lc = game.ReplicatedStorage.Net:FindFirstChild("Land_Control")
lc:FireServer("LightBar", true)
lc:FireServer("Siren", true)
task.wait(1)
local car = workspace.LandVehicles:FindFirstChild(plr.Name .. "_CoastguardResponse")
return tostring(a[1]) .. " " .. tostring(a[2]) .. " lightbar " .. tostring(car:GetAttribute("LightBar"))
