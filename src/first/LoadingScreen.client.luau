--[[
	Sushi Loading Screen  (LocalScript in ReplicatedFirst)
	=====================================================
	A cute pastel loading screen shown as soon as a player joins:
	  - scrolling sushi pattern background with falling sakura petals
	  - a bouncing sushi mascot with little sushi orbiting around it
	  - a striped loading bar with a sushi riding along it, plus silly
	    loading messages and gameplay tips
	  - a bouncy PLAY button once the game has loaded; clicking it bursts
	    sushi everywhere and fades into the game

	SETUP: Rojo syncs this file into ReplicatedFirst as a LocalScript named
	"LoadingScreen". Nothing else to do.
]]

local CONFIG = {
	Title = "Sushi Incremental", -- set to nil to use the name of the published game instead
	Subtitle = "🌸 Welcome to the sushi bar! 🌸",
	MinimumTime = 3, -- seconds the loading screen shows at least
	ShowInStudio = true, -- set false to skip it while testing in Studio
	HideRobloxUI = true, -- hides chat/leaderboard/backpack until Play is pressed

	Messages = {
		"Rolling the rice...",
		"Slicing fresh salmon...",
		"Warming up the tea...",
		"Folding the nori...",
		"Sharpening the knives...",
		"Waking up the chef...",
		"Polishing the chopsticks...",
		"Counting grains of rice...",
	},
	Tips = {
		"Tip: Walk over sushi to collect it!",
		"Tip: Rebirth to unlock permanent upgrades!",
		"Tip: Use the Max button to buy lots of upgrades at once!",
		"Tip: Upgrade Spawn Speed to get sushi faster!",
	},

	-- Colours
	BackgroundTop = Color3.fromRGB(255, 190, 212),
	BackgroundBottom = Color3.fromRGB(255, 226, 204),
	Accent = Color3.fromRGB(255, 105, 150),
	AccentDark = Color3.fromRGB(214, 70, 118),
	PlaySound = "rbxasset://sounds/electronicpingshort.wav",
}

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")

print("[LoadingScreen] Script started")

if RunService:IsStudio() and not CONFIG.ShowInStudio then
	print("[LoadingScreen] Skipped because ShowInStudio is false")
	return
end

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PINK_TEXT = CONFIG.AccentDark
local SUSHI = { "🍣", "🍙", "🍤", "🍱", "🍥", "🍡", "🍵", "🥢" }

--------------------------------------------------------------------------
-- Helpers
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

local function tween(object, time, goal, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function square(parent)
	create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = parent })
end

local function label(props, strokeColor, strokeThickness)
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
	})
	for key, value in props do
		if key ~= "Parent" then
			l[key] = value
		end
	end
	if strokeThickness and strokeThickness > 0 then
		create("UIStroke", { Color = strokeColor or PINK_TEXT, Thickness = strokeThickness, Parent = l })
	end
	l.Parent = props.Parent
	return l
end

local function setCoreGui(enabled)
	if not CONFIG.HideRobloxUI then
		return
	end
	task.spawn(function()
		-- SetCoreGuiEnabled can fail for a moment right after joining
		for _ = 1, 20 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, enabled) then
				return
			end
			task.wait(0.2)
		end
	end)
end

-- Stop the character walking around behind the loading screen
local function setControls(enabled)
	task.spawn(function()
		local ok, controls = pcall(function()
			local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
			return require(playerModule):GetControls()
		end)
		if ok and controls then
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

--------------------------------------------------------------------------
-- Screen
--------------------------------------------------------------------------

local screen = create("ScreenGui", {
	Name = "SushiLoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- A CanvasGroup lets the whole screen fade out together at the end
local root = create("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = screen,
})
local background = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Parent = root,
})
create("UIGradient", {
	Color = ColorSequence.new(CONFIG.BackgroundTop, CONFIG.BackgroundBottom),
	Rotation = 90,
	Parent = background,
})
local rootScale = create("UIScale", { Parent = root })

setCoreGui(false)
setControls(false)
print("[LoadingScreen] Showing loading screen")

