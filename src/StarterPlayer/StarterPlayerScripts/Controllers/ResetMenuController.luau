local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UI=require(script.Parent.UIKit)
local NF=require(RS.Shared.Util.NumberFormat)
local Prestige=require(RS.Shared.Config.PrestigeConfig)
local Rebirth=require(RS.Shared.Config.RebirthConfig)
local Ascension=require(RS.Shared.Config.AscensionConfig)
local player=Players.LocalPlayer
local R={}
local w=nil
local kind="Prestige"
local busy=false
local preview=nil
local confirm=nil
local function attr(key) return player:GetAttribute(key) or 0 end
local function info()
	if kind=="Prestige" then
		local gain=Prestige.Gain(attr("Money"),player:GetAttribute("PrestigeMultiplier") or 1)
		return "LOSE\nCash, KG and Cash upgrades\n\nKEEP\nSkills, Index and other progression\n\nGAIN\n+"..NF.Format(gain).." Prestiges\nCash head-start applies if unlocked.",gain>0
	elseif kind=="Rebirth" then
		local n=attr("TotalRebirths")
		return "LOSE\nCash, KG, Prestiges, Fish, Slices and their upgrades\n\nKEEP\nSkills, Index, runes, automation and lifetime stats\n\nGAIN\nx"..NF.Format(Rebirth.CashBoost(n+1)).." Cash\nCost: ★ "..NF.Format(Rebirth.Cost(n)),attr("Prestiges")>=Rebirth.Cost(n)
	end
	return "LOSE\nCash, KG, Cash upgrades and skill tree\n\nKEEP\nRebirths, Prestiges, runes, Index and automation\n\nGAIN\n+1 Ascension Point",Ascension.CanAscend(function(id) return player:GetAttribute("T_"..id)==true end)
end
local function refresh()
	if not w then return end
	local text,can=info();preview.Text=text
	confirm.SetDisabled(busy or not can);confirm.SetText(busy and "Please wait…" or can and "Confirm "..kind or "Requirement unmet")
	confirm.SetColors(can and UI.Gradients.Off or {UI.Theme.Colors.Disabled.Light,UI.Theme.Colors.Disabled.Base})
end
function R.Open(which)
	kind=which
	if not w then
		w=UI.Window({Name="ResetConfirm",Title="Confirm",Icon="↻",Size = UI.Theme.Layout.ResetMenuController.Size1,DisplayOrder=55})
		local scroll=UI.List(w.Body);scroll.Size=UDim2.new(1,0,1,-84)
		preview=UI.Label(scroll,{Name="Comparison",Text="",TextScaled=false,TextSize=UI.Theme.Text.Body,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,-24,0,0),TextXAlignment=Enum.TextXAlignment.Left},0)
		confirm=UI.Danger(w.Body,{Label="Confirm",Position=UDim2.new(0,12,1,-72),Size = UI.Theme.Layout.ResetMenuController.Size3},function()
			if busy then return end
			local _,can=info();if not can then return end
			busy=true;refresh()
			local selected=kind
			local ok,result=pcall(function()
				if selected=="Ascension" then require(script.Parent.AscensionController).Ascend();return true end
				return RS.Remotes:WaitForChild(selected=="Prestige" and "RequestPrestige" or "RequestRebirth"):InvokeServer()
			end)
			busy=false;refresh()
			if ok and result and result~=0 then
				w.Close()
				if selected~="Ascension" then UI.Celebrate(string.upper(selected).."!",selected=="Prestige" and "+"..NF.Format(result).." Prestiges" or "Rebirth "..NF.Format(result),UI.Theme.Colors.Accent.Base) end
			else UI.Feedback(confirm.Button,false);UI.Toast("Request was not completed. Please try again.",UI.Theme.Colors.Danger.Base) end
		end)
		UI.Secondary(w.Body,{Label="Not yet",Position=UDim2.new(0.6,6,1,-72),Size = UI.Theme.Layout.ResetMenuController.Size4},w.Close)
		UI.Loop(w.Frame,refresh)
	end
	w.Title.Text=kind.."?";refresh();w.Open()
end
function R.Init() end
return R
