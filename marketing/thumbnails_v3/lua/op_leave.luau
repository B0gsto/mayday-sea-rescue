local a = { dev("opEnd", me(), false) }
task.wait(2)
return tostring(a[1]) .. " " .. tostring(a[2])
