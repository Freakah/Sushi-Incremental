-- Lucky Neko Sushi Shop: client-only theme, controls, motion and feedback.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Lighting=game:GetService("Lighting")
local RS=game:GetService("ReplicatedStorage")
local MenuManager=require(script.Parent.MenuManager)
local Settings=require(script.Parent.SettingsState)
local NF=require(RS.Shared.Util.NumberFormat)
local player=Players.LocalPlayer
local UI={}
local C=Color3.fromRGB
local function swatch(base,light,dark,outline) return {Base=base,Light=light,Dark=dark,Outline=outline} end
UI.Theme={
	Colors={
		Primary=swatch(C(245,104,66),C(255,140,99),C(174,61,40),C(80,39,30)),
		Secondary=swatch(C(32,85,64),C(52,117,90),C(18,56,43),C(20,38,29)),
		Accent=swatch(C(255,200,61),C(255,222,112),C(183,124,25),C(89,60,22)),
		Success=swatch(C(105,203,57),C(139,228,91),C(59,132,36),C(36,70,25)),
		Wood=swatch(C(128,80,51),C(163,108,67),C(83,51,34),C(48,34,27)),
		Rice=swatch(C(255,240,206),C(255,248,230),C(219,196,156),C(32,45,38)),
		Danger=swatch(C(229,65,70),C(250,104,106),C(167,38,49),C(87,31,39)),
		Disabled=swatch(C(133,139,144),C(163,169,173),C(93,100,106),C(52,60,66)),
	},
	Ink=C(32,45,38),White=C(255,255,255),Muted=C(92,91,72),
	Spacing={XS=4,S=8,M=12,L=16,XL=24},Radius={Small=8,Medium=12,Card=18,Window=24},
	Stroke={Control=3,Panel=4,Text=2},Shadow=5,Text={Title=36,Header=26,Body=20,Caption=16},
	Size={Tap=44,Action=56,Tile=76,Header=72,Row=80},
	Motion={Hover=0.12,Press=0.06,Release=0.2,Open=0.25,Close=0.15,Feedback=0.25},
	Sounds={Hover="UIHover",Click="UIClick",Open="RareSpawn",Close="UIClick",Success="Upgrade",Error="UIClick"},
	Currency={},Rarity={},RuneRarity={},Icons={},Layout={},
}
local T=UI.Theme
-- Compatibility adapter also governs legacy controller tweens during migration.
UI.TweenService={Create=function(_,obj,info,props)
 local gui=obj:IsA("GuiObject") or obj:IsA("UIStroke") or obj:IsA("UIGradient") or obj:IsA("UIScale")
 if gui then
  local reduced=Settings.Get("ReduceMotion")==true
  info=TweenInfo.new(reduced and math.min(info.Time,0.1) or math.min(info.Time,0.35),info.EasingStyle,info.EasingDirection,reduced and 0 or info.RepeatCount,info.Reverses,info.DelayTime)
 end
 return TweenService:Create(obj,info,props)
end}
for key,s in pairs({Money={C(49,184,92),"$","Cash"},KG={C(242,138,50),"KG","Sushi KG"},
	Prestiges={C(137,104,232),"★","Prestiges"},TotalRebirths={C(32,182,210),"↻","Rebirths"},
	AscensionPoints={C(185,29,57),"AP","Ascension"},Runes={C(167,71,229),"R","Runes"},
	Neko={C(244,189,39),"N","Neko"},Robux={C(37,201,173),"R$","Robux"},
	Fish={C(52,153,235),"F","Fish"},Slices={C(233,83,157),"S","Slices"}}) do
	local spec=swatch(s[1],s[1]:Lerp(T.White,0.22),s[1]:Lerp(T.Ink,0.35),T.Ink)
	spec.Icon,spec.Name=s[2],s[3];T.Currency[key]=spec
end
T.Currency.Cash=T.Currency.Money;T.Currency.Rebirth=T.Currency.TotalRebirths;T.Currency.Ascension=T.Currency.AscensionPoints
for _,r in ipairs(require(RS.Shared.Config.RarityConfig).List) do T.Rarity[r.Id]=r end
for id,r in pairs(require(RS.Shared.Config.RuneConfig).Rarities) do T.RuneRarity[id]=r end
UI.Font=Enum.Font.FredokaOne
UI.Colors={Panel=T.Colors.Rice.Base,Inner=T.Colors.Rice.Dark,Row=T.Colors.Rice.Light,Outline=T.Ink,Title=T.Colors.Primary.Base,Text=T.Ink,Subtle=T.Muted}
UI.Gradients={On={T.Colors.Success.Light,T.Colors.Success.Base},Off={T.Colors.Danger.Light,T.Colors.Danger.Base},
	Dark={T.Colors.Secondary.Light,T.Colors.Secondary.Base},Blue={T.Currency.Fish.Light,T.Currency.Fish.Base},Gold={T.Colors.Accent.Light,T.Colors.Accent.Base}}
function UI.new(class,props,parent)
	local obj=Instance.new(class)
	if obj:IsA("GuiObject") then obj.BorderSizePixel=0 end
	for k,v in pairs(props or {}) do obj[k]=v end
	if parent then obj.Parent=parent end
	return obj
end
local new=UI.new
function UI.Corner(obj,r)
	local c=obj:FindFirstChildOfClass("UICorner") or new("UICorner",{},obj);c.CornerRadius=UDim.new(0,r or T.Radius.Medium);return c
end
function UI.Stroke(obj,width,color,border)
	return new("UIStroke",{Thickness=width or T.Stroke.Control,Color=color or T.Ink,LineJoinMode=Enum.LineJoinMode.Round,
		ApplyStrokeMode=border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual},obj)
end
function UI.Icon(parent,key,placeholder,props)
 props=table.clone(props or {})
 local asset=T.Icons[key]
 if asset and asset~="" then props.Image=asset;props.BackgroundTransparency=1;props.ScaleType=Enum.ScaleType.Fit;return new("ImageLabel",props,parent) end
 props.Text=placeholder or key;return UI.Label(parent,props,0)
end
function UI.Label(parent,props,width)
	local l=new("TextLabel",{BackgroundTransparency=1,Font=UI.Font,TextScaled=true,TextWrapped=true,RichText=true,TextColor3=T.Ink},parent)
	for k,v in pairs(props or {}) do l[k]=v end
	new("UITextSizeConstraint",{MaxTextSize=T.Text.Title},l)
	if (width or 0)>0 then UI.Stroke(l,width,l.TextColor3==T.Ink and T.Colors.Rice.Light or T.Ink) end
	return l
end
function UI.Gradient(obj,colors)
	local g=obj:FindFirstChildOfClass("UIGradient") or new("UIGradient",{},obj)
	g.Rotation=90;g.Color=ColorSequence.new(colors[1],colors[2]);return g
end
function UI.ReducedMotion() return Settings.Get("ReduceMotion")==true end
local activeTweens=setmetatable({},{__mode="k"})
function UI.Tween(obj,duration,props,style,direction)
	local active=activeTweens[obj] or {};activeTweens[obj]=active
	for key in pairs(props) do if active[key] then active[key]:Cancel() end end
	local tw=TweenService:Create(obj,TweenInfo.new(UI.ReducedMotion() and math.min(duration,0.1) or duration,
		style or Enum.EasingStyle.Quad,direction or Enum.EasingDirection.Out),props)
	for key in pairs(props) do active[key]=tw end
	tw.Completed:Once(function() for key in pairs(props) do if active[key]==tw then active[key]=nil end end end)
	tw:Play();return tw
