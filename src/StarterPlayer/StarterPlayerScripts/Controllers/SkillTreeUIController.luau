local UIKit = require(script.Parent.UIKit)
-- SkillTreeUIController: the Skill Tree menu (🌳 Skills button on the left of the HUD).
--   * full-screen hex grid over a dimmed game, START in the middle, 6 branches around it
--   * each hex: icon, short name, level pill (0/5); a price above the hexes you can buy next
--     (green = you can afford it, red = not yet); locked hexes are dimmed
--   * drag to move, mouse wheel / pinch to zoom, hover (or first tap on mobile) for details,
--     click / second tap to buy one level. Gamepad: D-pad to select, A to buy, B to exit.
--   * buying works from anywhere (server checks prerequisites, level and cash)
--   * animated: hexes pop in ring by ring, buyable hexes breathe, icons bob, energy flows
--     along unlocked lines, purchases burst, maxing a skill lights up the next lines

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = UIKit.TweenService
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local MenuManager = require(script.Parent.MenuManager)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer
local SkillTreeUIController = {}

local SQRT3 = math.sqrt(3)
local HEX_R = 58          -- drawn hex radius (centre -> corner), px
local CELL_R = 80         -- layout radius (bigger = more gap between hexes)
local BORDER = 5
local ZOOM_MIN, ZOOM_MAX = 0.35, 1.6
local DRAG_START = 8      -- px before a press becomes a drag
local LINE_W = 22

-- Uploaded art (rbxassetid). Empty = drawn fallback.
--   Hex: the hexagon used for every skill.  Lines: the bar connecting skills, one per branch colour.
local ART = {
	Hex = "",
	Lines = {
		Value = "rbxassetid://136357637342362",    -- pink
		Cash = "rbxassetid://75676403358018",      -- green
		Spawn = "rbxassetid://105997269561860",    -- blue
		Capacity = "rbxassetid://136884099137373", -- orange
		Luck = "rbxassetid://134339078559114",     -- purple
		Rebirth = "rbxassetid://99721386642861",   -- yellow
	},
	LineSlice = Rect.new(48, 24, 912, 72), -- 960x96 bar: keep the rounded ends, stretch the middle
	-- skill pictures: one 1024x1024 sheet, 7 icons per row in 146 px cells (index = Art in SkillTreeConfig)
	IconSheet = "rbxassetid://115909316479466", -- SkillIcons_Sheet2 (42 icons)
	IconCell = 146,
	IconCols = 7,
	-- hexagon frames: one 1024x1024 sheet, 3 per row in 341 px steps (340 px hexes)
	HexSheet = "", -- SkillHexes_Sheet
	HexStep = 341,
	HexSize = 340,
	HexIndex = { Spawn = 0, Capacity = 1, Luck = 2, Rebirth = 3, Value = 4, Cash = 5 }, -- blue, orange, purple, yellow, red, green
	HexLocked = 6, -- dark frame for undiscovered skills
	HexStart = 7,  -- silver frame for Start
	LockArt = 23,  -- padlock on undiscovered (???) skills
	StartArt = 9,  -- nigiri on Start
	CashArt = 13,  -- coin next to prices
	-- hexagon used once a skill has at least 1 level, per branch colour (Hex above = not unlocked yet)
	HexUnlocked = {
		Value = "rbxassetid://133847457083978",    -- pink
		Cash = "rbxassetid://100195133230174",     -- green
		Spawn = "rbxassetid://96092876929792",     -- blue
		Capacity = "rbxassetid://89848440504759",  -- orange
		Luck = "rbxassetid://137267426274281",     -- purple
		Rebirth = "rbxassetid://121639582623916",  -- yellow
	},
}

local COL = {
	Fill = UIKit.Theme.Colors.Rice.Dark,
	FillLocked = UIKit.Theme.Colors.Rice.Dark,
	BorderLocked = UIKit.Theme.Ink,
	Maxed = UIKit.Theme.Colors.Primary.Base,
	LineOff = UIKit.Theme.Colors.Rice.Dark,
	Afford = UIKit.Theme.Colors.Success.Base,
	NoAfford = UIKit.Theme.Colors.Danger.Base,
	Text = UIKit.Theme.White,
	Dim = UIKit.Theme.Muted,
	PillBg = UIKit.Theme.Colors.Rice.Dark,
}

local gui: ScreenGui
local world: Frame
local zoomScale: UIScale
local tooltip: Frame
local tipScale: UIScale
local tipBase = 1
local isOpen = false
local dirty = true
local openedAt = 0
local views: { [string]: any } = {}
local startView: any
local lines = {}
local pan = Vector2.zero
local zoom = 1
local hoveredId: string? = nil
local selectedId: string? = nil -- touch: first tap selects, second tap buys; gamepad: cursor
local buying = false
local lastInput = "mouse"

-- ===== helpers =====

local function money(): number return player:GetAttribute("Money") or 0 end
local function levelOf(id: string): number return player:GetAttribute(SkillTreeConfig.LevelAttribute(id)) or 0 end
local function levels()
	local t = {}
	for _, n in ipairs(SkillTreeConfig.List) do
		local l = levelOf(n.Id)
		if l > 0 then t[n.Id] = l end
	end
	return t
end

local function hexToPixel(q: number, r: number): Vector2
	return Vector2.new(SQRT3 * CELL_R * (q + r / 2), 1.5 * CELL_R * r)
end

local function pixelToHex(p: Vector2): (number, number)
	local x = (SQRT3 / 3 * p.X - p.Y / 3) / CELL_R
	local z = (2 / 3 * p.Y) / CELL_R
	local y = -x - z
	local rx, ry, rz = math.round(x), math.round(y), math.round(z)
	local dx, dy, dz = math.abs(rx - x), math.abs(ry - y), math.abs(rz - z)
	if dx > dy and dx > dz then
		rx = -ry - rz
	elseif dy <= dz then
		rz = -rx - ry
	end
	return rx, rz
end

local function ringOf(q: number, r: number): number
	return (math.abs(q) + math.abs(r) + math.abs(-q - r)) / 2
end

local byPos: { [string]: string } = {}
for _, n in ipairs(SkillTreeConfig.List) do byPos[n.Q .. "," .. n.R] = n.Id end

local function darker(c: Color3, f: number): Color3 return Color3.new(c.R * f, c.G * f, c.B * f) end
local function branchColor(node): Color3
	local b = SkillTreeConfig.BranchById[node.Branch]
	return b and b.Color or UIKit.Theme.Colors.Rice.Base
end

local function tween(obj, t: number, props, style, dir)
	return UIKit.Tween(obj, math.min(t,0.35), props, style, dir)
end