-- Scrolling sushi pattern
local SPACING = 150
local pattern = create("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, SPACING * 2, 1, SPACING * 2),
	Parent = root,
})
for row = 0, 15 do
	for col = 0, 20 do
		label({
			Text = SUSHI[(row * 3 + col) % #SUSHI + 1],
			TextTransparency = 0.78,
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.fromOffset(col * SPACING + (row % 2) * SPACING / 2, row * SPACING * 0.75),
			Rotation = if (row + col) % 2 == 0 then -12 else 12,
			Parent = pattern,
		})
	end
end

-- Petals layer
local petalLayer = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })

-- Mascot: a big bouncing sushi with a soft shadow and sushi orbiting it
local MASCOT_CENTER = Vector2.new(0.5, 0.3)
local shadow = create("Frame", {
	BackgroundColor3 = CONFIG.AccentDark,
	BackgroundTransparency = 0.8,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(MASCOT_CENTER.X, MASCOT_CENTER.Y + 0.12),
	Size = UDim2.fromScale(0.12, 0.025),
	ZIndex = 3,
	Parent = root,
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = shadow })

local mascot = label({
	Text = "🍣",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(MASCOT_CENTER.X, MASCOT_CENTER.Y),
	Size = UDim2.fromScale(0.22, 0.22),
	ZIndex = 4,
	Parent = root,
})
square(mascot)

local orbiters = {}
for i, emoji in { "🍙", "🍤", "🍥", "🍵", "🍡" } do
	local orbiter = label({
		Text = emoji,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.065, 0.065),
		ZIndex = 4,
		Parent = root,
	})
	square(orbiter)
	orbiters[i] = orbiter
end

-- Title
local titleLabel = label({
	Text = CONFIG.Title or "Sushi Shop",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.7, 0.13),
	ZIndex = 5,
	Parent = root,
}, CONFIG.AccentDark, 6)
local titleScale = create("UIScale", { Scale = 0, Parent = titleLabel })
if not CONFIG.Title then
	-- Look up the game's name without holding up the rest of the screen
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		if ok and info and info.Name and info.Name ~= "" then
			titleLabel.Text = info.Name
		end
	end)
end
tween(titleScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)

label({
	Text = CONFIG.Subtitle,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.615),
	Size = UDim2.fromScale(0.5, 0.04),
	ZIndex = 5,
	Parent = root,
}, CONFIG.AccentDark, 3)

