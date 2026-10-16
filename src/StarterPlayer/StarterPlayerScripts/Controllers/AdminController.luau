local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UI=require(script.Parent.UIKit)
local Zones=require(RS.Shared.Config.ZoneConfig)
local player=Players.LocalPlayer
local A={}
local ADMINS={ [2643321029]=true }
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }

-- "5m", "2.5b", "1e12", "300000"
local function parseAmount(s: string): number?
	s = string.lower((string.gsub(s, "[%s,]", "")))
	local n = tonumber(s)
	if n then return n end
	local num, suf = string.match(s, "^([%d%.]+)(%a+)$")
	if num and SUFFIX[suf] and tonumber(num) then return tonumber(num) * SUFFIX[suf] end
	return nil
end

function A.Init()
 if not ADMINS[player.UserId] then return end
 local remote=RS:WaitForChild("Remotes"):WaitForChild("AdminAction")
 local w=UI.Window({Name="AdminPanel",Title="Admin Counter",Icon="⚒",Size = UI.Theme.Layout.AdminController.Size1,DisplayOrder=60})
 local list=UI.List(w.Body)
 local box=UI.Input(list,"Amount: 500k, 2.5b or 1e15");box.Text="1m";box.LayoutOrder=0
 local function amount() local n=parseAmount(box.Text);if not n then UI.Toast("Enter a valid amount.",UI.Theme.Colors.Danger.Base) end;return n end
 for i,key in ipairs({"Cash","KG","Prestiges","Fish","Slices","AP","Rebirths"}) do
  local c=UI.Card(list,{Title=key,Description=key=="Rebirths" and "Set milestone count" or "Adjust currency balance",Action=key=="Rebirths" and "Set amount" or "+ Give",Order=i,OnAction=function() local n=amount();if n then remote:FireServer("Give",key,n) end end})
  if key~="Rebirths" then UI.Danger(c.Frame,{Label="Subtract",Position=UDim2.new(0,12,1,-58),Size = UI.Theme.Layout.AdminController.Size2},function() local n=amount();if n then remote:FireServer("Give",key,-n) end end) end
 end
 for i,z in ipairs(Zones.List) do UI.Secondary(list,{Label="Teleport: "..z.Name,LayoutOrder=10+i,Size = UI.Theme.Layout.AdminController.Size3},function() remote:FireServer("Teleport",z.Id) end) end
 local gui=UI.new("ScreenGui",{Name="AdminLauncher",ResetOnSpawn=false,DisplayOrder=50},player:WaitForChild("PlayerGui"))
 UI.Secondary(gui,{Name="AdminToggle",Label="Admin",Position=UDim2.new(0,12,0,56),Size = UI.Theme.Layout.AdminController.Size4},w.Toggle)
end
return A