-- a pointy-top hexagon made of 3 rotated rectangles
local function hexShape(parent: Instance, radius: number, color: Color3, name: string, z: number)
	local holder = UIKit.new("Frame", {
		Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius * 2, radius * 2), ZIndex = z,
	}, parent)
	local parts = {}
	for i = 0, 2 do
		local f = UIKit.new("Frame", {
			Name = "Part" .. i, BorderSizePixel = 0, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SQRT3 * radius, radius), Rotation = i * 60, ZIndex = z,
		}, holder)
		table.insert(parts, f)
	end
	local api = { Holder = holder, Parts = parts }
	function api.SetColor(c: Color3) for _, f in ipairs(parts) do f.BackgroundColor3 = c end end
	function api.SetTransparency(t: number) for _, f in ipairs(parts) do f.BackgroundTransparency = t end end
	return api
end

-- the uploaded hexagon image (same API as hexShape); falls back to the drawn hexagon
local function hexImage(parent: Instance, radius: number, name: string, z: number, color: Color3?)
	if ART.Hex == "" then return hexShape(parent, radius, color or COL.Fill, name, z) end
	local img = UIKit.new("ImageLabel", {
		Name = name, BackgroundTransparency = 1, Image = ART.Hex, ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 2, radius * 2), ZIndex = z, ImageColor3 = color or UIKit.Theme.White,
	}, parent)
	local api = { Holder = img, Image = true }
	function api.SetColor(c: Color3) img.ImageColor3 = c end
	function api.SetImage(id: string) if img.Image ~= id then img.Image = id end end
	function api.SetHex(i: number)
		if ART.HexSheet == "" then return end
		img.Image = ART.HexSheet
		img.ImageRectOffset = Vector2.new((i % 3) * ART.HexStep, math.floor(i / 3) * ART.HexStep)
		img.ImageRectSize = Vector2.new(ART.HexSize, ART.HexSize)
	end
	function api.SetTransparency(t: number) img.ImageTransparency = t end
	return api
end

-- shows a sheet picture (art index) when the sheet is uploaded, otherwise the emoji
local function setIcon(label: TextLabel, img: ImageLabel, art: number?, emoji: string)
	if art and ART.IconSheet ~= "" then
		local cell = ART.IconCell
		img.Image = ART.IconSheet
		img.ImageRectOffset = Vector2.new((art % ART.IconCols) * cell, math.floor(art / ART.IconCols) * cell)
		img.ImageRectSize = Vector2.new(cell, cell)
		img.Visible = true
		label.Text = ""
	else
		img.Visible = false
		label.Text = emoji
	end
end

local function iconImage(parent: Instance, scale: number)
	return UIKit.new("ImageLabel", {
		Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale, scale), SizeConstraint = Enum.SizeConstraint.RelativeYY, ScaleType = Enum.ScaleType.Fit,
		Visible = false, ZIndex = 7,
	}, parent)
end

-- ===== build =====

local function buildHex(root: Frame)
	-- soft drop shadow, coloured glow (breathes), rim, the hex art, then the content
	local shadow = hexImage(root, HEX_R + BORDER, "Shadow", 1, UIKit.Theme.Ink)
	shadow.Holder.Position = UDim2.new(0.5, 0, 0.5, 7)
	shadow.SetTransparency(0.5)
	local glow = hexShape(root, HEX_R + BORDER + 9, COL.Maxed, "Glow", 2)
	glow.SetTransparency(1)
	local border = hexShape(root, HEX_R + BORDER, COL.BorderLocked, "Border", 3)
	local fill = hexImage(root, HEX_R + 1, "Fill", 4)
	-- shine: a white copy of the hex shape, only visible inside a moving diagonal band
	local shine = hexImage(root, HEX_R + 1, "Shine", 5, UIKit.Theme.White)
	shine.SetTransparency(0.25)
	local shineGrad = UIKit.new("UIGradient", {
		Rotation = 25,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
	}, shine.Holder)
	shine.Holder.Visible = false
	if ART.HexSheet ~= "" then
		if shadow.SetHex then shadow.SetHex(ART.HexLocked) end
		if shine.SetHex then shine.SetHex(ART.HexLocked) end
		if fill.SetHex then fill.SetHex(ART.HexLocked) end
		border.SetTransparency(1)
	end
	-- content (its own holder so it can bob without moving the hex)
	local content = UIKit.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, root)
	return { Shadow = shadow, Glow = glow, Border = border, Fill = fill, Shine = shine.Holder, ShineGrad = shineGrad, Content = content }
end

local function buildNodeView(node)
	local pos = hexToPixel(node.Q, node.R)
	local size = HEX_R * 2 + BORDER * 2
	local root = UIKit.new("Frame", {
		Name = node.Id, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size, size), ZIndex = 2,
	}, world:FindFirstChild("Nodes"))
	local pop = UIKit.new("UIScale", { Name = "Pop" }, root)
	local parts = buildHex(root)
	local content = parts.Content

	local icon = UIKit.Label(content, {
		Name = "Icon", Text = node.Icon, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47), Size = UIKit.Theme.Layout.SkillTreeUIController.Size1, ZIndex = 7,
	}, 0)
	local iconImg = iconImage(icon, 1)
	-- name written over the picture (white with a dark outline)
	local name = UIKit.Label(content, {
		Name = "Name", Text = node.Name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromOffset(SQRT3 * HEX_R * 0.7, 34), TextWrapped = true, ZIndex = 9,
	}, 2.5)
	-- price tag inside the hex: just the amount
	local priceTag = UIKit.new("Frame", {
		Name = "PriceTag", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.71),
		Size = UDim2.fromOffset(SQRT3 * HEX_R * 0.72, 22), ZIndex = 9, Visible = false,
	}, content)
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
	}, priceTag)
	local priceText = UIKit.new("TextLabel", {
		Name = "Amount", BackgroundTransparency = 1, LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UIKit.Theme.Layout.SkillTreeUIController.Size2,
		Font = UIKit.Font, TextSize = 17, TextColor3 = UIKit.Theme.White, Text = "", ZIndex = 9,
	}, priceTag)
	UIKit.Stroke(priceText, 2.2, UIKit.Theme.Ink)
	-- level pill
	local pill = UIKit.new("Frame", {
		Name = "LevelPill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, size * 0.42 + 32),
		Size = UIKit.Theme.Layout.SkillTreeUIController.Size3, BackgroundColor3 = COL.PillBg, BackgroundTransparency = 0.15, ZIndex = 7,
	}, content)
	UIKit.Corner(pill, 10)
	local pillStroke = UIKit.Stroke(pill, 2, COL.BorderLocked, true)
	local level = UIKit.Label(pill, {
		Name = "Level", Text = "0/" .. node.Max, Position = UDim2.fromOffset(4, 2), Size = UIKit.Theme.Layout.SkillTreeUIController.Size4, ZIndex = 8,
	}, 1.5)
	local priceY = pos.Y - HEX_R - BORDER + 4
	local price = UIKit.Label(world:FindFirstChild("Prices"), {
		Name = node.Id, Text = "", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(pos.X, priceY), Size = UIKit.Theme.Layout.SkillTreeUIController.Size5, ZIndex = 3, Visible = false,
	}, 3)
	views[node.Id] = {
		Node = node, Root = root, Pop = pop, Pos = pos, Ring = ringOf(node.Q, node.R), Phase = math.random() * math.pi * 2,
		Glow = parts.Glow, Border = parts.Border, Fill = parts.Fill, Shadow = parts.Shadow, Content = content,
		Shine = parts.Shine, ShineGrad = parts.ShineGrad,
		Icon = icon, IconImg = iconImg, Name = name, PriceTag = priceTag, PriceText = priceText, Level = level, Pill = pill, PillStroke = pillStroke, Price = price, PriceBase = priceY,
		Hover = 0, PopUntil = 0,
	}
