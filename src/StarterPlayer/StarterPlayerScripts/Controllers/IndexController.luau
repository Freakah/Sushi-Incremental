local UIKit = require(script.Parent.UIKit)
-- IndexController: the 📖 Sushi Index — a collection book of every sushi type.
-- Discovered sushi show a live 3D preview; undiscovered ones are silhouettes.
-- Clicking a card shows its details. Each new discovery gives a permanent KG
-- bonus (RebirthConfig.IndexBonusPerType) and a "NEW SUSHI!" banner.

local Players = game:GetService("Players")
local TweenService = UIKit.TweenService
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RarityConfig = require(Shared.Config.RarityConfig)
local SushiCatalog = require(Shared.Config.SushiCatalog)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local NumberFormat = require(Shared.Util.NumberFormat)
local SushiModels = require(Shared.SushiModels)
local AnnouncementController = require(script.Parent.AnnouncementController)
local EffectsController = require(script.Parent.EffectsController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local new = UIKit.new

local IndexController = {}

local ACCENT = UIKit.Theme.Currency.Fish.Base
local LOCKED = UIKit.Theme.Colors.Rice.Base
local CARD_W, CARD_H, COLS = 130, 166, 4

local window
local cards = {}      -- [typeId] = { Frame, Viewport, Model, Name, Count, New, Stroke, Phase }
local unseen = {}     -- [typeId] = true for discoveries not looked at yet
local header = {}
local detail = {}
local selected: string? = nil
local mobileDetail=false
local gridScroll=nil
local detailScroll=nil
local detailBack=nil

local function discovered(typeId: string): number?
	return player:GetAttribute("Idx_" .. typeId)
end

local function totalTypes(): number
	local n = 0
	for _ in pairs(SushiCatalog.Types) do n += 1 end
	return n
end

local function zoneName(zoneId: string): string
	local z = ZoneConfig.ById[zoneId]
	return z and (z.Icon .. " " .. z.Name) or zoneId
end

-- a clean display copy of a sushi (no pillar, labels, particles or lights)
local function previewModel(typeId: string): Model
	local model = SushiModels.Build(typeId)
	model:ScaleTo(1)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Highlight") or d:IsA("Attachment") then
			d:Destroy()
		elseif d:IsA("BasePart") and (d.Name == "Pillar" or d.Name == "Ring") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.new())
	return model
end

local function viewport(parent, props, typeId: string, distance: number)
	local vp = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = UIKit.Theme.Colors.Rice.Base,
		LightColor = UIKit.Theme.White,
		LightDirection = Vector3.new(-0.4, -1, 0.6),
	}, parent)
	for k, v in pairs(props) do (vp :: any)[k] = v end
	local model = previewModel(typeId)
	model.Parent = vp
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, distance * 0.45, -distance), Vector3.new(0, 0.9, 0))
	vp.CurrentCamera = cam
	return vp, model
end

-- ===== detail panel =====

