-- Displays actual game state/results. Future timing challenges live in the preview pack.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UI=require(script.Parent.UIKit)
local NF=require(RS.Shared.Util.NumberFormat)
local player=Players.LocalPlayer
local M={}
function M.Init()
	local gui=UI.new("ScreenGui",{Name="MinigameHUD",ResetOnSpawn=false,DisplayOrder=6},player:WaitForChild("PlayerGui"))
	local strip=UI.new("Frame",{Name="Status",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-20),Size = UI.Theme.Layout.MinigameHUDController.Size1,BackgroundColor3=UI.Theme.Colors.Rice.Light},gui)
	UI.new("UISizeConstraint",{MaxSize = UI.Theme.Layout.MinigameHUDController.Size2},strip);UI.Corner(strip,18);UI.Stroke(strip,3,UI.Theme.Ink,true)
	local label=UI.Label(strip,{Text="",Position=UDim2.fromOffset(12,8),Size = UI.Theme.Layout.MinigameHUDController.Size3},0)
	local function refresh()
		strip.Size=UDim2.new(gui.AbsoluteSize.X<700 and 0.55 or 0.7,0,0,64)
		local zone=player:GetAttribute("Zone")
		strip.Visible=zone=="Fishing" or zone=="Slashing"
		label.Text=zone=="Fishing" and "Sushi Pond • stand on the pad to fish" or "Hold click / touch / R2 to slash"
	end
	player:GetAttributeChangedSignal("Zone"):Connect(refresh);gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh);refresh()
	local lastFish=0
	task.spawn(function()
		RS.Remotes:WaitForChild("FishCaught").OnClientEvent:Connect(function(amount,golden)
			if player:GetAttribute("Zone")~="Fishing" then return end
			label.Text=(golden and "GOLDEN CATCH! +" or "Caught +")..NF.Format(amount).." Fish"
			lastFish+=1;local ticket=lastFish;task.delay(1,function() if ticket==lastFish then refresh() end end)
			if golden then UI.Reward("Golden catch • +"..NF.Format(amount).." Fish") end
		end)
		RS.Remotes:WaitForChild("SlashFx").OnClientEvent:Connect(function(kind,who,amount,critical)
			if kind~="hit" or who~=player then return end
			label.Text=(critical and "CRIT! +" or "+")..NF.Format(amount).." Slices"
		end)
	end)
end
return M