end

local function buildStart()
	local size = HEX_R * 2 + BORDER * 2
	local root = UIKit.new("Frame", {
		Name = "START", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(size, size), ZIndex = 2,
	}, world:FindFirstChild("Nodes"))
	local pop = UIKit.new("UIScale", { Name = "Pop" }, root)
	local parts = buildHex(root)
	if ART.HexSheet ~= "" and parts.Fill.SetHex then parts.Fill.SetHex(ART.HexStart) end
	parts.Border.SetColor(UIKit.Theme.White)
	parts.Glow.SetColor(UIKit.Theme.White)
	if not parts.Fill.Image then parts.Fill.SetColor(UIKit.Theme.Colors.Rice.Dark) end
	local icon = UIKit.Label(parts.Content, { Name = "Icon", Text = "🍣", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, size * 0.36), Size = UIKit.Theme.Layout.SkillTreeUIController.Size6, ZIndex = 7 }, 0)
	setIcon(icon, iconImage(icon, 1), ART.StartArt, "🍣")
	UIKit.Label(parts.Content, { Name = "Name", Text = "Start", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, size * 0.36 + 26), Size = UIKit.Theme.Layout.SkillTreeUIController.Size7, ZIndex = 7 }, 3)
	startView = { Root = root, Pop = pop, Glow = parts.Glow, Content = parts.Content, Icon = icon, Ring = 0 }
end

