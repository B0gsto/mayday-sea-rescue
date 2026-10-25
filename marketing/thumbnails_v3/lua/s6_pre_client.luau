-- (6) the quay: send the craft home to the bay (relaunch), step off it, and walk away from it
relaunch("Lifeboat")
local hum = plr.Character:FindFirstChildOfClass("Humanoid")
for _ = 1, 3 do
	if not hum.SeatPart then break end
	local weld = hum.SeatPart:FindFirstChild("SeatWeld")
	hum.Sit = false
	hum.Jump = true
	if weld then weld:Destroy() end
	task.wait(1)
end
return "on foot " .. tostring(hum.SeatPart == nil)
