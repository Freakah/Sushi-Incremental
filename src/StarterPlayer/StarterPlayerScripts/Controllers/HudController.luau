-- Attribute-driven HUD; public GetBar/ShowGain/ShowCombo kept for existing effects.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UI=require(script.Parent.UIKit)
local NF=require(RS.Shared.Util.NumberFormat)
local PrestigeConfig=require(RS.Shared.Config.PrestigeConfig)
local player=Players.LocalPlayer
local H={}
local bars={}
local combo=nil
local comboToken=0
function H.GetBar(attribute) return bars[attribute] and bars[attribute].Frame end
function H.ShowGain(attribute,delta)
 local p=bars[attribute];if not p then return end
 p.Gain.Text="+"..NF.Format(delta);p.Gain.Visible=true;p.Token=(p.Token or 0)+1;local ticket=p.Token
 task.delay(0.8,function() if ticket==p.Token then p.Gain.Visible=false end end)
end
function H.ShowCombo(count)
 if not combo or count<3 then return end
 comboToken+=1;local ticket=comboToken
 combo.Text="x"..count..(count>=50 and " INSANE!" or count>=25 and " AMAZING!" or count>=10 and " GREAT!" or " COMBO")
 combo.Visible=true;task.delay(1,function() if ticket==comboToken then combo.Visible=false end end)
end
function H.Init()
 local gui=UI.new("ScreenGui",{Name="HUD",ResetOnSpawn=false,DisplayOrder=4},player:WaitForChild("PlayerGui"))
 local holder=UI.new("Frame",{Name="Bars",BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,68),Size = UI.Theme.Layout.HudController.Size1},gui)
 local list=UI.new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Right},holder)
 for i,attribute in ipairs({"KG","Money","Prestiges","Fish","Slices","TotalRebirths","AscensionPoints"}) do
  local p=UI.CurrencyPill(holder,attribute,{Format=attribute=="KG" and NF.KG or attribute=="Money" and NF.Cash or NF.Format});p.Frame.LayoutOrder=i
  p.Gain=UI.Label(p.Frame,{Name="Gain",Text="",Visible=false,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(0,-8,0.5,0),Size = UI.Theme.Layout.HudController.Size2,TextColor3=UI.Theme.Colors.Success.Dark},0)
  bars[attribute]=p
  local last=player:GetAttribute(attribute) or 0
  player:GetAttributeChangedSignal(attribute):Connect(function() local n=player:GetAttribute(attribute) or 0;if n>last then H.ShowGain(attribute,n-last) end;last=n end)
 end
 combo=UI.Label(holder,{Name="Combo",Text="",Visible=false,Size = UI.Theme.Layout.HudController.Size3,LayoutOrder=20},0)
 local function layout()
  local phone=gui.AbsoluteSize.X<700
  local zone=player:GetAttribute("Zone") or "Starter"
  local show={Money=true}
  if zone=="Fishing" then show.Fish=true elseif zone=="Slashing" then show.Slices=true else show.KG=true end
  show.Prestiges=(player:GetAttribute("TotalPrestiges") or 0)>0 or (player:GetAttribute("TotalMoney") or 0)>=PrestigeConfig.MinCash/2
  show.TotalRebirths=(player:GetAttribute("TotalRebirths") or 0)>0
  show.AscensionPoints=zone=="Ascension" or (player:GetAttribute("Ascensions") or 0)>0
  holder.Size=UDim2.fromOffset(phone and 142 or 220,380)
  holder.Position=UDim2.new(1,-12,0,96)
  list.Padding=UDim.new(0,phone and 6 or 8)
  for key,p in pairs(bars) do p.Frame.Visible=show[key]==true;p.Frame.Size=UDim2.fromOffset(phone and 142 or 220,phone and 48 or 52);p.Gain.Visible=p.Gain.Visible and not phone end
  combo.Size=UDim2.fromOffset(phone and 142 or 220,32)
 end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
 for _,key in ipairs({"Zone","TotalMoney","TotalPrestiges","TotalRebirths","Ascensions"}) do player:GetAttributeChangedSignal(key):Connect(layout) end
 layout()
 local boosts=UI.new("Frame",{Name="ActiveBoosts",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,8),Size = UI.Theme.Layout.HudController.Size4},gui)
 local boostText=UI.Label(boosts,{Text="",Size=UDim2.fromScale(1,1)},0)
 UI.Loop(boosts,function()
  local now=workspace:GetServerTimeNow();local texts={}
  for _,key in ipairs({"Cash","Luck"}) do local left=(player:GetAttribute("BoostEnd_"..key) or 0)-now;if left>0 then table.insert(texts,"2x "..key.." "..math.floor(left/60)..":"..string.format("%02d",math.floor(left%60))) end end
  boostText.Text=table.concat(texts," • ")
 end)
end
return H