local function buildLines()
	local holder = world:FindFirstChild("Lines")
	for _, node in ipairs(SkillTreeConfig.List) do
		for _, p in ipairs(node.Prereqs) do
			local from = if p == "START" then Vector2.zero else hexToPixel(SkillTreeConfig.ById[p].Q, SkillTreeConfig.ById[p].R)
			local to = hexToPixel(node.Q, node.R)
			local d = to - from
			local art = "" -- Connections use the shared code-built theme
			local props = {
				Name = (p .. ">" .. node.Id), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2),
				Size = UDim2.fromOffset(d.Magnitude, LINE_W), Rotation = math.deg(math.atan2(d.Y, d.X)), ZIndex = 1,
			}
			local f
			if art ~= "" then
				props.BackgroundTransparency = 1
				props.Image = art
				props.ScaleType = Enum.ScaleType.Slice
				props.SliceCenter = ART.LineSlice
				props.SliceScale = LINE_W / 96
				f = UIKit.new("ImageLabel", props, holder)
			else
				props.BackgroundColor3 = COL.LineOff
				f = UIKit.new("Frame", props, holder)
				UIKit.Corner(f, LINE_W // 2)
			end
			-- energy that flows from the unlocked skill toward the next one
			local spark = UIKit.new("Frame", {
				Name = "Spark", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.42),
				Size = UDim2.fromOffset(28, LINE_W * 0.3), BackgroundColor3 = UIKit.Theme.White, BackgroundTransparency = 1,
				BorderSizePixel = 0, ZIndex = 2,
			}, f)
			UIKit.Corner(spark, 6)
			UIKit.new("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			}, spark)
			table.insert(lines, {
				Frame = f, Spark = spark, From = p, To = node.Id, Image = art ~= "", Length = d.Magnitude, Size = props.Size,
				Ring = if p == "START" then 0 else ringOf(SkillTreeConfig.ById[p].Q, SkillTreeConfig.ById[p].R),
				Phase = math.random(), Lit = false,
			})
		end
	end
end

-- ===== state / refresh =====

local function stateOf(id: string, lv): string
	return SkillTreeConfig.GetState(id, lv, player:GetAttribute("TotalRebirths") or 0)
end

local bestId: string? = nil
local recommend: TextLabel
local ambience: any = {}

local function refresh()
	dirty = false
	local lv = levels()
	local cash = money()
	-- what each skill shows:
	--   "Shown"  = you can buy it / own it
	--   "Hidden" (??? hex) = the very next skill after one you can buy
	--   "Gone"   = further away: not drawn at all until the skill before it is bought
	local states = {}
	for id in pairs(views) do states[id] = stateOf(id, lv) end
	for id, v in pairs(views) do
		local node = v.Node
		local lvl = lv[id] or 0
		local state = states[id]
		local bc = branchColor(node)
		local vis = "Shown"
		if state == "Locked" then
			vis = "Gone"
			for _, p in ipairs(node.Prereqs) do
				if p ~= "START" and states[p] ~= "Locked" then vis = "Hidden" break end
			end
		end
		local wasGone = v.Vis == "Gone"
		v.Vis = vis
		v.Root.Visible = vis ~= "Gone"
		if wasGone and vis ~= "Gone" and isOpen then
			-- pops into view when the skill before it gets bought
			v.PopUntil = os.clock() + 0.45
			v.Pop.Scale = 0
			tween(v.Pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if ART.HexSheet ~= "" and v.Fill.SetHex then
			v.Fill.SetHex(if state ~= "Locked" then (ART.HexIndex[node.Branch] or ART.HexLocked) else ART.HexLocked)
		elseif v.Fill.SetImage then
			v.Fill.SetImage(if state ~= "Locked" then (ART.HexUnlocked[node.Branch] or ART.Hex) else ART.Hex)
		end
		v.State = state
		v.Level.Text = lvl .. "/" .. node.Max
		-- undiscovered = still locked: nothing about it is shown until the skill(s) before it are maxed
		local secret = state == "Locked"
		v.Secret = secret
		setIcon(v.Icon, v.IconImg, if secret then ART.LockArt else node.Art, if secret then "❓" else node.Icon)
		v.IconImg.ImageTransparency = if secret then 0.15 else 0
		v.Name.Text = if secret then "???" else node.Name
		v.Pill.Visible = false
		v.Name.Visible = not secret
		v.Affordable = false
		if state == "Maxed" then
			v.Name.TextColor3 = COL.Text
			v.Border.SetColor(COL.Maxed)
			v.Glow.SetColor(COL.Maxed)
			v.Fill.SetColor(if v.Fill.Image then UIKit.Theme.White else darker(bc, 0.42))
			v.Icon.TextTransparency, v.Name.TextTransparency, v.Level.TextTransparency = 0, 0, 0
			v.Level.TextColor3 = COL.Maxed
			v.PillStroke.Color = COL.Maxed
			v.Price.Visible = false
		elseif state == "Available" then
			local cost = SkillTreeConfig.GetCost(id, lvl) or 0
			v.Affordable = cash >= cost
			v.Name.TextColor3 = COL.Text
			v.Border.SetColor(bc)
			v.Glow.SetColor(bc)
			-- 0 levels: the branch colour, but calmer; it brightens once you own a level
			v.Fill.SetColor(if v.Fill.Image then (if lvl > 0 or ART.HexSheet ~= "" then UIKit.Theme.White else UIKit.Theme.Colors.Rice.Base) elseif lvl > 0 then darker(bc, 0.32) else COL.Fill)
			v.Icon.TextTransparency, v.Name.TextTransparency, v.Level.TextTransparency = 0, 0, 0
			v.Level.TextColor3 = if lvl > 0 then bc:Lerp(UIKit.Theme.White, 0.45) else COL.Text
			v.PillStroke.Color = bc
			v.Price.Text = NumberFormat.Cash(cost)
			v.Price.TextColor3 = if v.Affordable then COL.Afford else COL.NoAfford
			v.Price.Visible = true
		else
			v.Border.SetColor(COL.BorderLocked)
			v.Glow.SetTransparency(1)
			v.Fill.SetColor(if v.Fill.Image then (if ART.HexSheet ~= "" then UIKit.Theme.White else UIKit.Theme.Colors.Rice.Dark) else COL.FillLocked)
			v.Icon.TextTransparency, v.Name.TextTransparency, v.Level.TextTransparency = 0.3, 0.25, 0.45
			v.Name.TextColor3 = UIKit.Theme.Currency.Fish.Base
			v.Level.TextColor3 = COL.Dim
			v.PillStroke.Color = COL.BorderLocked
			v.Price.Visible = false
		end
	end
	-- prices live inside the hex now (white = you can afford it, soft red = not yet)
	for _, v in pairs(views) do
		v.PriceTag.Visible = v.Price.Visible
		v.PriceText.Text = v.Price.Text
		v.PriceText.TextColor3 = if v.Affordable then UIKit.Theme.White else UIKit.Theme.Colors.Primary.Base
		v.Price.Visible = false
	end
	-- the cheapest skill you can afford right now gets the bouncing arrow
	bestId = nil
	local bestCost = math.huge
	for id, v in pairs(views) do
		if v.Affordable then
			local c = SkillTreeConfig.GetCost(id, lv[id] or 0) or math.huge
			if c < bestCost then bestCost, bestId = c, id end
		end
	end
	for _, l in ipairs(lines) do
		local lit = l.From == "START" or SkillTreeConfig.IsMaxed(l.From, lv)
		l.Lit = lit
		local fromShown = l.From == "START" or (views[l.From] and views[l.From].Vis ~= "Gone")
		l.Frame.Visible = fromShown and views[l.To] and views[l.To].Vis ~= "Gone" or false
		if l.Image then
			-- the branch's coloured bar; greyed out until the skill before it is maxed
			l.Frame.ImageColor3 = if lit then UIKit.Theme.White else UIKit.Theme.Colors.Rice.Dark
		else
			l.Frame.BackgroundColor3 = if lit then branchColor(SkillTreeConfig.ById[l.To]) else COL.LineOff
		end
		if not lit then l.Spark.BackgroundTransparency = 1 end
	end
end

-- ===== tooltip =====

local tipTitle: TextLabel
local tipDesc: TextLabel
local tipAction: TextLabel
local tipShownId: string? = nil

-- stat skills are named after their effect ("+15% Spawn"), so the tooltip gives them a
-- proper name from their family, numbered by price: "Spawn Speed I", "Spawn Speed II", ...
local FAMILY_NAMES = {
	KG = "Sushi Value", Cash = "Cash Boost", Luck = "Luck Boost", Spawn = "Spawn Speed",
	Walk = "Swift Feet", Prestige = "Prestige Boost",
}
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local skillTitle: { [string]: string } = {}
do
	local families = {}
	for _, n in ipairs(SkillTreeConfig.List) do
		local fam = n.Effect and FAMILY_NAMES[n.Effect.Key]
		if fam and string.match(n.Name, "^[%+%d]") then
			families[fam] = families[fam] or {}
			table.insert(families[fam], n)
		end
	end
	for fam, nodes in pairs(families) do
		table.sort(nodes, function(a, b) return if a.Cost == b.Cost then a.Id < b.Id else a.Cost < b.Cost end)
		for i, n in ipairs(nodes) do skillTitle[n.Id] = fam .. " " .. (ROMAN[i] or tostring(i)) end
	end
end

-- stack the visible rows and size the panel to fit them
local function layoutTooltip()
	local y = 10
	for _, row in ipairs({ tipTitle, tipDesc, tipAction }) do
		if row.Visible then
			row.Position = UDim2.fromOffset(16, y)
			y += row.Size.Y.Offset + 4
		end
	end
	tooltip.Size = UDim2.fromOffset(560, y + 8)
end

local function showTooltip(id: string?)
	if not id or not views[id] then
		tooltip.Visible = false
		tipShownId = nil
		return
	end
	local v = views[id]
	local node = v.Node
	local lv = levels()
	local lvl = lv[id] or 0
	local state = stateOf(id, lv)
	local secret = state == "Locked"
	-- 1) skill name  2) what it does (the hex's own words for stat skills)  3) cost / status
	tipTitle.Text = if secret then "Undiscovered Skill" else (skillTitle[id] or node.Name)
	tipDesc.Text = if secret then "???" elseif skillTitle[id] then node.Name else node.Desc
	if state == "Maxed" then
		tipAction.Text = "<font color=\"#6EFF6E\">Owned</font>"
	elseif state == "Locked" then
		local need = {}
		local hidden = false
		for _, p in ipairs(node.Prereqs) do
			if p ~= "START" and not SkillTreeConfig.IsMaxed(p, lv) then
				-- never name a skill that is itself still undiscovered
				if stateOf(p, lv) == "Locked" then hidden = true else table.insert(need, SkillTreeConfig.ById[p].Name) end
			end
		end
		tipAction.Text = if hidden or #need == 0 then "🔍 Discover the skills before it first"
			else "🔍 Max " .. table.concat(need, " & ") .. " to discover it"
	else
		local cost = SkillTreeConfig.GetCost(id, lvl) or 0
		local how = if lastInput == "touch" then "Tap again" elseif lastInput == "gamepad" then "Press A" else "Click"
		if money() >= cost then
			tipAction.Text = how .. " to buy for <font color=\"#6EFF6E\">" .. NumberFormat.Cash(cost) .. "</font>"
		else
			tipAction.Text = "<font color=\"#FF5F5F\">Need " .. NumberFormat.Cash(cost - money()) .. " more</font>"
		end
	end
	if tipShownId ~= id then
		-- pop in when it switches to another skill
		tipScale.Scale = tipBase * 0.9
		tween(tipScale, 0.2, { Scale = tipBase }, Enum.EasingStyle.Back)
	end
	tipShownId = id
	layoutTooltip()
	tooltip.Visible = true
end

-- ===== camera (pan / zoom) =====

local function applyView()
	world.Position = UDim2.new(0.5, pan.X, 0.5, pan.Y)
	zoomScale.Scale = zoom
end

local function clampPan()
	local limit = CELL_R * 7 * zoom
	pan = Vector2.new(math.clamp(pan.X, -limit, limit), math.clamp(pan.Y, -limit, limit))
end

local function zoomAt(newZoom: number, screenPoint: Vector2)
	newZoom = math.clamp(newZoom, ZOOM_MIN, ZOOM_MAX)
	local vp = gui.AbsoluteSize
	local centre = vp / 2 + pan
	local worldPoint = (screenPoint - centre) / zoom
	zoom = newZoom
	pan = screenPoint - vp / 2 - worldPoint * zoom
	clampPan()
	applyView()
end

local function fitView()
	local vp = gui.AbsoluteSize
	local minX, maxX, minY, maxY = 0, 0, 0, 0
	for _, v in pairs(views) do
		if v.Vis == "Gone" then continue end
		minX, maxX = math.min(minX, v.Pos.X), math.max(maxX, v.Pos.X)
		minY, maxY = math.min(minY, v.Pos.Y), math.max(maxY, v.Pos.Y)
	end
	local w, h = (maxX - minX) + HEX_R * 2.6, (maxY - minY) + HEX_R * 2.8
	local availH = vp.Y - 130 -- exit button
	local fit = math.min(vp.X * 0.94 / w, availH / h)
	-- whole tree if it's readable, otherwise a readable zoom centred on Start (drag to explore)
	local screen = math.clamp(math.min(vp.X / 1400, vp.Y / 820), 0.5, 1) -- same scale as the header/Exit
	zoom = math.clamp(math.max(fit, 0.8 * screen), ZOOM_MIN, 1)
	if zoom > fit + 0.01 then
		pan = Vector2.new(0, -10)
	else
		pan = Vector2.new(-(minX + maxX) / 2 * zoom, -(minY + maxY) / 2 * zoom - 10)
	end
	applyView()
end

-- InputObject positions exclude the top-bar inset; this ScreenGui ignores it
local function toScreen(p: Vector3 | Vector2): Vector2
	return Vector2.new(p.X, p.Y) + GuiService:GetGuiInset()
end

local function nodeAtScreen(p: Vector2): string?
	local local_ = (p - gui.AbsoluteSize / 2 - pan) / zoom
	local q, r = pixelToHex(local_)
	local id = byPos[q .. "," .. r]
	if not id or views[id].Vis == "Gone" then return nil end
	-- stay inside the drawn hex (not the gap between hexes)
	if (local_ - views[id].Pos).Magnitude > HEX_R + BORDER then return nil end
	return id
end

-- ===== effects =====

local fxLayer: Frame

local function shake(v)
	if UIKit.ReducedMotion() then UIKit.Sound("Error"); return end
	local base = UDim2.fromOffset(v.Pos.X, v.Pos.Y)
	task.spawn(function()
		for i = 1, 7 do
			local t = (if i % 2 == 0 then 1 else -1) * (8 - i)
			v.Root.Position = base + UDim2.fromOffset(t, 0)
			task.wait(0.03)
		end
		v.Root.Position = base
	end)
end

-- floating text that rises from a hex and fades
local function floatText(pos: Vector2, text: string, color: Color3, big: boolean?)
	local lbl = UIKit.Label(fxLayer, {
		Text = text, TextColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y - 20), Size = UDim2.fromOffset(if big then 190 else 120, if big then 42 else 32), ZIndex = 20,
	}, 3)
	local sc = UIKit.new("UIScale", { Scale = 0.4 }, lbl)
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(lbl, 0.9, { Position = UDim2.fromOffset(pos.X, pos.Y - (if big then 105 else 85)) }, Enum.EasingStyle.Quart)
	task.delay(0.55, function()
		tween(lbl, 0.35, { TextTransparency = 1 })
		local st = lbl:FindFirstChildOfClass("UIStroke")
		if st then tween(st, 0.35, { Transparency = 1 }) end
	end)
	task.delay(1, function() lbl:Destroy() end)