end
function UI.Sound(cue) local audio=require(script.Parent.AudioController);if audio.PlayUI then audio.PlayUI(cue) end end
local loops=setmetatable({},{__mode="k"})
local function shown(obj)
	local node=obj
	while node do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("LayerCollector") and not node.Enabled then return false end
		node=node.Parent
	end
	return obj.Parent~=nil
end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
	elapsed+=dt;if elapsed<1/30 then return end;elapsed=0
	local now=os.clock()
	for obj,fn in pairs(loops) do if not obj.Parent then loops[obj]=nil elseif shown(obj) then fn(now,UI.ReducedMotion()) end end
end)
function UI.Loop(obj,fn) loops[obj]=fn end
function UI.Badge(parent,text,color)
	local b=new("Frame",{Name="Notification",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(28,28),BackgroundColor3=color or T.Colors.Danger.Base,ZIndex=parent.ZIndex+8},parent)
	if #tostring(text or "!")>2 then b.Size=UDim2.fromOffset(56,28) end
	UI.Corner(b,14);UI.Stroke(b,3,T.Ink,true)
	local l=UI.Label(b,{Text=tostring(text or "!"),TextColor3=T.White,Size=UDim2.fromScale(1,1),ZIndex=b.ZIndex+1},2)
	local sc=new("UIScale",{},b)
	UI.Loop(b,function(now,reduced) sc.Scale=reduced and 1 or 1+(now%4<0.6 and math.max(0,math.sin(now*3))*0.12 or 0) end)
	return b,l
end
local controls=setmetatable({},{__mode="k"})
function UI.Animate(b,hoverScale,tilt)
	if controls[b] then return controls[b].Scale end
	b.AutoButtonColor=false;b.Selectable=true
	local sc=b:FindFirstChild("PopScale") or new("UIScale",{Name="PopScale"},b)
	local rot=b.Rotation
	local focus=new("Frame",{Name="FocusRing",Size=UDim2.new(1,8,1,8),Position=UDim2.fromOffset(-4,-4),BackgroundTransparency=1,Visible=false,ZIndex=b.ZIndex+10},b)
	UI.Corner(focus,T.Radius.Card);UI.Stroke(focus,4,T.Colors.Accent.Base,true)
	local state={Scale=sc,Hover=false,Pressed=false};controls[b]=state
	local function render()
		local disabled=b:GetAttribute("Disabled")==true
		focus.Visible=b:GetAttribute("Selected")==true or GuiService.SelectedObject==b
		local s=disabled and 1 or state.Pressed and 0.92 or state.Hover and (hoverScale or 1.06) or 1
		UI.Tween(sc,state.Pressed and T.Motion.Press or T.Motion.Release,{Scale=UI.ReducedMotion() and 1 or s},Enum.EasingStyle.Back)
		UI.Tween(b,T.Motion.Hover,{Rotation=rot+(not UI.ReducedMotion() and state.Hover and not disabled and (tilt or 2) or 0)})
		local shadow=b:FindFirstChild("ButtonShadow")
		if shadow then UI.Tween(shadow,T.Motion.Press,{Position=UDim2.fromOffset(0,state.Pressed and 1 or T.Shadow)}) end
		local icon=b:FindFirstChild("Icon")
		if icon then UI.Tween(icon,T.Motion.Hover,{Rotation=not UI.ReducedMotion() and state.Hover and 5 or 0}) end
		local face=b:FindFirstChild("ButtonFace") or b
		local g=face:FindFirstChildOfClass("UIGradient")
		if g then g.Offset=Vector2.new(0,state.Pressed and -0.2 or state.Hover and 0.15 or 0) end
	end
	state.Render=render
	b.MouseEnter:Connect(function() state.Hover=true;render() end)
	b.MouseLeave:Connect(function() state.Hover=false;state.Pressed=false;render() end)
	b.SelectionGained:Connect(function() state.Hover=true;render();UI.Sound("Hover") end)
	b.SelectionLost:Connect(function() state.Hover=false;state.Pressed=false;render() end)
	b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch or i.KeyCode==Enum.KeyCode.ButtonA then state.Pressed=true;render() end end)
	b.InputEnded:Connect(function() state.Pressed=false;render() end)
	b.Activated:Connect(function() state.Pressed=false;render() end)
	b:GetAttributeChangedSignal("Disabled"):Connect(render);b:GetAttributeChangedSignal("Selected"):Connect(render)
	return sc
end
function UI.SetInteraction(b,state)
 local control=controls[b];if not control then UI.Animate(b);control=controls[b] end
 control.Hover=state=="Hover";control.Pressed=state=="Pressed";control.Render()
end
function UI.SkinCardButton(b)
 local color=b.BackgroundColor3
 local gradient=b:FindFirstChildOfClass("UIGradient")
 local sequence=gradient and gradient.Color
 local content={};for _,child in ipairs(b:GetChildren()) do if child:IsA("GuiObject") then table.insert(content,child) end end
 UI.StyleButton(b,"Rice");b.BackgroundColor3=color;b.ButtonFace.BackgroundColor3=color
 if sequence then b:FindFirstChildOfClass("UIGradient").Color=sequence;b.ButtonFace:FindFirstChildOfClass("UIGradient").Color=sequence end
 local edge=b:FindFirstChildOfClass("UIStroke");edge:GetPropertyChangedSignal("Color"):Connect(function() b.ButtonFace:FindFirstChildOfClass("UIStroke").Color=edge.Color end)
 for _,child in ipairs(content) do child.ZIndex=math.max(child.ZIndex,b.ZIndex+3);for _,d in ipairs(child:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex=math.max(d.ZIndex,b.ZIndex+4) end end end
 b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() b.ButtonFace.BackgroundColor3=b.BackgroundColor3 end)
 return b
end
function UI.StyleButton(b,variant)
	local s=T.Colors[variant or "Secondary"] or T.Colors.Secondary
	b.BackgroundColor3=T.White;UI.Corner(b,12)
	local edge=b:FindFirstChildOfClass("UIStroke") or UI.Stroke(b,3,s.Outline,true)
	edge.Color=s.Outline;edge.Thickness=3;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	UI.Gradient(b,{s.Light,s.Base})
	if not b:FindFirstChild("ButtonShadow") then
		local shadow=new("Frame",{Name="ButtonShadow",Position=UDim2.fromOffset(0,T.Shadow),Size=UDim2.fromScale(1,1),BackgroundColor3=s.Dark,ZIndex=b.ZIndex},b);UI.Corner(shadow,12)
		local face=new("Frame",{Name="ButtonFace",Size=UDim2.fromScale(1,1),BackgroundColor3=T.White,ZIndex=b.ZIndex+1},b)
		UI.Corner(face,12);UI.Gradient(face,{s.Light,s.Base});UI.Stroke(face,3,s.Outline,true)
		local gloss=new("Frame",{Name="Gloss",Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,0.25,0),BackgroundColor3=T.White,BackgroundTransparency=0.83,ZIndex=b.ZIndex+2},b);UI.Corner(gloss,8)
		if variant=="Success" then
			face.ClipsDescendants=true
			local shine=new("Frame",{Name="BuyShine",Size=UDim2.fromScale(0.12,1),BackgroundColor3=T.White,BackgroundTransparency=0.65,ZIndex=b.ZIndex+2,Rotation=15},face)
			UI.Loop(shine,function(now,reduced) shine.Visible=not reduced and now%5<0.35;shine.Position=UDim2.fromScale((now%5)/0.35*1.4-0.2,0) end)
		end
	end
	UI.Animate(b);return b