local function showDetail(typeId: string)
	if gridScroll and window.Frame.AbsoluteSize.X<700 then mobileDetail=true;gridScroll.Visible=false;detailScroll.Visible=true;detailBack.Button.Visible=true end
	selected = typeId
	local def = SushiCatalog.Types[typeId]
	local rarity = RarityConfig.ById[def.Rarity]
	local count = discovered(typeId)
	unseen[typeId] = nil
	if cards[typeId] then cards[typeId].New.Visible = false end

	if detail.Model then detail.Model:Destroy() end
	detail.Viewport:ClearAllChildren()
	local model = previewModel(typeId)
	model.Parent = detail.Viewport
	local cam = new("Camera", { FieldOfView = 40 }, detail.Viewport)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 2.6, -5.8), Vector3.new(0, 0.9, 0))
	detail.Viewport.CurrentCamera = cam
	detail.Viewport.ImageColor3 = count and UIKit.Theme.White or UIKit.Theme.Ink
	detail.Model = model

	detail.Name.Text = count and def.Name or "???"
	detail.Name.TextColor3 = count and (rarity.Order == 1 and UIKit.Theme.White or rarity.Color) or LOCKED
	detail.Rarity.Text = string.upper(rarity.Id)
	detail.RarityChip.BackgroundColor3 = rarity.Color
	local zone = ZoneConfig.ById[def.Zone]
	local kgMult = zone and zone.KGMultiplier or 1
	detail.Weight.Text = "⚖️ " .. (count
		and (NumberFormat.Format(rarity.MinKG * kgMult) .. " – " .. NumberFormat.Format(rarity.MaxKG * kgMult) .. " kg")
		or "??? kg")
	detail.Zone.Text = "📍 " .. zoneName(def.Zone)
	detail.Count.Text = count and ("🍣 Collected x" .. NumberFormat.Format(count)) or "🔒 Not found yet"

	for id, c in pairs(cards) do
		c.Selected.Visible = id == typeId
	end
	local sc = detail.Frame:FindFirstChild("PopScale")
	if sc then
		sc.Scale = 0.94
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local function buildDetail(body: Frame)
	local f = new("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 62),
		Size = UIKit.Theme.Layout.IndexController.Size1,
		BackgroundColor3 = UIKit.Colors.Row,
	}, body)
	UIKit.Corner(f, 16)
	UIKit.Stroke(f, 3, UIKit.Colors.Outline, true)
	new("UIScale", { Name = "PopScale" }, f)
	detail.Frame = f
	local stage = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UIKit.Theme.Layout.IndexController.Size2, BackgroundColor3 = UIKit.Colors.Inner }, f)
	UIKit.Corner(stage, 12)
	UIKit.Stroke(stage, 2.5, UIKit.Colors.Outline, true)
	detail.Viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = UIKit.Theme.Colors.Rice.Base,
		LightColor = UIKit.Theme.White,
		LightDirection = Vector3.new(-0.4, -1, 0.6),
	}, stage)
	detail.Name = UIKit.Label(f, { Position = UDim2.fromOffset(10, 208), Size = UIKit.Theme.Layout.IndexController.Size3 }, 3)
	local chip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 246), Size = UIKit.Theme.Layout.IndexController.Size4 }, f)
	UIKit.Corner(chip, 14)
	UIKit.Stroke(chip, 2.5, UIKit.Colors.Outline, true)
	detail.RarityChip = chip
	detail.Rarity = UIKit.Label(chip, { Size = UIKit.Theme.Layout.IndexController.Size5, Position = UDim2.fromOffset(6, 3) }, 2)
	detail.Weight = UIKit.Label(f, { Position = UDim2.fromOffset(14, 286), Size = UIKit.Theme.Layout.IndexController.Size6, TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
	detail.Zone = UIKit.Label(f, { Position = UDim2.fromOffset(14, 318), Size = UIKit.Theme.Layout.IndexController.Size7, TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
	detail.Count = UIKit.Label(f, { Position = UDim2.fromOffset(14, 350), Size = UIKit.Theme.Layout.IndexController.Size8, TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
end

-- ===== cards =====

local function refreshCard(typeId: string)
	local c = cards[typeId]
	if not c then return end
	local def = SushiCatalog.Types[typeId]
	local rarity = RarityConfig.ById[def.Rarity]
	local count = discovered(typeId)
	local night = def.Zone ~= "Starter" and (ZoneConfig.ById[def.Zone] and ZoneConfig.ById[def.Zone].Icon .. " " or "") or ""
	if count then
		c.Viewport.ImageColor3 = UIKit.Theme.White
		c.Name.Text = night .. def.Name
		c.Name.TextColor3 = UIKit.Theme.White
		c.Count.Text = "x" .. NumberFormat.Format(count)
		c.Frame.BackgroundColor3 = rarity.Color:Lerp(UIKit.Theme.Ink, 0.45)
		c.Stroke.Color = rarity.Color
	else
		c.Viewport.ImageColor3 = UIKit.Theme.Ink
		c.Name.Text = night .. "???"
		c.Name.TextColor3 = UIKit.Theme.Muted
		c.Count.Text = "🔒"
		c.Frame.BackgroundColor3 = UIKit.Theme.Colors.Rice.Dark
		c.Stroke.Color = LOCKED
	end
	c.New.Visible = unseen[typeId] == true
end

local function makeCard(parent, typeId: string, order: number)
	local b = new("TextButton", {
		Name = typeId,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		BackgroundColor3 = UIKit.Theme.Colors.Rice.Dark,
	}, parent)
	b:SetAttribute("NoSound", false)
	UIKit.Corner(b, 14)
	local stroke = UIKit.Stroke(b, 3, LOCKED, true)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Theme.White, UIKit.Theme.Colors.Rice.Base) }, b)
	local vp, model = viewport(b, { Position = UDim2.fromOffset(5, 4), Size = UIKit.Theme.Layout.IndexController.Size9 }, typeId, 5.4)
	local name = UIKit.Label(b, { Position = UDim2.fromOffset(5, 108), Size = UIKit.Theme.Layout.IndexController.Size10 }, 2.5)
	local chip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UIKit.Theme.Layout.IndexController.Size11, BackgroundColor3 = UIKit.Theme.Muted, BackgroundTransparency = 0.25 }, b)
	UIKit.Corner(chip, 12)
	local count = UIKit.Label(chip, { Size = UIKit.Theme.Layout.IndexController.Size12, Position = UDim2.fromOffset(4, 2), TextColor3 = UIKit.Theme.Colors.Accent.Base }, 2)
	local newTag = new("Frame", { Position = UDim2.fromOffset(-6, -8), Size = UIKit.Theme.Layout.IndexController.Size13, BackgroundColor3 = UIKit.Theme.Colors.Danger.Base, Visible = false, ZIndex = 3 }, b)
	UIKit.Corner(newTag, 10)
	UIKit.Stroke(newTag, 2.5, UIKit.Colors.Outline, true)
	UIKit.Label(newTag, { Text = "NEW", Size = UIKit.Theme.Layout.IndexController.Size14, Position = UDim2.fromOffset(3, 2), ZIndex = 3 }, 2)
	local sel = new("Frame", { Size = UIKit.Theme.Layout.IndexController.Size15, Position = UDim2.fromOffset(-4, -4), BackgroundTransparency = 1, Visible = false, ZIndex = 0 }, b)
	UIKit.Corner(sel, 17)
	UIKit.Stroke(sel, 3, UIKit.Theme.White, true)
	UIKit.SkinCardButton(b)
	UIKit.Animate(b, 1.06)
	b.Activated:Connect(function() showDetail(typeId) end)
	cards[typeId] = { Frame = b, Viewport = vp, Model = model, Name = name, Count = count, New = newTag, Stroke = stroke, Selected = sel, Phase = math.random() * 6 }
	refreshCard(typeId)
end

local function refreshHeader()
	local n = player:GetAttribute("IndexCount") or 0
	local total = totalTypes()
	header.Count.Text = 'Discovered <font color="#FFE17A">' .. n .. " / " .. total .. "</font>"
	header.Bonus.Text = '<font color="#6EFF6E">+' .. math.floor(n * RebirthConfig.IndexBonusPerType * 100 + 0.5) .. "% KG</font>"
	TweenService:Create(header.Fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(n / total, 0, 1), 1) }):Play()
	for _, r in ipairs(RarityConfig.List) do
		local h = header.Sections[r.Id]
		if h then
			local got, all = 0, 0
			for _, id in ipairs(SushiCatalog.Pools[r.Id] or {}) do
				all += 1
				if discovered(id) then got += 1 end
			end
			h.Text = string.upper(r.Id) .. '  <font color="#FFFFFF">' .. got .. "/" .. all .. "</font>"
		end
	end
