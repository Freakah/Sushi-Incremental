-- RunesMenuController: the 🔮 Runes menu (tile on the left).
-- Left: one tab per area that has runes (Fish Pond for now). Right: that area's runes
-- from most common to rarest, as cards: name ([MAX] once maxed), rarity, chance (with your
-- Rune Luck), what it boosts right now, and how many you have. Runes you haven't rolled
-- yet show their rarity and chance but stay hidden (???).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuneConfig = require(ReplicatedStorage.Shared.Config.RuneConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local RunesMenuController = {}

local C = Color3.fromRGB
local CARD_W, CARD_H, GAP, COLS = 196, 214, 14, 4
local SIDE_W = 190
local GOLD = C(255, 205, 70)
local CARD_BG = C(34, 36, 46)
local LOCKED_BG = C(26, 27, 34)

local window
local selected = RuneConfig.Areas[1].Id
local tabs = {}
local pages = {} -- [areaId] = { Frame, Cards }
local header: TextLabel
local info: TextLabel
local seen = {} -- [runeId] = true once shown in the menu (for the tile badge)
local hasNew = false

local function hex(c: Color3) return c:ToHex() end
local function colored(t: string, c: Color3) return '<font color="#' .. hex(c) .. '">' .. t .. "</font>" end
-- x1.004 / x2.5 / x421.9 (small boosts keep 3 decimals so you can see them grow)
local function mult(v: number): string
	local s = if v < 10 then string.format("%.3f", v) elseif v < 100 then string.format("%.2f", v) else string.format("%.1f", v)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return "x" .. s
end

local function buildCard(parent, rune, index: number)
	local rarity = RuneConfig.RarityOf(rune)
	local col, row = (index - 1) % COLS, math.floor((index - 1) / COLS)
	local f = UIKit.new("Frame", {
		Name = rune.Id,
		Position = UDim2.fromOffset(col * (CARD_W + GAP), row * (CARD_H + GAP)),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = CARD_BG,
	}, parent)
	UIKit.Corner(f, 14)
	local stroke = UIKit.Stroke(f, 4, rarity.Color, true)
	local grad
	if rarity.Rainbow then
		grad = UIKit.new("UIGradient", { Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 90, 90)), ColorSequenceKeypoint.new(0.25, C(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, C(90, 255, 140)), ColorSequenceKeypoint.new(0.75, C(90, 170, 255)),
			ColorSequenceKeypoint.new(1, C(220, 110, 255)) }) }, stroke)
	end
	-- a soft band of the rarity colour across the top
	local band = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = rarity.Color, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, f)
	UIKit.Corner(band, 14)
	local name = UIKit.Label(f, { Text = rune.Name, Size = UDim2.new(1, -14, 0, 26), Position = UDim2.fromOffset(7, 8), TextColor3 = rarity.Color }, 2.5)
	UIKit.Label(f, { Text = string.upper(rune.Rarity), Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 35), TextColor3 = rarity.Color }, 2)
	local chance = UIKit.Label(f, { Text = "", Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 56) }, 2.5)
	local stats = {}
	local order = {}
	for _, s in ipairs(RuneConfig.Stats) do
		if rune.Boost[s.Id] then table.insert(order, s) end
	end
	for i, s in ipairs(order) do
		stats[i] = { Stat = s, Label = UIKit.Label(f, { Text = "", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 86 + (i - 1) * 22) }, 2) }
	end
	-- copies: progress toward Max + the count in the corner
	local barBack = UIKit.new("Frame", { Position = UDim2.new(0, 12, 1, -40), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = C(16, 17, 22), BorderSizePixel = 0 }, f)
	UIKit.Corner(barBack, 4)
	local barFill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = rarity.Color, BorderSizePixel = 0 }, barBack)
	UIKit.Corner(barFill, 4)
	local progress = UIKit.Label(f, { Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, -12, 0, 20), Position = UDim2.new(0, 12, 1, -28), TextColor3 = C(190, 195, 210) }, 2)
	local count = UIKit.Label(f, { Text = "", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, -12, 0, 24), Position = UDim2.new(0.5, 0, 1, -30) }, 2.5)
	local scale = UIKit.new("UIScale", {}, f)
	return { Rune = rune, Frame = f, Band = band, Name = name, Chance = chance, Stats = stats, Fill = barFill, Progress = progress, Count = count, Scale = scale, Grad = grad }
end

local function refreshCard(c, luck: number)
	local rune = c.Rune
	local rarity = RuneConfig.RarityOf(rune)
	local n = player:GetAttribute(RuneConfig.Attr(rune.Id)) or 0
	local found = n > 0
	c.Frame.BackgroundColor3 = if found then CARD_BG else LOCKED_BG
	c.Band.Visible = found
	c.Chance.Text = RuneConfig.FormatChance(RuneConfig.EffectiveChance(rune, luck))
	if not found then
		c.Name.Text = "???"
		for _, s in ipairs(c.Stats) do s.Label.Text = colored("???", C(120, 122, 135)) end
		c.Progress.Text = "Not found yet"
		c.Count.Text = ""
		c.Fill.Size = UDim2.fromScale(0, 1)
		return
	end
	local maxed = n >= rune.Max
	c.Name.Text = rune.Name .. (if maxed then " " .. colored("[MAX]", GOLD) else "")
	for _, s in ipairs(c.Stats) do
		local v = RuneConfig.BoostFor(rune, s.Stat.Id, n)
		s.Label.Text = colored(s.Stat.Name, s.Stat.Color) .. " " .. mult(v)
	end
	c.Progress.Text = if maxed then colored("MAX", GOLD) else NumberFormat.Format(n) .. " / " .. NumberFormat.Format(rune.Max)
	c.Count.Text = "x" .. NumberFormat.Format(n)
	c.Fill.Size = UDim2.fromScale(math.clamp(n / rune.Max, 0, 1), 1)
	c.Fill.BackgroundColor3 = if maxed then GOLD else rarity.Color
