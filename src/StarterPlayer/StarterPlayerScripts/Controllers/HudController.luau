-- HudController: right-side currency bars.
-- Cash is always shown; the rest depends on the area you're in:
--   main area: Sushi KG, Cash, Prestiges (once you're close to your first Prestige)
--   Sushi Pond: Fish, Cash
--   Sushi Slashing: Slices, Cash
--   Sushi Restaurant: Neko, Cash
-- Bars are created from a spec so new currencies are one line to add.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)

local player = Players.LocalPlayer
local HudController = {}

local gui: ScreenGui
local bars = {}

local DARK = Color3.fromRGB(35, 22, 10)

local function stroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or DARK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function createBar(spec, index: number)
	local bar = Instance.new("Frame")
	bar.Name = spec.Attribute .. "Bar"
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Position = UDim2.new(1, 0, 0, (index - 1) * 66)
	bar.Size = UDim2.fromOffset(310, 58)
	bar.BackgroundColor3 = spec.Color
	bar.BorderSizePixel = 0
	bar.Parent = gui.Bars
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	grad.Color = ColorSequence.new(spec.Color, spec.Color2)
	grad.Parent = bar
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = bar

	local icon = Instance.new(if spec.Image then "ImageLabel" else "TextLabel") :: any
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.new(1, -8, 0.42, 0)
	icon.Size = UDim2.fromOffset(52, 46)
	if spec.Image then
		icon.Image = spec.Image
		icon.ScaleType = Enum.ScaleType.Fit
	else
		icon.Font = Enum.Font.FredokaOne
		icon.TextScaled = true
		icon.Text = spec.Icon
	end
	icon.Rotation = -8
	icon.Parent = bar

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(1, 1)
	caption.Position = UDim2.new(1, -4, 1, 2)
	caption.Size = UDim2.fromOffset(64, 20)
	caption.Font = Enum.Font.FredokaOne
	caption.TextScaled = true
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.Text = spec.Caption
	caption.Parent = bar
	stroke(caption, 2)

	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.AnchorPoint = Vector2.new(1, 0.5)
	amount.Position = UDim2.new(1, -66, 0.5, 0)
	amount.Size = UDim2.new(1, -80, 0, 44)
	amount.Font = Enum.Font.FredokaOne
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextColor3 = spec.TextColor or Color3.fromRGB(255, 244, 120)
	amount.Text = "0"
	amount.Parent = bar
	stroke(amount, 3)

	local gain = Instance.new("TextLabel")
	gain.Name = "Gain"
	gain.BackgroundTransparency = 1
	gain.AnchorPoint = Vector2.new(1, 0.5)
	gain.Position = UDim2.new(0, -6, 0.5, 0)
	gain.Size = UDim2.fromOffset(140, 30)
	gain.Font = Enum.Font.FredokaOne
	gain.TextScaled = true
	gain.TextXAlignment = Enum.TextXAlignment.Right
	gain.TextColor3 = Color3.new(1, 1, 1)
	gain.TextTransparency = 1
	gain.Parent = bar
	local gainStroke = stroke(gain, 2.5)
	gainStroke.Transparency = 1

	local state = {
		Spec = spec,
		Bar = bar,
		Scale = uiScale,
		Amount = amount,
		Gain = gain,
		GainStroke = gainStroke,
		Shown = 0,
		Target = 0,
		Pending = 0,
		LastGain = 0,
	}
	bars[spec.Attribute] = state

	local function onChanged()
		local value = player:GetAttribute(spec.Attribute) or 0
		local delta = value - state.Target
		state.Target = value
		if delta > 0 and state.Initialized then
			HudController.ShowGain(spec.Attribute, delta)
		elseif not state.Initialized then
			state.Shown = value
		end
		state.Initialized = true
	end
	player:GetAttributeChangedSignal(spec.Attribute):Connect(onChanged)
	onChanged()
end