end

local function build()
	window = UIKit.Window({ Name = "Index", Title = "Index", Icon = "📖", Accent = ACCENT, Size = UIKit.Theme.Layout.IndexController.Size16 })
	local body = window.Body

	-- progress strip
	header.Count = UIKit.Label(body, { Position = UDim2.fromOffset(18, 12), Size = UIKit.Theme.Layout.IndexController.Size17, TextXAlignment = Enum.TextXAlignment.Left }, 3)
	local track = new("Frame", { Position = UDim2.fromOffset(258, 18), Size = UIKit.Theme.Layout.IndexController.Size18, BackgroundColor3 = UIKit.Theme.Muted }, body)
	UIKit.Corner(track, 11)
	UIKit.Stroke(track, 3, UIKit.Colors.Outline, true)
	header.Fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UIKit.Theme.White }, track)
	UIKit.Corner(header.Fill, 11)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Theme.Currency.Fish.Base, UIKit.Theme.Currency.Fish.Base) }, header.Fill)
	header.Bonus = UIKit.Label(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 12), Size = UIKit.Theme.Layout.IndexController.Size19, TextXAlignment = Enum.TextXAlignment.Right }, 3)

	-- grid
	local scroll = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(12, 62),
		Size = UIKit.Theme.Layout.IndexController.Size20,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = ACCENT,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, body)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12) }, scroll)
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	header.Sections = {}
	for _, rarity in ipairs(RarityConfig.List) do
		local pool = SushiCatalog.Pools[rarity.Id]
		if pool then
			local section = new("Frame", { Name = rarity.Id, LayoutOrder = rarity.Order, BackgroundTransparency = 1, Size = UIKit.Theme.Layout.IndexController.Size21, AutomaticSize = Enum.AutomaticSize.Y }, scroll)
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, section)
			local bar = new("Frame", { LayoutOrder = 1, Size = UIKit.Theme.Layout.IndexController.Size22, BackgroundColor3 = rarity.Color }, section)
			UIKit.Corner(bar, 12)
			UIKit.Stroke(bar, 3, UIKit.Colors.Outline, true)
			local grad = new("UIGradient", { Transparency = NumberSequence.new(0, 0.7) }, bar)
			if rarity.Rainbow then
				local keys = {}
				for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.65, 1))) end
				grad.Color = ColorSequence.new(keys)
			end
			header.Sections[rarity.Id] = UIKit.Label(bar, { Size = UIKit.Theme.Layout.IndexController.Size23, Position = UDim2.fromOffset(12, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Theme.White }, 3)
			local row = new("Frame", { LayoutOrder = 2, BackgroundTransparency = 1, Size = UIKit.Theme.Layout.IndexController.Size24, AutomaticSize = Enum.AutomaticSize.Y }, section)
			new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4) }, row)
			new("UIGridLayout", { CellSize = UDim2.fromOffset(CARD_W, CARD_H), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder }, row)
			for i, typeId in ipairs(pool) do makeCard(row, typeId, i) end
		end
	end

	buildDetail(body)
	gridScroll=scroll
	detailScroll=new("ScrollingFrame",{Name="MobileDetail",BackgroundTransparency=1,Position=UDim2.fromOffset(8,108),Size = UIKit.Theme.Layout.IndexController.Size25,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=8,Visible=false},body)
	detailBack=UIKit.Secondary(body,{Label="Back to collection",Position=UDim2.fromOffset(8,58),Size = UIKit.Theme.Layout.IndexController.Size26,Visible=false},function() mobileDetail=false;scroll.Visible=true;detailScroll.Visible=false;detailBack.Button.Visible=false end)
	local function layout(phone)
		local width=body.AbsoluteSize.X
		local gridWidth=phone and width-32 or width-310
		for _,section in ipairs(scroll:GetChildren()) do
			if section:IsA("Frame") then for _,row in ipairs(section:GetChildren()) do local grid=row:FindFirstChildOfClass("UIGridLayout");if grid then local cols=math.max(1,math.floor(gridWidth/140));grid.CellSize=UDim2.fromOffset(math.floor((gridWidth-(cols-1)*10)/cols),166) end end end
		end
		header.Count.Size=UDim2.new(phone and 0.65 or 0.4,-12,0,34);header.Count.Position=UDim2.fromOffset(8,8)
		header.Bonus.Size=UDim2.new(phone and 0.35 or 0.2,-12,0,34)
		header.Fill.Parent.Visible=not phone
		if phone then
			scroll.Size = UIKit.Theme.Layout.IndexController.Size27
			detail.Frame.Parent=detailScroll;detail.Frame.AnchorPoint=Vector2.zero;detail.Frame.Position=UDim2.fromOffset(4,4);detail.Frame.Size = UIKit.Theme.Layout.IndexController.Size28
			scroll.Visible=not mobileDetail;detailScroll.Visible=mobileDetail;detailBack.Button.Visible=mobileDetail
		else
			detail.Frame.Parent=body;detail.Frame.AnchorPoint=Vector2.new(1,0);detail.Frame.Position=UDim2.new(1,-12,0,62);detail.Frame.Size = UIKit.Theme.Layout.IndexController.Size29
			scroll.Size = UIKit.Theme.Layout.IndexController.Size30;scroll.Visible=true;detailScroll.Visible=false;detailBack.Button.Visible=false
		end
	end
	table.insert(window.OnLayout,layout)
	window.Layout()
	window.OnOpen = { function()
		refreshHeader()
		scroll.CanvasPosition = Vector2.zero
		-- open on the newest discovery, otherwise the current selection / first card
		local pick = next(unseen) or selected
		if not pick then
			for _, r in ipairs(RarityConfig.List) do
				local pool = SushiCatalog.Pools[r.Id]
				if pool and pool[1] then pick = pool[1] break end
			end
		end
		if pick then showDetail(pick) end
		if window.Frame.AbsoluteSize.X<700 then mobileDetail=false;scroll.Visible=true;detailScroll.Visible=false;detailBack.Button.Visible=false end
	end }
	window.OnClose = { function()
		table.clear(unseen)
		for id in pairs(cards) do refreshCard(id) end
	end }
