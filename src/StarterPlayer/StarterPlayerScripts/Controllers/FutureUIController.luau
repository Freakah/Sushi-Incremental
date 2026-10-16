-- Complete future-feature UI previews. Demo state never calls a gameplay remote.
local UI=require(script.Parent.UIKit)
local F={}
local T=UI.Theme
local pages={}
local windows={}
local categories={"Traits","Relics","Rollables","Auras","Rings","Potions","Mounts"}
F.Categories=categories
F.Offers={
	{"VIP Bento Bundle","Crown, title and permanent perk preview","👑"},
	{"Starter Bento","A welcoming sushi-shop bundle","🍱"},
	{"Lucky Neko Bundle","Sushi luck, rune luck and roll luck","🍀"},
	{"2x Cash","Existing pass: double all Cash","$"},
	{"2x Sushi Value","Existing pass: double sushi weight","KG"},
	{"2x Neko","Future restaurant income multiplier","N"},
	{"Rune Master","Rune bulk, speed and luck","🔮"},
	{"Chef Helper Master","Minion equip, capsule bulk, luck and speed","🤖"},
	{"Mining Master","Mining damage, speed and ore multiplier","⛏"},
	{"Katana Master","Sword damage, speed and luck","🗡"},
	{"Recipe Card Master","Card luck and equip slots","▣"},
	{"Fortune Master","Enchant and expedition luck","🍀"},
	{"Prism Master","Prism yield and speed","◆"},
	{"Collectible Master","Collectible yield and opening speed","☺"},
	{"2x Rune Luck","More luck on rune rolls","🔮"},
	{"Rune Bulk +5","Additional rune rolls per opening","★"},
	{"2x Mining Speed","Faster mining preview","⛏"},
	{"Auto Mine Anywhere","Automation offer preview","🤖"},
	{"Auto Roll","Roll when the cooldown ends","↻"},
	{"2x Fish","Fishing yield preview","F"},
	{"More Rollables +5","Additional rollable slots","⚄"},
	{"Flame Rollable Skin","Cosmetic preview","♨"},
	{"2x Gold","Future resource multiplier","Au"},
	{"2x Silver","Future resource multiplier","Ag"},
	{"2x Iron","Future resource multiplier","Fe"},
	{"2x Crystals","Future resource multiplier","◆"},
	{"2x Wood","Future resource multiplier","木"},
}
F.Potions={"Rune Luck","Rune Bulk","Rune Speed","Expedition Luck","Capsule Luck","Drops Luck","Mastery XP","Aura Luck"}
local function heading(list,text,order)
	UI.Label(list,{Text=text,TextXAlignment=Enum.TextXAlignment.Left,Size = UI.Theme.Layout.FutureUIController.Size1,LayoutOrder=order},0)
end
local function demoAction(text) UI.Toast("Preview • "..text,T.Colors.Accent.Base) end
local function window(name,title)
	if windows[name] then return windows[name] end
	local w=UI.Window({Name="Preview_"..name,Title=title.." • Preview",Icon="🍣",Size = UI.Theme.Layout.FutureUIController.Size2})
	windows[name]=w
	return w
end
local function gift(title)
	F.GiftItem=title
	local w=window("Gift","Gift a Bento")
	if not pages.Gift then
		pages.Gift=true;local list=UI.List(w.Body)
		heading(list,"Choose a recipient",1)
		local box=UI.Input(list,"Player username");box.LayoutOrder=2
		UI.Card(list,{Title="Gift preview",Description="Recipient → Review → Confirm → Result",Action="Review gift",Order=3,OnAction=function()
			if box.Text:match("^%s*$") then UI.Toast("Enter a recipient first.",T.Colors.Danger.Base);return end
			UI.Confirm({Name="GiftConfirm",Title="Review gift",Text=F.GiftItem.."\nRecipient: "..box.Text.."\nPreview only — no purchase or delivery.",OnConfirm=function() demoAction("Gift result: delivered") end})
		end})
	end
	w.Open()
end
function F.OpenShop()
	local w=window("Offers","Bento Offers")
	if not pages.Offers then
		pages.Offers=true;local list=UI.List(w.Body)
		heading(list,"Future offers • prices pending configuration",1)
		for i,spec in ipairs(F.Offers) do
			local c=UI.ShopCard(list,{Name=({"VIPBundle","StarterBundle","LuckyBundle","DoubleCash","DoubleSushi","DoubleNeko"})[i] or spec[1]:gsub("%W",""),Title=spec[1],Description=spec[2],Icon=spec[3],Action="Preview",Order=i+1,OnAction=function() demoAction(spec[1]) end})
			local g=UI.Secondary(c.Frame,{Label="Gift",Position=UDim2.new(0,12,1,-58),Size = UI.Theme.Layout.FutureUIController.Size3},function() gift(spec[1]) end)
			UI.Tooltip(g.Button,"Preview a gift for another player")
			if i<=3 then UI.Ribbon(c.Frame,({"VIP","Best Value","Popular"})[i]) end
		end
	end
	w.Open()