end

-- an expanding hexagon ring + sparkles flying out
local function burst(pos: Vector2, color: Color3, big: boolean?)
	local holder = UIKit.new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset((HEX_R + BORDER) * 2, (HEX_R + BORDER) * 2), ZIndex = 19,
	}, fxLayer)
	local ring = hexShape(holder, HEX_R + BORDER, color, "Ring", 19)
	ring.SetTransparency(0.3)
	local sc = UIKit.new("UIScale", { Scale = 1 }, holder)
	tween(sc, 0.45, { Scale = if big then 1.9 else 1.45 })
	for _, f in ipairs(ring.Parts) do tween(f, 0.45, { BackgroundTransparency = 1 }) end
	local count = if big then 12 else 7
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.4
		local dist = (if big then 120 else 85) + math.random() * 30
		local s = UIKit.Label(fxLayer, {
			Text = if big and i % 2 == 0 then "⭐" else "✨", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(pos.X, pos.Y), Size = UIKit.Theme.Layout.SkillTreeUIController.Size8, ZIndex = 21, Rotation = math.random(-30, 30),
		}, 0)
		tween(s, 0.55, { Position = UDim2.fromOffset(pos.X + math.cos(a) * dist, pos.Y + math.sin(a) * dist), Rotation = math.random(-120, 120) }, Enum.EasingStyle.Quart)
		task.delay(0.3, function() tween(s, 0.3, { TextTransparency = 1 }) end)
		task.delay(0.65, function() s:Destroy() end)
	end
	task.delay(0.5, function() holder:Destroy() end)
end

local function bounce(v, from: number, time: number, style)
	v.PopUntil = os.clock() + time
	v.Pop.Scale = from
	tween(v.Pop, time, { Scale = 1 }, style or Enum.EasingStyle.Back)
end

local function popNode(v, maxed: boolean)
	bounce(v, if maxed then 1.35 else 1.22, if maxed then 0.6 else 0.45, Enum.EasingStyle.Elastic)
	burst(v.Pos, if maxed then COL.Maxed else branchColor(v.Node), maxed)
	local lvl = levelOf(v.Node.Id)
	floatText(v.Pos, if v.Node.Max == 1 then "UNLOCKED!" elseif maxed then "MAXED!" else ("Lv " .. lvl), if maxed then COL.Maxed else branchColor(v.Node):Lerp(UIKit.Theme.White, 0.35), maxed)
	if maxed then
		-- the lines leaving this skill grow out one after another and wake up the next skills
		local n = 0
		for _, l in ipairs(lines) do
			if l.From == v.Node.Id then
				n += 1
				local target = views[l.To]
				task.delay(0.12 * n, function()
					l.Frame.Size = UDim2.fromOffset(0, LINE_W)
					tween(l.Frame, 0.35, { Size = l.Size })
					if target then
						task.delay(0.3, function()
							bounce(target, 1.18, 0.45)
							burst(target.Pos, branchColor(target.Node), false)
						end)
					end
				end)
			end
		end
	end
end

-- ===== buying =====