end

-- ===== public =====

function IndexController.Toggle() window.Toggle() end
function IndexController.HasNew(): boolean return next(unseen) ~= nil end

-- Discovery celebrations share the UI feedback layer.
local queue={}
local showing=false

local function nextPopup()
 if showing or #queue==0 then return end
 showing=true
 local item=table.remove(queue,1)
 local def=SushiCatalog.Types[item.Type]
 local rarity=RarityConfig.ById[def.Rarity]
 UIKit.Celebrate("NEW SUSHI!",def.Name.." • "..rarity.Id.." • +"..math.floor(RebirthConfig.IndexBonusPerType*100+0.5).."% KG",rarity.Color)
 task.delay(2.8,function() showing=false;nextPopup() end)
end

local function onNewDiscovery(typeId: string, kg: number?)
	local def = SushiCatalog.Types[typeId]
	if not def then return end
	table.insert(queue, { Type = typeId, KG = kg })
	nextPopup()
	unseen[typeId] = true
	refreshCard(typeId)
end

function IndexController.Init()
	build()

	for typeId in pairs(SushiCatalog.Types) do
		player:GetAttributeChangedSignal("Idx_" .. typeId):Connect(function()
			refreshCard(typeId)
			if selected == typeId and window.IsOpen() then showDetail(typeId) end
		end)
	end
	player:GetAttributeChangedSignal("IndexCount"):Connect(refreshHeader)
	refreshHeader()
	Remotes.NewDiscovery.OnClientEvent:Connect(onNewDiscovery)

	-- previews sway on the cards and spin in the detail panel while open
	RunService.RenderStepped:Connect(function()
		if not window.IsOpen() or UIKit.ReducedMotion() then return end
		local t = os.clock()
		for typeId, c in pairs(cards) do
			if discovered(typeId) then
				c.Model:PivotTo(CFrame.Angles(0, math.sin(t * 1.2 + c.Phase) * 0.6, 0))
			end
		end
		if detail.Model and detail.Model.Parent then
			detail.Model:PivotTo(CFrame.Angles(0, t * 1.2, 0))
		end
	end)
end

return IndexController
