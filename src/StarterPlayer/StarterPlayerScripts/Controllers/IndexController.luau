-- IndexController: the 📖 Sushi Index — a collection book of every sushi type.
-- Discovered sushi show a live 3D preview; undiscovered ones are silhouettes.
-- Clicking a card shows its details. Each new discovery gives a permanent KG
-- bonus (RebirthConfig.IndexBonusPerType) and a "NEW SUSHI!" banner.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RarityConfig = require(Shared.Config.RarityConfig)
local SushiCatalog = require(Shared.Config.SushiCatalog)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local NumberFormat = require(Shared.Util.NumberFormat)
local SushiModels = require(Shared.SushiModels)
local UIKit = require(script.Parent.UIKit)
local AnnouncementController = require(script.Parent.AnnouncementController)
local EffectsController = require(script.Parent.EffectsController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local new = UIKit.new

local IndexController = {}

local ACCENT = Color3.fromRGB(95, 185, 255)
local LOCKED = Color3.fromRGB(120, 120, 128)
local CARD_W, CARD_H, COLS = 130, 166, 4

local window
local cards = {}      -- [typeId] = { Frame, Viewport, Model, Name, Count, New, Stroke, Phase }
local unseen = {}     -- [typeId] = true for discoveries not looked at yet
local header = {}
local detail = {}
local selected: string? = nil

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
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
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
	detail.Viewport.ImageColor3 = count and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	detail.Model = model

	detail.Name.Text = count and def.Name or "???"
	detail.Name.TextColor3 = count and (rarity.Order == 1 and Color3.new(1, 1, 1) or rarity.Color) or LOCKED
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
		Size = UDim2.new(0, 262, 1, -74),
		BackgroundColor3 = UIKit.Colors.Row,
	}, body)
	UIKit.Corner(f, 16)
	UIKit.Stroke(f, 3, UIKit.Colors.Outline, true)
	new("UIScale", { Name = "PopScale" }, f)
	detail.Frame = f
	local stage = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 190), BackgroundColor3 = UIKit.Colors.Inner }, f)
	UIKit.Corner(stage, 12)
	UIKit.Stroke(stage, 2.5, UIKit.Colors.Outline, true)
	detail.Viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
	}, stage)
	detail.Name = UIKit.Label(f, { Position = UDim2.fromOffset(10, 208), Size = UDim2.new(1, -20, 0, 34) }, 3)
	local chip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 246), Size = UDim2.fromOffset(150, 28) }, f)
	UIKit.Corner(chip, 14)
	UIKit.Stroke(chip, 2.5, UIKit.Colors.Outline, true)
	detail.RarityChip = chip
	detail.Rarity = UIKit.Label(chip, { Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3) }, 2)
	detail.Weight = UIKit.Label(f, { Position = UDim2.fromOffset(14, 286), Size = UDim2.new(1, -28, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
	detail.Zone = UIKit.Label(f, { Position = UDim2.fromOffset(14, 318), Size = UDim2.new(1, -28, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
	detail.Count = UIKit.Label(f, { Position = UDim2.fromOffset(14, 350), Size = UDim2.new(1, -28, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
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
		c.Viewport.ImageColor3 = Color3.new(1, 1, 1)
		c.Name.Text = night .. def.Name
		c.Name.TextColor3 = Color3.new(1, 1, 1)
		c.Count.Text = "x" .. NumberFormat.Format(count)
		c.Frame.BackgroundColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.45)
		c.Stroke.Color = rarity.Color
	else
		c.Viewport.ImageColor3 = Color3.new(0, 0, 0)
		c.Name.Text = night .. "???"
		c.Name.TextColor3 = Color3.fromRGB(190, 190, 196)
		c.Count.Text = "🔒"
		c.Frame.BackgroundColor3 = Color3.fromRGB(52, 52, 58)
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
		BackgroundColor3 = Color3.fromRGB(52, 52, 58),
	}, parent)
	b:SetAttribute("NoSound", false)
	UIKit.Corner(b, 14)
	local stroke = UIKit.Stroke(b, 3, LOCKED, true)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }, b)
	local vp, model = viewport(b, { Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 0, 104) }, typeId, 5.4)
	local name = UIKit.Label(b, { Position = UDim2.fromOffset(5, 108), Size = UDim2.new(1, -10, 0, 24) }, 2.5)
	local chip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.fromOffset(80, 24), BackgroundColor3 = Color3.fromRGB(35, 35, 40), BackgroundTransparency = 0.25 }, b)
	UIKit.Corner(chip, 12)
	local count = UIKit.Label(chip, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), TextColor3 = Color3.fromRGB(255, 225, 120) }, 2)
	local newTag = new("Frame", { Position = UDim2.fromOffset(-6, -8), Size = UDim2.fromOffset(52, 24), BackgroundColor3 = Color3.fromRGB(235, 55, 55), Visible = false, ZIndex = 3 }, b)
	UIKit.Corner(newTag, 10)
	UIKit.Stroke(newTag, 2.5, UIKit.Colors.Outline, true)
	UIKit.Label(newTag, { Text = "NEW", Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), ZIndex = 3 }, 2)
	local sel = new("Frame", { Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4), BackgroundTransparency = 1, Visible = false, ZIndex = 0 }, b)
	UIKit.Corner(sel, 17)
	UIKit.Stroke(sel, 3, Color3.new(1, 1, 1), true)
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
	window = UIKit.Window({ Name = "Index", Title = "Index", Icon = UIKit.Icons.Index, Accent = ACCENT, Size = Vector2.new(900, 650) })
	local body = window.Body

	-- progress strip
	header.Count = UIKit.Label(body, { Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(230, 34), TextXAlignment = Enum.TextXAlignment.Left }, 3)
	local track = new("Frame", { Position = UDim2.fromOffset(258, 18), Size = UDim2.new(1, -420, 0, 22), BackgroundColor3 = Color3.fromRGB(38, 38, 44) }, body)
	UIKit.Corner(track, 11)
	UIKit.Stroke(track, 3, UIKit.Colors.Outline, true)
	header.Fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, track)
	UIKit.Corner(header.Fill, 11)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(140, 215, 255), Color3.fromRGB(60, 140, 235)) }, header.Fill)
	header.Bonus = UIKit.Label(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 12), Size = UDim2.fromOffset(140, 34), TextXAlignment = Enum.TextXAlignment.Right }, 3)

	-- grid
	local scroll = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -298, 1, -74),
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
			local section = new("Frame", { Name = rarity.Id, LayoutOrder = rarity.Order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, scroll)
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, section)
			local bar = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = rarity.Color }, section)
			UIKit.Corner(bar, 12)
			UIKit.Stroke(bar, 3, UIKit.Colors.Outline, true)
			local grad = new("UIGradient", { Transparency = NumberSequence.new(0, 0.7) }, bar)
			if rarity.Rainbow then
				local keys = {}
				for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.65, 1))) end
				grad.Color = ColorSequence.new(keys)
			end
			header.Sections[rarity.Id] = UIKit.Label(bar, { Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(12, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1) }, 3)
			local row = new("Frame", { LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, section)
			new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4) }, row)
			new("UIGridLayout", { CellSize = UDim2.fromOffset(CARD_W, CARD_H), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder }, row)
			for i, typeId in ipairs(pool) do makeCard(row, typeId, i) end
		end
	end

	buildDetail(body)
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
	end }
	window.OnClose = { function()
		table.clear(unseen)
		for id in pairs(cards) do refreshCard(id) end
	end }
