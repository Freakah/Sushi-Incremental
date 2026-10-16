local UIKit = require(script.Parent.UIKit)
-- BoardsController: the incremental-style boards in the world.
--   💵 Cash Upgrades  |  ⭐ Prestige wall (scrolls sideways)  |  🔄 Rebirth   (+ the market "Converter")
--   🤖 Automation wall (scrolls sideways)
--   🎣 Sushi Pond: 🐟 Fish Upgrades
--   🗡️ Sushi Slashing: 🍥 Slice Upgrades
-- Board parts are tagged "UpgradeBoard" with a BoardType attribute, so any zone
-- can have its own wall. Everything is drawn on SurfaceGuis and clicked with our
-- own raycast (Roblox's SurfaceGui input is unreliable on transparent parts).
-- All purchases go through the server-validated remotes.

local Players = game:GetService("Players")
local TweenService = UIKit.TweenService
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local AscensionConfig = require(Shared.Config.AscensionConfig)
local FishConfig = require(Shared.Config.FishConfig)
local SliceConfig = require(Shared.Config.SliceConfig)
local PrestigeConfig = require(Shared.Config.PrestigeConfig)
local AutomationConfig = require(Shared.Config.AutomationConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local NumberFormat = require(Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)
local MarketController = require(script.Parent.MarketController)
local AnnouncementController = require(script.Parent.AnnouncementController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local BoardsController = {}

-- ===== theme =====
local FONT = UIKit.Font
local WHITE = UIKit.Theme.White
local OUTLINE = UIKit.Theme.Ink
local PANEL = UIKit.Theme.Colors.Rice.Dark
local GREY_TEXT = UIKit.Theme.Muted
local CASH = UIKit.Theme.Currency.Money.Base
local RED = UIKit.Theme.Currency.TotalRebirths.Base
local GOLD = UIKit.Theme.Currency.Prestiges.Base
local KG = UIKit.Theme.Currency.KG.Base
local ASC = UIKit.Theme.Currency.AscensionPoints.Base
local FISH = UIKit.Theme.Currency.Fish.Base
local SLICE = UIKit.Theme.Currency.Slices.Base

local SEQ = {
	Green = ColorSequence.new(UIKit.Theme.Colors.Success.Base, UIKit.Theme.Colors.Success.Base),
	Red = ColorSequence.new(UIKit.Theme.Colors.Primary.Base, UIKit.Theme.Colors.Danger.Base),
	Yellow = ColorSequence.new(UIKit.Theme.Colors.Accent.Base, UIKit.Theme.Colors.Primary.Base),
	Grey = ColorSequence.new(UIKit.Theme.Muted, UIKit.Theme.Muted),
}

-- ===== layout (pixels; boards are drawn at 40 px per stud) =====
local CARD_W, CARD_H, GAP = 170, 220, 12
local PILL_H, TITLE_H = 64, 44
local PANEL_H = TITLE_H + CARD_H + GAP * 2 -- 288
-- scrolling walls: a fixed card on the left, then WALL_VISIBLE cards between ◀ ▶
local WALL_VISIBLE, EXCHANGE_W, ARROW_W = 3, 200, 36
local VIEW_W = WALL_VISIBLE * CARD_W + (WALL_VISIBLE + 1) * GAP
local CANVAS = {
	CashBoard = Vector2.new(3 * CARD_W + 4 * GAP, PILL_H + PANEL_H), -- 558 x 352
	PrestigeWall = Vector2.new(GAP + EXCHANGE_W + GAP + ARROW_W + VIEW_W + ARROW_W + GAP, PILL_H + PANEL_H), -- 866 x 352
	RebirthBoard = Vector2.new(340, 420), -- taller than the rows: it's a milestone
	AutomationWall = Vector2.new(GAP + ARROW_W + VIEW_W + ARROW_W + GAP, PILL_H + PANEL_H), -- 654 x 352
	Converter = Vector2.new(3 * CARD_W + 4 * GAP, PILL_H + PANEL_H), -- same size as the upgrade boards
	FishUpgradesBoard = Vector2.new(4 * CARD_W + 5 * GAP, PILL_H + PANEL_H), -- More Fish, Faster Fish, Fish Luck, Auto Fish
	SliceUpgradesBoard = Vector2.new(4 * CARD_W + 5 * GAP, PILL_H + PANEL_H), -- More Slices, Faster Slashes, Critical Slices, Auto Slash
	AscensionBoard = Vector2.new(300, PILL_H + PANEL_H),
	AscensionUpgradesBoard = Vector2.new(4 * CARD_W + 5 * GAP, PILL_H + PANEL_H),
}

local views = {}      -- every built board, each with .Refresh()
local cardsById = {}  -- [upgradeId] = { card frames } for purchase pops
local buyStreak, lastBuy = 0, 0
local confirmUntil = 0
local fxGui: ScreenGui

local buttonHandlers = setmetatable({}, { __mode = "k" }) -- [TextButton] = fire()
local worldGuis: { [BasePart]: SurfaceGui } = {}
local scrollers: { [BasePart]: (number) -> () } = {} -- scrolling walls, by board part

-- ===== helpers =====

local function new(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	inst.Parent = parent
	return inst
end

local function stroke(parent, thickness, border: boolean?)
	return new("UIStroke", {
		Thickness = thickness,
		Color = OUTLINE,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

local function label(parent, props, strokeThickness)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextScaled = true, RichText = true, TextColor3 = UIKit.Theme.Ink }, parent)
	for k, v in pairs(props) do (t :: any)[k] = v end
	stroke(t, strokeThickness or 2.5)
	return t
end

local function colored(s: string, c: Color3) return '<font color="#' .. c:ToHex() .. '">' .. s .. "</font>" end

local function pop(obj: GuiObject, amount: number)
	local sc = obj:FindFirstChild("PopScale") :: UIScale
	if not sc then return end
	sc.Scale = amount
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function shake(obj: GuiObject)
	if UIKit.ReducedMotion() then UIKit.Sound("Error"); return end
	local p = obj.Position
	task.spawn(function()
		for _, dx in ipairs({ -6, 6, -4, 4, 0 }) do
			obj.Position = p + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		obj.Position = p
	end)
	UIKit.Sound("Error")
end

local function flash(frame: Frame, color: Color3)
	color=UIKit.Theme.Colors.Success.Base
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.45, ZIndex = 20 }, frame)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
	TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	task.delay(0.45, function() f:Destroy() end)
end

local function button(parent, props, onClick)
 props.Label="";props.Variant="Success";props.NoSound=true
 local api=UIKit.Button(parent,props)
 buttonHandlers[api.Button]=function()
  if api.Button:GetAttribute("Disabled") then return end
  UIKit.SetInteraction(api.Button,"Pressed");UIKit.Sound("Click");task.delay(0.06,function() UIKit.SetInteraction(api.Button,"Normal") end);onClick(api.Button)
 end
 return api
end

local function setButton(btn, seq: ColorSequence, txt: string, visible: boolean?)
	btn.Gradient.Color = seq
	btn.Label.Text = txt
	btn.Button.Visible = visible ~= false
end

local function mix(a: Color3, b: Color3, t: number): Color3 return a:Lerp(b, t) end

local function panel(parent, width: number, height: number, y: number, title: string, titleColor: Color3)
	local p = new("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.04,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 26) }, p)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Theme.Colors.Rice.Dark, UIKit.Theme.Colors.Rice.Dark) }, p)
	local st = stroke(p, 4, true)
	st.Color = mix(OUTLINE, titleColor, 0.35)
	-- header ribbon behind the title
	local ribbon = new("Frame", {
		Name = "Ribbon", Position = UDim2.fromOffset(12, 7), Size = UIKit.Theme.Layout.BoardsController.Size1,
		BackgroundColor3 = titleColor, BackgroundTransparency = 0.8, ZIndex = 0,
	}, p)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, ribbon)
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) }),
	}, ribbon)
	label(p, { Name = "Title", Text = title, TextColor3 = titleColor, Size = UIKit.Theme.Layout.BoardsController.Size2, Position = UDim2.fromOffset(20, 8) }, 3)
	return p
