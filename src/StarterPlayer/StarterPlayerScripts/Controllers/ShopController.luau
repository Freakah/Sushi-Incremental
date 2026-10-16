local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Marketplace=game:GetService("MarketplaceService")
local Config=require(RS.Shared.Config.ShopConfig)
local UI=require(script.Parent.UIKit)
local player=Players.LocalPlayer
local S={}
local window=nil
local cards={}
local prices={}
local selected="Passes"
local pages={}
local tabs={}
local function refresh()
 local now=workspace:GetServerTimeNow()
 for _,c in ipairs(cards) do
  local item=c.Item;local owned=c.Pass and player:GetAttribute(Config.PassAttr(item.Key))==true
  c.Action.SetDisabled(owned or item.Id==0)
  c.Action.SetText(owned and "Owned" or item.Id==0 and "Coming soon" or "R$ "..(prices[item.Id] or item.Price))
  c.Action.SetColors(owned and UI.Gradients.Gold or item.Id==0 and {UI.Theme.Colors.Disabled.Light,UI.Theme.Colors.Disabled.Base} or UI.Gradients.On)
  local boost=item.Grant and item.Grant.Boost
  local left=boost and math.max(0,(player:GetAttribute(Config.BoostAttr(boost[1])) or 0)-now) or 0
  c.Description.Text=item.Desc..(left>0 and " • "..math.floor(left/60)..":"..string.format("%02d",math.floor(left%60)).." active" or "")
 end
 for id,page in pairs(pages) do page.Visible=id==selected;tabs[id].SetSelected(id==selected) end
end
function S.Toggle() if window then window.Toggle() end end
function S.Init()
 window=UI.Window({Name="Shop",Title="Sushi Shop",Icon="🛒",Size = UI.Theme.Layout.ShopController.Size1})
 local nav=UI.new("Frame",{Name="Tabs",BackgroundTransparency=1,Position=UDim2.fromOffset(8,8),Size = UI.Theme.Layout.ShopController.Size2},window.Body)
 UI.new("UIGridLayout",{CellSize = UI.Theme.Layout.ShopController.Size3,CellPadding=UDim2.fromOffset(8,8),FillDirectionMaxCells=3},nav)
 for i,id in ipairs({"Upgrades","Passes","Products"}) do
  tabs[id]=UI.Tab(nav,{Label=id,LayoutOrder=i},function() selected=id;refresh() end)
  local page=UI.new("Frame",{Name=id,BackgroundTransparency=1,Position=UDim2.fromOffset(0,68),Size = UI.Theme.Layout.ShopController.Size4,Visible=false},window.Body);pages[id]=page
 end
 local upgrades=UI.List(pages.Upgrades)
 UI.Card(upgrades,{Title="Upgrade Boards",Description="Cash, Prestige, Fish, Slices, AP and Automation",Action="Open boards",Order=1,OnAction=function() window.Close();require(script.Parent.BoardMenuController).Open() end})
 UI.Card(upgrades,{Title="Future UI Pack",Description="Bento bundles, gifting, boosts, codes and collections",Action="Preview pack",Order=2,OnAction=function() require(script.Parent.FutureUIController).OpenHub() end})
 for _,kind in ipairs({"Passes","Products"}) do
  local list=UI.List(pages[kind]);local pass=kind=="Passes"
  for i,item in ipairs(Config[kind]) do
   local c
   c=UI.ShopCard(list,{Name=item.Key,Title=item.Name,Description=item.Desc,Icon=item.Icon,Action="Coming soon",Order=i,OnAction=function()
    if item.Id==0 or (pass and player:GetAttribute(Config.PassAttr(item.Key))) then return end
    if pass then Marketplace:PromptGamePassPurchase(player,item.Id) else Marketplace:PromptProductPurchase(player,item.Id) end
   end});c.Item=item;c.Pass=pass;table.insert(cards,c)
   task.spawn(function() if item.Id==0 then return end;local ok,info=pcall(Marketplace.GetProductInfo,Marketplace,item.Id,pass and Enum.InfoType.GamePass or Enum.InfoType.Product);if ok and info.PriceInRobux then prices[item.Id]=info.PriceInRobux;refresh() end end)
  end
 end
 table.insert(window.OnOpen,refresh);UI.Loop(window.Frame,refresh)
 task.spawn(function() local event=RS:WaitForChild("Remotes"):WaitForChild("ShopGranted",30);if not event then return end;event.OnClientEvent:Connect(function(key) local item=Config.PassByKey[key] or Config.ProductByKey[key];if item then UI.Celebrate("THANK YOU!",item.Name,UI.Theme.Currency.Robux.Base);refresh() end end) end)
 refresh()
end
return S
