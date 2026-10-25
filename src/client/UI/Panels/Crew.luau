--!strict
-- Crew panel: the four party seats, with the leader ringed, then your hired crew (WP-15: one tile
-- per role, lit when hired; hiring itself happens at your dock's station, in the world). Invite
-- opens Roblox's own invite sheet; Leave is the same remote the boat prompt uses. The server echoes
-- both changes. Hired crew: the CrewHired models in Workspace.CrewHire.<your UserId>.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrewHire = require(Shared:WaitForChild("Crew"):WaitForChild("CrewHire"))
local Glyph = require(script.Parent.Parent:WaitForChild("Glyph"))
local Net = require(Shared:WaitForChild("Net"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local Crew = {}

local function hiredRoles(): { [string]: boolean }
	local out = {}
	local root = Workspace:FindFirstChild("CrewHire")
	local mine = root and root:FindFirstChild(tostring(player.UserId))
	for _, m in if mine then mine:GetChildren() else {} do
		local role = m:GetAttribute("CrewRole")
		if m:GetAttribute("CrewHired") == true and type(role) == "string" then
			out[role] = true
		end
	end
	return out
end

local function crewName(id: number): string
	local member = Players:GetPlayerByUserId(id)
	return if member then member.DisplayName else `Player {id}`
end

function Crew.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Crew",
		icon = "crew",
		size = Vector2.new(720, 560),
		onClose = onClose,
	})
	local ids: { number } = {}
	local leader = 0
	local refresh: () -> ()

	local function paint()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local host = Instance.new("Frame")
		host.Name = "Seats"
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromScale(1, 0)
		host.AutomaticSize = Enum.AutomaticSize.Y
		host.Parent = panel.body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(140, 184)
		grid.CellPadding = UDim2.fromOffset(12, 12)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = host
		local members = if #ids > 0 then ids else { player.UserId }
		for i = 1, 4 do
			local id = members[i]
			local card = Instance.new("Frame")
			card.Name = `Seat{i}`
			card.LayoutOrder = i
			card.Size = UDim2.fromOffset(140, 184)
			card.BackgroundTransparency = 1
			card.Parent = host
			local _, face = Style.block(card, Style.grad(if id then "teal" else "disabled"))
			local art = Instance.new("ImageLabel")
			art.Name = "Face"
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0.08)
			art.Size = UDim2.fromOffset(96, 96)
			art.BackgroundColor3 = Color3.new(1, 1, 1)
			art.BackgroundTransparency = if id then 0 else 0.65
			art.Image = if id then `rbxthumb://type=AvatarHeadShot&id={id}&w=150&h=150` else ""
			Style.corner(art, 999)
			art.Parent = face
			if id and id == leader then
				Style.stroke(art, 6, true).Color = Theme.Grad.yellow.top
			else
				Style.stroke(art, 3, true)
			end
			local name = Style.label(
				face,
				if id then if id == player.UserId then "You" else crewName(id) else "Open seat",
				Theme.Text.small
			)
			name.Position = UDim2.new(0, 8, 0.62, 0)
			name.Size = UDim2.new(1, -16, 0, 30)
			name.TextWrapped = false
			local role = Style.label(
				face,
				if id == leader then "Leader" elseif id then "Crew" else "",
				Theme.Text.small
			)
			role.Position = UDim2.new(0, 8, 0.79, 0)
			role.Size = UDim2.new(1, -16, 0, 26)
			role.TextWrapped = false
		end

		-- hired crew: a lit tile per hired role, a dark one with a padlock otherwise
		local hired = hiredRoles()
		local staff = Instance.new("Frame")
		staff.Name = "Hired"
		staff.LayoutOrder = 1
		staff.BackgroundTransparency = 1
		staff.Size = UDim2.new(1, 0, 0, 150)
		staff.Parent = panel.body
		local srow = Style.list(staff, true, 14)
		srow.HorizontalAlignment = Enum.HorizontalAlignment.Center
		for i, roleId in CrewHire.Order do
			local on = hired[roleId] == true
			local tile = Instance.new("Frame")
			tile.Name = roleId
			tile.LayoutOrder = i
			tile.BackgroundTransparency = 1
			tile.Size = UDim2.fromOffset(170, 150)
			tile.Parent = staff
			local _, face = Style.block(tile, Style.grad(if on then "orange" else "locked"))
			local icon = Instance.new("Frame")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.fromScale(0.5, 0.08)
			icon.Size = UDim2.fromOffset(70, 70)
			icon.Parent = face
			if on then
				Glyph.draw(CrewHire.Roles[roleId].glyph, icon, Color3.new(1, 1, 1))
			else
				Style.icon(icon, "lock")
			end
			local name = Style.label(face, roleId, Theme.Text.small)
			name.Position = UDim2.new(0, 6, 1, -50)
			name.Size = UDim2.new(1, -12, 0, 34)
			name.TextWrapped = false
			name.TextScaled = true
		end

		local buttons = Instance.new("Frame")
		buttons.LayoutOrder = 2
		buttons.BackgroundTransparency = 1
		buttons.Size = UDim2.new(1, 0, 0, 80)
		buttons.Parent = panel.body
		local row = Style.list(buttons, true, 12)
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		local invite = Style.button(buttons, UDim2.fromOffset(280, 68))
		invite.LayoutOrder = 1
		local _, iFace = Style.block(invite, Style.grad("buy"))
		Style.label(iFace, "Invite", Theme.Text.button)
		Style.press(invite, function()
			task.spawn(function()
				local ok, can = pcall(function()
					return SocialService:CanSendGameInviteAsync(player)
				end)
				if ok and can then
					pcall(function()
						SocialService:PromptGameInvite(player)
					end)
				end
			end)
		end)
		local leave = Style.button(buttons, UDim2.fromOffset(220, 68))
		leave.LayoutOrder = 2
		leave.Visible = #ids > 0
		local _, lFace = Style.block(leave, Style.grad("close"))
		Style.label(lFace, "Leave", Theme.Text.button)
		Style.press(leave, function()
			Net.event("CrewLeave"):FireServer()
		end)
	end

	refresh = function()
		if panel.isOpen() then
			paint()
		end
	end
	Net.event("CrewJoin").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.members) == "table" then
			ids = payload.members
			leader = tonumber(payload.leader) or 0
			refresh()
		end
	end)
	Net.event("CrewLeave").OnClientEvent:Connect(function()
		ids, leader = {}, 0
		refresh()
	end)
	paint()

	return {
		open = function()
			panel.open()
			paint()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Crew