end

local function pill(parent, width: number, icon: string, color: Color3)
	local f = new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(width, 52),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.04,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, f)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Theme.Colors.Rice.Dark, UIKit.Theme.Colors.Rice.Dark) }, f)
	stroke(f, 3.5, true).Color = mix(OUTLINE, color, 0.35)
	label(f, { Text = icon, Size = UIKit.Theme.Layout.BoardsController.Size3, Position = UDim2.fromOffset(12, 6) }, 0)
	return label(f, { Name = "Amount", TextColor3 = color, Size = UIKit.Theme.Layout.BoardsController.Size4, Position = UDim2.fromOffset(56, 8), TextXAlignment = Enum.TextXAlignment.Left }, 3)
end

-- ===== data helpers =====

local function money(): number return player:GetAttribute("Money") or 0 end
local function cashLevel(id) return player:GetAttribute(UpgradeConfig.AttributeName(id)) or 1 end
local function ap(): number return player:GetAttribute("AscensionPoints") or 0 end
local function ascLevel(id) return player:GetAttribute(AscensionConfig.AttributeName(id)) or 1 end
local function fish(): number return player:GetAttribute("Fish") or 0 end
local function prestiges(): number return player:GetAttribute("Prestiges") or 0 end
local function fishLevel(id) return player:GetAttribute(FishConfig.Upgrades.AttributeName(id)) or 1 end
local function slices(): number return player:GetAttribute("Slices") or 0 end
local function sliceLevel(id) return player:GetAttribute(SliceConfig.Upgrades.AttributeName(id)) or 1 end
local function prestLevel(id) return player:GetAttribute(PrestigeConfig.AttributeName(id)) or 1 end

-- every upgrade board shares the same cards
local KINDS = {
	Cash = { Config = UpgradeConfig, List = UpgradeConfig.List, Level = cashLevel, Balance = money, Remote = "RequestUpgrade",
		Currency = colored("Cash", CASH), Accent = CASH, Title = "Cash Upgrades", PillIcon = "💵" },
	Ascension = { Config = AscensionConfig, List = AscensionConfig.Upgrades, Level = ascLevel, Balance = ap, Remote = "RequestAscensionUpgrade",
		Currency = colored("AP", ASC), Accent = ASC, Title = "Ascension Upgrades", PillIcon = "✨", PillColor = ASC, Flash = ASC, PillSuffix = " AP" },
	Fish = { Config = FishConfig.Upgrades, List = FishConfig.Upgrades.List, Level = fishLevel, Balance = fish, Remote = "RequestFishUpgrade",
		Currency = colored("Fish", FISH), Accent = FISH, Title = "Fish Upgrades", PillIcon = "🐟", PillColor = FISH, Flash = FISH },
	Slice = { Config = SliceConfig.Upgrades, List = SliceConfig.Upgrades.List, Level = sliceLevel, Balance = slices, Remote = "RequestSliceUpgrade",
		Currency = colored("Slices", SLICE), Accent = SLICE, Title = "Slice Upgrades", PillIcon = "🍥", PillColor = SLICE, Flash = SLICE },
	Prestige = { Config = PrestigeConfig, List = PrestigeConfig.List, Level = prestLevel, Balance = prestiges, Remote = "RequestPrestigeUpgrade",
		Currency = colored("Prestiges", GOLD), Accent = GOLD, Title = "Prestige Upgrades", PillIcon = "⭐", PillColor = GOLD, Flash = GOLD },
}

local function affordable(getCost, id, lvl, balance): number
	local n, total = 0, 0
	while true do
		local c = getCost(id, lvl + n)
		if not c or total + c > balance + 1e-9 then break end
		total += c
		n += 1
	end
	return n
end

-- ===== purchases =====

local function tryBuy(kind: string, id: string, buyMax: boolean, cardFrame: Frame)
	local k = KINDS[kind]
	local n = affordable(k.Config.GetCost, id, k.Level(id), k.Balance())
	if n == 0 then
		shake(cardFrame)
		return
	end
	Remotes[k.Remote]:FireServer(id, buyMax)
end

local function onPurchased(kind: string, id: string, _newLevel: number, bought: number?)
	local now = os.clock()
	buyStreak = (now - lastBuy < 1.2) and math.min(buyStreak + 1, 10) or 0
	lastBuy = now
	EffectsController.PlaySound("Upgrade", 1 + buyStreak * 0.05)
	local k = KINDS[kind]
	local def = k.Config.ById[id]
	local color = k.Flash or k.Accent
	for _, card in ipairs(cardsById[id] or {}) do
		flash(card, color)
		pop(card, 1.08)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and def then
		local msg = bought and bought > 1 and ("+" .. bought .. " LEVELS!") or "LEVEL UP!"
		EffectsController.FloatingText(root.Position + Vector3.new(0, 3.5, 0), def.Icon .. " " .. msg, def.Color or color, true)
		EffectsController.Burst(root.Position + Vector3.new(0, 2, 0), def.Color or color, 20)
	end
end

-- ===== upgrade card =====

