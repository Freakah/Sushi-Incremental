-- Studio-only component and future-screen gallery. Never sends purchase requests.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local UI=require(script.Parent.UIKit)
local Future=require(script.Parent.FutureUIController)
local S={}
local w=nil
function S.Open()
	if not RunService:IsStudio() then return end
	if not w then
		w=UI.Window({Name="UIShowcase",Title="Lucky Neko • Showcase",Icon="🍣",Size = UI.Theme.Layout.UIShowcaseController.Size1})
		local list=UI.List(w.Body)
		local order=0
		local function heading(text) order+=1;UI.Label(list,{Text=text,Size = UI.Theme.Layout.UIShowcaseController.Size2,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=order},0) end
		heading("All controls • mouse, touch and controller")
		for _,variant in ipairs({"Primary","Secondary","Success","Danger","Accent","Disabled"}) do
			for _,state in ipairs({"Normal","Hover","Pressed","Disabled","Selected","Notification","Affordable"}) do
				order+=1
				local b=UI.Button(list,{Label=variant.." • "..state,Variant=variant,LayoutOrder=order,Size = UI.Theme.Layout.UIShowcaseController.Size3},function() UI.Toast("Activated "..variant.." / "..state) end)
				if state=="Disabled" then b.SetDisabled(true)
				elseif state=="Selected" then b.SetSelected(true)
				elseif state=="Notification" then b.SetNotification(12)
				elseif state=="Affordable" then b.SetAffordable(true)
				elseif state=="Hover" then b.Button.Rotation=2;b.Button.PopScale.Scale=1.06
				elseif state=="Pressed" then b.Button.PopScale.Scale=0.92;b.Button.ButtonShadow.Position=UDim2.fromOffset(0,1) end
			end
		end
		heading("Toggle • slider • quantity • icon • close • tab")
		order+=1;UI.Toggle(UI.Row(list,"◉","Reduce motion",order),UI.ReducedMotion(),function(v) require(script.Parent.SettingsState).Set("ReduceMotion",v) end)
		order+=1;UI.Slider(UI.Row(list,"♪","Preview slider",order),0.5,function() end)
		order+=1;local q=UI.Quantity(list,"x1",function(v) UI.Toast("Quantity "..v) end);q.Frame.LayoutOrder=order
		for _,name in ipairs({"IconButton","CloseButton","Tab"}) do order+=1;UI[name](list,{Label=name,LayoutOrder=order,Size = UI.Theme.Layout.UIShowcaseController.Size4},function() UI.Toast(name) end) end
		for _,state in ipairs({"Normal","Hover","Pressed","Disabled","Selected","Notification","Affordable"}) do
   order+=1;local toggle=UI.Toggle(UI.Row(list,"◉","Toggle • "..state,order),state=="Selected",function() end)
   order+=1;local slider=UI.Slider(UI.Row(list,"♪","Slider • "..state,order),0.5,function() end)
   if state=="Disabled" then toggle.SetDisabled(true);slider.SetDisabled(true)
   elseif state=="Selected" then toggle.SetSelected(true);slider.Button:SetAttribute("Selected",true)
   elseif state=="Notification" then toggle.SetNotification(2);UI.Badge(slider.Button,2)
   elseif state=="Affordable" then toggle.SetAffordable(true)
   elseif state=="Hover" or state=="Pressed" then UI.SetInteraction(toggle.Button,state);UI.SetInteraction(slider.Button,state) end
  end
  heading("Cards • all interaction and collection states")
		for _,name in ipairs({"UpgradeCard","CollectionCard","ShopCard","TitleCard","RuneCard","AreaCard"}) do
			for _,state in ipairs({"Normal","Hover","Pressed","Disabled","Locked","Selected","Notification","Affordable","NEW","MAX"}) do
				order+=1;local c=UI[name](list,{Title=name,Description=state.." • Level 2 • x2 → x3",Action="KG 250",Order=order,OnAction=function() UI.Reward("Preview • purchase success") end})
				if state=="Hover" or state=="Pressed" then UI.SetInteraction(c.Action.Button,state) elseif state=="Disabled" then c.Action.SetDisabled(true) elseif state=="Notification" then c.Action.SetNotification(8) elseif state=="Affordable" then c.Action.SetAffordable(true) elseif state=="Locked" then UI.Lock(c.Frame,"Unlocks at Rebirth 3") elseif state=="Selected" then c.Action.SetSelected(true) elseif state=="NEW" or state=="MAX" then UI.Badge(c.Frame,state) end
			end
		end
		heading("Currency counters • every configured identity")
		for _,key in ipairs({"Money","KG","Prestiges","TotalRebirths","AscensionPoints","Runes","Neko","Robux","Fish","Slices"}) do order+=1;local p=UI.CurrencyPill(list,key,{Value=1250000});p.Frame.LayoutOrder=order end
		heading("Progress • XP • Rebirth")
		for _,name in ipairs({"Progress","XPBar","RebirthBar"}) do order+=1;local b=UI[name](list);b.Frame.LayoutOrder=order;b.Set(0.62,name.." • 62%") end
		heading("Feedback and utilities")
		local actions={{"Confirm dialog",function() UI.Confirm({Title="Prestige?",Text="Lose: Cash and upgrades\nKeep: Skills and Index\nGain: +25 Prestiges",OnConfirm=function() UI.Reward("Preview • +25 Prestiges") end}) end},
			{"Reward popup",function() UI.Reward("+1,250 Cash! • Preview") end},{"Toast",function() UI.Toast("Welcome to Sushi Incremental!") end},
			{"Celebration",function() UI.Celebrate("LEVEL UP!","Lucky Neko • preview") end},{"Future screen pack",Future.OpenHub}}
		for _,a in ipairs(actions) do order+=1;UI.Primary(list,{Label=a[1],LayoutOrder=order,Size = UI.Theme.Layout.UIShowcaseController.Size5,Tooltip="Try "..a[1]},a[2]) end
		order+=1;local spin=UI.Spinner(list);spin.LayoutOrder=order
		order+=1;local empty=UI.Empty(list);empty.LayoutOrder=order
		order+=1;local box=UI.Input(list,"Code / search field");box.LayoutOrder=order
	end
	w.Open()
end
function S.Init()
	if not RunService:IsStudio() then return end
	local gui=UI.new("ScreenGui",{Name="ShowcaseLauncher",ResetOnSpawn=false,DisplayOrder=90},Players.LocalPlayer:WaitForChild("PlayerGui"))
	UI.Secondary(gui,{Name="Showcase",Label="UI Lab",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,8),Size = UI.Theme.Layout.UIShowcaseController.Size6},S.Open)
end
return S
