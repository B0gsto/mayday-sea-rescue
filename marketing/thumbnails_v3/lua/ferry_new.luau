print(dev("opEnd", me(), false))
task.wait(2)
local a = { dev("op", me(), "CapsizedFerry") }
task.wait(3)
return tostring(a[1]) .. " " .. tostring(a[2])