end

-- ===== public =====

function IndexController.Toggle() window.Toggle() end
function IndexController.HasNew(): boolean return next(unseen) ~= nil end

-- ===== "NEW SUSHI!" discovery bubble =====

local INK = Color3.fromRGB(62, 38, 64)
local CREAM = Color3.fromRGB(255, 247, 238)
local PINK = Color3.fromRGB(255, 112, 150)
local MINT = Color3.fromRGB(150, 232, 200)
local SOFT = Color3.fromRGB(110, 90, 118)
local BODY_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)

local POPUP_Y = 62 -- top-right corner, under the Roblox top bar
local popupGui: ScreenGui
local queue = {}
local showing = false

local function ink(parent, thickness: number)
	return new("UIStroke", { Color = INK, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, parent)
end

local function round(parent, r: number)
	return new("UICorner", { CornerRadius = r >= 1 and UDim.new(0, r) or UDim.new(r, 0) }, parent)
end

local function text(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = INK,
	}, parent)
	for k, v in pairs(props) do (l :: any)[k] = v end
	return l
end

local function buildPopup(typeId: string, kg: number?)
	local def = SushiCatalog.Types[typeId]
	local rarity = RarityConfig.ById[def.Rarity]
	local W, H = 460, 108

	local root = new("Frame", {
		Name = "NewSushi",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, W + 40, 0, POPUP_Y), -- starts off-screen on the right
		Size = UDim2.fromOffset(W, H + 30),
		BackgroundTransparency = 1,
	}, popupGui)
	local fit = math.clamp(workspace.CurrentCamera.ViewportSize.X / 1500, 0.52, 0.72)
	local scale = new("UIScale", { Scale = fit }, root)

	-- shadow, tail and body
	local shadow = new("Frame", { Position = UDim2.fromOffset(0, 25), Size = UDim2.fromOffset(W, H), BackgroundColor3 = INK, ZIndex = 1 }, root)
	round(shadow, 30)
	local tail = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(150, 14 + H - 2),
		Size = UDim2.fromOffset(18, 18), Rotation = 45, BackgroundColor3 = CREAM, ZIndex = 2,
	}, root)
	ink(tail, 3.5)
	local body = new("Frame", { Position = UDim2.fromOffset(0, 14), Size = UDim2.fromOffset(W, H), BackgroundColor3 = CREAM, ZIndex = 3 }, root)
	round(body, 30)
	ink(body, 3.5)

	-- sushi portrait
	local circle = new("Frame", {
		Position = UDim2.fromOffset(16, 13), Size = UDim2.fromOffset(82, 82),
		BackgroundColor3 = Color3.fromRGB(255, 226, 234), ZIndex = 4,
	}, body)
	round(circle, 0.5)
	ink(circle, 3)
	local vp = viewport(circle, { Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 1, -12), ZIndex = 5 }, typeId, 4.6)
	vp.Name = "Preview"

	-- name + lines
	text(body, { Text = def.Name, Position = UDim2.fromOffset(112, 16), Size = UDim2.fromOffset(W - 232, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	text(body, { Text = "Added to your Sushi Index", FontFace = BODY_FONT, TextColor3 = SOFT, Position = UDim2.fromOffset(112, 54), Size = UDim2.fromOffset(W - 232, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	local rc = rarity.Color:Lerp(INK, 0.25)
	text(body, {
		RichText = true,
		Text = string.format('<font color="#%s">%s</font>%s', rc:ToHex(), def.Rarity, kg and ("  •  " .. NumberFormat.Format(kg) .. " kg") or ""),
		TextColor3 = SOFT, Position = UDim2.fromOffset(112, 76), Size = UDim2.fromOffset(W - 232, 18),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
	})

	-- bonus badge
	local bShadow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -60, 0.5, 5), Size = UDim2.fromOffset(88, 70), Rotation = 4, BackgroundColor3 = INK, ZIndex = 4 }, body)
	round(bShadow, 16)
	local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -62, 0.5, 0), Size = UDim2.fromOffset(88, 70), Rotation = 4, BackgroundColor3 = MINT, ZIndex = 5 }, body)
	round(badge, 16)
	ink(badge, 3)
	text(badge, { Text = "+" .. math.floor(RebirthConfig.IndexBonusPerType * 100 + 0.5) .. "%", Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 0, 34), ZIndex = 6 })
	text(badge, { Text = "KG", Position = UDim2.fromOffset(4, 42), Size = UDim2.new(1, -8, 0, 16), ZIndex = 6 })

	-- tag
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(104, 16), Size = UDim2.fromOffset(150, 34), Rotation = -6, BackgroundColor3 = PINK, ZIndex = 7 }, root)
	round(tag, 0.5)
	ink(tag, 3)
	text(tag, { Text = "NEW SUSHI!", TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), ZIndex = 8 })

	-- sparkles
	local sparkles = {}
	for _, s in ipairs({
		{ UDim2.fromOffset(-14, 8), 26, Color3.fromRGB(255, 214, 80) },
		{ UDim2.new(1, -6, 0, 10), 18, Color3.fromRGB(255, 140, 180) },
		{ UDim2.new(1, -28, 0, H + 10), 18, Color3.fromRGB(255, 214, 80) },
	}) do
		-- a 4-point sparkle made of two crossed capsules (no font has a reliable ✦ glyph)
		local l = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = s[1], Size = UDim2.fromOffset(s[2], s[2]), ZIndex = 9 }, root)
		for _, sz in ipairs({ UDim2.fromScale(0.26, 1), UDim2.fromScale(1, 0.26) }) do
			local arm = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz, BackgroundColor3 = s[3], ZIndex = 9 }, l)
			round(arm, 0.5)
		end
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), Rotation = 45, BackgroundColor3 = s[3], ZIndex = 9 }, l)
		round(dot, 3)
		table.insert(sparkles, l)
	end
	return root, scale, fit, sparkles
end

local function nextPopup()
	if showing or #queue == 0 then return end
	showing = true
	local item = table.remove(queue, 1)
	local root, scale, fit, sparkles = buildPopup(item.Type, item.KG)
	EffectsController.PlaySound("RareSpawn", 1.25)
	TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(1, -18, 0, POPUP_Y) }):Play()
	for i, sp in ipairs(sparkles) do
		TweenService:Create(sp, TweenInfo.new(0.7 + i * 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 25, Size = sp.Size + UDim2.fromOffset(6, 6) }):Play()
	end
	task.delay(3.2, function()
		local out = TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, root.Size.X.Offset * fit + 40, 0, POPUP_Y) })
		out:Play()
		out.Completed:Wait()
		root:Destroy()
		showing = false
		nextPopup()
	end)
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
	popupGui = new("ScreenGui", { Name = "NewSushiPopup", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12 }, player:WaitForChild("PlayerGui"))
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
		if not window.IsOpen() then return end
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