end
function UI.Button(parent,props,callback)
	props=props or {}
	local b=new("TextButton",{Text="",Size=UDim2.fromOffset(180,T.Size.Action),ZIndex=2})
	if props.NoSound then b:SetAttribute("NoSound",true) end
	local extras={Colors=true,Label=true,StrokeColor=true,Variant=true,Tooltip=true,Price=true,Currency=true,NoSound=true}
	for k,v in pairs(props) do if not extras[k] then b[k]=v end end
	b.Parent=parent
	UI.StyleButton(b,props.Variant)
	local l=UI.Label(b,{Name="ButtonLabel",Text=props.Label or "",TextColor3=T.White,Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-16,1,-12),ZIndex=b.ZIndex+3},2)
	local api={Button=b,Label=l,Gradient=b:FindFirstChildOfClass("UIGradient")}
	api.Gradient:GetPropertyChangedSignal("Color"):Connect(function()
		b.ButtonFace:FindFirstChildOfClass("UIGradient").Color=api.Gradient.Color
	end)
	function api.SetText(v) l.Text=tostring(v) end
	function api.SetColors(colors) UI.Gradient(b,colors);UI.Gradient(b.ButtonFace,colors);b.ButtonShadow.BackgroundColor3=colors[2]:Lerp(T.Ink,0.35) end
	local enabledColors={api.Gradient.Color.Keypoints[1].Value,api.Gradient.Color.Keypoints[2].Value}
	function api.SetDisabled(v)
		if v and not b:GetAttribute("Disabled") then enabledColors={api.Gradient.Color.Keypoints[1].Value,api.Gradient.Color.Keypoints[2].Value} end
		b:SetAttribute("Disabled",v==true);b.Active=not v;b.Selectable=not v
		api.SetColors(v and {T.Colors.Disabled.Light,T.Colors.Disabled.Base} or enabledColors)
	end
	function api.SetSelected(v) b:SetAttribute("Selected",v==true) end
	function api.SetNotification(count)
		if not api.Badge then api.Badge,api.BadgeLabel=UI.Badge(b,count) end
		api.Badge.Visible=count~=nil and count~=false and count~=0
		api.BadgeLabel.Text=type(count)=="number" and (count>99 and "99+" or tostring(count)) or "!"
	end
	function api.SetAffordable(v)
		b:SetAttribute("Affordable",v==true)
		UI.Loop(b,function(now,reduced) local st=b.ButtonFace:FindFirstChildOfClass("UIStroke");st.Color=v and T.Colors.Success.Base or (props.StrokeColor or T.Ink);st.Thickness=v and not reduced and 3+0.7*(math.sin(now*3)+1) or 3 end)
	end
	if props.Colors then api.SetColors(props.Colors) end
	if props.StrokeColor then b.ButtonFace:FindFirstChildOfClass("UIStroke").Color=props.StrokeColor end
	if props.Tooltip then UI.Tooltip(b,props.Tooltip) end
	if callback then b.Activated:Connect(function() if not b:GetAttribute("Disabled") then callback() end end) end
	return api
end
for name,variant in pairs({Primary="Primary",Secondary="Secondary",Danger="Danger",CloseButton="Danger",Tab="Secondary",IconButton="Primary"}) do
	UI[name]=function(parent,props,callback) props=table.clone(props or {});props.Variant=props.Variant or variant;return UI.Button(parent,props,callback) end
end
function UI.IconButton(parent,props,callback)
 props=table.clone(props or {});props.Size=props.Size or UDim2.fromOffset(52,52);props.Variant=props.Variant or "Primary";props.Tooltip=props.Tooltip or props.Label or "Action"
 local b=UI.Button(parent,props,callback)
 for _,obj in ipairs({b.Button,b.Button.ButtonFace,b.Button.ButtonShadow}) do UI.Corner(obj,100) end
 return b
end
function UI.Buy(parent,props,callback)
	props=table.clone(props or {});props.Variant="Success";local c=T.Currency[props.Currency or "Money"] or T.Currency.Money
	props.Label=c.Icon.." "..NF.Format(props.Price or 0);return UI.Button(parent,props,callback)
end
function UI.Tile(parent,props,callback)
	local b=UI.Primary(parent,{Name=props.Name,Label="",Size=UDim2.fromOffset(T.Size.Tile,T.Size.Tile),LayoutOrder=props.Order or 0},callback)
	local icon=UI.Icon(b.Button,props.Name,props.Icon or "?",{Name="Icon",TextColor3=T.White,Size=UDim2.new(1,-16,0.58,0),Position=UDim2.fromOffset(8,4),ZIndex=6},0)
	UI.Label(b.Button,{Name="Caption",Text=props.Text or props.Name,TextColor3=T.White,Size=UDim2.new(1,-8,0.3,0),Position=UDim2.new(0,4,0.65,0),ZIndex=6},2)
	UI.Loop(icon,function(now,reduced) icon.Position=UDim2.fromOffset(8,4+(reduced and 0 or math.sin(now*1.6)*1.5)) end)
	b.Badge,b.BadgeLabel=UI.Badge(b.Button,"!");b.Badge.Visible=false;return b
end
local blur=new("BlurEffect",{Name="SushiMenuBlur",Size=0},Lighting)
local blurOwner=nil
local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720) end
function UI.MenuEffect(name,opened)
 if opened then blurOwner=name;UI.Tween(blur,0.25,{Size=UI.ReducedMotion() and 0 or 12})
 elseif blurOwner==name then blurOwner=nil;UI.Tween(blur,0.15,{Size=0}) end
end
function UI.Ribbon(parent,text)
 local f=new("Frame",{Name="Ribbon",Size=UDim2.fromOffset(112,28),Position=UDim2.fromOffset(10,-8),Rotation=-3,BackgroundColor3=T.Colors.Accent.Base,ZIndex=12},parent)
 UI.Corner(f,8);UI.Stroke(f,3,T.Ink,true);UI.Label(f,{Text=text,Size=UDim2.fromScale(1,1),ZIndex=13},0);return f
end
function UI.Device() local v=viewport();return v.X<700 and "Phone" or v.X<1100 and "Tablet" or "Desktop" end
function UI.Neko(parent,props)
 props=props or {}
 local cat=new("Frame",{Name="NekoMascot",Size=UDim2.fromOffset(48,42),BackgroundTransparency=1,Position=props.Position or UDim2.new(1,-100,0,30),ZIndex=4},parent)
 for _,x in ipairs({5,31}) do local ear=new("Frame",{Size=UDim2.fromOffset(14,14),Position=UDim2.fromOffset(x,2),Rotation=45,BackgroundColor3=T.Colors.Rice.Base,ZIndex=4},cat);UI.Corner(ear,3);UI.Stroke(ear,2,T.Ink,true) end
 local head=new("Frame",{Size=UDim2.fromOffset(44,30),Position=UDim2.fromOffset(2,8),BackgroundColor3=T.Colors.Rice.Base,ZIndex=5},cat);UI.Corner(head,14);UI.Stroke(head,2,T.Ink,true)
 for _,x in ipairs({12,30}) do local eye=new("Frame",{Size=UDim2.fromOffset(4,6),Position=UDim2.fromOffset(x,19),BackgroundColor3=T.Ink,ZIndex=6},cat);UI.Corner(eye,2) end
 local nose=new("Frame",{Size=UDim2.fromOffset(5,4),Position=UDim2.fromOffset(22,25),BackgroundColor3=T.Colors.Primary.Base,ZIndex=6},cat);UI.Corner(nose,2)
 local paw=new("Frame",{Size=UDim2.fromOffset(12,16),Position=UDim2.fromOffset(38,25),BackgroundColor3=T.Colors.Rice.Light,ZIndex=7},cat);UI.Corner(paw,6);UI.Stroke(paw,2,T.Ink,true)
 return cat