end

local function refresh()
	local luck = player:GetAttribute("RuneLuck") or 1
	local area = RuneConfig.AreaById[selected]
	header.Text = area.Icon .. " " .. area.Name .. " Runes"
	info.Text = "Stand at the Rune Altar to roll • " .. RuneConfig.RollCost .. " " .. area.CurrencyIcon .. " per roll     "
		.. colored("🍀 Rune Luck " .. mult(luck), C(110, 220, 255))
		.. "     🎲 " .. NumberFormat.Format(player:GetAttribute("RuneRolls") or 0) .. " rolls"
	for id, page in pairs(pages) do
		page.Frame.Visible = id == selected
		if id == selected then
			for _, c in ipairs(page.Cards) do refreshCard(c, luck) end
		end
	end
	for id, t in pairs(tabs) do
		t.SetColors(if id == selected then UIKit.Gradients.Blue else UIKit.Gradients.Dark)
	end
end

function RunesMenuController.Toggle() window.Toggle() end
function RunesMenuController.HasNew(): boolean return hasNew end

function RunesMenuController.Init()
	local gridW = COLS * CARD_W + (COLS - 1) * GAP
	window = UIKit.Window({ Name = "Runes", Title = "Runes", Icon = "🔮", Accent = C(120, 230, 255), Size = Vector2.new(SIDE_W + gridW + 44 + 60 + 24, 720) })
	local body = window.Body

	-- area tabs
	local side = UIKit.new("Frame", { Name = "Areas", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0, SIDE_W, 1, -28) }, body)
	UIKit.Label(side, { Text = "Areas", Size = UDim2.new(1, 0, 0, 28), TextColor3 = UIKit.Colors.Subtle }, 2.5)
	for i, area in ipairs(RuneConfig.Areas) do
		tabs[area.Id] = UIKit.Button(side, {
			Name = area.Id, Label = area.Icon .. " " .. area.Name,
			Position = UDim2.fromOffset(0, 36 + (i - 1) * 66), Size = UDim2.new(1, 0, 0, 56),
			Colors = UIKit.Gradients.Dark,
		}, function()
			selected = area.Id
			refresh()
		end)
	end
	UIKit.Label(side, { Text = "More areas soon", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 36 + #RuneConfig.Areas * 66 + 6), TextColor3 = C(150, 152, 162) }, 2)

	-- the selected area's runes
	local main = UIKit.new("Frame", { Name = "Main", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE_W + 34, 10), Size = UDim2.new(1, -(SIDE_W + 48), 1, -20) }, body)
	header = UIKit.Label(main, { Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 36) }, 3)
	info = UIKit.Label(main, { Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 38), TextColor3 = UIKit.Colors.Subtle }, 2)
	for _, area in ipairs(RuneConfig.Areas) do
		local rows = math.ceil(#area.Runes / COLS)
		local scroll = UIKit.new("ScrollingFrame", {
			Name = area.Id, BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70),
			CanvasSize = UDim2.fromOffset(0, rows * (CARD_H + GAP) + 8), ScrollBarThickness = 8,
			ScrollBarImageColor3 = C(150, 150, 160), ScrollingDirection = Enum.ScrollingDirection.Y,
		}, main)
		local grid = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(gridW, rows * (CARD_H + GAP)) }, scroll)
		local cards = {}
		for i, rune in ipairs(area.Runes) do table.insert(cards, buildCard(grid, rune, i)) end
		pages[area.Id] = { Frame = scroll, Cards = cards }
	end

	-- live updates + the tile badge (a rune you haven't seen in the menu yet)
	local dirty = true
	local function watch(attr) player:GetAttributeChangedSignal(attr):Connect(function() dirty = true end) end
	watch("RuneLuck"); watch("RuneRolls")
	for _, rune in ipairs(RuneConfig.All) do
		local attr = RuneConfig.Attr(rune.Id)
		seen[rune.Id] = (player:GetAttribute(attr) or 0) > 0
		player:GetAttributeChangedSignal(attr):Connect(function()
			dirty = true
			if (player:GetAttribute(attr) or 0) > 0 and not seen[rune.Id] then
				if window.IsOpen() then
					seen[rune.Id] = true
				else
					hasNew = true
				end
			end
			-- a little pop on the card if the menu is open
			local page = pages[rune.Area]
			if page and window.IsOpen() then
				for _, c in ipairs(page.Cards) do
					if c.Rune == rune then
						c.Scale.Scale = 1.06
						TweenService:Create(c.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					end
				end
			end
		end)
	end
	RunService.Heartbeat:Connect(function()
		if not window.IsOpen() then return end
		if dirty then
			dirty = false
			refresh()
		end
		-- the Secret card's border shimmers
		for _, page in pairs(pages) do
			for _, c in ipairs(page.Cards) do
				if c.Grad then c.Grad.Rotation = (os.clock() * 90) % 360 end
			end
		end
	end)
	table.insert(window.OnOpen, function()
		hasNew = false
		for _, rune in ipairs(RuneConfig.All) do seen[rune.Id] = (player:GetAttribute(RuneConfig.Attr(rune.Id)) or 0) > 0 end
		refresh()
	end)
end

return RunesMenuController