local function makeCard(parent, index: number, kind: string, def)
	local f = new("Frame", {
		Name = def.Id,
		Position = UDim2.fromOffset(GAP + (index - 1) * (CARD_W + GAP), TITLE_H + GAP),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
	}, parent)
	new("UIScale", { Name = "PopScale" }, f)
	local accent = KINDS[kind].Accent
	local c = { Frame = f, Kind = kind, Def = def }
	-- card background
	local bg = new("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 0 }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, bg)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Theme.Colors.Rice.Dark, UIKit.Theme.Colors.Rice.Dark) }, bg)
	c.Stroke = stroke(bg, 3, true)
	label(f, { Text = def.Name, TextColor3 = accent, Size = UIKit.Theme.Layout.BoardsController.Size5, Position = UDim2.fromOffset(6, 6) })
	c.Level = label(f, { Size = UIKit.Theme.Layout.BoardsController.Size6, Position = UDim2.fromOffset(6, 31), TextColor3 = GREY_TEXT }, 2)
	-- icon on a round badge
	local badge = new("Frame", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 51), Size = UIKit.Theme.Layout.BoardsController.Size7, BackgroundColor3 = UIKit.Theme.Muted }, f)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	c.BadgeStroke = new("UIStroke", { Thickness = 2.5, Color = accent, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	label(badge, { Text = def.Icon, Size = UIKit.Theme.Layout.BoardsController.Size8, Position = UDim2.fromOffset(5, 5) }, 0)
	-- level progress bar
	local bar = new("Frame", { Name = "Bar", Position = UDim2.fromOffset(16, 119), Size = UIKit.Theme.Layout.BoardsController.Size9, BackgroundColor3 = UIKit.Theme.Muted }, f)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
	c.BarFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0 }, bar)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, c.BarFill)
	c.Value = label(f, { Size = UIKit.Theme.Layout.BoardsController.Size10, Position = UDim2.fromOffset(6, 130), TextColor3 = WHITE }, 3)
	c.Cost = label(f, { Size = UIKit.Theme.Layout.BoardsController.Size11, Position = UDim2.fromOffset(7, 157) }, 2)
	c.Accent = accent
	c.Buy = button(f, { Position = UDim2.fromOffset(6, 180), Size = UIKit.Theme.Layout.BoardsController.Size12 }, function()
		if def.Toggle and KINDS[kind].Config.GetCost(def.Id, KINDS[kind].Level(def.Id)) == nil then
			local attr = "Set_" .. def.Toggle
			Remotes.SetSetting:FireServer(def.Toggle, player:GetAttribute(attr) == false)
			return
		end
		tryBuy(kind, def.Id, false, f)
	end)
	c.Max = button(f, { Position = UDim2.fromOffset(88, 180), Size = UIKit.Theme.Layout.BoardsController.Size13 }, function() tryBuy(kind, def.Id, true, f) end)
	c.Maxed = label(f, { Text = "⭐ MAXED ⭐", TextColor3 = GOLD, Size = UIKit.Theme.Layout.BoardsController.Size14, Position = UDim2.fromOffset(8, 182), Visible = false }, 3)
	if def.RequiredRebirths then
		-- shown on top of the card until you reach that Rebirth
		local lock = new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Theme.Muted, BackgroundTransparency = 0.04, ZIndex = 5, Visible = false }, f)
		new("UICorner", { CornerRadius = UDim.new(0, 16) }, lock)
		new("UIStroke", { Thickness = 3, Color = UIKit.Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, lock)
		label(lock, { Text = "Rebirth Required:", ZIndex = 6, Size = UIKit.Theme.Layout.BoardsController.Size15, Position = UDim2.fromOffset(6, 12) }, 2)
		label(lock, { Text = tostring(def.RequiredRebirths), TextColor3 = RED, ZIndex = 6, Size = UIKit.Theme.Layout.BoardsController.Size16, Position = UDim2.fromOffset(6, 36) }, 3)
		label(lock, { Text = "🔒", ZIndex = 6, Size = UIKit.Theme.Layout.BoardsController.Size17, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72) }, 0)
		label(lock, { Text = "Unlocks:", ZIndex = 6, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size18, Position = UDim2.fromOffset(6, 136) }, 2)
		label(lock, { Text = def.Icon .. " " .. def.Name, ZIndex = 6, TextColor3 = c.Accent or accent, Size = UIKit.Theme.Layout.BoardsController.Size19, Position = UDim2.fromOffset(6, 156) }, 2.5)
		label(lock, { Text = def.Description or "", ZIndex = 6, TextWrapped = true, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size20, Position = UDim2.fromOffset(8, 182) }, 1.5)
		c.Lock = lock
	end
	cardsById[def.Id] = cardsById[def.Id] or {}
	table.insert(cardsById[def.Id], f)
	return c
end

local function refreshCard(c)
	local def = c.Def
	local k = KINDS[c.Kind]
	if c.Lock then
		local locked = (player:GetAttribute("TotalRebirths") or 0) < def.RequiredRebirths
		c.Lock.Visible = locked
		if locked then
			setButton(c.Buy, SEQ.Grey, "", false)
			setButton(c.Max, SEQ.Grey, "", false)
			c.Maxed.Visible = false
			return
		end
	end
	local lvl = k.Level(def.Id)
	local getCost = k.Config.GetCost
	local getValue = k.Config.GetValue
	local balance = k.Balance()
	local cost = getCost(def.Id, lvl)
	c.Level.Text = "Level " .. (lvl - 1) .. "/" .. (def.MaxLevel - 1)
	c.BarFill.Size = UDim2.fromScale(math.clamp((lvl - 1) / math.max(def.MaxLevel - 1, 1), 0, 1), 1)
	local cur = def.Format(getValue(def.Id, lvl))
	if not cost then
		c.Stroke.Color = GOLD
		c.BadgeStroke.Color = GOLD
		c.BarFill.BackgroundColor3 = GOLD
		c.Value.Text = colored(cur, GOLD)
		c.Cost.Text = ""
		setButton(c.Max, SEQ.Grey, "", false)
		if def.Toggle then
			-- owned switch (e.g. Auto Buy): ON / OFF
			local on = player:GetAttribute("Set_" .. def.Toggle) ~= false
			c.Value.Text = colored(on and "ON" or "OFF", on and CASH or GREY_TEXT)
			c.Cost.Text = "Tap to switch"
			setButton(c.Buy, on and SEQ.Green or SEQ.Grey, on and "ON" or "OFF")
			c.Buy.Button.Position = UDim2.fromOffset(CARD_W / 2 - 37, 180)
			c.Maxed.Visible = false
			return
		end
		setButton(c.Buy, SEQ.Grey, "", false)
		c.Maxed.Visible = true
		return
	end
	c.Maxed.Visible = false
	local canBuy = balance >= cost
	c.Stroke.Color = if canBuy then c.Accent else UIKit.Theme.Ink
	c.BadgeStroke.Color = c.Accent
	c.BarFill.BackgroundColor3 = c.Accent
	c.Value.Text = colored(cur, GREY_TEXT) .. " > " .. colored(def.Format(getValue(def.Id, lvl + 1)), c.Accent)
	c.Cost.Text = "Cost: " .. colored(NumberFormat.Format(cost), if canBuy then CASH else RED) .. " " .. k.Currency
	setButton(c.Buy, balance >= cost and SEQ.Green or SEQ.Red, "Buy")
	local n = affordable(getCost, def.Id, lvl, balance)
	setButton(c.Max, n > 0 and SEQ.Yellow or SEQ.Red, "Max x" .. n)