end
function UI.Window(opts)
	local size=opts.Size or Vector2.new(760,640)
	local gui=new("ScreenGui",{Name=opts.Name,ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=opts.DisplayOrder or 30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Enabled=false},player:WaitForChild("PlayerGui"))
	local backdrop=new("TextButton",{Name="Backdrop",Text="",Size=UDim2.fromScale(1,1),BackgroundColor3=T.Ink,BackgroundTransparency=1,Selectable=false,AutoButtonColor=false,ZIndex=1},gui);backdrop:SetAttribute("NoSound",true)
	local f=new("CanvasGroup",{Name="Window",Active=true,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(size.X,size.Y),BackgroundColor3=T.Colors.Rice.Base,ZIndex=2},gui)
	UI.Corner(f,24);UI.Stroke(f,4,T.Ink,true)
	local sc=new("UIScale",{},f)
	local h=new("Frame",{Name="Header",Size=UDim2.new(1,0,0,T.Size.Header),BackgroundColor3=T.Colors.Wood.Base,ZIndex=3},f);UI.Corner(h,24);UI.Gradient(h,{T.Colors.Wood.Light,T.Colors.Wood.Base})
	UI.Label(h,{Name="Icon",Text=opts.Icon or "🍣",TextColor3=T.White,Position=UDim2.fromOffset(16,14),Size=UDim2.fromOffset(44,44),ZIndex=4},0)
	local title=UI.Label(h,{Name="Title",Text=opts.Title or opts.Name,TextColor3=T.White,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(72,12),Size=UDim2.new(1,-204,0,48),ZIndex=4},3)
	local close=UI.CloseButton(h,{Name="Close",Label="X",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,12),Size=UDim2.fromOffset(48,44),ZIndex=5})
	UI.Neko(h,{Position=UDim2.new(1,-116,0,28)})
	local plank=new("Frame",{Name="PlankAccent",Position=UDim2.new(0,16,1,-6),Size=UDim2.new(1,-32,0,2),BackgroundColor3=T.Colors.Wood.Dark,BackgroundTransparency=0.4,ZIndex=4},h)
	local body=new("Frame",{Name="Body",Position=UDim2.fromOffset(12,84),Size=UDim2.new(1,-24,1,-96),BackgroundColor3=T.Colors.Rice.Base,ZIndex=3},f);UI.Corner(body,18);UI.Stroke(body,3,T.Ink,true)
	local win={Gui=gui,Frame=f,Body=body,Title=title,OnOpen={},OnClose={},OnLayout={},CloseButton=close.Button}
	local opened=false;local generation=0;local previousFocus=nil
	local function layout()
		local v=gui.AbsoluteSize;if v.X<1 then v=viewport() end
		f.Size=UDim2.fromOffset(math.min(size.X,v.X-24),math.min(size.Y,v.Y-24));sc.Scale=1
		for _,fn in ipairs(win.OnLayout) do fn(v.X<700,f.AbsoluteSize) end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	f:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() for _,fn in ipairs(win.OnLayout) do fn(gui.AbsoluteSize.X<700,f.AbsoluteSize) end end)
	function win.IsOpen() return opened end
	function win.Open()
		if opened then return end;MenuManager.Opening(opts.Name);opened=true;generation+=1;previousFocus=GuiService.SelectedObject
		gui.Enabled=true;layout();f.GroupTransparency=1;sc.Scale=UI.ReducedMotion() and 1 or 0.8
		UI.Tween(f,0.25,{GroupTransparency=0});UI.Tween(sc,0.25,{Scale=1},Enum.EasingStyle.Back);UI.Tween(backdrop,0.25,{BackgroundTransparency=0.35})
		blurOwner=opts.Name;UI.Tween(blur,0.25,{Size=UI.ReducedMotion() and 0 or 12});MenuManager.Activated(opts.Name)
		if Input:GetLastInputType().Name:find("Gamepad") then GuiService.SelectedObject=close.Button end
		UI.Sound("Open");for _,fn in ipairs(win.OnOpen) do task.spawn(fn) end
	end
	function win.Close()
		if not opened then return end;opened=false;generation+=1;local ticket=generation;MenuManager.Closed(opts.Name)
		UI.Tween(f,0.15,{GroupTransparency=1});UI.Tween(sc,0.15,{Scale=UI.ReducedMotion() and 1 or 0.9});UI.Tween(backdrop,0.15,{BackgroundTransparency=1})
		if blurOwner==opts.Name then blurOwner=nil;UI.Tween(blur,0.15,{Size=0}) end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject=previousFocus and previousFocus.Parent and previousFocus or nil end
		UI.Sound("Close");for _,fn in ipairs(win.OnClose) do task.spawn(fn) end
		task.delay(0.15,function() if ticket==generation and not opened then gui.Enabled=false end end)
	end
	function win.Toggle() if opened then win.Close() else win.Open() end end
	win.Layout=layout;close.Button.Activated:Connect(win.Close);backdrop.Activated:Connect(win.Close);MenuManager.Register(opts.Name,win.Close);layout();return win
end
function UI.List(parent,padding)
	local s=new("ScrollingFrame",{Name="List",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=8,ScrollBarImageColor3=T.Colors.Wood.Base,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y},parent)
	new("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,16)},s)
	new("UIListLayout",{Padding=UDim.new(0,padding or 12),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},s);return s
end
function UI.Row(parent,icon,text,order)
	local f=new("Frame",{Name=text,LayoutOrder=order or 0,Size=UDim2.new(1,-4,0,80),BackgroundColor3=T.Colors.Rice.Light},parent);UI.Corner(f,18);UI.Stroke(f,3,T.Ink,true)
	UI.Label(f,{Name="Icon",Text=icon,Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(40,40)},0)
	UI.Label(f,{Name="Text",Text=text,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(64,8),Size=UDim2.new(1,-240,0,56)},0)
	local function layout()
		local compact=f.AbsoluteSize.X<560
		f.Size=UDim2.new(1,-4,0,compact and 132 or 80)
		f.Text.Size=UDim2.new(1,compact and -80 or -240,0,compact and 48 or 56)
		for _,control in ipairs(f:GetChildren()) do
			if control:IsA("GuiButton") then control.Position=compact and UDim2.new(1,-12,1,-36) or UDim2.new(1,-12,0.5,0) end
		end
	end
	f:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout);f.ChildAdded:Connect(layout);task.defer(layout)
	return f
end
function UI.Toggle(row,initial,onChange)
	local value=initial==true
	local b=UI.Button(row,{Name="Toggle",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(140,48)})
	local function render() b.SetText(value and "ON  ●" or "○  OFF");b.SetColors(value and UI.Gradients.On or {T.Colors.Disabled.Light,T.Colors.Disabled.Base});b.SetSelected(value) end
	b.Button.Activated:Connect(function() if b.Button:GetAttribute("Disabled") then return end;value=not value;render();onChange(value) end)
	function b.Set(v) value=v==true;render() end;render();return b
