-- Accessible screen companion for every purchase board. Uses existing remotes only.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UI=require(script.Parent.UIKit)
local NF=require(RS.Shared.Util.NumberFormat)
local player=Players.LocalPlayer
local B={}
local window=nil
local selected="Cash"
local views={}
local function config(name) return require(RS.Shared.Config[name.."Config"]) end
local kinds={
	Cash={Config=config("Upgrade"),Currency="Money",Remote="RequestUpgrade"},
	Prestige={Config=config("Prestige"),Currency="Prestiges",Remote="RequestPrestigeUpgrade"},
	Fish={Config=config("Fish").Upgrades,Currency="Fish",Remote="RequestFishUpgrade"},
	Slices={Config=config("Slice").Upgrades,Currency="Slices",Remote="RequestSliceUpgrade"},
	Ascension={Config=config("Ascension"),Currency="AscensionPoints",Remote="RequestAscensionUpgrade"},
}
local auto=config("Automation")
local function build()
	window=UI.Window({Name="BoardMenu",Title="Upgrade Counter",Icon="🍣",Size = UI.Theme.Layout.BoardMenuController.Size1})
	local nav=UI.new("Frame",{BackgroundTransparency=1,Size = UI.Theme.Layout.BoardMenuController.Size2,Position=UDim2.fromOffset(8,8)},window.Body)
	UI.new("UIGridLayout",{CellSize = UI.Theme.Layout.BoardMenuController.Size3,CellPadding=UDim2.fromOffset(8,8),FillDirectionMaxCells=3},nav)
	local tabs={}
	local area=UI.new("Frame",{BackgroundTransparency=1,Size = UI.Theme.Layout.BoardMenuController.Size4,Position=UDim2.fromOffset(0,124)},window.Body)
	for i,name in ipairs({"Cash","Prestige","Fish","Slices","Ascension","Automation"}) do
		tabs[name]=UI.Tab(nav,{Label=name,LayoutOrder=i},function() selected=name;B.Refresh() end)
		local list=UI.List(area);list.Name=name;views[name]={List=list,Cards={}}
		if kinds[name] then
			local k=kinds[name];local defs=k.Config.List or k.Config.Upgrades
			local pill=UI.CurrencyPill(list,k.Currency);pill.Frame.LayoutOrder=0
			if name=="Prestige" or name=="Ascension" then
				UI.Card(list,{Title=name,Description=name=="Ascension" and "Visit the Blood Altar to Ascend" or "Trade Cash for Prestiges",Action=name=="Ascension" and "Altar info" or "Prestige",Order=1,OnAction=function()
					if name=="Ascension" then UI.Toast("Walk onto the Blood Altar in the Blood Rift.") else require(script.Parent.ResetMenuController).Open("Prestige") end
				end})
			end
			for n,def in ipairs(defs) do
				local function buy(max)
					local lvl=player:GetAttribute(k.Config.AttributeName(def.Id)) or 1
					local cost=k.Config.GetCost(def.Id,lvl)
					if not cost then
						if def.Toggle then RS.Remotes.SetSetting:FireServer(def.Toggle,player:GetAttribute("Set_"..def.Toggle)==false) end
						return
					end
					if (player:GetAttribute(k.Currency) or 0)<cost then UI.Toast("Not enough "..UI.Theme.Currency[k.Currency].Name,UI.Theme.Colors.Danger.Base);return end
					RS.Remotes[k.Remote]:FireServer(def.Id,max)
				end
				local c=UI.UpgradeCard(list,{Title=def.Name,Icon=def.Icon,Order=n+2,Action="Buy",OnAction=function() buy(false) end})
				local max=UI.Secondary(c.Frame,{Label="MAX",Position=UDim2.new(0,12,1,-58),Size = UI.Theme.Layout.BoardMenuController.Size5},function() buy(true) end)
				c.Def=def;c.Max=max;table.insert(views[name].Cards,c)
			end
		else
			for n,def in ipairs(auto.List) do
				local c=UI.Card(list,{Title=def.Name,Icon=def.Icon,Description=def.Description,Order=n,Action="Buy",OnAction=function()
					if player:GetAttribute(auto.OwnedAttr(def.Id)) then RS.Remotes.ToggleAutomation:FireServer(def.Id,player:GetAttribute(auto.OnAttr(def.Id))~=true)
					else local ok,result=pcall(function() return RS.Remotes.BuyAutomation:InvokeServer(def.Id) end);if not ok or not result then UI.Toast("Automation purchase unavailable.",UI.Theme.Colors.Danger.Base) end end
				end});c.Def=def;table.insert(views[name].Cards,c)
			end
		end
	end
	function B.Refresh()
		for name,v in pairs(views) do
			v.List.Visible=name==selected;tabs[name].SetSelected(name==selected)
			for _,c in ipairs(v.Cards) do
				local def=c.Def;local k=kinds[name]
				if k then
					local lvl=player:GetAttribute(k.Config.AttributeName(def.Id)) or 1;local cost=k.Config.GetCost(def.Id,lvl)
					local unlocked=not def.RequiredRebirths or (player:GetAttribute("TotalRebirths") or 0)>=def.RequiredRebirths
					local currency=UI.Theme.Currency[k.Currency]
					c.Description.Text=not unlocked and "Unlocks at Rebirth "..def.RequiredRebirths or "Level "..(lvl-1).." • "..def.Format(k.Config.GetValue(def.Id,lvl))..(cost and " → "..def.Format(k.Config.GetValue(def.Id,lvl+1)) or " • MAX")
					c.Action.SetText(not unlocked and "Locked" or cost and currency.Icon.." "..NF.Format(cost) or def.Toggle and (player:GetAttribute("Set_"..def.Toggle)~=false and "ON" or "OFF") or "MAX")
					c.Action.SetDisabled(not unlocked or (not cost and not def.Toggle));c.Max.SetDisabled(not unlocked or not cost)
					c.Action.SetAffordable(unlocked and cost~=nil and (player:GetAttribute(k.Currency) or 0)>=cost)
				else
					local unlocked=auto.IsUnlocked(def.Id,player:GetAttribute("TotalRebirths"));local owned=player:GetAttribute(auto.OwnedAttr(def.Id))==true
					c.Description.Text=unlocked and def.Description or "Unlocks at Rebirth "..auto.RequiredRebirths(def.Id)
					c.Action.SetText(owned and (player:GetAttribute(auto.OnAttr(def.Id)) and "ON" or "OFF") or "★ "..NF.Format(def.Cost));c.Action.SetDisabled(not unlocked)
				end
			end
		end
	end
	table.insert(window.OnOpen,B.Refresh)
	local dirty=true;player.AttributeChanged:Connect(function() dirty=true end)
	UI.Loop(window.Frame,function() if dirty then dirty=false;B.Refresh() end end)
end
function B.Open() if not window then build() end;window.Open() end
function B.Init() end
return B