end

-- ===== boards =====

local function buildUpgradeBoard(root: GuiObject, kind: string)
	local k = KINDS[kind]
	local amount = pill(root, 260, k.PillIcon, k.PillColor or k.Accent)
	local p = panel(root, #k.List * CARD_W + (#k.List + 1) * GAP, PANEL_H, PILL_H, k.Title, k.PillColor or k.Accent)
	local cards = {}
	for i, def in ipairs(k.List) do
		table.insert(cards, makeCard(p, i, kind, def))
	end
	table.insert(views, {
		Refresh = function()
			amount.Text = NumberFormat.Format(k.Balance()) .. (k.PillSuffix or "")
			for _, c in ipairs(cards) do refreshCard(c) end
		end,
	})
end

-- ✨ Ascension info (next to the Blood Rift): what it does + your progress towards it
local function buildAscensionBoard(root: GuiObject)
	local amount = pill(root, 240, "✨", ASC)
	local p = panel(root, CANVAS.AscensionBoard.X, PANEL_H, PILL_H, "Ascension", ASC)
	local function centered(y, h, props, s)
		props.Position = UDim2.fromOffset(14, y)
		props.Size = UDim2.new(1, -28, 0, h)
		return label(p, props, s)
	end
	centered(40, 40, { Text = "Resets your " .. colored("Cash", CASH) .. ", " .. colored("Upgrades", CASH) .. " & " .. colored("Skill Tree", GOLD)
		.. " for a permanent " .. colored("Ascension Point", ASC), TextWrapped = true }, 2)
	centered(82, 66, { Text = "🩸" }, 0)
	local count = centered(150, 28, { TextColor3 = ASC }, 3)
	local req = centered(182, 22, {}, 2)
	local hint = centered(212, 44, { TextWrapped = true, TextColor3 = GREY_TEXT }, 2)
	table.insert(views, {
		Refresh = function()
			local n = player:GetAttribute("Ascensions") or 0
			amount.Text = NumberFormat.Format(ap()) .. " AP"
			count.Text = NumberFormat.Format(n) .. (n == 1 and " Ascension" or " Ascensions")
			local ok = AscensionConfig.CanAscend(function(id) return player:GetAttribute("T_" .. id) == true end)
			req.Text = (ok and "✅ " or "🔒 ") .. "Needs " .. colored(AscensionConfig.RequiredNodeName, GOLD) .. " (Skill Tree)"
			hint.Text = ok and colored("The Blood Rift is open! Walk to the altar.", CASH) or "Enter the Blood Rift and walk up to the Blood Altar"
		end,
	})
end

-- ⭐ Prestige celebration
local function prestigeFx(gained: number)
	EffectsController.PlaySound("Upgrade", 0.9)
	EffectsController.CameraPunch(5)
	local big = label(fxGui, { Text = "⭐ PRESTIGE!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.4, 0.09) }, 5)
	new("UIGradient", { Color = ColorSequence.new(UIKit.Theme.Colors.Primary.Light, UIKit.Theme.Colors.Primary.Base) }, big)
	local sub = label(fxGui, { Text = "+" .. NumberFormat.Format(gained) .. " ⭐ Prestiges", TextColor3 = GOLD, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.3, 0.05) }, 3)
	for _, l in ipairs({ big, sub }) do
		local sc = new("UIScale", { Scale = 0.4 }, l)
		TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		EffectsController.Burst(root.Position, GOLD, 40)
		EffectsController.Burst(root.Position + Vector3.new(0, 3, 0), CASH, 25)
	end
	task.delay(1.6, function()
		for _, l in ipairs({ big, sub }) do
			TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play() end
		end
		task.wait(0.4)
		big:Destroy(); sub:Destroy()
	end)
end

-- a card-sized frame with the card background (for the exchange and teaser cards)
local function cardShell(parent, x: number, width: number, strokeColor: Color3)
	local f = new("Frame", { Position = UDim2.fromOffset(x, TITLE_H + GAP), Size = UDim2.fromOffset(width, CARD_H), BackgroundTransparency = 1 }, parent)
	new("UIScale", { Name = "PopScale" }, f)
	local bg = new("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 0 }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, bg)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Theme.Colors.Rice.Dark, UIKit.Theme.Colors.Rice.Dark) }, bg)
	stroke(bg, 3, true).Color = strokeColor
	return f
end

local function badgeIcon(parent, y: number, icon: string, color: Color3)
	local badge = new("Frame", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UIKit.Theme.Layout.BoardsController.Size21, BackgroundColor3 = UIKit.Theme.Muted }, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	new("UIStroke", { Thickness = 2.5, Color = color, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	label(badge, { Text = icon, Size = UIKit.Theme.Layout.BoardsController.Size22, Position = UDim2.fromOffset(5, 5) }, 0)
	return badge
end

-- A sideways-scrolling strip of cards between ◀ ▶ (and the mouse wheel while you point at
-- the wall). Add card frames in order (positioned with X(i)), then Show() hides the ones
-- outside the window so they can't be clicked.
local function scrollStrip(p: Frame, part: BasePart, viewX: number)
	local view = new("Frame", { Name = "View", Position = UDim2.fromOffset(viewX, 0), Size = UDim2.fromOffset(VIEW_W, PANEL_H), BackgroundTransparency = 1, ClipsDescendants = true }, p)
	local stripFrame = new("Frame", { Name = "Strip", Size = UDim2.fromOffset(VIEW_W, PANEL_H), BackgroundTransparency = 1 }, view)
	local slots = {}
	local offset = 0
	local left, right
	local function maxOffset() return math.max(0, #slots - WALL_VISIBLE) end
	local function show()
		for i, f in ipairs(slots) do f.Visible = i > offset and i <= offset + WALL_VISIBLE end
		setButton(left, offset > 0 and SEQ.Yellow or SEQ.Grey, "◀")
		setButton(right, offset < maxOffset() and SEQ.Yellow or SEQ.Grey, "▶")
	end
	local function scroll(dir: number)
		local target = math.clamp(offset + dir, 0, maxOffset())
		if target == offset then return end
		offset = target
		for _, f in ipairs(slots) do f.Visible = true end -- slide everything, then hide what's out of view
		local tw = TweenService:Create(stripFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(-offset * (CARD_W + GAP), 0) })
		tw:Play()
		tw.Completed:Once(show)
		EffectsController.PlaySound("UIClick", 1.1)
	end
	local arrowY = TITLE_H + GAP + CARD_H / 2 - 32
	left = button(p, { Position = UDim2.fromOffset(viewX - ARROW_W + 2, arrowY), Size = UDim2.fromOffset(ARROW_W - 6, 64) }, function() scroll(-1) end)
	right = button(p, { Position = UDim2.fromOffset(viewX + VIEW_W + 4, arrowY), Size = UDim2.fromOffset(ARROW_W - 6, 64) }, function() scroll(1) end)
	scrollers[part] = scroll
	return {
		Strip = stripFrame,
		X = function(i: number) return GAP + (i - 1) * (CARD_W + GAP) end,
		Count = function() return #slots end,
		Add = function(f: Frame) table.insert(slots, f) end,
		Show = show,
	}
end

-- locked "coming soon" cards at the end of a scrolling wall
local function addTeasers(strip, teasers)
	for _, t in ipairs(teasers) do
		local tf = cardShell(strip.Strip, strip.X(strip.Count() + 1), CARD_W, UIKit.Theme.Colors.Rice.Dark)
		label(tf, { Text = t.Title, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size23, Position = UDim2.fromOffset(6, 10) })
		label(tf, { Text = t.Icon, Size = UIKit.Theme.Layout.BoardsController.Size24, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48) }, 0)
		label(tf, { Text = t.Text, TextWrapped = true, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size25, Position = UDim2.fromOffset(10, 132) }, 2)
		label(tf, { Text = "Coming soon", TextColor3 = GOLD, Size = UIKit.Theme.Layout.BoardsController.Size26, Position = UDim2.fromOffset(10, 184) }, 2)
		strip.Add(tf)
	end
end

-- 🤖 The Automation wall: one card per automation (Buy with Prestiges, then an On/Off
-- switch). A card stays locked until its area is unlocked.
local AUTO = UIKit.Theme.Currency.Fish.Base
local function makeAutoCard(strip, def)
	local i = strip.Count() + 1
	local f = cardShell(strip.Strip, strip.X(i), CARD_W, UIKit.Theme.Colors.Rice.Dark)
	local c = { Frame = f, Def = def, Stroke = f.Bg:FindFirstChildOfClass("UIStroke") }
	label(f, { Text = def.Name, TextColor3 = AUTO, Size = UIKit.Theme.Layout.BoardsController.Size27, Position = UDim2.fromOffset(6, 6) })
	c.Count = label(f, { TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size28, Position = UDim2.fromOffset(6, 30) }, 2)
	badgeIcon(f, 50, def.Icon, AUTO)
	label(f, { Text = "Auto", Size = UIKit.Theme.Layout.BoardsController.Size29, Position = UDim2.fromOffset(6, 116) }, 2.5)
	label(f, { Text = def.Description, TextWrapped = true, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size30, Position = UDim2.fromOffset(7, 137) }, 1.5)
	c.Price = label(f, { Size = UIKit.Theme.Layout.BoardsController.Size31, Position = UDim2.fromOffset(7, 169) }, 2)
	c.Btn = button(f, { Position = UDim2.fromOffset(12, 188), Size = UDim2.fromOffset(CARD_W - 24, 28) }, function()
		local owned = player:GetAttribute(AutomationConfig.OwnedAttr(def.Id)) == true
		if not AutomationConfig.IsUnlocked(def.Id, player:GetAttribute("TotalRebirths")) then
			shake(f)
		elseif owned then
			Remotes:WaitForChild("ToggleAutomation"):FireServer(def.Id, player:GetAttribute(AutomationConfig.OnAttr(def.Id)) ~= true)
		elseif prestiges() < def.Cost then
			shake(f)
		else
			task.spawn(function()
				if Remotes:WaitForChild("BuyAutomation"):InvokeServer(def.Id) then
					EffectsController.PlaySound("Upgrade", 1.1)
					flash(f, AUTO)
					pop(f, 1.08)
				else
					shake(f)
				end
			end)
		end
	end)
	-- locked until the area is unlocked
	local zone = ZoneConfig.ById[def.Zone]
	local lock = new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Theme.Muted, BackgroundTransparency = 0.04, ZIndex = 5, Visible = false }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, lock)
	label(lock, { Text = def.Name, ZIndex = 6, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size32, Position = UDim2.fromOffset(6, 10) }, 2)
	label(lock, { Text = "🔒", ZIndex = 6, Size = UIKit.Theme.Layout.BoardsController.Size33, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40) }, 0)
	label(lock, { Text = "Unlock the", ZIndex = 6, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size34, Position = UDim2.fromOffset(6, 104) }, 2)
	label(lock, { Text = zone and (zone.Icon .. " " .. zone.Name) or def.Zone, ZIndex = 6, TextColor3 = AUTO, Size = UIKit.Theme.Layout.BoardsController.Size35, Position = UDim2.fromOffset(6, 124) }, 2.5)
	label(lock, { Text = "Rebirth Required: " .. AutomationConfig.RequiredRebirths(def.Id), ZIndex = 6, TextColor3 = RED, Size = UIKit.Theme.Layout.BoardsController.Size36, Position = UDim2.fromOffset(6, 160) }, 2)
	c.Lock = lock
	strip.Add(f)
	return c
end

local function refreshAutoCard(c)
	local def = c.Def
	local unlocked = AutomationConfig.IsUnlocked(def.Id, player:GetAttribute("TotalRebirths"))
	local owned = player:GetAttribute(AutomationConfig.OwnedAttr(def.Id)) == true
	local on = player:GetAttribute(AutomationConfig.OnAttr(def.Id)) == true
	c.Lock.Visible = not unlocked
	c.Btn.Button.Visible = unlocked
	c.Count.Text = owned and "1/1" or "0/1"
	if owned then
		c.Stroke.Color = on and CASH or GOLD
		c.Price.Text = "Toggle:"
		setButton(c.Btn, on and SEQ.Green or SEQ.Red, on and "On" or "Off", unlocked)
	else
		local can = prestiges() >= def.Cost
		c.Stroke.Color = can and AUTO or UIKit.Theme.Ink
		c.Price.Text = "Cost: " .. colored(NumberFormat.Format(def.Cost) .. " ⭐", can and CASH or RED)
		setButton(c.Btn, can and SEQ.Green or SEQ.Red, "Buy", unlocked)
	end
end

local function buildAutomationWall(root: GuiObject, part: BasePart)
	local amount = pill(root, 260, "⭐", GOLD)
	local p = panel(root, CANVAS.AutomationWall.X, PANEL_H, PILL_H, "🤖 Automation", AUTO)
	local strip = scrollStrip(p, part, GAP + ARROW_W)
	local cards = {}
	for _, def in ipairs(AutomationConfig.List) do table.insert(cards, makeAutoCard(strip, def)) end
	addTeasers(strip, AutomationConfig.Teasers)
	strip.Show()
	table.insert(views, {
		Refresh = function()
			amount.Text = NumberFormat.Format(prestiges())
			for _, c in ipairs(cards) do refreshAutoCard(c) end
			strip.Show()
		end,
	})
end

-- ⭐ The Prestige wall: the Cash -> Prestige exchange on the left, then every Prestige
-- Upgrade on a strip you scroll sideways (◀ ▶ buttons or the mouse wheel). Locked cards
-- show the Rebirth they need; teaser cards at the end tease the next worlds.
local prestiging = false
local prestigeConfirmUntil = 0
local function buildPrestigeWall(root: GuiObject, part: BasePart)
	local k = KINDS.Prestige
	local amount = pill(root, 260, "⭐", GOLD)
	local p = panel(root, CANVAS.PrestigeWall.X, PANEL_H, PILL_H, "Prestige", GOLD)

	-- the exchange card
	local ex = cardShell(p, GAP, EXCHANGE_W, GOLD)
	label(ex, { Text = "Prestige", TextColor3 = GOLD, Size = UIKit.Theme.Layout.BoardsController.Size37, Position = UDim2.fromOffset(6, 6) })
	label(ex, { Text = "Resets " .. colored("Cash", CASH) .. ", " .. colored("KG", KG) .. " & " .. colored("Cash Upgrades", CASH),
		TextWrapped = true, TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size38, Position = UDim2.fromOffset(8, 32) }, 1.5)
	badgeIcon(ex, 66, "⭐", GOLD)
	local gain = label(ex, { TextColor3 = GOLD, Size = UIKit.Theme.Layout.BoardsController.Size39, Position = UDim2.fromOffset(6, 132) }, 3)
	local hint = label(ex, { TextColor3 = GREY_TEXT, Size = UIKit.Theme.Layout.BoardsController.Size40, Position = UDim2.fromOffset(8, 160) }, 2)
	local btn
	btn = button(ex, { Position = UDim2.fromOffset(10, 180), Size = UDim2.fromOffset(EXCHANGE_W - 20, 34) }, function()
		require(script.Parent.ResetMenuController).Open("Prestige")
	end)

	-- the scrolling strip of upgrade cards (+ teasers at the end)
	local strip = scrollStrip(p, part, GAP + EXCHANGE_W + GAP + ARROW_W)
	local cards = {}
	for i, def in ipairs(k.List) do
		local c = makeCard(strip.Strip, i, "Prestige", def)
		table.insert(cards, c)
		strip.Add(c.Frame)
	end
	addTeasers(strip, PrestigeConfig.Teasers)
	strip.Show()

	table.insert(views, {
		Refresh = function()
			amount.Text = NumberFormat.Format(prestiges())
			local mult = player:GetAttribute("PrestigeMultiplier") or 1
			local n = PrestigeConfig.Gain(money(), mult)
			if n > 0 then
				gain.Text = "+" .. NumberFormat.Format(n) .. " ⭐"
				hint.Text = "for all your " .. colored(NumberFormat.Cash(money()), CASH)
			else
				gain.Text = "+0 ⭐"
				hint.Text = "Need " .. colored(NumberFormat.Cash(PrestigeConfig.MinCash), CASH) .. " Cash"
			end
			if n <= 0 then
				setButton(btn, SEQ.Grey, NumberFormat.Cash(PrestigeConfig.MinCash - money()) .. " to go")
			elseif prestiging then
				setButton(btn, SEQ.Grey, "...")
			elseif os.clock() < prestigeConfirmUntil then
				setButton(btn, SEQ.Yellow, "CONFIRM?")
			else
				setButton(btn, SEQ.Yellow, "Prestige")
			end
			for _, c in ipairs(cards) do refreshCard(c) end
			strip.Show()
		end,
	})
end

-- 🔄 Rebirth: the milestone screen standing on the Rebirth Altar (end of the Prestige row).
-- Kept short: the Cash boost before/after, what it unlocks, a ⭐ progress bar to the price,
-- one line on what resets, and the button.
local rebirthing = false
local rebirthConfirmUntil = 0
local function rebirthFx(total: number)
	EffectsController.PlaySound("Upgrade", 0.8)
	EffectsController.CameraPunch(7)
	local unlocks = RebirthConfig.UnlocksAt(total)
	local lines = { "🔄 REBIRTH " .. total .. "!", "Cash x" .. NumberFormat.Format(RebirthConfig.CashBoost(total)) }
	for _, u in ipairs(unlocks) do table.insert(lines, u.Icon .. " " .. u.Text .. " unlocked!") end
	local made = {}
	for i, text in ipairs(lines) do
		local l = label(fxGui, { Text = text, TextColor3 = i == 1 and WHITE or (i == 2 and CASH or GOLD), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.28 + (i - 1) * 0.065), Size = UDim2.fromScale(i == 1 and 0.5 or 0.36, i == 1 and 0.09 or 0.05) }, i == 1 and 5 or 3)
		if i == 1 then new("UIGradient", { Color = ColorSequence.new(UIKit.Theme.Colors.Primary.Base, UIKit.Theme.Colors.Accent.Base) }, l) end
		local sc = new("UIScale", { Scale = 0.4 }, l)
		TweenService:Create(sc, TweenInfo.new(0.4 + i * 0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		table.insert(made, l)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		EffectsController.Burst(root.Position, RED, 45)
		EffectsController.Burst(root.Position + Vector3.new(0, 3, 0), GOLD, 30)
	end
	task.delay(2.6, function()
		for _, l in ipairs(made) do
			TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play() end
		end
		task.wait(0.4)
		for _, l in ipairs(made) do l:Destroy() end
	end)
end

local function buildRebirthBoard(root: GuiObject)
	local size = CANVAS.RebirthBoard
	local amount = pill(root, 250, "🔄", RED)
	local p = panel(root, size.X, size.Y - PILL_H, PILL_H, "Rebirth", RED)
	local function centered(y, h, props, s)
		props.Position = UDim2.fromOffset(16, y)
		props.Size = UDim2.new(1, -32, 0, h)
		return label(p, props, s)
	end
	badgeIcon(p, 46, "🔄", RED)
	local boost = centered(116, 36, {}, 3)
	local unlocks = centered(156, 26, { TextColor3 = GOLD }, 2.5)
	-- ⭐ progress toward the price
	local track = new("Frame", { Position = UDim2.fromOffset(30, 196), Size = UIKit.Theme.Layout.BoardsController.Size41, BackgroundColor3 = UIKit.Theme.Muted }, p)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	new("UIStroke", { Thickness = 2, Color = RED, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, track)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	new("UIGradient", { Color = ColorSequence.new(UIKit.Theme.Colors.Danger.Base, UIKit.Theme.Colors.Primary.Base) }, fill)
	local progress = label(track, { Size = UIKit.Theme.Layout.BoardsController.Size42, Position = UDim2.fromOffset(4, 2), ZIndex = 3 }, 2.5)
	centered(232, 20, { Text = "Resets Cash, Prestiges, Fish & Slices", TextColor3 = GREY_TEXT }, 2)
	local btn
	btn = button(p, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 272), Size = UIKit.Theme.Layout.BoardsController.Size43 }, function()
		require(script.Parent.ResetMenuController).Open("Rebirth")
	end)
	table.insert(views, {
		Refresh = function()
			local total = player:GetAttribute("TotalRebirths") or 0
			local price = RebirthConfig.Cost(total)
			amount.Text = NumberFormat.Format(total) .. (total == 1 and " Rebirth" or " Rebirths")
			boost.Text = colored("x" .. NumberFormat.Format(RebirthConfig.CashBoost(total)), GREY_TEXT) .. " > "
				.. colored("x" .. NumberFormat.Format(RebirthConfig.CashBoost(total + 1)) .. " Cash", CASH)
			local list = {}
			for _, u in ipairs(RebirthConfig.UnlocksAt(total + 1)) do table.insert(list, u.Icon .. " " .. u.Text) end
			unlocks.Text = #list > 0 and ("Unlocks " .. table.concat(list, " & ")) or colored("Bigger Cash boost", GREY_TEXT)
			local have = prestiges()
			local frac = math.clamp(have / price, 0, 1)
			fill.Size = UDim2.fromScale(frac, 1)
			fill.Visible = frac > 0
			progress.Text = NumberFormat.Format(math.min(have, price)) .. " / " .. NumberFormat.Format(price) .. " ⭐"
			if have < price then
				setButton(btn, SEQ.Grey, NumberFormat.Format(price - have) .. " ⭐ to go")
			elseif rebirthing then
				setButton(btn, SEQ.Grey, "...")
			elseif os.clock() < rebirthConfirmUntil then
				setButton(btn, SEQ.Yellow, "CONFIRM?")
			else
				setButton(btn, SEQ.Red, "Rebirth")
			end
		end,
	})
end

-- The Sushi Market screen (like the reference "Converter")
local function buildConverter(root: GuiObject, part: BasePart)
	-- laid out exactly like the upgrade boards: amount pill on top, titled panel below
	local size = CANVAS.Converter
	local amount = pill(root, 260, "🍣", KG)
	local p = panel(root, size.X, PANEL_H, PILL_H, "Sushi Market", GOLD)
	local function centered(y, h, props, s)
		props.Position = UDim2.fromOffset(20, y)
		props.Size = UDim2.new(1, -40, 0, h)
		return label(p, props, s)
	end
	centered(46, 26, { Text = "Sell your " .. colored("Sushi", KG) .. " for " .. colored("Cash", CASH) }, 2)
	new("Frame", { Position = UDim2.fromOffset(60, 80), Size = UIKit.Theme.Layout.BoardsController.Size44, BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, BorderSizePixel = 0 }, p)
	centered(90, 30, { Text = "Sushi Value", TextColor3 = GOLD }, 3)
	local rate = centered(122, 26, {}, 2)
	local preview = centered(154, 44, { TextColor3 = CASH }, 3)
	local btn = button(p, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 210), Size = UIKit.Theme.Layout.BoardsController.Size45 }, function(b)
		if (player:GetAttribute("KG") or 0) <= 0 then
			shake(b)
			return
		end
		MarketController.Sell()
	end)
	table.insert(views, {
		Refresh = function()
			local kg = player:GetAttribute("KG") or 0
			local r = player:GetAttribute("SellRate") or EconomyConfig.BaseSellRate
			amount.Text = NumberFormat.KG(kg)
			rate.Text = "1kg " .. colored("Sushi", KG) .. " = " .. NumberFormat.Format(r) .. " " .. colored("Cash", CASH)
			preview.Text = "+" .. NumberFormat.Format(kg * r) .. " Cash"
			setButton(btn, kg > 0 and SEQ.Yellow or SEQ.Grey, "Sell")
		end,
	})