end
function UI.Slider(row,initial,onChange)
	local value=math.clamp(initial or 0,0,1)
	local b=new("TextButton",{Name="Slider",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(220,48),BackgroundTransparency=1,Selectable=true},row);b:SetAttribute("NoSound",true)
	local rail=new("Frame",{Position=UDim2.new(0,12,0.5,-7),Size=UDim2.new(1,-24,0,14),BackgroundColor3=T.Colors.Rice.Dark},b);UI.Corner(rail,7);UI.Stroke(rail,3,T.Ink,true)
	local fill=new("Frame",{Size=UDim2.fromScale(value,1),BackgroundColor3=T.Colors.Success.Base},rail);UI.Corner(fill,7)
	local knob=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(value,0.5),Size=UDim2.fromOffset(28,28),BackgroundColor3=T.Colors.Accent.Base,ZIndex=3},rail);UI.Corner(knob,14);UI.Stroke(knob,3,T.Ink,true)
	local pct=UI.Label(b,{Text="",Position=UDim2.fromOffset(0,-18),Size=UDim2.new(1,0,0,20)},0)
	local connections={};local drag=nil
	local function set(v,notify,final) value=math.clamp(v,0,1);fill.Size=UDim2.fromScale(value,1);knob.Position=UDim2.fromScale(value,0.5);pct.Text=math.floor(value*100+0.5).."%";if notify then onChange(value,final) end end
	local function fromX(x) if not b:GetAttribute("Disabled") and rail.AbsoluteSize.X>0 then set((x-rail.AbsolutePosition.X)/rail.AbsoluteSize.X,true,false) end end
	b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=i;fromX(i.Position.X) end end)
	table.insert(connections,Input.InputChanged:Connect(function(i) if drag and (i==drag or i.UserInputType==Enum.UserInputType.MouseMovement) then fromX(i.Position.X) end end))
	table.insert(connections,Input.InputEnded:Connect(function(i) if drag and (i==drag or i.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil;onChange(value,true) end end))
	table.insert(connections,Input.InputBegan:Connect(function(i) if GuiService.SelectedObject~=b or b:GetAttribute("Disabled") then return end;if i.KeyCode==Enum.KeyCode.DPadLeft then set(value-0.05,true,true) elseif i.KeyCode==Enum.KeyCode.DPadRight then set(value+0.05,true,true) end end))
	UI.Animate(b,1,0)
	b.SelectionGained:Connect(function() knob.BackgroundColor3=T.Colors.Primary.Base end);b.SelectionLost:Connect(function() knob.BackgroundColor3=T.Colors.Accent.Base end)
	b.Destroying:Connect(function() for _,c in ipairs(connections) do c:Disconnect() end end);set(value,false);return {Button=b,Set=function(v) set(v,false) end,SetDisabled=function(v) b:SetAttribute("Disabled",v==true);b.Selectable=not v;b.Active=not v end}
end
function UI.Quantity(parent,initial,onChange)
	local f=new("Frame",{Name="Quantity",BackgroundTransparency=1,Size=UDim2.fromOffset(270,52)},parent)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)},f)
	local items={};local value=initial or "x1"
	local function refresh() for key,b in pairs(items) do b.SetSelected(key==value);b.SetColors(key==value and UI.Gradients.Gold or UI.Gradients.Dark) end end
	for _,key in ipairs({"x1","x10","MAX"}) do items[key]=UI.Tab(f,{Label=key,Size=UDim2.fromOffset(80,44)},function() value=key;refresh();onChange(key) end) end
	refresh();return {Frame=f,Buttons=items,Set=function(v) value=v;refresh() end}