end
function F.OpenInventory(category)
	category=category or "Traits"
	local w=window("Inventory_"..category,category)
	if not pages[category] then
		pages[category]=true;local list=UI.List(w.Body)
		heading(list,"Collection • "..category,1)
		local sort=UI.Secondary(list,{Label="Sort: rarity ↓",LayoutOrder=2,Size = UI.Theme.Layout.FutureUIController.Size4},function() demoAction("Sort switched") end)
		local search=UI.Input(list,"Search "..category:lower());search.LayoutOrder=3
		local items={}
		local equipped=nil
		for i,name in ipairs({"Rice Charm","Salmon Crest","Lucky Neko","Sakura Spirit"}) do
			local c
			c=UI.CollectionCard(list,{Title=name,Description=({"Common • Found","Rare • New discovery","Legendary • Found","Secret • Locked"})[i],Icon="🍣",Action="Equip",Order=i+3,OnAction=function()
				equipped=equipped==name and nil or name
				for _,item in ipairs(items) do item.Card.Action.SetText(equipped==item.Name and "Unequip" or "Equip");item.Card.Action.SetSelected(equipped==item.Name) end
				UI.Reward("Preview • "..(equipped and equipped.." equipped" or "Unequipped"))
			end})
			table.insert(items,{Name=name,Card=c})
			if i==2 then UI.Badge(c.Frame,"NEW") end
			if i==4 then c.Action.SetDisabled(true);c.Action.SetText("Locked");UI.Tooltip(c.Action.Button,"Unlock requirement preview") end
		end
		search:GetPropertyChangedSignal("Text"):Connect(function() for _,item in ipairs(items) do item.Card.Frame.Visible=item.Name:lower():find(search.Text:lower(),1,true)~=nil end end)
		sort.Button.Activated:Connect(function() for _,item in ipairs(items) do item.Card.Frame.LayoutOrder=20-item.Card.Frame.LayoutOrder end end)
	end
	w.Open()
end
function F.OpenPotions()
	local w=window("Boosts","Boost Pantry")
	if not pages.Boosts then
		pages.Boosts=true;local list=UI.List(w.Body);heading(list,"Demo inventory • timed boosts",1)
		for i,name in ipairs(F.Potions) do
			local count=3;local c;local expires=0
			c=UI.Card(list,{Title="2x "..name,Description="15 minutes • x3 in demo inventory",Icon="♧",Action="Use x1",Order=i+1,OnAction=function()
				if count<=0 then UI.Toast("No potions remaining.",T.Colors.Danger.Base);return end
				count-=1;expires=os.clock()+900;c.Description.Text="Active: 15:00 • x"..count.." remaining";c.Action.SetDisabled(count==0);UI.Reward("Preview • 2x "..name.." active")
			end})
			UI.Loop(c.Frame,function() local left=math.max(0,math.floor(expires-os.clock()));if left>0 then c.Description.Text="Active: "..math.floor(left/60)..":"..string.format("%02d",left%60).." • x"..count.." remaining" end end)
		end
	end
	w.Open()
end
function F.OpenCodes()
	local w=window("Codes","Lucky Coupons")
	if not pages.Codes then
		pages.Codes=true;local list=UI.List(w.Body);heading(list,"Enter a code below",1)
		local input=UI.Input(list,"Enter code");input.LayoutOrder=2
		local status=UI.Label(list,{Text="Preview: try SUSHI, EXPIRED or USED",LayoutOrder=3,Size = UI.Theme.Layout.FutureUIController.Size5},0)
		local claimed=false
		UI.Primary(list,{Label="Claim",LayoutOrder=4,Size = UI.Theme.Layout.FutureUIController.Size6},function()
			local code=input.Text:upper():gsub("%s","")
			if code=="" then status.Text="Enter a code first."
			elseif code=="EXPIRED" then status.Text="This code has expired."
			elseif code=="USED" or claimed then status.Text="Already redeemed."
			elseif code=="SUSHI" then claimed=true;status.Text="Preview reward claimed: +1,250 Cash";UI.Reward("Preview • +1,250 Cash")
			else status.Text="Code not found." end
		end)
		UI.Card(list,{Title="Community reward",Description="Preview • Inactive",Icon="☺",Action="Activate",Order=5,OnAction=function() demoAction("Community reward active") end})
	end
	w.Open()