end

function BoardsController.RefreshAll()
	for _, v in ipairs(views) do v.Refresh() end
end

-- ===== build the world boards =====

local function buildBoardFor(part: BasePart)
	if worldGuis[part] then return end
	local boardType = part:GetAttribute("BoardType")
	local size = CANVAS[boardType]
	if not size then return end
	-- the label that shows which board this is in Studio's Edit mode
	local preview = part:FindFirstChild("EditPreview")
	if preview then preview:Destroy() end
	part.Transparency = 1 -- only tinted so it can be clicked and moved in Edit mode
	local sg = new("SurfaceGui", {
		Name = boardType,
		Adornee = part,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = size,
		LightInfluence = 0,
		MaxDistance = 130,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local canvas = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, sg)
	if boardType == "CashBoard" then
		buildUpgradeBoard(canvas, "Cash")
	elseif boardType == "PrestigeWall" then
		buildPrestigeWall(canvas, part)
	elseif boardType == "RebirthBoard" then
		buildRebirthBoard(canvas)
	elseif boardType == "AutomationWall" then
		buildAutomationWall(canvas, part)
	elseif boardType == "AscensionUpgradesBoard" then
		buildUpgradeBoard(canvas, "Ascension")
	elseif boardType == "AscensionBoard" then
		buildAscensionBoard(canvas)
	elseif boardType == "Converter" then
		buildConverter(canvas, part)
	elseif boardType == "FishUpgradesBoard" then
		buildUpgradeBoard(canvas, "Fish")
	elseif boardType == "SliceUpgradesBoard" then
		buildUpgradeBoard(canvas, "Slice")
	end
	worldGuis[part] = sg
end

-- ===== clicking the world boards =====

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local hovered: TextButton? = nil

local function isShown(g: Instance?): boolean
	while g and g:IsA("GuiObject") do
		if not g.Visible then return false end
		g = g.Parent
	end
	return true
end

-- true when a screen (HUD/menu) element is under the pointer, so it wins
local function screenUiAt(pos: Vector2): boolean
	for _, o in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)) do
		local lc = o:FindFirstAncestorWhichIsA("LayerCollector")
		if lc and lc:IsA("ScreenGui") and lc.Enabled and (o:IsA("GuiButton") or o.Active) and isShown(o) then
			return true
		end
	end
	return false