-- Loading bar
local bar = create("Frame", {
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.73),
	Size = UDim2.fromScale(0.42, 0.055),
	ZIndex = 5,
	Parent = root,
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
create("UIStroke", { Color = CONFIG.AccentDark, Thickness = 4, Parent = bar })
create("UISizeConstraint", { MinSize = Vector2.new(260, 30), MaxSize = Vector2.new(620, 52), Parent = bar })

local fill = create("Frame", {
	BackgroundColor3 = WHITE,
	Size = UDim2.fromScale(0, 1),
	ZIndex = 6,
	Parent = bar,
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
-- Candy stripes
local stripes = {}
local STRIPES = 8
for i = 0, STRIPES do
	local t = i / STRIPES
	table.insert(stripes, ColorSequenceKeypoint.new(t, if i % 2 == 0 then CONFIG.Accent else CONFIG.AccentDark:Lerp(CONFIG.Accent, 0.4)))
end
local stripeGradient = create("UIGradient", { Color = ColorSequence.new(stripes), Parent = fill })

local percent = label({
	Text = "0%",
	Size = UDim2.fromScale(1, 0.7),
	Position = UDim2.fromScale(0, 0.15),
	ZIndex = 8,
	Parent = bar,
}, CONFIG.AccentDark, 3)

local rider = label({
	Text = "🍣",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0, 0.1),
	Size = UDim2.fromScale(0.12, 1.4),
	ZIndex = 9,
	Parent = bar,
})
square(rider)

local status = label({
	Text = CONFIG.Messages[1],
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.8),
	Size = UDim2.fromScale(0.5, 0.04),
	ZIndex = 5,
	Parent = root,
}, CONFIG.AccentDark, 3)

local tip = label({
	Text = CONFIG.Tips[math.random(1, #CONFIG.Tips)],
	TextColor3 = CONFIG.AccentDark,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.96),
	Size = UDim2.fromScale(0.6, 0.035),
	ZIndex = 5,
	Parent = root,
}, WHITE, 2)

-- Play button (hidden until loading finishes)
local play = create("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.Accent,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.75),
	Size = UDim2.fromScale(0.24, 0.11),
	Visible = false,
	ZIndex = 10,
	Parent = root,
})
create("UICorner", { CornerRadius = UDim.new(0.35, 0), Parent = play })
create("UIStroke", { Color = WHITE, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = play })
create("UIAspectRatioConstraint", { AspectRatio = 3, Parent = play })
create("UISizeConstraint", { MinSize = Vector2.new(180, 60), MaxSize = Vector2.new(420, 140), Parent = play })
create("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(215, 215, 215)), Rotation = 90, Parent = play })
label({
	Text = "▶  PLAY",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.8, 0.62),
	ZIndex = 11,
	Parent = play,
}, CONFIG.AccentDark, 4)
local playScale = create("UIScale", { Scale = 0, Parent = play })

--------------------------------------------------------------------------
-- Animation loop
--------------------------------------------------------------------------

local petals = {}
local function spawnPetal()
	local size = math.random(10, 20)
	local petal = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, math.random(170, 215), math.random(200, 225)),
		Size = UDim2.fromOffset(size, size * 0.7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
		Parent = petalLayer,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = petal })
	table.insert(petals, {
		Frame = petal,
		X = math.random(),
		Y = -0.05,
		Speed = 0.05 + math.random() * 0.07,
		Sway = math.random() * math.pi * 2,
		Spin = math.random(-120, 120),
	})
end

