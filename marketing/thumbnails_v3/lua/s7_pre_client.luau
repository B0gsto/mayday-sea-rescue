-- (7) the Coastguard Response 4x4 on Fore Street under the bunting, blue lights on a call
local hum = plr.Character:FindFirstChildOfClass("Humanoid")
if hum.SeatPart then hum.Sit = false hum:ChangeState(Enum.HumanoidStateType.Jumping) task.wait(1) end
local a = { dev("op", me(), "CliffCasualty") }
task.wait(1)
local b = { dev("vehicle", me(), "CoastguardResponse") }
task.wait(4)
return "op " .. tostring(a[1]) .. " " .. tostring(a[2]) .. " | car " .. tostring(b[1]) .. " " .. tostring(b[2])