end
function F.OpenRolls()
	local w=window("Rolls","Sushi Fortune")
	if not pages.Rolls then
		pages.Rolls=true;local list=UI.List(w.Body);heading(list,"Roll preview • luck, bulk and speed",1)
		local result=UI.Label(list,{Text="Ready to roll",LayoutOrder=2,Size = UI.Theme.Layout.FutureUIController.Size7},0)
		local row=UI.Row(list,"↻","Auto roll",3)
		local auto=false;local running=false;local lastAuto=0
		local function roll()
			if running then return end;running=true;result.Text="Rolling…"
			task.delay(0.3,function() local rare=math.random(1,5)==1;result.Text=rare and "Legendary Lucky Neko!" or "Common Rice Charm";running=false;if rare then UI.Celebrate("LUCKY NEKO!","Legendary • preview",T.Colors.Accent.Base) end end)
		end
		UI.Toggle(row,false,function(v) auto=v end)
		UI.Primary(list,{Label="Roll",LayoutOrder=4,Size = UI.Theme.Layout.FutureUIController.Size8},roll)
		local q=UI.Quantity(list,"x1",function(v) demoAction("Roll quantity "..v) end);q.Frame.LayoutOrder=5
		UI.Loop(row,function(now) if auto and w.IsOpen() and now-lastAuto>=2 then lastAuto=now;roll() end end)
	end
	w.Open()
end
function F.OpenRestaurant()
	local w=window("Restaurant","Neko Restaurant")
	if not pages.Restaurant then
		pages.Restaurant=true;local list=UI.List(w.Body)
		local balance=UI.CurrencyPill(list,"Neko",{Value=1250});balance.Frame.LayoutOrder=1
		for i,name in ipairs({"Sushi Dropper","Conveyor Speed","Golden Plate","Neko Multiplier"}) do
			local level=1;local c
			c=UI.UpgradeCard(list,{Title=name,Description="Level 1 • x1 → x2 • N 250",Action="N 250",Icon="🏮",Order=i+1,OnAction=function()
				level+=1;c.Description.Text="Demo level "..level.." • upgraded";UI.Feedback(c.Action.Button,true)
			end});c.Action.SetAffordable(true)
		end
		UI.Card(list,{Title="Buy pad",Description="Stand here to buy • N 500",Action="Buy preview",Order=6,OnAction=function() demoAction("Buy pad unlocked") end})
	end
	w.Open()
end
function F.OpenMinigame(kind)
	local w=window("Game_"..kind,kind.." Challenge")
	if not pages["Game_"..kind] then
		pages["Game_"..kind]=true;local list=UI.List(w.Body);heading(list,"Future timing challenge • demo rewards",1)
		local meter=UI.Progress(list,{Name="Timing",Color=T.Currency.Fish.Base});meter.Frame.LayoutOrder=2
		local started=os.clock();local holding=false
		UI.Loop(meter.Frame,function(now) if not holding then meter.Set((math.sin((now-started)*3)+1)/2,"Aim for the centre") end end)
		UI.Primary(list,{Label=kind=="Fishing" and "Catch!" or "Slash!",LayoutOrder=3,Size = UI.Theme.Layout.FutureUIController.Size9},function()
			holding=true;UI.Reward(kind=="Fishing" and "Preview • Golden Koi +25 Fish" or "Preview • CRIT! +50 Slices");task.delay(1,function() holding=false end)
		end)
	end
	w.Open()
end
function F.OpenEvents()
 local w=window("Events","Festival Progress")
 if not pages.Events then
  pages.Events=true;local list=UI.List(w.Body)
  heading(list,"Festival and mastery preview",1)
  local xp=UI.XPBar(list);xp.Frame.LayoutOrder=2;xp.Set(0.72,"Chef Level 12 • 720 / 1K XP")
  for i,label in ipairs({"Starter Milestone","Sushi Empire","Beyond the Rift"}) do local p=UI.Progress(list);p.Frame.LayoutOrder=i+2;p.Set(i==1 and 0.8 or 0.1,label.." • preview") end
  local limited=UI.ShopCard(list,{Title="Festival Neko Mount",Description="Limited time • Ended • Out of stock",Icon="☺",Action="Out of stock",Order=6})
  limited.Action.SetDisabled(true);UI.Ribbon(limited.Frame,"Festival")
  UI.ShopCard(list,{Title="Sakura Rollable",Description="Seasonal cosmetic • coming soon",Icon="🌸",Action="Preview",Order=7,OnAction=function() demoAction("Seasonal cosmetic") end})
 end
 w.Open()
end
function F.OpenHub()
	local w=window("Hub","Future UI Pack")
	if not pages.Hub then
		pages.Hub=true;local list=UI.List(w.Body)
		local routes={{"Bento Offers",F.OpenShop},{"Boost Pantry",F.OpenPotions},{"Codes",F.OpenCodes},{"Fortune Rolls",F.OpenRolls},{"Neko Restaurant",F.OpenRestaurant},
			{"Festival / Mastery",F.OpenEvents},{"Rune equip / altar",function() F.OpenInventory("Runes") end},{"Fishing Challenge",function() F.OpenMinigame("Fishing") end},{"Slashing Challenge",function() F.OpenMinigame("Slashing") end}}
		for _,category in ipairs(categories) do table.insert(routes,{category,function() if category=="Potions" then F.OpenPotions() else F.OpenInventory(category) end end}) end
		for i,r in ipairs(routes) do UI.Primary(list,{Label=r[1],LayoutOrder=i,Size = UI.Theme.Layout.FutureUIController.Size10},r[2]) end
	end
	w.Open()
end
function F.Init() end
return F
