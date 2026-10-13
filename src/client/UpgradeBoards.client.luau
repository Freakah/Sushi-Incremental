--[[
	UpgradeBoards  (LocalScript in StarterPlayer > StarterPlayerScripts)
	===================================================================
	Draws the clickable upgrade boards on the board parts in Workspace and
	makes them feel juicy: buttons bounce, numbers count up, floating
	"-$50" / "LEVEL UP!" text, sparkle bursts, rising pitch on buy streaks,
	shaking when you can't afford something, and a big rebirth celebration.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local remote = ReplicatedStorage:WaitForChild("UpgradeShopRemote")
local boardsFolder = workspace:WaitForChild(Config.BoardsFolderName)
local leaderstats = player:WaitForChild("leaderstats")

--------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(26, 28, 36)
local CARD = Color3.fromRGB(46, 49, 62)
local OUTLINE = Color3.fromRGB(12, 12, 18)
local BAR_BG = Color3.fromRGB(18, 19, 26)
local GREY_TEXT = Color3.fromRGB(185, 190, 208)
local BUY = Color3.fromRGB(80, 220, 70)
local MAX = Color3.fromRGB(255, 205, 50)
local DISABLED = Color3.fromRGB(105, 108, 122)
local RED = Color3.fromRGB(255, 75, 95)
local GOLD = Color3.fromRGB(255, 215, 70)
local REBIRTH_BUTTON = Color3.fromRGB(240, 55, 85)

local UPGRADE_CANVAS = Vector2.new(1200, 700)
local REBIRTH_CANVAS = Vector2.new(520, 700)

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------

local function create(className, props)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function border(parent, thickness, color)
	return create("UIStroke", {
		Thickness = thickness,
		Color = color or OUTLINE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Text with a dark outline, sized to fit its box
local function text(props, strokeThickness)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		RichText = true,
		TextColor3 = WHITE,
	})
	for key, value in props do
		if key ~= "Parent" then
			label[key] = value
		end
	end
	create("UIStroke", { Thickness = strokeThickness or 3, Color = OUTLINE, Parent = label })
	label.Parent = props.Parent
	return label
end

local function tween(object, time, goal, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function hex(color)
	return "#" .. color:ToHex()
end

local function colored(message, color)
	return ('<font color="%s">%s</font>'):format(hex(color), message)
end

local format = Config.FormatNumber

local function getCurrency(currencyId)
	local stat = leaderstats:FindFirstChild(Config.Currencies[currencyId].Stat)
	return if stat then stat.Value else 0
end

-- Centre of a GUI object in its board's pixel space
local function centerOf(root, object)
	local offset = object.AbsolutePosition - root.AbsolutePosition + object.AbsoluteSize / 2
	return UDim2.fromOffset(offset.X, offset.Y)
end

--------------------------------------------------------------------------
-- Juice: sounds, pops, floating text, sparkles, shakes, flashes
--------------------------------------------------------------------------

local sounds = {}
for name, id in Config.Sounds do
	sounds[name] = create("Sound", { SoundId = id, Volume = 0.5, Parent = SoundService })
end

local function playSound(name, pitch)
	local sound = sounds[name]
	if not sound then
		return
	end
	local copy = sound:Clone()
	copy.PlaybackSpeed = pitch or 1
	copy.Parent = SoundService
	copy:Play()
	Debris:AddItem(copy, 3)
end

-- Buying again quickly raises the pitch, like a combo
local combo, lastBuy = 0, 0
local function comboPitch()
	local now = os.clock()
	combo = if now - lastBuy < 1.2 then math.min(combo + 1, 12) else 0
	lastBuy = now
	return 1 + combo * 0.06
end

local function getScale(object)
	return object:FindFirstChild("PopScale") or create("UIScale", { Name = "PopScale", Parent = object })
end

local function pop(object, amount)
	local scale = getScale(object)
	scale.Scale = amount or 1.25
	tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function floatText(root, message, color, position, size)
	local label = text({
		Text = message,
		TextColor3 = color,
		Size = size or UDim2.fromOffset(300, 50),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 40,
		Parent = root,
	}, 4)
	local scale = create("UIScale", { Scale = 0.4, Parent = label })
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(label, 1, { Position = position - UDim2.fromOffset(0, 100), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(label:FindFirstChildOfClass("UIStroke"), 1, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(label, 1.1)
end

local function sparkles(root, position, color, count)
	for i = 1, count or 10 do
		local angle = (i / (count or 10)) * math.pi * 2 + math.random() * 0.5
		local distance = math.random(80, 150)
		local size = math.random(10, 18)
		local spark = create("Frame", {
			BackgroundColor3 = if i % 2 == 0 then color else WHITE,
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Rotation = 45,
			ZIndex = 39,
			Parent = root,
		})
		corner(spark, 3)
		tween(spark, 0.6, {
			Position = position + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = 45 + math.random(-180, 180),
			Size = UDim2.fromOffset(4, 4),
		})
		Debris:AddItem(spark, 0.7)
	end
end

local homePositions = {}
local function shake(object)
	local home = homePositions[object] or object.Position
	homePositions[object] = home
	task.spawn(function()
		for _, dx in { -12, 12, -9, 9, -5, 5, 0 } do
			object.Position = home + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		object.Position = home
	end)
end

local function flash(frame, color)
	local overlay = create("Frame", {
		BackgroundColor3 = color or WHITE,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = frame,
	})
	corner(overlay, 24)
	tween(overlay, 0.45, { BackgroundTransparency = 1 })
	Debris:AddItem(overlay, 0.5)
end

--------------------------------------------------------------------------
-- Buttons (bounce on hover/press, shiny sweep when you can afford them)
--------------------------------------------------------------------------

local shines = {}

local function makeButton(parent, props)
	local button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = props.Color,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ClipsDescendants = true,
		Parent = parent,
	})
	corner(button, props.Radius or 16)
	local stroke = border(button, 4)
	-- Soft top-to-bottom shading for a glossy look
	create("UIGradient", {
		Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190)),
		Rotation = 90,
		Parent = button,
	})

	local shine = create("Frame", {
		BackgroundColor3 = WHITE,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
		Parent = button,
	})
	corner(shine, props.Radius or 16)
	local shineGradient = create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 20,
		Parent = shine,
	})
	table.insert(shines, shineGradient)

	local label = text({
		Text = props.Text,
		Size = UDim2.fromScale(0.86, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = button,
	}, 3)

	local scale = create("UIScale", { Parent = button })
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		tween(scale, 0.15, { Scale = 1.07 })
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		tween(scale, 0.15, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.07, { Scale = 0.9 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.25, { Scale = if hovering then 1.07 else 1 }, Enum.EasingStyle.Back)
	end)

	return { Button = button, Label = label, Shine = shine, Stroke = stroke }
end

local function setButton(b, color, message, shiny)
	b.Button.BackgroundColor3 = color
	b.Label.Text = message
	b.Shine.Visible = shiny
end

--------------------------------------------------------------------------
-- Board surfaces
--------------------------------------------------------------------------

local function makeSurface(part, canvas, name)
	local gui = create("SurfaceGui", {
		Name = name,
		Adornee = part,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = canvas,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ClipsDescendants = true,
		Parent = playerGui,
	})
	return create("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
end

local function makePanel(root, position, size, radius)
	local panel = create("Frame", {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		Position = position,
		Size = size,
		Parent = root,
	})
	corner(panel, radius)
	border(panel, 4)
	return panel
end

local function makeBar(parent, position, size, color)
	local bar = create("Frame", {
		BackgroundColor3 = BAR_BG,
		Position = position,
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = parent,
	})
	corner(bar, 999)
	border(bar, 2)
	local fill = create("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = bar })
	corner(fill, 999)
	create("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 200)), Rotation = 90, Parent = fill })
	return bar, fill
end

--------------------------------------------------------------------------
-- Currency pills (the counter above each board)
--------------------------------------------------------------------------

local pills = {}

local function makePill(root, currencyId)
	local currency = Config.Currencies[currencyId]
	local pill = makePanel(root, UDim2.fromOffset(UPGRADE_CANVAS.X / 2 - 230, 0), UDim2.fromOffset(460, 104), 28)
	text({
		Text = currency.Icon,
		Size = UDim2.fromOffset(84, 84),
		Position = UDim2.fromOffset(18, 10),
		Parent = pill,
	}, 0)
	local amount = text({
		Text = "0",
		TextColor3 = currency.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(330, 70),
		Position = UDim2.fromOffset(114, 17),
		Parent = pill,
	}, 4)
	local value = getCurrency(currencyId)
	table.insert(pills, { Currency = currencyId, Root = root, Frame = pill, Label = amount, Shown = value, Pending = 0 })
end

--------------------------------------------------------------------------
-- Upgrade cards
--------------------------------------------------------------------------

local cards = {}
local dirty = true
local function markDirty()
	dirty = true
end

local function countAffordable(upgradeId, level, balance)
	local upgrade = Config.Upgrades[upgradeId]
	local count = 0
	while level < upgrade.MaxLevel and count < 999 do
		local cost = Config.GetCost(upgradeId, level)
		if balance < cost then
			break
		end
		balance -= cost
		level += 1
		count += 1
	end
	return count
end

local function refreshCard(card)
	local upgrade = card.Upgrade
	local level = Config.GetLevel(player, card.Id)
	local maxed = level >= upgrade.MaxLevel

	card.Level.Text = ("%d/%d"):format(level, upgrade.MaxLevel)
	if card.LastLevel ~= level then
		tween(card.Fill, 0.35, { Size = UDim2.fromScale(level / upgrade.MaxLevel, 1) }, Enum.EasingStyle.Back)
		card.LastLevel = level
	end

	local current = upgrade.Format(upgrade.Value(level))
	local currency = Config.Currencies[upgrade.Currency]
	if maxed then
		card.Value.Text = current
		card.Cost.Text = colored("MAXED", GOLD)
		setButton(card.Buy, GOLD, "MAXED", false)
		setButton(card.Max, DISABLED, "Max", false)
		return
	end

	card.Value.Text = current .. " > " .. upgrade.Format(upgrade.Value(level + 1))
	local cost = Config.GetCost(card.Id, level)
	local balance = getCurrency(upgrade.Currency)
	local canBuy = balance >= cost
	card.Cost.Text = "Cost: " .. colored(format(cost), if canBuy then WHITE else RED) .. " " .. colored(upgrade.Currency, currency.Color)

	local affordable = countAffordable(card.Id, level, balance)
	setButton(card.Buy, if canBuy then BUY else DISABLED, "Buy", canBuy)
	setButton(card.Max, if affordable > 0 then MAX else DISABLED, "Max x" .. affordable, affordable > 1)
end

local function onBuy(card, buyMax, b)
	if card.Pending then
		return
	end
	local upgrade = card.Upgrade
	local root = card.Root
	local level = Config.GetLevel(player, card.Id)

	local function fail(message)
		playSound("Fail", 0.55)
		shake(b.Button)
		floatText(root, message, RED, centerOf(root, b.Button))
	end

	-- Instant feedback without waiting for the server when it obviously fails
	if level >= upgrade.MaxLevel then
		return fail("MAXED")
	end
	local cost = Config.GetCost(card.Id, level)
	if getCurrency(upgrade.Currency) < cost then
		return fail("Need " .. format(cost) .. " " .. upgrade.Currency)
	end

	card.Pending = true
	local ok, result, extra = remote:InvokeServer("Buy", card.Id, buyMax)
	card.Pending = false

	if ok then
		local bought, spent = result, extra
		playSound("Buy", comboPitch())
		flash(card.Frame)
		pop(card.Icon, 1.35)
		pop(card.Value)
		sparkles(root, centerOf(root, card.Icon), card.TitleColor, 10 + math.min(bought, 10))
		floatText(root, "-" .. format(spent) .. " " .. upgrade.Currency, RED, centerOf(root, b.Button))
		local nowMaxed = Config.GetLevel(player, card.Id) >= upgrade.MaxLevel
		local headline = if nowMaxed then "MAXED!" elseif bought > 1 then ("+%d LEVELS!"):format(bought) else "LEVEL UP!"
		floatText(root, headline, GOLD, centerOf(root, card.Icon), UDim2.fromOffset(320, 60))
	else
		local reason = result
		if reason == "TooPoor" then
			fail("Need " .. format(extra) .. " " .. upgrade.Currency)
		elseif reason == "Maxed" then
			fail("MAXED")
		elseif reason == "Loading" then
			fail("Loading...")
		end
	end
	markDirty()
end

local function buildUpgradeBoard(part, board)
	local root = makeSurface(part, UPGRADE_CANVAS, "UpgradeBoard_" .. board.Id)
	makePill(root, board.Currency)
	local panel = makePanel(root, UDim2.fromOffset(0, 124), UDim2.fromOffset(UPGRADE_CANVAS.X, UPGRADE_CANVAS.Y - 124), 36)

	local count = #board.Upgrades
	local gap, margin = 18, 24
	local width = (UPGRADE_CANVAS.X - margin * 2 - gap * (count - 1)) / count

	for i, upgradeId in board.Upgrades do
		local upgrade = Config.Upgrades[upgradeId]
		local frame = create("Frame", {
			BackgroundColor3 = CARD,
			BackgroundTransparency = 0.45,
			Position = UDim2.fromOffset(margin + (i - 1) * (width + gap), 18),
			Size = UDim2.fromOffset(width, 540),
			Parent = panel,
		})
		corner(frame, 24)

		local function centered(y, w, h)
			return UDim2.fromOffset(width / 2, y), UDim2.fromOffset(w, h)
		end

		local position, size = centered(14, width - 24, 46)
		text({ Text = upgrade.Title, TextColor3 = board.TitleColor, Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 4)

		position, size = centered(62, width * 0.5, 30)
		local level = text({ Text = "0/0", Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 3)

		local _, fill = makeBar(frame, UDim2.fromOffset(width / 2, 98), UDim2.fromOffset(width * 0.7, 14), board.TitleColor)

		position, size = centered(122, width * 0.5, 138)
		local icon = text({ Text = upgrade.Icon, Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 0)

		position, size = centered(266, width - 30, 56)
		local value = text({ Text = "", TextColor3 = board.TitleColor, Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 4)

		position, size = centered(326, width - 30, 36)
		local cost = text({ Text = "", Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 3)

		local buy = makeButton(frame, {
			Text = "Buy",
			Color = BUY,
			Position = UDim2.fromOffset(width * 0.06, 376),
			Size = UDim2.fromOffset(width * 0.5, 76),
		})
		local max = makeButton(frame, {
			Text = "Max x0",
			Color = MAX,
			Position = UDim2.fromOffset(width * 0.6, 376),
			Size = UDim2.fromOffset(width * 0.34, 76),
		})

		position, size = centered(470, width - 30, 52)
		text({ Text = upgrade.Description, TextColor3 = GREY_TEXT, TextWrapped = true, Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 2)

		local card = {
			Id = upgradeId,
			Upgrade = upgrade,
			Root = root,
			Frame = frame,
			TitleColor = board.TitleColor,
			Level = level,
			Fill = fill,
			Icon = icon,
			Value = value,
			Cost = cost,
			Buy = buy,
			Max = max,
			Index = i,
		}
		buy.Button.Activated:Connect(function()
			onBuy(card, false, buy)
		end)
		max.Button.Activated:Connect(function()
			onBuy(card, true, max)
		end)
		table.insert(cards, card)
	end
	markDirty()
end

--------------------------------------------------------------------------
-- Rebirth board
--------------------------------------------------------------------------

local rebirth = nil

local effectsGui = create("ScreenGui", {
	Name = "UpgradeEffects",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
	Parent = playerGui,
})

local function celebrateRebirth(gain)
	local whiteout = create("Frame", {
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1, 1),
		Parent = effectsGui,
	})
	tween(whiteout, 0.8, { BackgroundTransparency = 1 })
	Debris:AddItem(whiteout, 0.9)

	local title = text({
		Text = "REBIRTH!",
		TextColor3 = RED,
		Size = UDim2.fromScale(0.6, 0.16),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = effectsGui,
	}, 6)
	local subtitle = text({
		Text = "+" .. format(gain) .. " Rebirths",
		TextColor3 = GOLD,
		Size = UDim2.fromScale(0.4, 0.08),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = effectsGui,
	}, 5)
	for _, label in { title, subtitle } do
		local scale = create("UIScale", { Scale = 0, Parent = label })
		tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(1.6, function()
			tween(label, 0.5, { TextTransparency = 1 })
			tween(label:FindFirstChildOfClass("UIStroke"), 0.5, { Transparency = 1 })
		end)
		Debris:AddItem(label, 2.2)
	end
end

local function refreshRebirth()
	if not rebirth then
		return
	end
	local rebirths = getCurrency("Rebirths")
	local gain = Config.GetRebirthGain(player)
	local requirement = Config.GetRebirthRequirement(player)
	local cash = getCurrency("Cash")
	local progress = math.clamp(cash / requirement, 0, 1)
	local ready = cash >= requirement

	rebirth.Amount.Text = colored(format(rebirths), RED) .. " " .. colored("(+" .. format(gain) .. ")", WHITE)
	rebirth.Requirement.Text = "Requirement: " .. colored(format(requirement) .. " Cash", Config.Currencies.Cash.Color)
	rebirth.Fill.Size = UDim2.fromScale(progress, 1)
	rebirth.Fill.BackgroundColor3 = if ready then GOLD else Config.Currencies.Cash.Color
	rebirth.Percent.Text = ("%d%%"):format(math.floor(progress * 100))
	rebirth.Footer.Text = ("Rebirthed %s times"):format(format(Config.GetRebirthCount(player)))
	rebirth.Ready = ready
	if not rebirth.Armed then
		setButton(rebirth.Button, if ready then REBIRTH_BUTTON else DISABLED, "Rebirth", ready)
	end
end

local function onRebirth()
	local b = rebirth.Button
	local root = rebirth.Root
	if rebirth.Pending then
		return
	end
	if not rebirth.Ready then
		playSound("Fail", 0.55)
		shake(b.Button)
		floatText(root, "Need " .. format(Config.GetRebirthRequirement(player)) .. " Cash", RED, centerOf(root, b.Button))
		return
	end

	-- First click asks to confirm, since rebirthing resets your cash
	if not rebirth.Armed then
		rebirth.Armed = true
		setButton(b, GOLD, "Are you sure?", true)
		pop(b.Button, 1.1)
		task.delay(3, function()
			rebirth.Armed = false
			markDirty()
		end)
		return
	end

	rebirth.Armed = false
	rebirth.Pending = true
	local ok, gain = remote:InvokeServer("Rebirth")
	rebirth.Pending = false
	if ok then
		playSound("Rebirth", 0.7)
		task.delay(0.15, playSound, "Rebirth", 1)
		task.delay(0.3, playSound, "Rebirth", 1.4)
		flash(rebirth.Frame, RED)
		pop(rebirth.Icon, 1.5)
		sparkles(root, centerOf(root, rebirth.Icon), RED, 18)
		celebrateRebirth(gain)
		for _, card in cards do
			if card.Upgrade.ResetOnRebirth then
				flash(card.Frame, RED)
			end
		end
	else
		playSound("Fail", 0.55)
		shake(b.Button)
	end
	markDirty()
end

local function buildRebirthBoard(part)
	local root = makeSurface(part, REBIRTH_CANVAS, "UpgradeBoard_Rebirth")
	local panel = makePanel(root, UDim2.fromOffset(0, 0), UDim2.fromOffset(REBIRTH_CANVAS.X, REBIRTH_CANVAS.Y), 36)
	local w = REBIRTH_CANVAS.X

	local function centered(y, width, height)
		return UDim2.fromOffset(w / 2, y), UDim2.fromOffset(width, height)
	end
	local top = Vector2.new(0.5, 0)
	local cashColor = Config.Currencies.Cash.Color

	local position, size = centered(20, w - 40, 62)
	text({ Text = "Rebirth", TextColor3 = RED, Position = position, Size = size, AnchorPoint = top, Parent = panel }, 5)

	position, size = centered(88, w - 50, 66)
	text({
		Text = "Resets your " .. colored("Cash", cashColor) .. " & " .. colored("Cash Upgrades", cashColor) .. " in exchange for " .. colored("Rebirths", RED),
		TextWrapped = true,
		Position = position,
		Size = size,
		AnchorPoint = top,
		Parent = panel,
	}, 3)

	position, size = centered(160, 170, 150)
	local icon = text({ Text = Config.Currencies.Rebirths.Icon, Position = position, Size = size, AnchorPoint = top, Parent = panel }, 0)

	position, size = centered(318, w - 40, 64)
	local amount = text({ Text = "", Position = position, Size = size, AnchorPoint = top, Parent = panel }, 4)

	position, size = centered(388, w - 60, 36)
	local requirement = text({ Text = "", Position = position, Size = size, AnchorPoint = top, Parent = panel }, 3)

	local bar, fill = makeBar(panel, UDim2.fromOffset(w / 2, 432), UDim2.fromOffset(w * 0.8, 28), cashColor)
	local percent = text({ Text = "0%", Size = UDim2.fromScale(1, 0.9), Position = UDim2.fromScale(0, 0.05), ZIndex = 3, Parent = bar }, 2)

	local button = makeButton(panel, {
		Text = "Rebirth",
		Color = REBIRTH_BUTTON,
		Position = UDim2.fromOffset(w / 2, 480),
		Size = UDim2.fromOffset(w * 0.8, 100),
		AnchorPoint = top,
		Radius = 22,
	})

	position, size = centered(600, w - 60, 34)
	local footer = text({ Text = "", TextColor3 = GREY_TEXT, Position = position, Size = size, AnchorPoint = top, Parent = panel }, 2)

	rebirth = {
		Root = root,
		Frame = panel,
		Icon = icon,
		Amount = amount,
		Requirement = requirement,
		Fill = fill,
		Percent = percent,
		Button = button,
		Footer = footer,
		Ready = false,
		Armed = false,
	}
	button.Button.Activated:Connect(onRebirth)
	markDirty()
end

--------------------------------------------------------------------------
-- Build boards as their parts appear
--------------------------------------------------------------------------

local function findBoardPart(id)
	local part = boardsFolder:WaitForChild(id, 60)
	if part and part:IsA("Model") then
		part = part.PrimaryPart
	end
	if not part or not part:IsA("BasePart") then
		warn(("[UpgradeBoards] Couldn't find a part called %q in Workspace.%s"):format(id, Config.BoardsFolderName))
		return nil
	end
	return part
end

for _, board in Config.Boards do
	task.spawn(function()
		local part = findBoardPart(board.Id)
		if part then
			buildUpgradeBoard(part, board)
		end
	end)
end
task.spawn(function()
	local part = findBoardPart(Config.RebirthBoardId)
	if part then
		buildRebirthBoard(part)
	end
end)

--------------------------------------------------------------------------
-- Live updates
--------------------------------------------------------------------------

player.AttributeChanged:Connect(markDirty)

local function watchStat(stat)
	if stat:IsA("ValueBase") then
		stat.Changed:Connect(markDirty)
		markDirty()
	end
end
for _, stat in leaderstats:GetChildren() do
	watchStat(stat)
end
leaderstats.ChildAdded:Connect(watchStat)

-- Show "+123" above a counter, bundled a few times a second so it stays readable
task.spawn(function()
	while true do
		task.wait(0.35)
		for _, pill in pills do
			if pill.Pending > 0 then
				local currency = Config.Currencies[pill.Currency]
				floatText(pill.Root, "+" .. format(pill.Pending), currency.Color, UDim2.fromOffset(UPGRADE_CANVAS.X / 2 + 340, 64), UDim2.fromOffset(240, 44))
				pop(pill.Frame, 1.08)
				pill.Pending = 0
			end
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()

	if dirty then
		dirty = false
		for _, card in cards do
			refreshCard(card)
		end
		refreshRebirth()
	end

	-- Counters roll smoothly toward their real value
	for _, pill in pills do
		local target = getCurrency(pill.Currency)
		local last = pill.Target or target
		if target > last then
			pill.Pending += target - last
		end
		pill.Target = target
		pill.Shown += (target - pill.Shown) * math.min(1, dt * 10)
		if math.abs(target - pill.Shown) < 0.005 then
			pill.Shown = target
		end
		local shown = if target % 1 == 0 then math.floor(pill.Shown + 0.5) else pill.Shown
		pill.Label.Text = format(shown)
	end

	-- Idle animations: icons wobble, the rebirth icon spins, shines sweep
	for _, card in cards do
		card.Icon.Rotation = math.sin(now * 2 + card.Index) * 7
	end
	if rebirth then
		rebirth.Icon.Rotation = (now * 40) % 360
		local stroke = rebirth.Button.Stroke
		if rebirth.Ready then
			stroke.Color = GOLD
			stroke.Thickness = 4 + (math.sin(now * 6) + 1) * 2
		else
			stroke.Color = OUTLINE
			stroke.Thickness = 4
		end
	end
	local sweep = ((now * 0.9) % 2.4) - 1.2
	for _, gradient in shines do
		gradient.Offset = Vector2.new(sweep, 0)
	end
end)