end

-- the board part under the pointer (front side only), and where on it was hit
local function boardAt(pos: Vector2): (BasePart?, Vector3?)
	local parts = {}
	for part in pairs(worldGuis) do table.insert(parts, part) end
	if #parts == 0 then return nil end
	rayParams.FilterDescendantsInstances = parts
	local ray = workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 130, rayParams)
	if not hit then return nil end
	local part = hit.Instance :: BasePart
	if not worldGuis[part] then return nil end
	local lp = part.CFrame:PointToObjectSpace(hit.Position)
	if lp.Z > 0 then return nil end -- the back of the board
	return part, lp
end

local function worldButtonAt(pos: Vector2): TextButton?
	local part, lp = boardAt(pos)
	if not part or not lp then return nil end
	local sg = worldGuis[part]
	local cx = (0.5 - lp.X / part.Size.X) * sg.CanvasSize.X
	local cy = (0.5 - lp.Y / part.Size.Y) * sg.CanvasSize.Y
	for b in pairs(buttonHandlers) do
		if b:IsDescendantOf(sg) and isShown(b) then
			local ap, as = b.AbsolutePosition, b.AbsoluteSize
			if cx >= ap.X and cx <= ap.X + as.X and cy >= ap.Y and cy <= ap.Y + as.Y then
				return b
			end
		end
	end
	return nil
