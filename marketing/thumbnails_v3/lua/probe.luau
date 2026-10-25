local out = {}
local function find(pat)
	for _, d in workspace:GetDescendants() do
		if (d:IsA("Model") or d:IsA("Folder")) and string.find(string.lower(d.Name), pat) then
			local ok, p = pcall(function() return d:GetPivot().Position end)
			local s = d:GetFullName() .. " " .. (ok and string.format("%.0f,%.0f,%.0f", p.X, p.Y, p.Z) or "")
			table.insert(out, s)
			if #out > 50 then return end
		end
	end
end
for _, pat in {"bunting", "harbourlight", "lighthouse", "sanctuary", "beacon"} do find(pat) end
for _, c in workspace:GetChildren() do table.insert(out, "WS " .. c.Name .. " " .. c.ClassName) end
local plr = game.Players:GetPlayers()[1]
table.insert(out, "player " .. tostring(plr and plr.Character and plr.Character:GetPivot().Position))
return table.concat(out, "\n")