function SkillTreeUIController.Buy(id: string)
	local v = views[id]
	if not v then return false end
	if buying then return true end
	local lv = levels()
	local state = stateOf(id, lv)
	if state ~= "Available" then
		shake(v)
		return false
	end
	local cost = SkillTreeConfig.GetCost(id, lv[id] or 0) or math.huge
	if money() < cost then
		shake(v)
		v.Price.TextColor3 = COL.NoAfford
		task.spawn(function()
			for i = 1, 4 do v.Price.Rotation = (if i % 2 == 0 then 6 else -6) task.wait(0.04) end
			v.Price.Rotation = 0
		end)
		return false
	end
	buying = true
	EffectsController.PlaySound("UIClick", 1.1)
	local ok, result = pcall(function()
		return ReplicatedStorage.Remotes:WaitForChild("BuyTreeNode"):InvokeServer(id)
	end)
	buying = false
	if ok and result == true then
		local maxed = levelOf(id) >= v.Node.Max
		EffectsController.PlaySound("Upgrade", if maxed then 1.15 else 1)
		refresh()
		popNode(v, maxed)
		dirty = true
		return true
	end
	shake(v)
	dirty = true
	return false
end

-- ===== open / close =====

function SkillTreeUIController.IsOpen() return isOpen end

local function introAnimation()
	-- hexes pop in ring by ring from Start, lines fade in behind them
	local function popIn(v, delay)
		v.Pop.Scale = 0
		v.PopUntil = os.clock() + delay + 0.45
		task.delay(delay, function()
			if isOpen then tween(v.Pop, 0.42, { Scale = 1 }, Enum.EasingStyle.Back) end
		end)
	end
	popIn(startView, 0)
	for _, v in pairs(views) do
		v.Price.TextTransparency = 1
		popIn(v, 0.05 + v.Ring * 0.06 + math.random() * 0.03)
		task.delay(0.3 + v.Ring * 0.06, function()
			if isOpen then tween(v.Price, 0.25, { TextTransparency = 0 }) end
		end)
	end
	for _, l in ipairs(lines) do
		local f = l.Frame
		local prop = if l.Image then "ImageTransparency" else "BackgroundTransparency"
		f[prop] = 1
		task.delay(0.08 + l.Ring * 0.06, function()
			if isOpen then tween(f, 0.3, { [prop] = if l.Lit then 0 else 0.1 }) end
		end)
	end
end

function SkillTreeUIController.Open()
	if isOpen then return end
	MenuManager.Opening("SkillTreeUI")
	UIKit.MenuEffect("SkillTreeUI",true)
	isOpen = true
	openedAt = os.clock()
	gui.Enabled = true
	dirty = true
	refresh()
	fitView()
	local bg = gui:FindFirstChild("Backdrop")
	bg.BackgroundTransparency = 1
	tween(bg, 0.3, { BackgroundTransparency = 0.25 })
	local header = gui:FindFirstChild("Header")
	header.Position = UDim2.new(0.5, 0, 0, -90)
	tween(header, 0.45, { Position = UDim2.new(0.5, 0, 0, 14) }, Enum.EasingStyle.Back)
	local exit = gui:FindFirstChild("Exit")
	exit.Position = UDim2.new(0.5, 0, 1, 120)
	tween(exit, 0.45, { Position = UDim2.new(0.5, 0, 1, -18) }, Enum.EasingStyle.Back)
	introAnimation()
	if lastInput == "gamepad" then
		selectedId = selectedId or SkillTreeConfig.List[1].Id
		showTooltip(selectedId)
	end
end

function SkillTreeUIController.Close()
	if not isOpen then return end
	isOpen = false
	MenuManager.Closed("SkillTreeUI")
	UIKit.MenuEffect("SkillTreeUI",false)
	hoveredId, selectedId = nil, nil
	tooltip.Visible = false
	tipShownId = nil
	gui.Enabled = false
end

function SkillTreeUIController.Toggle()
	if isOpen then SkillTreeUIController.Close() else SkillTreeUIController.Open() end
end

-- true when a skill can be bought right now (pulses the Skills button)
function SkillTreeUIController.HasAffordable(): boolean
	local lv = levels()
	local cash = money()
	for _, n in ipairs(SkillTreeConfig.List) do
		if stateOf(n.Id, lv) == "Available" and cash >= (SkillTreeConfig.GetCost(n.Id, lv[n.Id] or 0) or math.huge) then
			return true
		end
	end
	return false
end

-- ===== per-frame animation =====

local press: any = nil -- { Input, Start, Pan, Dragged, NodeId, Held }

local function animate(dt: number)
	if UIKit.ReducedMotion() then
		startView.Glow.SetTransparency(1);startView.Icon.Rotation=0
		for id,v in pairs(views) do v.Root.Rotation=0;v.Icon.Rotation=0;v.Content.Position=UDim2.new();v.Shine.Visible=false;v.Glow.SetTransparency(id==selectedId and 0.35 or 1);if os.clock()>v.PopUntil then v.Pop.Scale=1 end end
		for _,p in ipairs(ambience.Petals or {}) do p.Label.Visible=false end
		for _,l in ipairs(lines) do l.Spark.BackgroundTransparency=1 end
		recommend.Visible=false;return
	end
	for _,p in ipairs(ambience.Petals or {}) do p.Label.Visible=true end
	local t = os.clock()
	local intro = t - openedAt < 0.9
	-- Start: slow breathing glow
	startView.Glow.SetTransparency(0.7 + math.sin(t * 2) * 0.14)
	startView.Icon.Rotation = math.sin(t * 1.6) * 6
	for id, v in pairs(views) do
		-- hover easing (scale + tiny wobble)
		local want = if id == hoveredId or id == selectedId then 1 else 0
		v.Hover += (want - v.Hover) * math.min(dt * 14, 1)
		if t > v.PopUntil then
			local s = 1 + v.Hover * (if v.State == "Locked" then 0.04 else 0.09)
			if v.State == "Available" and v.Affordable then
				s += (math.sin(t * 3.2 + v.Phase) * 0.5 + 0.5) * 0.03 -- buyable: gentle heartbeat
			end
			v.Pop.Scale = s
		end
		v.Root.Rotation = v.Hover * math.sin(t * 3 + v.Phase) * 1.5
		-- glow / icon motion by state
		local wave = math.sin(t * 2.4 + v.Phase) * 0.5 + 0.5
		if v.State == "Maxed" then
			v.Glow.SetTransparency(0.6 + wave * 0.2 - v.Hover * 0.2)
			v.Content.Position = UDim2.fromOffset(0, math.sin(t * 1.8 + v.Phase) * 1.5)
			v.Icon.Rotation = math.sin(t * 1.5 + v.Phase) * 5
		elseif v.State == "Available" then
			local base = if v.Affordable then 0.45 else 0.8
			v.Glow.SetTransparency(math.clamp(base + wave * 0.3 - v.Hover * 0.3, 0, 1))
			v.Content.Position = UDim2.fromOffset(0, math.sin(t * 2.2 + v.Phase) * (if v.Affordable then 2.5 else 1.2))
			v.Icon.Rotation = math.sin(t * 2 + v.Phase) * (if v.Affordable then 7 else 3)
			-- the price hops a little when you can afford it
			local hop = if v.Affordable then math.abs(math.sin(t * 3.2 + v.Phase)) * 4 else 0
			v.Price.Position = UDim2.fromOffset(v.Pos.X, v.PriceBase - hop - v.Hover * 6)
		else
			v.Glow.SetTransparency(1)
			v.Content.Position = UDim2.fromOffset(0, 0)
			v.Icon.Rotation = 0
		end
	end
	-- shine sweeping across skills you can afford
	for _, v in pairs(views) do
		local on = v.Affordable and v.Vis ~= "Gone"
		v.Shine.Visible = on
		if on then v.ShineGrad.Offset = Vector2.new(((t * 0.55 + v.Phase * 0.3) % 2.6) - 1.3, 0) end
	end
	-- bouncing arrow over the cheapest skill you can afford
	local bv = bestId and views[bestId]
	recommend.Visible = bv ~= nil and not intro
	if bv then
		recommend.Position = UDim2.fromOffset(bv.Pos.X, bv.PriceBase + 2 - math.abs(math.sin(t * 4)) * 9)
	end
	-- ambience: slow light rays behind Start + drifting petals
	local area = gui.AbsoluteSize
	for _, p in ipairs(ambience.Petals or {}) do
		p.X += p.VX * dt
		p.Y += p.VY * dt
		if p.Y > area.Y + 30 or p.X > area.X + 30 then
			p.X, p.Y = math.random() * area.X - area.X * 0.3, -30
		end
		p.Label.Position = UDim2.fromOffset(p.X + math.sin(t * p.Sway + p.Phase) * 18, p.Y)
		p.Label.Rotation = (t * p.Spin + p.Phase * 50) % 360
	end
	-- energy flowing along unlocked lines
	for _, l in ipairs(lines) do
		if l.Lit and not intro then
			local speed = 140 / math.max(l.Length, 1) -- same px/s on every line
			local p = (t * speed + l.Phase) % 1
			l.Spark.Position = UDim2.fromScale(p, 0.42)
			l.Spark.BackgroundTransparency = 0.15 + math.abs(p - 0.5) * 1.4
		end
	end