-- Punch the bar and show a stacking "+x" next to it
function HudController.ShowGain(attribute: string, delta: number)
	local b = bars[attribute]
	if not b then return end
	local now = os.clock()
	if now - b.LastGain > 1.2 then b.Pending = 0 end
	b.Pending += delta
	b.LastGain = now
	b.Gain.Text = "+" .. (b.Spec.Format or NumberFormat.Format)(b.Pending)
	b.Gain.TextTransparency = 0
	b.GainStroke.Transparency = 0
	local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9)
	TweenService:Create(b.Gain, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(b.GainStroke, fade, { Transparency = 1 }):Play()

	b.Scale.Scale = 1.1
	TweenService:Create(b.Scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Returns the on-screen bar frame for a currency (used by fly-to-HUD effects)
function HudController.GetBar(attribute: string): Frame?
	local b = bars[attribute]
	return b and b.Bar
end

-- ===== combo counter =====
local comboLabel: TextLabel
local comboScale: UIScale
local comboStroke: UIStroke
local comboShownAt = 0
local COMBO_TIERS = {
	{ 50, Color3.fromRGB(255, 90, 200), "INSANE!" },
	{ 25, Color3.fromRGB(255, 120, 60), "AMAZING!" },
	{ 10, Color3.fromRGB(255, 210, 60), "GREAT!" },
	{ 0, Color3.fromRGB(255, 255, 255), "COMBO" },
}

function HudController.ShowCombo(count: number)
	if not comboLabel or count < 3 then return end
	local color, word = Color3.new(1, 1, 1), "COMBO"
	for _, tier in ipairs(COMBO_TIERS) do
		if count >= tier[1] then color, word = tier[2], tier[3]; break end
	end
	comboLabel.Text = "x" .. count .. " " .. word
	comboLabel.TextColor3 = color
	comboLabel.TextTransparency = 0
	comboStroke.Transparency = 0
	comboLabel.Rotation = math.random(-4, 4)
	comboScale.Scale = 1.3
	TweenService:Create(comboScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	comboShownAt = os.clock()
end

function HudController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local container = Instance.new("Frame")
	container.Name = "Bars"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(1, 0.5)
	container.Position = UDim2.new(1, -14, 0.45, 0)
	container.Size = UDim2.fromOffset(310, 266)
	container.Parent = gui
	local responsive = Instance.new("UIScale")
	responsive.Parent = container

	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		responsive.Scale = math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.55, 1.15)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	createBar({
		Attribute = "KG",
		Icon = "🍣",
		Caption = "Sushi",
		Suffix = " kg",
		Color = Color3.fromRGB(255, 150, 60),
		Color2 = Color3.fromRGB(255, 205, 60),
		TextColor = Color3.new(1, 1, 1),
		Format = NumberFormat.KG,
	}, 1)

	createBar({
		Attribute = "Money",
		Icon = "💵",
		Caption = "Cash",
		Prefix = "$",
		Color = Color3.fromRGB(40, 190, 70),
		Color2 = Color3.fromRGB(110, 235, 90),
		TextColor = Color3.new(1, 1, 1),
		Format = NumberFormat.Cash,
	}, 2)

	createBar({
		Attribute = "Prestiges",
		Icon = "⭐",
		Caption = "Prestiges",
		Color = Color3.fromRGB(235, 160, 20),
		Color2 = Color3.fromRGB(255, 220, 80),
		TextColor = Color3.new(1, 1, 1),
		Format = NumberFormat.Format,
	}, 3)
	bars.Prestiges.Bar:FindFirstChild("Caption").Size = UDim2.fromOffset(84, 20)

	createBar({
		Attribute = "Fish",
		Image = "rbxassetid://76498223565580", -- the More Fish icon
		Caption = "Fish",
		Color = Color3.fromRGB(30, 120, 225),
		Color2 = Color3.fromRGB(100, 205, 255),
		TextColor = Color3.new(1, 1, 1),
		Format = NumberFormat.Format,
	}, 4)

	createBar({
		Attribute = "Slices",
		Icon = "🍥",
		Caption = "Slices",
		Color = Color3.fromRGB(225, 70, 120),
		Color2 = Color3.fromRGB(255, 150, 180),
		TextColor = Color3.new(1, 1, 1),
		Format = NumberFormat.Format,
	}, 5)

	createBar({
		Attribute = "Neko",
		Icon = "🐱",
		Caption = "Neko",
		Color = Color3.fromRGB(240, 110, 160),
		Color2 = Color3.fromRGB(255, 190, 215),
		TextColor = Color3.new(1, 1, 1),
		Format = NumberFormat.Format,
	}, 6)

	-- which bars each area shows (Cash is always there); areas not listed use the main area's
	local ZONE_BARS = {
		Fishing = { "Fish", "Money" },
		Slashing = { "Slices", "Money" },
		Dropper = { "Neko", "Money" },
	}
	-- the Prestiges bar appears once you're halfway to your first Prestige (or have any)
	local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
	local function relayout()
		local zoneBars = ZONE_BARS[player:GetAttribute("Zone") or "Starter"]
		local order = if zoneBars then table.clone(zoneBars) else { "KG", "Money" }
		if not zoneBars and ((player:GetAttribute("TotalRebirths") or 0) > 0 or (player:GetAttribute("TotalPrestiges") or 0) > 0
			or (player:GetAttribute("TotalMoney") or 0) >= PrestigeConfig.MinCash / 2) then
			table.insert(order, "Prestiges")
		end
		for _, b in pairs(bars) do b.Bar.Visible = false end
		for i, attr in ipairs(order) do
			local b = bars[attr]
			b.Bar.Visible = true
			b.Bar.Position = UDim2.new(1, 0, 0, (i - 1) * 66)
		end
		if comboLabel then comboLabel.Position = UDim2.new(1, -10, 0, #order * 66 + 6) end
	end
	for _, a in ipairs({ "Zone", "TotalRebirths", "TotalPrestiges", "TotalMoney" }) do
		player:GetAttributeChangedSignal(a):Connect(relayout)
	end

	-- Smooth counting animation
	comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "Combo"
	comboLabel.BackgroundTransparency = 1
	comboLabel.AnchorPoint = Vector2.new(1, 0)
	comboLabel.Position = UDim2.new(1, -10, 0, 270)
	comboLabel.Size = UDim2.fromOffset(260, 40)
	comboLabel.Font = Enum.Font.FredokaOne
	comboLabel.TextScaled = true
	comboLabel.TextXAlignment = Enum.TextXAlignment.Right
	comboLabel.TextTransparency = 1
	comboLabel.Parent = container
	comboStroke = stroke(comboLabel, 3)
	comboStroke.Transparency = 1
	comboScale = Instance.new("UIScale")
	comboScale.Parent = comboLabel
	relayout()

	RunService.RenderStepped:Connect(function(dt)
		if comboLabel.TextTransparency < 1 and os.clock() - comboShownAt > 1 then
			local t = math.min(1, comboLabel.TextTransparency + dt * 3)
			comboLabel.TextTransparency = t
			comboStroke.Transparency = t
		end
		for _, b in pairs(bars) do
			if b.Shown ~= b.Target then
				local diff = b.Target - b.Shown
				b.Shown += diff * math.min(1, dt * 12)
				if math.abs(b.Target - b.Shown) < 0.005 then b.Shown = b.Target end
			end
			b.Amount.Text = (b.Spec.Format or NumberFormat.Format)(b.Shown)
		end
	end)
end

return HudController