local startTime = os.clock()
local progress = 0
local finished = false
local playReady = false
local nextPetal = 0
local nextMessage = os.clock() + 1.2
local messageIndex = 1

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local elapsed = now - startTime

	-- Background drifts diagonally forever
	local shift = (elapsed * 25) % SPACING
	pattern.Position = UDim2.fromOffset(-shift, -shift * 0.75)

	-- Petals
	if now >= nextPetal then
		nextPetal = now + 0.12
		spawnPetal()
	end
	for i = #petals, 1, -1 do
		local p = petals[i]
		p.Y += p.Speed * dt
		p.Sway += dt * 1.5
		p.Frame.Position = UDim2.fromScale(p.X + math.sin(p.Sway) * 0.02, p.Y)
		p.Frame.Rotation += p.Spin * dt
		if p.Y > 1.05 then
			p.Frame:Destroy()
			table.remove(petals, i)
		end
	end

	-- Mascot bounces and squashes a little, the shadow shrinks as it jumps
	local hop = math.abs(math.sin(elapsed * 3))
	mascot.Position = UDim2.fromScale(MASCOT_CENTER.X, MASCOT_CENTER.Y - hop * 0.05)
	mascot.Rotation = math.sin(elapsed * 3) * 8
	shadow.Size = UDim2.fromScale(0.12 - hop * 0.04, 0.025 - hop * 0.008)
	shadow.BackgroundTransparency = 0.75 + hop * 0.15

	for i, orbiter in orbiters do
		local angle = elapsed * 1.2 + (i - 1) / #orbiters * math.pi * 2
		orbiter.Position = UDim2.fromScale(MASCOT_CENTER.X + math.cos(angle) * 0.17, MASCOT_CENTER.Y + math.sin(angle) * 0.09)
		orbiter.Rotation = math.sin(elapsed * 4 + i) * 15
		-- Orbiters behind the mascot are drawn behind it
		orbiter.ZIndex = if math.sin(angle) < 0 then 3 else 5
	end

	titleLabel.Rotation = math.sin(elapsed * 1.5) * 2

	if finished then
		return
	end

	-- Loading progress: follows real loading, but never faster than MinimumTime
	local loaded = game:IsLoaded() and ContentProvider.RequestQueueSize == 0
	local target = if loaded then 1 else 0.92 * (1 - math.exp(-elapsed / 2.5))
	target = math.min(target, elapsed / CONFIG.MinimumTime)
	progress += (target - progress) * math.min(1, dt * 5)
	if target >= 1 and progress > 0.995 then
		progress = 1
	end

	fill.Size = UDim2.fromScale(progress, 1)
	rider.Position = UDim2.fromScale(math.clamp(progress, 0.04, 0.96), 0.15 - hop * 0.25)
	rider.Rotation = math.sin(elapsed * 8) * 10
	stripeGradient.Offset = Vector2.new(((elapsed * 0.25) % (2 / STRIPES)) - 2 / STRIPES, 0)
	percent.Text = ("%d%%"):format(math.floor(progress * 100))

	if now >= nextMessage and not playReady then
		nextMessage = now + 1.2
		messageIndex = messageIndex % #CONFIG.Messages + 1
		status.Text = CONFIG.Messages[messageIndex]
		if messageIndex % 3 == 0 then
			tip.Text = CONFIG.Tips[math.random(1, #CONFIG.Tips)]
		end
	end

	if progress >= 1 and not playReady then
		playReady = true
		status.Text = "Your sushi is ready! 🍣"
		-- Move the message below the Play button so it isn't covered
		tween(status, 0.4, { Position = UDim2.fromScale(0.5, 0.875) }, Enum.EasingStyle.Back)
		tween(bar, 0.3, { BackgroundTransparency = 1 })
		for _, child in bar:GetDescendants() do
			if child:IsA("GuiObject") then
				child.Visible = false
			elseif child:IsA("UIStroke") then
				tween(child, 0.3, { Transparency = 1 })
			end
		end
		play.Visible = true
		tween(playScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end
end)

-- Idle pulse on the play button (only while not hovered)
local hovering = false
task.spawn(function()
	while screen.Parent and not finished do
		if playReady and not hovering then
			tween(playScale, 0.5, { Scale = 1.06 }, Enum.EasingStyle.Sine)
			task.wait(0.5)
			if not hovering and not finished then
				tween(playScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Sine)
			end
			task.wait(0.5)
		else
			task.wait(0.1)
		end
	end
end)

play.MouseEnter:Connect(function()
	hovering = true
	tween(playScale, 0.15, { Scale = 1.12 })
end)
play.MouseLeave:Connect(function()
	hovering = false
	tween(playScale, 0.15, { Scale = 1 })
end)
play.MouseButton1Down:Connect(function()
	tween(playScale, 0.08, { Scale = 0.9 })
end)

--------------------------------------------------------------------------
-- Play!
--------------------------------------------------------------------------

local function sushiBurst()
	for i = 1, 24 do
		local angle = (i / 24) * math.pi * 2 + math.random() * 0.3
		local piece = label({
			Text = SUSHI[math.random(1, #SUSHI)],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = play.Position,
			Size = UDim2.fromScale(0.06, 0.06),
			ZIndex = 12,
			Parent = root,
		})
		square(piece)
		local distance = 0.25 + math.random() * 0.3
		tween(piece, 0.8, {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.75 + math.sin(angle) * distance),
			Rotation = math.random(-360, 360),
			TextTransparency = 1,
		})
	end
end

play.Activated:Connect(function()
	if finished or not playReady then
		return
	end
	finished = true

	local sound = create("Sound", { SoundId = CONFIG.PlaySound, Volume = 0.6, PlaybackSpeed = 1.2, Parent = SoundService })
	sound:Play()

	tween(playScale, 0.25, { Scale = 1.25 }, Enum.EasingStyle.Back)
	sushiBurst()
	task.wait(0.35)

	tween(rootScale, 0.6, { Scale = 1.15 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(root, 0.6, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.65)

	connection:Disconnect()
	screen:Destroy()
	sound:Destroy()
	setCoreGui(true)
	setControls(true)
end)