end

-- ===== input =====


local pinchZoom = 1

local function setHover(id: string?)
	if id == hoveredId then return end
	hoveredId = id
	if id then EffectsController.PlaySound("UIHover") end
	showTooltip(id or selectedId)
end

local function moveSelection(dir: Vector2)
	local from = selectedId and views[selectedId] and views[selectedId].Pos or Vector2.zero
	local best, bestScore = nil, math.huge
	for id, v in pairs(views) do
		local d = v.Pos - from
		if d.Magnitude > 1 and v.Vis ~= "Gone" then
			local along = d.Unit:Dot(dir)
			if along > 0.45 then
				local score = d.Magnitude * (2 - along)
				if score < bestScore then best, bestScore = id, score end
			end
		end
	end
	if best then
		selectedId = best
		setHover(best)
		-- keep the selection on screen
		local p = views[best].Pos * zoom + pan
		local vp = gui.AbsoluteSize
		if math.abs(p.X) > vp.X * 0.35 or math.abs(p.Y) > vp.Y * 0.3 then
			pan = -views[best].Pos * zoom
			clampPan()
			applyView()
		end
	end
end

local function bindInput(catcher: GuiButton)
	catcher.InputBegan:Connect(function(input)
		if not isOpen then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			lastInput = if t == Enum.UserInputType.Touch then "touch" else "mouse"
			if press and t == Enum.UserInputType.Touch then return end -- second finger = pinch
			press = { Input = input, Start = Vector2.new(input.Position.X, input.Position.Y), Pan = pan, Dragged = false,
				NodeId = nodeAtScreen(toScreen(input.Position)), Time = os.clock(), Bought = 0 }
		end
	end)
	catcher.InputChanged:Connect(function(input)
		if not isOpen then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local m = UserInputService:GetMouseLocation()
			zoomAt(zoom * (if input.Position.Z > 0 then 1.12 else 1 / 1.12), m)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not isOpen then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or (press and input == press.Input) then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			if press and (t == Enum.UserInputType.Touch or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
				local d = p - press.Start
				if press.Dragged or d.Magnitude > DRAG_START then
					press.Dragged = true
					pan = press.Pan + d
					clampPan()
					applyView()
				end
			elseif t == Enum.UserInputType.MouseMovement then
				lastInput = "mouse"
				setHover(nodeAtScreen(toScreen(p)))
			end
		elseif t == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local v = Vector2.new(input.Position.X, -input.Position.Y)
			if v.Magnitude > 0.2 then
				pan -= v * 14
				clampPan()
				applyView()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not isOpen or not press or input ~= press.Input and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local p = press
		press = nil
		if p.Dragged or p.Held then return end
		local id = nodeAtScreen(toScreen(input.Position))
		if not id then
			selectedId = nil
			setHover(nil)
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and selectedId ~= id then
			-- first tap shows the details, second tap buys
			selectedId = id
			hoveredId = nil
			setHover(id)
			return
		end
		SkillTreeUIController.Buy(id)
		showTooltip(id)
	end)
	UserInputService.TouchPinch:Connect(function(positions, scale, _velocity, state)
		if not isOpen then return end
		if state == Enum.UserInputState.Begin then
			pinchZoom = zoom
			press = nil
		elseif state == Enum.UserInputState.Change and #positions >= 2 then
			local mid = toScreen((positions[1] + positions[2]) / 2)
			zoomAt(pinchZoom * scale, mid)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not isOpen then return end
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			lastInput = "gamepad"
			local k = input.KeyCode
			if k == Enum.KeyCode.ButtonB then
				SkillTreeUIController.Close()
			elseif k == Enum.KeyCode.ButtonA and selectedId then
				SkillTreeUIController.Buy(selectedId)
				showTooltip(selectedId)
			elseif k == Enum.KeyCode.DPadUp then moveSelection(Vector2.new(0, -1))
			elseif k == Enum.KeyCode.DPadDown then moveSelection(Vector2.new(0, 1))
			elseif k == Enum.KeyCode.DPadLeft then moveSelection(Vector2.new(-1, 0))
			elseif k == Enum.KeyCode.DPadRight then moveSelection(Vector2.new(1, 0))
			elseif k == Enum.KeyCode.ButtonR1 then zoomAt(zoom * 1.15, gui.AbsoluteSize / 2)
			elseif k == Enum.KeyCode.ButtonL1 then zoomAt(zoom / 1.15, gui.AbsoluteSize / 2)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and not processed then
			SkillTreeUIController.Close()
		end
	end)
end

-- ===== init =====

function SkillTreeUIController.Init()
	gui = UIKit.new("ScreenGui", {
		Name = "SkillTreeUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	-- the dimmed game behind
	UIKit.new("Frame", {
		Name = "Backdrop", Size = UDim2.fromScale(1, 1), Active = true,
		BackgroundColor3 = UIKit.Theme.Colors.Rice.Dark, BackgroundTransparency = 0.25, ZIndex = 1,
	}, gui)

	-- drifting sakura petals behind the tree (screen space)
	local petalLayer = UIKit.new("Frame", { Name = "Petals", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, gui)
	ambience.Petals = {}
	for i = 1, 14 do
		local size = math.random(16, 28)
		local lbl = UIKit.Label(petalLayer, { Name = "Petal", Text = "🌸", Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), TextTransparency = 0.45, ZIndex = 2 }, 0)
		table.insert(ambience.Petals, {
			Label = lbl, X = math.random() * 1600, Y = math.random() * 900,
			VX = 12 + math.random() * 18, VY = 22 + math.random() * 22,
			Sway = 0.6 + math.random(), Spin = 20 + math.random() * 40, Phase = math.random() * 6,
		})
	end
	local view = UIKit.new("Frame", { Name = "View", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, ClipsDescendants = true }, gui)
	world = UIKit.new("Frame", { Name = "World", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UIKit.Theme.Layout.SkillTreeUIController.Size9, ZIndex = 2 }, view)
	zoomScale = UIKit.new("UIScale", {}, world)
	-- invisible layer over the tree that takes drag / zoom / clicks (hexes are hit-tested by maths)
	local catcher = UIKit.new("TextButton", {
		Name = "Input", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Selectable = false,
	}, gui)
	catcher:SetAttribute("NoSound", true)
	-- layers: lines under the hexes, prices above them, effects on top
	-- soft warm glow behind Start (moves/zooms with the tree)
	local amb = UIKit.new("Frame", { Name = "Ambience", BackgroundTransparency = 1, Size = UIKit.Theme.Layout.SkillTreeUIController.Size10, ZIndex = 0 }, world)
	UIKit.new("Frame", { Name = "Lines", BackgroundTransparency = 1, Size = UIKit.Theme.Layout.SkillTreeUIController.Size11, ZIndex = 1 }, world)
	UIKit.new("Frame", { Name = "Nodes", BackgroundTransparency = 1, Size = UIKit.Theme.Layout.SkillTreeUIController.Size12, ZIndex = 2 }, world)
	UIKit.new("Frame", { Name = "Prices", BackgroundTransparency = 1, Size = UIKit.Theme.Layout.SkillTreeUIController.Size13, ZIndex = 3 }, world)
	fxLayer = UIKit.new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UIKit.Theme.Layout.SkillTreeUIController.Size14, ZIndex = 4 }, world)

	buildLines()
	buildStart()
	for _, node in ipairs(SkillTreeConfig.List) do buildNodeView(node) end
	recommend = UIKit.Label(world:FindFirstChild("Prices"), {
		Name = "Recommend", Text = "▼", TextColor3 = COL.Afford, AnchorPoint = Vector2.new(0.5, 1),
		Size = UIKit.Theme.Layout.SkillTreeUIController.Size15, ZIndex = 3, Visible = false,
	}, 3)

	-- soft dark strips behind the header and the Exit button so they read over the tree
	for _, top in ipairs({ false }) do
		local strip = UIKit.new("Frame", {
			Name = if top then "TopShade" else "BottomShade", BorderSizePixel = 0, BackgroundColor3 = UIKit.Theme.Ink,
			AnchorPoint = Vector2.new(0, if top then 0 else 1), Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.new(1, 0, 0, if top then 96 else 110), ZIndex = 4, -- under the input layer
		}, gui)
		UIKit.new("UIGradient", {
			Rotation = if top then 90 else -90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		}, strip)
	end

	-- header (empty: the title was removed, kept so the layout code stays simple)
	local header = UIKit.new("Frame", { Name = "Header", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UIKit.Theme.Layout.SkillTreeUIController.Size16, ZIndex = 10 }, gui)
	local headerScale = UIKit.new("UIScale", {}, header)

	-- tooltip (bottom, above Exit)
	tooltip = UIKit.new("Frame", {
		Name = "Tooltip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UIKit.Theme.Layout.SkillTreeUIController.Size17,
		BackgroundColor3 = UIKit.Theme.Colors.Secondary.Base, BackgroundTransparency = 0, Visible = false, ZIndex = 10,
	}, gui)
	UIKit.Corner(tooltip, 24)
	UIKit.Stroke(tooltip, 5, UIKit.Theme.Ink, true)
	tipScale = UIKit.new("UIScale", {}, tooltip)
	-- nigiri sitting on the top-right corner
	UIKit.new("ImageLabel", {
		Name = "Sushi", Image = "rbxassetid://135530546062071", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -18, 0, 4), Size = UIKit.Theme.Layout.SkillTreeUIController.Size18, ZIndex = 12,
	}, tooltip)
	-- rows are stacked by layoutTooltip(), so only their heights matter here
	tipTitle = UIKit.Label(tooltip, { Name = "Title", Text = "", Size = UIKit.Theme.Layout.SkillTreeUIController.Size19, ZIndex = 11, TextColor3 = UIKit.Theme.White }, 3)
	tipDesc = UIKit.Label(tooltip, { Name = "Desc", Text = "", Size = UIKit.Theme.Layout.SkillTreeUIController.Size20, ZIndex = 11, TextColor3 = UIKit.Colors.Subtle }, 2)
	tipAction = UIKit.Label(tooltip, { Name = "Action", Text = "", Size = UIKit.Theme.Layout.SkillTreeUIController.Size21, ZIndex = 11 }, 3)

	-- big red Exit
	local exit = UIKit.Button(gui, {
		Name = "Exit", Label = "Exit", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
		Size = UIKit.Theme.Layout.SkillTreeUIController.Size22, Colors = UIKit.Gradients.Off, StrokeColor = UIKit.Theme.Colors.Danger.Base, ZIndex = 12,
	}, function() SkillTreeUIController.Close() end)
	exit.Label.ZIndex = 13
	local hint = UIKit.Label(gui, {
		Name = "Hint", Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
		Size = UIKit.Theme.Layout.SkillTreeUIController.Size23, ZIndex = 10, TextColor3 = UIKit.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right,
	}, 2)

	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(vp.X / 1400, vp.Y / 820), 0.55, 1)
		headerScale.Scale = s
		tipBase = s
		tipScale.Scale = s
		exit.Button.Size = UDim2.fromOffset(250 * s, 74 * s)
		tooltip.Position = UDim2.new(0.5, 0, 1, -(28 + 84 * s))
		hint.Visible = vp.X > 900
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	hint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Drag to move • Pinch to zoom"
		else "Drag to move • Scroll to zoom"

	bindInput(catcher)
	MenuManager.Register("SkillTreeUI", SkillTreeUIController.Close)

	player.AttributeChanged:Connect(function(name)
		if name == "Money" or name == "TotalRebirths" or string.sub(name, 1, 3) == "TL_" then
			dirty = true -- prices still turn green / red as your Cash changes
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not isOpen then return end
		if dirty then
			refresh()
			if tooltip.Visible then showTooltip(hoveredId or selectedId) end
		end
		animate(dt)
	end)
end

return SkillTreeUIController
