local UIKit = require(script.Parent.UIKit)
-- MarketController: the Sushi Market sell panel, sell feedback, the stall's live
-- rate screen, the lucky cat, and the beginner guide trail to the market.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = UIKit.TweenService
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local NumberFormat = require(Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local MarketController = {}

local YELLOW = UIKit.Theme.Colors.Accent.Base
local GREEN = UIKit.Theme.Colors.Success.Base
local DARK = UIKit.Theme.Ink
local SELL_ACTION = "SushiMarketSell"

local market: Model
local sellZone: BasePart -- the sell stall nearest to the player (one per zone)
local rateGuis: { SurfaceGui } = {}
local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local ui = {}
local isOpen = false

-- ===== small UI helpers =====

local function stroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or DARK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function label(parent, name, text, y, h, color, rich)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.new(0, 12, 0, y)
	t.Size = UDim2.new(1, -24, 0, h)
	t.Font = UIKit.Font
	t.TextScaled = true
	t.RichText = rich or false
	t.Text = text
	t.TextColor3 = color
	t.Parent = parent
	stroke(t, 2.5)
	return t
end

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- ===== panel =====

-- the on-screen sell button: key hint follows the device the player is using
local function inputKind(): string
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") then return "gamepad" end
	if isTouch() or last == Enum.UserInputType.Touch then return "touch" end
	return "mouse"
end

local function refresh()
	local kg = player:GetAttribute("KG") or 0
	local rate = player:GetAttribute("SellRate") or EconomyConfig.GetSellRate(1)
	local canSell = kg > 0
	ui.ButtonGradient.Color = canSell
		and ColorSequence.new(UIKit.Theme.Colors.Accent.Base, UIKit.Theme.Colors.Primary.Base)
		or ColorSequence.new(UIKit.Theme.Colors.Rice.Base, UIKit.Theme.Colors.Rice.Base)
	local edge = canSell and UIKit.Theme.Colors.Danger.Base or UIKit.Theme.Colors.Rice.Base
	ui.ButtonStroke.Color = edge
	ui.TitleStroke.Color = edge
	ui.SubStroke.Color = edge
	if canSell then
		ui.Title.Text = "💰 SELL ALL"
		ui.Sub.Text = NumberFormat.KG(kg) .. "  =  +" .. NumberFormat.Cash(EconomyConfig.RoundCash(kg * rate))
	else
		ui.Title.Text = "SELL ALL"
		ui.Sub.Text = "Collect sushi first!"
	end
	local kind = inputKind()
	ui.Key.Visible = kind ~= "touch"
	ui.KeyText.Text = kind == "gamepad" and "X" or "E"

	-- world screens on every sell stall
	for _, rateGui in ipairs(rateGuis) do
		local label = rateGui:FindFirstChild("Rate")
		if label then label.Text = "1 kg = $" .. NumberFormat.Format(rate) end
	end
end

local function buildPanel()
	gui = Instance.new("ScreenGui")
	gui.Name = "MarketPanel"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	-- compact pill at the bottom-center, clear of the thumbstick and jump button
	panel = Instance.new("Frame")
	panel.Name = "SellPill"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -26)
	panel.Size = UIKit.Theme.Layout.MarketController.Size1
	panel.Parent = gui
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local button = Instance.new("TextButton")
	button.Name = "SellButton"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = UIKit.Theme.White
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = panel
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
	ui.ButtonStroke = stroke(button, 3.5)
	ui.ButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ui.ButtonGradient = Instance.new("UIGradient")
	ui.ButtonGradient.Rotation = 90
	ui.ButtonGradient.Parent = button
	ui.ButtonScale = Instance.new("UIScale")
	ui.ButtonScale.Parent = button
	-- soft highlight on the top half
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = UIKit.Theme.White
	shine.BackgroundTransparency = 0.72
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 16, 0, 5)
	shine.Size = UIKit.Theme.Layout.MarketController.Size2
	shine.Parent = button
	Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)

	-- key hint chip (E / X), hidden on phones
	local key = Instance.new("Frame")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 14, 0.5, 0)
	key.Size = UIKit.Theme.Layout.MarketController.Size3
	key.BackgroundColor3 = UIKit.Theme.Colors.Rice.Dark
	key.Parent = button
	Instance.new("UICorner", key).CornerRadius = UDim.new(0, 9)
	local keyText = Instance.new("TextLabel")
	keyText.BackgroundTransparency = 1
	keyText.Size = UDim2.fromScale(1, 1)
	keyText.Font = UIKit.Font
	keyText.TextSize = 22
	keyText.TextColor3 = UIKit.Theme.White
	keyText.Parent = key
	ui.Key, ui.KeyText = key, keyText

	local texts = Instance.new("Frame")
	texts.BackgroundTransparency = 1
	texts.ZIndex=6
	texts.Position = UDim2.new(0, 56, 0, 6)
	texts.Size = UIKit.Theme.Layout.MarketController.Size4
	texts.Parent = button
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UIKit.Theme.Layout.MarketController.Size5
	title.Font = UIKit.Font
	title.TextScaled = true
	title.TextColor3 = UIKit.Theme.White
	title.Parent = texts
	ui.TitleStroke = stroke(title, 2.5)
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UIKit.Theme.Layout.MarketController.Size6
	sub.Font = UIKit.Font
	sub.TextScaled = true
	sub.TextColor3 = UIKit.Theme.White
	sub.Parent = texts
	ui.SubStroke = stroke(sub, 2)
	ui.Title, ui.Sub = title, sub
	ui.Button = button
	UIKit.StyleButton(button,"Success")
	button.ButtonFace:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() end)
	ui.Title.ZIndex=6;ui.Sub.ZIndex=6;key.ZIndex=6;keyText.ZIndex=7;shine.Visible=false
	ui.ButtonGradient:GetPropertyChangedSignal("Color"):Connect(function() button.ButtonFace:FindFirstChildOfClass("UIGradient").Color=ui.ButtonGradient.Color end)

	button.Activated:Connect(function()
		MarketController.Sell()
	end)
	button.MouseEnter:Connect(function()
		TweenService:Create(ui.ButtonScale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(ui.ButtonScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		if isOpen then refresh() end
	end)

	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		panelScale:SetAttribute("Base", math.clamp(math.min(vp.X / 1300, vp.Y / 800), 0.75, 1.1))
		if isOpen then panelScale.Scale = panelScale:GetAttribute("Base") end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
end

local function setOpen(open: boolean)
	if open == isOpen then return end
	isOpen = open
	local base = panelScale:GetAttribute("Base") or 1
	if open then
		refresh()
		gui.Enabled = true
		panelScale.Scale = base * 0.6
		TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
		ContextActionService:BindAction(SELL_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then task.spawn(MarketController.Sell) end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	else
		ContextActionService:UnbindAction(SELL_ACTION)
		local t = TweenService:Create(panelScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = base * 0.6 })
		t:Play()
		t.Completed:Connect(function()
			if not isOpen then gui.Enabled = false end
		end)
	end
end

-- ===== selling =====

local lastRequest = 0
function MarketController.Sell()
	if (player:GetAttribute("KG") or 0) <= 0 then
		if UIKit.ReducedMotion() then UIKit.Sound("Error"); return end
		-- gentle "nope" shake
		local p = ui.Button.Position
		for _, dx in ipairs({ -6, 6, -4, 4, 0 }) do
			ui.Button.Position = p + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		ui.Button.Position = p
		return
	end
	if os.clock() - lastRequest < EconomyConfig.SellCooldown then return end
	lastRequest = os.clock()
	ui.ButtonScale.Scale = 0.9
	TweenService:Create(ui.ButtonScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Remotes.RequestSell:FireServer()
end

-- Cash notes fly from the middle of the screen into the Cash bar
local function flyCashToHud(count: number)
	local bar = HudController.GetBar("Money")
	if not bar then return end
	local target = bar.AbsolutePosition + bar.AbsoluteSize * Vector2.new(0.85, 0.5)
	local vp = workspace.CurrentCamera.ViewportSize
	local inset = game:GetService("GuiService"):GetGuiInset()
	for i = 1, count do
		local note = Instance.new("TextLabel")
		note.BackgroundTransparency = 1
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.Size = UIKit.Theme.Layout.MarketController.Size7
		note.TextScaled = true
		note.Text = "💵"
		note.Rotation = math.random(-30, 30)
		local start = Vector2.new(vp.X / 2 + math.random(-90, 90), vp.Y / 2 + math.random(-40, 60)) - inset
		note.Position = UDim2.fromOffset(start.X, start.Y)
		note.Parent = gui
		local delay = (i - 1) * 0.04
		task.delay(delay, function()
			local tw = TweenService:Create(note, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
				Rotation = 0,
				Size = UIKit.Theme.Layout.MarketController.Size8,
			})
			tw:Play()
		end)
		Debris:AddItem(note, 0.6 + delay)
	end
end

local catWaveUntil = 0
local function onSold(kg: number, cash: number, bonus: boolean?)
	EffectsController.PlaySound("Sell")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		EffectsController.FloatingText(root.Position + Vector3.new(0, 3, 0), (bonus and "🤝 x2 DEAL! +" or "+") .. NumberFormat.Cash(cash), bonus and UIKit.Theme.Colors.Accent.Base or GREEN, true)
		if bonus then EffectsController.CameraPunch(3) end
	end
	EffectsController.Burst(sellZone.Position + Vector3.new(0, 2, 0), UIKit.Theme.Colors.Accent.Base, 30)
	gui.Enabled = true -- fly-in notes live on this gui
	flyCashToHud(math.clamp(math.floor(cash / 25) + 4, 4, 12))
	catWaveUntil = os.clock() + 1.5
	if not isOpen then
		task.delay(0.7, function() if not isOpen then gui.Enabled = false end end)
	end
end

-- ===== guide trail (beginners only) =====

local CHEVRONS = 26
local SPACING = 3
local trailFolder: Folder
local chevrons = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function buildTrail()
	trailFolder = Instance.new("Folder")
	trailFolder.Name = "GuideTrail"
	trailFolder.Parent = workspace
	for i = 1, CHEVRONS do
		local arms = {}
		for _ = 1, 2 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = UIKit.Theme.White
			p.Size = Vector3.new(0.35, 0.12, 1.3)
			p.Transparency = 1
			p.Parent = trailFolder
			table.insert(arms, p)
		end
		chevrons[i] = arms
	end
end

local function hideTrail()
	for _, arms in ipairs(chevrons) do
		arms[1].Transparency = 1
		arms[2].Transparency = 1
	end
end

local ARM_L = CFrame.new(-0.4, 0, 0.46) * CFrame.Angles(0, math.rad(-40), 0)
local ARM_R = CFrame.new(0.4, 0, 0.46) * CFrame.Angles(0, math.rad(40), 0)

local function updateTrail(root: BasePart, now: number)
	local from = root.Position
	local to = sellZone.Position
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude - 6
	if dist <= 2 then hideTrail() return end
	local dir = flat.Unit
	local offset = (now * 7) % SPACING
	local filter = { player.Character, trailFolder }
	for _, name in ipairs({ "MySushi", "ClientFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(filter, f) end
	end
	rayParams.FilterDescendantsInstances = filter
	for i, arms in ipairs(chevrons) do
		local d = 3 + (i - 1) * SPACING + offset
		if d > dist then
			arms[1].Transparency = 1
			arms[2].Transparency = 1
		else
			local p = from + dir * d
			local hit = workspace:Raycast(Vector3.new(p.X, from.Y + 4, p.Z), Vector3.new(0, -20, 0), rayParams)
			local y = hit and hit.Position.Y + 0.15 or (from.Y - 2.8)
			local cf = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + dir)
			arms[1].CFrame = cf * ARM_L
			arms[2].CFrame = cf * ARM_R
			-- fade in near the player, fade out near the market
			local fade = math.max(0, 1 - math.min(d - 3, dist - d, 4) / 4)
			local tr = 0.15 + 0.85 * fade
			arms[1].Transparency = tr
			arms[2].Transparency = tr
		end
	end
end

-- ===== per-frame =====

local pawBase: CFrame?
local pawPivot: CFrame?

local function step()
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = root and humanoid and humanoid.Health > 0

	local inZone = false
	if alive then
		-- track the nearest sell stall
		local best, bestDist = sellZone, math.huge
		for _, z in ipairs(CollectionService:GetTagged("SellZone")) do
			if z:IsA("BasePart") and z:IsDescendantOf(workspace) then
				local d = ((root :: BasePart).Position - z.Position).Magnitude
				if d < bestDist then best, bestDist = z, d end
			end
		end
		sellZone = best
		local offset = (root :: BasePart).Position - sellZone.Position
		inZone = Vector3.new(offset.X, 0, offset.Z).Magnitude <= EconomyConfig.SellZoneRadius and math.abs(offset.Y) < 10
	end
	setOpen(inZone)

	-- beginner trail (only after the tutorial, which draws its own arrows)
	local kg = player:GetAttribute("KG") or 0
	local lifetime = player:GetAttribute("TotalMoney") or 0
	local tutorialDone = (player:GetAttribute("TutorialStep") or 0) >= 5
	if alive and tutorialDone and not inZone and kg >= EconomyConfig.GuideTrailKG and lifetime < EconomyConfig.GuideTrailMaxLifetimeCash then
		updateTrail(root :: BasePart, now)
	else
		hideTrail()
	end

	-- lucky cat paw: slow idle wave, fast wave after a sale
	local paw = market:FindFirstChild("LuckyCat") and market.LuckyCat:FindFirstChild("WavePaw")
	if paw then
		if not pawBase then
			pawBase = paw.CFrame
			pawPivot = paw.CFrame * CFrame.new(0, -0.6, 0)
		end
		local speed = now < catWaveUntil and 14 or 3
		local angle = math.sin(now * speed) * math.rad(25)
		paw.CFrame = (pawPivot :: CFrame) * CFrame.Angles(angle, 0, 0) * (pawPivot :: CFrame):Inverse() * (pawBase :: CFrame)
	end
end

function MarketController.Init()
	market = workspace:WaitForChild("Map"):WaitForChild("SushiMarket")
	sellZone = market:WaitForChild("SellZone")
	for _, d in ipairs(workspace.Map:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Name == "RateGui" then table.insert(rateGuis, d) end
	end
	buildPanel()
	buildTrail()
	for _, attr in ipairs({ "KG", "SellRate" }) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
	Remotes.Sold.OnClientEvent:Connect(onSold)
	RunService.Heartbeat:Connect(step)
end

return MarketController