end
function UI.Progress(parent,opts)
	opts=opts or {};local f=new("Frame",{Name=opts.Name or "Progress",Size=opts.Size or UDim2.new(1,0,0,28),BackgroundColor3=T.Colors.Rice.Dark,ClipsDescendants=true},parent);UI.Corner(f,14);UI.Stroke(f,3,T.Ink,true)
	local fill=new("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=opts.Color or T.Colors.Success.Base},f);UI.Corner(fill,14)
	local l=UI.Label(f,{Name="Count",Text="",Size=UDim2.fromScale(1,1),ZIndex=3},0)
	local shine=new("Frame",{Name="Shine",Size=UDim2.fromScale(0.15,1),BackgroundColor3=T.White,BackgroundTransparency=0.7,ZIndex=2},fill)
	UI.Loop(f,function(now,reduced) shine.Visible=not reduced;shine.Position=UDim2.fromScale((now*0.4)%1.4-0.2,0) end)
	return {Frame=f,Fill=fill,Label=l,Set=function(v,text) UI.Tween(fill,0.25,{Size=UDim2.fromScale(math.clamp(v,0,1),1)});l.Text=text or "" end}
end
UI.XPBar=UI.Progress;UI.RebirthBar=UI.Progress
function UI.Card(parent,opts)
	opts=opts or {};local f=new("Frame",{Name=opts.Name or "Card",Size=opts.Size or UDim2.new(1,-8,0,164),BackgroundColor3=T.Colors.Rice.Light,LayoutOrder=opts.Order or 0},parent);UI.Corner(f,18);UI.Stroke(f,3,opts.Color or T.Ink,true)
	UI.Icon(f,opts.Name or opts.Title or "GenericUpgrade",opts.Icon or "🍣",{Name="Icon",Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(64,64)},0)
	local title=UI.Label(f,{Name="Name",Text=opts.Title or "Sushi Upgrade",Position=UDim2.fromOffset(88,12),Size=UDim2.new(1,-104,0,32),TextXAlignment=Enum.TextXAlignment.Left},0)
	local desc=UI.Label(f,{Name="Description",Text=opts.Description or "",Position=UDim2.fromOffset(88,48),Size=UDim2.new(1,-104,0,44),TextXAlignment=Enum.TextXAlignment.Left,TextColor3=T.Muted},0)
	local action=UI.Button(f,{Name="Action",Label=opts.Action or "View",Variant=opts.Variant or "Success",Position=UDim2.new(1,-172,1,-58),Size=UDim2.fromOffset(156,44)},opts.OnAction)
	return {Frame=f,Title=title,Description=desc,Action=action}
end
for _,name in ipairs({"UpgradeCard","CollectionCard","ShopCard","TitleCard","RuneCard","AreaCard"}) do UI[name]=UI.Card end
function UI.Lock(parent,requirement)
	local f=new("Frame",{Name="LockOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=T.Colors.Disabled.Dark,BackgroundTransparency=0.06,ZIndex=20},parent);UI.Corner(f,18)
	local blocked={}
	for _,b in ipairs(parent:GetDescendants()) do if b:IsA("GuiButton") then table.insert(blocked,{Button=b,Disabled=b:GetAttribute("Disabled"),Active=b.Active,Selectable=b.Selectable});b:SetAttribute("Disabled",true);b.Active=false;b.Selectable=false end end
	f.Destroying:Connect(function() for _,state in ipairs(blocked) do if state.Button.Parent then state.Button:SetAttribute("Disabled",state.Disabled);state.Button.Active=state.Active;state.Button.Selectable=state.Selectable end end end)
	UI.Label(f,{Text="LOCKED\n"..requirement,TextColor3=T.White,Size=UDim2.new(1,-24,1,-24),Position=UDim2.fromOffset(12,12),ZIndex=21},2);return f
end
function UI.Empty(parent,message) return UI.Label(parent,{Name="EmptyState",Text=message or "No runes yet — visit a Rune Altar!",Size=UDim2.new(1,-24,0,88),TextColor3=T.Muted},0) end
function UI.Spinner(parent)
	local f=new("Frame",{Name="SushiSpinner",Size=UDim2.fromOffset(48,48),BackgroundColor3=T.Colors.Rice.Light},parent);UI.Corner(f,24);UI.Stroke(f,4,T.Colors.Wood.Base,true);UI.Label(f,{Text="🍣",Size=UDim2.fromScale(1,1)},0)
	UI.Loop(f,function(now,reduced) f.Rotation=reduced and 0 or (now*180)%360 end);return f
end
function UI.Input(parent,placeholder)
	local b=new("TextBox",{Name="Input",Text="",PlaceholderText=placeholder or "Enter code",ClearTextOnFocus=false,Font=UI.Font,TextSize=20,TextColor3=T.Ink,PlaceholderColor3=T.Muted,Size=UDim2.new(1,0,0,52),BackgroundColor3=T.Colors.Rice.Light},parent)
	UI.Corner(b,12);UI.Stroke(b,3,T.Ink,true);new("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},b);return b
end
local overlayGui=nil
local function overlays() if not overlayGui then overlayGui=new("ScreenGui",{Name="SushiFeedback",ResetOnSpawn=false,DisplayOrder=80},player:WaitForChild("PlayerGui")) end;return overlayGui end
local queue={};local busy=false
local function nextToast()
	if busy or #queue==0 then return end;busy=true;local item=table.remove(queue,1)
	local f=new("CanvasGroup",{Name="Toast",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,16),Size=UDim2.new(0.9,0,0,64),BackgroundColor3=T.Colors.Rice.Light,GroupTransparency=1},overlays())
	new("UISizeConstraint",{MaxSize=Vector2.new(560,64)},f);UI.Corner(f,18);UI.Stroke(f,3,item.Color or T.Ink,true)
	UI.Label(f,{Text=item.Text,Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,1,-16)},0);UI.Tween(f,0.2,{GroupTransparency=0})
	task.delay(2.5,function() UI.Tween(f,0.15,{GroupTransparency=1});task.delay(0.16,function() f:Destroy();busy=false;nextToast() end) end)
end
function UI.Toast(text,color) table.insert(queue,{Text=text,Color=color});nextToast() end
function UI.Reward(text) UI.Toast(text,T.Colors.Success.Base);UI.Sound("Success") end
function UI.Tooltip(b,text)
	local tip=nil
	local function hide() if tip then tip:Destroy();tip=nil end end
	local function show()
		hide();tip=new("Frame",{Name="Tooltip",Size=UDim2.fromOffset(240,72),BackgroundColor3=T.Colors.Secondary.Base},overlays());UI.Corner(tip,12);UI.Stroke(tip,3,T.Ink,true)
		local p=b.AbsolutePosition;local v=viewport();tip.Position=UDim2.fromOffset(math.clamp(p.X,12,math.max(12,v.X-252)),math.clamp(p.Y-80,12,math.max(12,v.Y-84)))
		UI.Label(tip,{Text=text,TextColor3=T.White,Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-16)},0)
	end
	b.MouseEnter:Connect(show);b.MouseLeave:Connect(hide);b.SelectionGained:Connect(show);b.SelectionLost:Connect(hide);b.Destroying:Connect(hide);b.Activated:Connect(hide)
end
function UI.Confirm(opts)
	local win=UI.Window({Name=opts.Name or "Confirm",Title=opts.Title or "Are you sure?",Icon=opts.Icon or "!",Size=Vector2.new(520,390),DisplayOrder=60})
	UI.Label(win.Body,{Text=opts.Text or "",Position=UDim2.fromOffset(16,12),Size=UDim2.new(1,-32,1,-92),TextXAlignment=Enum.TextXAlignment.Left},0)
	local pending=false
	local yes=UI.Danger(win.Body,{Label=opts.ConfirmText or "Confirm",Position=UDim2.new(0,12,1,-68),Size=UDim2.new(0.5,-18,0,52)},function()
		if pending then return end;pending=true
		local ok,err=pcall(opts.OnConfirm or function() end);pending=false
		if ok then win.Close() else UI.Toast("Please try again.",T.Colors.Danger.Base);warn("[UI Confirm] "..tostring(err)) end
	end)
	UI.Secondary(win.Body,{Label="Cancel",Position=UDim2.new(0.5,6,1,-68),Size=UDim2.new(0.5,-18,0,52)},win.Close)
	table.insert(win.OnClose,function() task.delay(0.2,function() if not win.IsOpen() then MenuManager.Unregister(opts.Name or "Confirm",win.Close);win.Gui:Destroy() end end) end)
	win.Open();return win,yes
end
function UI.Feedback(b,success)
	UI.Sound(success and "Success" or "Error")
	local f=new("Frame",{Name="Feedback",Size=UDim2.fromScale(1,1),BackgroundColor3=success and T.Colors.Success.Base or T.Colors.Danger.Base,BackgroundTransparency=0.3,ZIndex=b.ZIndex+9},b)
	UI.Corner(f,12);UI.Tween(f,0.25,{BackgroundTransparency=1});task.delay(0.26,function() f:Destroy() end)
	local sc=b:FindFirstChild("PopScale");if sc and not UI.ReducedMotion() then sc.Scale=success and 1.08 or 0.94;UI.Tween(sc,0.2,{Scale=1},Enum.EasingStyle.Back) end
end
local celebrationBusy=false
local celebrationQueue={}
function UI.Celebrate(title,subtitle,color)
	if celebrationBusy then table.insert(celebrationQueue,{Title=title,Subtitle=subtitle,Color=color});return end
	celebrationBusy=true
	local f=new("CanvasGroup",{Name="Celebration",Size=UDim2.fromScale(1,1),BackgroundColor3=T.Ink,BackgroundTransparency=0.4},overlays())
	local rays=new("Frame",{Name="Rays",Size=UDim2.fromOffset(400,400),Position=UDim2.fromScale(0.5,0.45),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1},f)
	for i=1,12 do local r=new("Frame",{Size=UDim2.fromOffset(10,360),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Rotation=i*30,BackgroundColor3=color or T.Colors.Accent.Base,BackgroundTransparency=0.85},rays);UI.Corner(r,5) end
	UI.Label(f,{Text=title,TextColor3=color or T.Colors.Accent.Base,Size=UDim2.new(0.9,0,0,76),Position=UDim2.fromScale(0.5,0.4),AnchorPoint=Vector2.new(0.5,0.5)},3)
	UI.Label(f,{Text=subtitle or "",TextColor3=T.White,Size=UDim2.new(0.85,0,0,60),Position=UDim2.fromScale(0.5,0.52),AnchorPoint=Vector2.new(0.5,0.5)},2)
	local petals={};local start=os.clock()
	if not UI.ReducedMotion() then for i=1,24 do local p=new("Frame",{Size=UDim2.fromOffset(8,12),BackgroundColor3=i%2==0 and T.Colors.Primary.Base or T.Colors.Accent.Base},f);UI.Corner(p,4);table.insert(petals,{Object=p,X=math.random(),Phase=math.random()}) end end
	UI.Loop(f,function(now,reduced) rays.Rotation=reduced and 0 or (now-start)*18;for _,p in ipairs(petals) do p.Object.Visible=not reduced;p.Object.Position=UDim2.fromScale(p.X+math.sin(now+p.Phase)*0.04,((now-start)*0.4+p.Phase)%1.2-0.1);p.Object.Rotation=now*80 end end)
	UI.Sound("Success");task.delay(2.4,function() UI.Tween(f,0.25,{GroupTransparency=1});task.delay(0.26,function() f:Destroy();celebrationBusy=false;local nextItem=table.remove(celebrationQueue,1);if nextItem then UI.Celebrate(nextItem.Title,nextItem.Subtitle,nextItem.Color) end end) end)
end
function UI.CurrencyPill(parent,attribute,opts)
	opts=opts or {};local s=T.Currency[attribute] or T.Currency.Money
	local f=new("Frame",{Name=attribute.."Bar",Size=UDim2.fromOffset(220,52),BackgroundColor3=s.Base},parent);UI.Corner(f,18);UI.Stroke(f,3,s.Outline,true);UI.Gradient(f,{s.Light,s.Base})
	UI.Icon(f,attribute,s.Icon,{TextColor3=T.White,Position=UDim2.fromOffset(8,4),Size=UDim2.fromOffset(40,40)},2)
	local amount=UI.Label(f,{Name="Amount",Text="0",TextColor3=T.White,Position=UDim2.fromOffset(56,4),Size=UDim2.new(1,-64,0,28),TextXAlignment=Enum.TextXAlignment.Right},2)
	UI.Label(f,{Name="Caption",Text=s.Name,TextColor3=T.White,Position=UDim2.fromOffset(56,32),Size=UDim2.new(1,-64,0,16),TextXAlignment=Enum.TextXAlignment.Right},1)
	local target=tonumber(opts.Value) or player:GetAttribute(attribute) or 0;local displayed=target;local format=opts.Format or NF.Format
	local conn=nil;if opts.Value==nil then conn=player:GetAttributeChangedSignal(attribute):Connect(function() target=player:GetAttribute(attribute) or 0 end) end
	UI.Loop(f,function(_,reduced) displayed=reduced and target or displayed+(target-displayed)*0.3;if math.abs(displayed-target)<0.005 then displayed=target end;amount.Text=format(displayed) end)
	f.Destroying:Connect(function() if conn then conn:Disconnect() end end);amount.Text=format(displayed)
	return {Frame=f,Amount=amount,Set=function(v) target=v end}
end
-- Fixed UI geometry is centralized here; controller layouts reflow these at runtime.
T.Layout.AdminController={
 Size1=Vector2.new(640,680),
 Size2=UDim2.fromOffset(120,44),
 Size3=UDim2.new(1,-8,0,48),
 Size4=UDim2.fromOffset(92,44),
}
T.Layout.AnnouncementController={
 Size1=UDim2.new(0.9, 0, 0, 70),
 Size2=Vector2.new(560, 70),
 Size3=UDim2.new(1, -24, 1, -12),
}
T.Layout.AreasController={
 Size1=Vector2.new(720,680),
}
T.Layout.AscensionController={
 Size1=UDim2.new(1, -16, 1, -12),
 Size2=Vector2.new(540,510),
 Size3=UDim2.new(1,-32,0,64),
 Size4=UDim2.new(1,-32,0,64),
 Size5=UDim2.new(1,-32,0,48),
 Size6=UDim2.new(1,-32,0,44),
 Size7=UDim2.new(0.55,-18,0,56),
 Size8=UDim2.new(0.45,-18,0,56),
}
T.Layout.BoardMenuController={
 Size1=Vector2.new(800,720),
 Size2=UDim2.new(1,-16,0,108),
 Size3=UDim2.new(0.333,-6,0,44),
 Size4=UDim2.new(1,0,1,-124),
 Size5=UDim2.fromOffset(90,44),
}
T.Layout.BoardsController={
 Size1=UDim2.new(1, -24, 0, 34),
 Size2=UDim2.new(1, -40, 0, 32),
 Size3=UDim2.fromOffset(40, 40),
 Size4=UDim2.new(1, -66, 0, 36),
 Size5=UDim2.new(1, -12, 0, 24),
 Size6=UDim2.new(1, -12, 0, 17),
 Size7=UDim2.fromOffset(62, 62),
 Size8=UDim2.new(1, -10, 1, -10),
 Size9=UDim2.new(1, -32, 0, 7),
 Size10=UDim2.new(1, -12, 0, 24),
 Size11=UDim2.new(1, -14, 0, 18),
 Size12=UDim2.fromOffset(74, 34),
 Size13=UDim2.fromOffset(76, 34),
 Size14=UDim2.new(1, -16, 0, 30),
 Size15=UDim2.new(1, -12, 0, 22),
 Size16=UDim2.new(1, -12, 0, 30),
 Size17=UDim2.fromOffset(56, 56),
 Size18=UDim2.new(1, -12, 0, 18),
 Size19=UDim2.new(1, -12, 0, 24),
 Size20=UDim2.new(1, -16, 0, 30),
 Size21=UDim2.fromOffset(62, 62),
 Size22=UDim2.new(1, -10, 1, -10),
 Size23=UDim2.new(1, -12, 0, 24),
 Size24=UDim2.fromOffset(70, 70),
 Size25=UDim2.new(1, -20, 0, 44),
 Size26=UDim2.new(1, -20, 0, 22),
 Size27=UDim2.new(1, -12, 0, 22),
 Size28=UDim2.new(1, -12, 0, 16),
 Size29=UDim2.new(1, -12, 0, 20),
 Size30=UDim2.new(1, -14, 0, 30),
 Size31=UDim2.new(1, -14, 0, 16),
 Size32=UDim2.new(1, -12, 0, 22),
 Size33=UDim2.fromOffset(56, 56),
 Size34=UDim2.new(1, -12, 0, 18),
 Size35=UDim2.new(1, -12, 0, 24),
 Size36=UDim2.new(1, -12, 0, 20),
 Size37=UDim2.new(1, -12, 0, 24),
 Size38=UDim2.new(1, -16, 0, 30),
 Size39=UDim2.new(1, -12, 0, 26),
 Size40=UDim2.new(1, -16, 0, 17),
 Size41=UDim2.new(1, -60, 0, 26),
 Size42=UDim2.new(1, -8, 1, -4),
 Size43=UDim2.fromOffset(250, 60),
 Size44=UDim2.new(1, -120, 0, 3),
 Size45=UDim2.fromOffset(240, 62),
}
T.Layout.FutureUIController={
 Size1=UDim2.new(1,-8,0,48),
 Size2=Vector2.new(820,680),
 Size3=UDim2.fromOffset(104,44),
 Size4=UDim2.new(1,-8,0,48),
 Size5=UDim2.new(1,-8,0,52),
 Size6=UDim2.new(1,-8,0,52),
 Size7=UDim2.new(1,-8,0,96),
 Size8=UDim2.new(1,-8,0,56),
 Size9=UDim2.new(1,-8,0,56),
 Size10=UDim2.new(1,-8,0,52),
}
T.Layout.HudController={
 Size1=UDim2.fromOffset(220,380),
 Size2=UDim2.fromOffset(110,32),
 Size3=UDim2.fromOffset(220,32),
 Size4=UDim2.fromOffset(240,44),
}
T.Layout.IndexController={
 Size1=UDim2.new(0, 262, 1, -74),
 Size2=UDim2.new(1, -20, 0, 190),
 Size3=UDim2.new(1, -20, 0, 34),
 Size4=UDim2.fromOffset(150, 28),
 Size5=UDim2.new(1, -12, 1, -6),
 Size6=UDim2.new(1, -28, 0, 26),
 Size7=UDim2.new(1, -28, 0, 26),
 Size8=UDim2.new(1, -28, 0, 26),
 Size9=UDim2.new(1, -10, 0, 104),
 Size10=UDim2.new(1, -10, 0, 24),
 Size11=UDim2.fromOffset(80, 24),
 Size12=UDim2.new(1, -8, 1, -4),
 Size13=UDim2.fromOffset(52, 24),
 Size14=UDim2.new(1, -6, 1, -4),
 Size15=UDim2.new(1, 8, 1, 8),
 Size16=Vector2.new(900, 650),
 Size17=UDim2.fromOffset(230, 34),
 Size18=UDim2.new(1, -420, 0, 22),
 Size19=UDim2.fromOffset(140, 34),
 Size20=UDim2.new(1, -298, 1, -74),
 Size21=UDim2.new(1, 0, 0, 0),
 Size22=UDim2.new(1, -6, 0, 34),
 Size23=UDim2.new(1, -24, 1, -8),
 Size24=UDim2.new(1, 0, 0, 0),
 Size25=UDim2.new(1,-16,1,-116),
 Size26=UDim2.new(1,-16,0,44),
 Size27=UDim2.new(1,-24,1,-74),
 Size28=UDim2.new(1,-16,0,404),
 Size29=UDim2.new(0,262,1,-74),
 Size30=UDim2.new(1,-298,1,-74),
 Size31=UDim2.fromOffset(18, 18),
 Size32=UDim2.fromOffset(82, 82),
 Size33=UDim2.new(1, -8, 1, -12),
 Size34=UDim2.fromOffset(88, 70),
 Size35=UDim2.fromOffset(88, 70),
 Size36=UDim2.new(1, -8, 0, 34),
 Size37=UDim2.new(1, -8, 0, 16),
 Size38=UDim2.fromOffset(150, 34),
 Size39=UDim2.new(1, -24, 1, -12),
}
T.Layout.MarketController={
 Size1=UDim2.fromOffset(250, 66),
 Size2=UDim2.new(1, -32, 0.34, 0),
 Size3=UDim2.fromOffset(34, 34),
 Size4=UDim2.new(1, -72, 1, -12),
 Size5=UDim2.new(1, 0, 0.58, 0),
 Size6=UDim2.new(1, 0, 0.4, 0),
 Size7=UDim2.fromOffset(40, 40),
 Size8=UDim2.fromOffset(26, 26),
}
T.Layout.MenuButtonsController={
 Size1=UDim2.fromOffset(164,360),
 Size2=UDim2.fromOffset(76,76),
 Size3=UDim2.fromOffset(104,44),
}
T.Layout.MinigameHUDController={
 Size1=UDim2.new(0.7,0,0,64),
 Size2=Vector2.new(420,64),
 Size3=UDim2.new(1,-24,1,-16),
}
T.Layout.ProfileController={
 Size1=Vector2.new(740,680),
 Size2=UDim2.fromOffset(64,64),
 Size3=UDim2.new(1,-8,0,64),
 Size4=UDim2.new(0.55,-12,1,-16),
 Size5=UDim2.new(0.45,-12,1,-16),
}
T.Layout.ResetMenuController={
 Size1=Vector2.new(600,650),
 Size2=UDim2.new(1,-32,1,-96),
 Size3=UDim2.new(0.6,-18,0,56),
 Size4=UDim2.new(0.4,-18,0,56),
}
T.Layout.RunesMenuController={
 RuneName=UDim2.new(1,-56,0,26),
 RuneIcon=UDim2.fromOffset(36,36),
 Size1=UDim2.new(1, 0, 0, 70),
 Size2=UDim2.new(1, -14, 0, 26),
 Size3=UDim2.new(1, -40, 0, 18),
 Size4=UDim2.new(1, -40, 0, 22),
 Size5=UDim2.new(1, -20, 0, 20),
 Size6=UDim2.new(1, -24, 0, 8),
 Size7=UDim2.new(0.6, -12, 0, 20),
 Size8=UDim2.new(0.5, -12, 0, 24),
 Size9=UDim2.new(1, 0, 0, 28),
 Size10=UDim2.new(1, 0, 0, 56),
 Size11=UDim2.new(1, 0, 0, 22),
 Size12=UDim2.new(1, 0, 0, 36),
 Size13=UDim2.new(1, 0, 0, 22),
 Size14=UDim2.new(1, 0, 1, -70),
}
T.Layout.SettingsController={
 Size1=Vector2.new(640, 720),
}
T.Layout.ShopController={
 Size1=Vector2.new(840,700),
 Size2=UDim2.new(1,-16,0,52),
 Size3=UDim2.new(0.333,-6,0,44),
 Size4=UDim2.new(1,0,1,-68),
}
T.Layout.SkillTreeUIController={
 Size1=UDim2.fromOffset(62, 62),
 Size2=UDim2.fromOffset(0, 22),
 Size3=UDim2.fromOffset(46, 20),
 Size4=UDim2.new(1, -8, 1, -4),
 Size5=UDim2.fromOffset(104, 27),
 Size6=UDim2.fromOffset(54, 50),
 Size7=UDim2.fromOffset(90, 30),
 Size8=UDim2.fromOffset(26, 26),
 Size9=UDim2.fromOffset(0, 0),
 Size10=UDim2.fromOffset(0, 0),
 Size11=UDim2.fromOffset(0, 0),
 Size12=UDim2.fromOffset(0, 0),
 Size13=UDim2.fromOffset(0, 0),
 Size14=UDim2.fromOffset(0, 0),
 Size15=UDim2.fromOffset(30, 26),
 Size16=UDim2.fromOffset(520, 60),
 Size17=UDim2.fromOffset(560, 128),
 Size18=UDim2.fromOffset(68, 46),
 Size19=UDim2.new(1, -32, 0, 40),
 Size20=UDim2.new(1, -32, 0, 28),
 Size21=UDim2.new(1, -32, 0, 38),
 Size22=UDim2.fromOffset(250, 74),
 Size23=UDim2.fromOffset(470, 22),
}
T.Layout.TitlesController={
 Size1=Vector2.new(820, 640),
 Size2=UDim2.new(1, -10, 0, 86),
 Size3=UDim2.new(1, -250, 0, 36),
 Size4=UDim2.new(0.5, -40, 0, 22),
 Size5=UDim2.new(0.5, -230, 0, 18),
 Size6=UDim2.new(1, 0, 1, 4),
 Size7=UDim2.fromOffset(190, 58),
}
T.Layout.TutorialController={
 Size1=UDim2.fromOffset(72, 72),
 Size2=UDim2.fromOffset(56, 34),
 Size3=UDim2.fromOffset(64, 30),
 Size4=UDim2.fromOffset(5, 16),
 Size5=UDim2.fromOffset(6, 8),
 Size6=UDim2.fromOffset(2, 2),
 Size7=UDim2.fromOffset(9, 5),
 Size8=UDim2.fromOffset(8, 5),
 Size9=UDim2.fromOffset(6, 13),
 Size10=UDim2.new(1, 70, 1, 84),
 Size11=UDim2.fromOffset(20, 20),
 Size12=UDim2.fromOffset(30, 14),
 Size13=UDim2.fromOffset(0, 36),
 Size14=UDim2.fromOffset(52, 30),
 Size15=UDim2.new(1, -36, 0, 54),
 Size16=UDim2.new(1, -32, 0, 46),
 Size17=UDim2.fromOffset(32, 32),
 Size18=UDim2.new(1, -54, 1, -10),
 Size19=UDim2.new(1, -32, 0, 38),
 Size20=Vector2.new(38, 0),
 Size21=UDim2.new(1, -50, 1, -12),
 Size22=UDim2.fromOffset(16, 18),
 Size23=UDim2.fromOffset(12, 4.5),
 Size24=UDim2.new(1, -64, 0, 36),
 Size25=UDim2.new(1, -32, 0, 38),
}
T.Layout.UIShowcaseController={
 Size1=Vector2.new(900,740),
 Size2=UDim2.new(1,-8,0,44),
 Size3=UDim2.new(1,-8,0,52),
 Size4=UDim2.new(1,-8,0,48),
 Size5=UDim2.new(1,-8,0,52),
 Size6=UDim2.fromOffset(92,44),
}
T.Layout.ZoneController={
 Size1=UDim2.fromOffset(340, 78),
}

Settings.Changed:Connect(function(key)
 if key~="ReduceMotion" then return end
 for _,control in pairs(controls) do control.Render() end
 UI.Tween(blur,0.1,{Size=UI.ReducedMotion() and 0 or blurOwner and 12 or 0})
end)
return UI
