local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UI=require(script.Parent.UIKit)
local NF=require(RS.Shared.Util.NumberFormat)
local Titles=require(RS.Shared.Config.TitleConfig)
local Tree=require(RS.Shared.Config.SkillTreeConfig)
local Catalog=require(RS.Shared.Config.SushiCatalog)
local player=Players.LocalPlayer
local P={}
local w=nil
function P.Toggle() if w then w.Toggle() end end
function P.Init()
 w=UI.Window({Name="Profile",Title="Chef Profile",Icon="☺",Size = UI.Theme.Layout.ProfileController.Size1})
 local list=UI.List(w.Body)
 local portrait=UI.Card(list,{Name="Portrait",Title="@"..player.Name,Description="",Icon="☺",Action="Change title",Order=0,OnAction=function() require(script.Parent.TitlesController).Toggle() end})
 local image=UI.new("ImageLabel",{Name="Avatar",Size = UI.Theme.Layout.ProfileController.Size2,Position=UDim2.fromOffset(12,12),BackgroundTransparency=1},portrait.Frame)
 UI.Corner(image,18)
 task.spawn(function() local ok,url=pcall(Players.GetUserThumbnailAsync,Players,player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420);if ok then image.Image=url end end)
 local count=0;for _ in pairs(Catalog.Types) do count+=1 end
 local specs={{"Cash","TotalMoney"},{"Playtime","Playtime"},{"Fish","TotalFish"},{"Rebirths","TotalRebirths"},{"Prestiges","TotalPrestiges"},{"Sushi","SushiCollected"},{"Weight","TotalKG"},{"Index","IndexCount"},{"Upgrades","TreeCount"},{"Titles","Titles"},{"Robux","RobuxSpent"}}
 local values={}
 for i,spec in ipairs(specs) do
  local row=UI.new("Frame",{Name=spec[1],Size = UI.Theme.Layout.ProfileController.Size3,BackgroundColor3=UI.Theme.Colors.Rice.Light,LayoutOrder=i},list);UI.Corner(row,12);UI.Stroke(row,3,UI.Theme.Ink,true)
  UI.Label(row,{Text="Total "..spec[1],Position=UDim2.fromOffset(12,8),Size = UI.Theme.Layout.ProfileController.Size4,TextXAlignment=Enum.TextXAlignment.Left},0)
  values[spec[2]]=UI.Label(row,{Text="",Position=UDim2.new(0.55,0,0,8),Size = UI.Theme.Layout.ProfileController.Size5,TextXAlignment=Enum.TextXAlignment.Right},0)
 end
 local function refresh()
  local title=Titles.ById[player:GetAttribute("EquippedTitle") or Titles.Default] or Titles.ById[Titles.Default];portrait.Description.Text="["..title.Name.."] • Nametag preview"
  for _,spec in ipairs(specs) do
   local key=spec[2];local n=player:GetAttribute(key) or 0
   if key=="Titles" then n=0;for _,t in ipairs(Titles.List) do local _,ok=Titles.Progress(player,t.Id);if ok then n+=1 end end end
   values[key].Text=key=="Playtime" and math.floor(n/3600).."h "..math.floor(n%3600/60).."m" or key=="TotalKG" and NF.KG(n) or NF.Format(n)
   if key=="IndexCount" then values[key].Text..="/"..count elseif key=="TreeCount" then values[key].Text..="/"..Tree.Count elseif key=="Titles" then values[key].Text..="/"..#Titles.List end
  end
 end
 table.insert(w.OnOpen,refresh);local dirty=true;player.AttributeChanged:Connect(function() dirty=true end);UI.Loop(w.Frame,function() if dirty then dirty=false;refresh() end end)
end
return P
