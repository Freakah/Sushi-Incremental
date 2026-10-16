local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local UI=require(script.Parent.UIKit)
local Zones=require(RS.Shared.Config.ZoneConfig)
local player=Players.LocalPlayer
local A={}
local window=nil
local cards={}
local function nearby(id)
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _,p in ipairs(CollectionService:GetTagged(Zones.PortalTag)) do
		if p:IsA("BasePart") and p:GetAttribute("TargetZone")==id then
			local d=root.Position-p.Position
			if Vector2.new(d.X,d.Z).Magnitude<=Zones.PortalRadius+4 and math.abs(d.Y)<8 then return true end
		end
	end
	return false
end
local function refresh()
	for id,c in pairs(cards) do
		local z=Zones.ById[id]
		local unlocked,requirement=Zones.IsUnlocked(z,function(key) return player:GetAttribute(key) end)
		local current=player:GetAttribute("Zone")==id
		c.Action.SetText(current and "Here" or unlocked and (nearby(id) and "Teleport" or "Find portal") or "Locked")
		c.Action.SetSelected(current);c.Action.SetDisabled(current or not unlocked)
		c.Action.SetColors(unlocked and UI.Gradients.On or {UI.Theme.Colors.Disabled.Light,UI.Theme.Colors.Disabled.Base})
		c.Description.Text=unlocked and (id=="Dropper" and "Rebirth 3 • Restaurant gameplay coming soon" or z.Subtitle or "Upgrades, Market and Rebirth shrine") or requirement
	end
end
function A.Toggle() if window then window.Toggle() end end
function A.Init()
	window=UI.Window({Name="Areas",Title="Sushi Islands",Icon="🏮",Size = UI.Theme.Layout.AreasController.Size1})
	local list=UI.List(window.Body)
	for i,z in ipairs(Zones.List) do
		cards[z.Id]=UI.AreaCard(list,{Name=z.Id,Title=z.Name,Icon=z.Icon,Order=i,Action="Teleport",OnAction=function()
			if not nearby(z.Id) then UI.Toast("Walk to the "..z.Name.." portal to travel.");return end
			window.Close();require(script.Parent.ZoneController).TravelTo(z.Id)
		end})
	end
	local empty=UI.Empty(list,"More sushi islands coming soon!");empty.LayoutOrder=6
	table.insert(window.OnOpen,refresh)
	UI.Loop(window.Frame,function() refresh() end)
end
return A
