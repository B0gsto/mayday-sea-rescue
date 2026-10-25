local r = {}
table.insert(r, table.concat({ tostring(dev("unlockAll", me())) }, " "))
table.insert(r, tostring(select(2, dev("rank", me(), 8))))
table.insert(r, tostring(select(2, dev("opEnd", me(), true))))
return table.concat(r, " | ") .. " attrs coldopen " .. tostring(plr:GetAttribute("ColdOpenActive")) .. " done " .. tostring(plr:GetAttribute("ColdOpenDone"))