end

local function setHover(b: TextButton?)
	if b == hovered then return end
	if hovered then UIKit.SetInteraction(hovered,"Normal") end
	if b then UIKit.SetInteraction(b,"Hover") end
	if hovered then
		local sc = hovered:FindFirstChild("PopScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play() end
	end
	hovered = b
	if b then
		local sc = b:FindFirstChild("PopScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.08 }):Play() end
		EffectsController.PlaySound("UIHover")
	end
end

local function hookWorldInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		if t == Enum.UserInputType.Touch and gameProcessed then return end -- thumbstick / jump
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if screenUiAt(pos) then return end
		local b = worldButtonAt(pos)
		if b then buttonHandlers[b]() end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		setHover(not screenUiAt(pos) and worldButtonAt(pos) or nil)
	end)
	-- the mouse wheel scrolls a scrolling wall while you point at it (and zooms the camera otherwise)
	ContextActionService:BindActionAtPriority("BoardScroll", function(_, state, input)
		if state ~= Enum.UserInputState.Change then return Enum.ContextActionResult.Pass end
		local pos = UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset() -- same space as input.Position
		if screenUiAt(pos) then return Enum.ContextActionResult.Pass end
		local part = boardAt(pos)
		local scroll = part and scrollers[part]
		if not scroll then return Enum.ContextActionResult.Pass end
		scroll(input.Position.Z > 0 and -1 or 1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)
end

function BoardsController.Init()
	fxGui = new("ScreenGui", { Name = "BoardsFX", ResetOnSpawn = false, DisplayOrder = 8 }, player:WaitForChild("PlayerGui"))
	for _, part in ipairs(CollectionService:GetTagged("UpgradeBoard")) do
		if part:IsA("BasePart") then buildBoardFor(part) end
	end
	CollectionService:GetInstanceAddedSignal("UpgradeBoard"):Connect(function(part)
		if part:IsA("BasePart") then buildBoardFor(part) end
	end)
	hookWorldInput()

	local watched = { "Money", "KG", "SellRate", "TotalRebirths", "RebirthCost",
		"Ascensions", "AscensionPoints", "Set_AutoBuy", "T_" .. AscensionConfig.RequiredNode,
		"Fish", "Slices", "Prestiges", "TotalPrestiges", "PrestigeCount", "PrestigeMultiplier" }
	for _, u in ipairs(FishConfig.Upgrades.List) do table.insert(watched, FishConfig.Upgrades.AttributeName(u.Id)) end
	for _, u in ipairs(SliceConfig.Upgrades.List) do table.insert(watched, SliceConfig.Upgrades.AttributeName(u.Id)) end
	for _, u in ipairs(PrestigeConfig.List) do table.insert(watched, PrestigeConfig.AttributeName(u.Id)) end
	for _, a in ipairs(AutomationConfig.List) do
		table.insert(watched, AutomationConfig.OwnedAttr(a.Id))
		table.insert(watched, AutomationConfig.OnAttr(a.Id))
	end
	for _, u in ipairs(AscensionConfig.Upgrades) do table.insert(watched, AscensionConfig.AttributeName(u.Id)) end
	for _, u in ipairs(UpgradeConfig.List) do table.insert(watched, UpgradeConfig.AttributeName(u.Id)) end
	local dirty = true -- refresh at most once per frame
	for _, a in ipairs(watched) do
		player:GetAttributeChangedSignal(a):Connect(function() dirty = true end)
	end
	local lastTick = 0
	RunService.RenderStepped:Connect(function()
		if dirty then
			dirty = false
			BoardsController.RefreshAll()
		elseif os.clock() - lastTick >= 1 then
			lastTick = os.clock()
			for _, v in ipairs(views) do
				if v.Ticks then v.Refresh() end
			end
		end
	end)

	Remotes.UpgradePurchased.OnClientEvent:Connect(function(id, newLevel, bought)
		onPurchased("Cash", id, newLevel, bought)
	end)
	Remotes.AscensionUpgradePurchased.OnClientEvent:Connect(function(id, newLevel, bought)
		onPurchased("Ascension", id, newLevel, bought)
	end)
	task.spawn(function()
		Remotes:WaitForChild("FishUpgradePurchased").OnClientEvent:Connect(function(id, newLevel, bought)
			onPurchased("Fish", id, newLevel, bought)
		end)
		Remotes:WaitForChild("SliceUpgradePurchased").OnClientEvent:Connect(function(id, newLevel, bought)
			onPurchased("Slice", id, newLevel, bought)
		end)
		Remotes:WaitForChild("PrestigeUpgradePurchased").OnClientEvent:Connect(function(id, newLevel, bought)
			onPurchased("Prestige", id, newLevel, bought)
		end)
	end)
end

return BoardsController
