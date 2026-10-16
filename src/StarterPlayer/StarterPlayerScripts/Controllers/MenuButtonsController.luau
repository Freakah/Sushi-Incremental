local Players=game:GetService("Players")
local UI=require(script.Parent.UIKit)
local M={}
function M.Init()
 local routes={
  {"Shop","🛒","ShopController"},{"Index","📖","IndexController","HasNew"},
  {"Skills","🌳","SkillTreeUIController","HasAffordable"},{"Runes","🔮","RunesMenuController","HasNew"},
  {"Titles","🏷","TitlesController","HasNew"},{"Profile","☺","ProfileController"},
  {"Areas","🏮","AreasController"},{"Settings","⚙","SettingsController"},
 }
 local gui=UI.new("ScreenGui",{Name="MenuButtons",ResetOnSpawn=false,DisplayOrder=25},Players.LocalPlayer:WaitForChild("PlayerGui"))
 local holder=UI.new("Frame",{Name="Tiles",BackgroundTransparency=1,Position=UDim2.fromOffset(12,92),Size = UI.Theme.Layout.MenuButtonsController.Size1},gui)
 local grid=UI.new("UIGridLayout",{CellSize = UI.Theme.Layout.MenuButtonsController.Size2,CellPadding=UDim2.fromOffset(12,12),FillDirectionMaxCells=2,SortOrder=Enum.SortOrder.LayoutOrder},holder)
 local expanded=false
 local toggle=UI.Primary(gui,{Name="MenuDrawer",Label="Menus",Position=UDim2.fromOffset(12,8),Size = UI.Theme.Layout.MenuButtonsController.Size3},function() expanded=not expanded;holder.Visible=expanded end)
 for i,r in ipairs(routes) do
  local tile=UI.Tile(holder,{Name=r[1],Text=r[1],Icon=r[2],Order=i},function() require(script.Parent:WaitForChild(r[3])).Toggle();if gui.AbsoluteSize.X<700 then expanded=false;holder.Visible=false end end)
  if r[4] then UI.Loop(tile.Button,function() local c=require(script.Parent:WaitForChild(r[3]));tile.Badge.Visible=c[r[4]] and c[r[4]]() or false end) end
 end
 local function layout()
  local phone=gui.AbsoluteSize.X<700
  toggle.Button.Visible=phone
  holder.Visible=not phone or expanded
  holder.Position=UDim2.fromOffset(12,phone and 62 or 92)
  grid.CellSize=UDim2.fromOffset(phone and 64 or 76,phone and 64 or 76)
  holder.Size=UDim2.fromOffset(phone and 140 or 164,phone and 300 or 360)
 end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout);layout()
end
return M
