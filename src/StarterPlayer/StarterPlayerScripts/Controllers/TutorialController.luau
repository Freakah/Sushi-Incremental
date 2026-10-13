-- TutorialController: the 5-step onboarding bubble on the right side of the screen,
-- plus the guide arrows (a bouncing 3D arrow over the objective and a chevron trail
-- on the ground from the player to it).
--   1 Collect sushi  2 Sell  3 Buy an upgrade  4 Unlock a skill  5 Prestige
-- Progress lives on the server (Player attribute "TutorialStep" = steps completed),
-- so it survives rejoining and never shows for existing players.
-- Phones get a compact pill (tap to expand); on PC you can click the bubble to shrink it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SkillTreeConfig = require(Shared.Config.SkillTreeConfig)
local PrestigeConfig = require(Shared.Config.PrestigeConfig)
local NumberFormat = require(Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)

local player = Players.LocalPlayer
local TutorialController = {}

local C = Color3.fromRGB
local COL = {
	Cream = C(255, 249, 247),
	Border = C(198, 176, 252),
	TitlePill = C(236, 226, 255),
	TitleStroke = C(138, 92, 228),
	Text = C(112, 72, 196),
	Tip = C(253, 233, 244),
	StepPill = C(172, 142, 246),
	Blue1 = C(130, 186, 255),
	Blue2 = C(92, 148, 246),
	BlueEdge = C(78, 126, 228),
	BlueTrack = C(218, 232, 255),
	Green1 = C(140, 230, 140),
	Green2 = C(70, 190, 100),
	GreenEdge = C(52, 152, 82),
	Plum = C(92, 48, 78),
	Arrow = C(176, 124, 255),
	Trail = C(150, 96, 255), -- Neon brightens this to a soft lavender glow
}
local FONT = Enum.Font.FredokaOne
local W, H = 300, 224   -- expanded bubble (before scaling)
local CW, CH = 250, 54  -- compact pill
local TOTAL = 5

local map: Folder

-- ===== small helpers =====

local function new(class: string, props, parent: Instance?)
	local inst = Instance.new(class)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(parent, radius: number?)
	return new("UICorner", { CornerRadius = radius and UDim.new(0, radius) or UDim.new(1, 0) }, parent)
end

local function stroke(parent, thickness: number, color: Color3, border: boolean?)
	return new("UIStroke", {
		Thickness = thickness,
		Color = color,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

local function label(parent, props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextColor3 = COL.Text, TextSize = 16, RichText = true }, parent)
	for k, v in pairs(props) do (t :: any)[k] = v end
	return t
end

local function attr(name: string): number
	return player:GetAttribute(name) or 0
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- "gamepad" / "touch" / "mouse": used to word the instructions for the player's device
local function inputKind(): string
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") then return "gamepad" end
	if isTouch() or last == Enum.UserInputType.Touch then return "touch" end
	return "mouse"
end

local function pivotOf(inst: Instance?): Vector3?
	if not inst then return nil end
	if inst:IsA("Model") then return inst:GetPivot().Position end
	if inst:IsA("BasePart") then return inst.Position end
	return nil
end

-- top of a flat board part, plus a little air
local function boardTop(name: string): Vector3?
	local boards = map:FindFirstChild("UpgradeBoards")
	local b = boards and boards:FindFirstChild(name)
	if not (b and b:IsA("BasePart")) then return nil end
	return b.Position + Vector3.new(0, b.Size.Y / 2 + 2.6, 0)
end

local function nearestSushi(root: BasePart): Vector3?
	local folder = workspace:FindFirstChild("MySushi")
	local best, bestDist = nil, math.huge
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") then
				local p = m:GetPivot().Position
				local d = (p - root.Position).Magnitude
				if d < 120 and d < bestDist then best, bestDist = p, d end
			end
		end
	end
	if best then return best + Vector3.new(0, 3.2, 0) end
	local pad = pivotOf(map:FindFirstChild("SushiPad"))
	return pad and pad + Vector3.new(0, 4, 0)
end

local function cashGoal(prefix: string, cost: number)
	local have = math.min(attr("Money"), cost)
	return prefix .. "  " .. NumberFormat.Cash(math.floor(have)) .. " / " .. NumberFormat.Cash(cost), have / cost
end

-- ===== the five steps =====
-- Goal() -> CTA text, progress 0..1 (nil = no bar). Target(root) -> world point for the arrow.

local STEPS = {
	{
		Title = "Sushi Time!",
		Text = "Walk over the sushi on the pad to collect it!",
		TipIcon = "✨",
		Tip = "The heavier and rarer the sushi, the more it's worth!",
		Goal = function()
			local n = math.min(attr("SushiCollected"), 5)
			return "Collect sushi  " .. n .. "/5", n / 5
		end,
		Target = nearestSushi,
	},
	{
		Title = "Time to Sell!",
		Text = function()
			local how = ({ touch = "tap", gamepad = "press", mouse = "click" })[inputKind()]
			return "Go to the Sushi Market board and " .. how .. " Sell to turn your sushi into Cash!"
		end,
		TipIcon = "💰",
		Tip = "Sell often so you can afford upgrades sooner!",
		Goal = function() return "Sell at the Sushi Market", nil end,
		Target = function()
			-- point at the sell screen on the counter
			local market = map:FindFirstChild("SushiMarket")
			local screen = market and market:FindFirstChild("Converter") :: BasePart?
			if screen then return screen.Position + Vector3.new(0, screen.Size.Y / 2 + 3, 0) end
			local p = pivotOf(market and market:FindFirstChild("SellZone"))
			return p and p + Vector3.new(0, 8, 0)
		end,
	},
	{
		Title = "Upgrade Time!",
		Text = function()
			local how = inputKind() == "touch" and "Tap" or "Click"
			return how .. " Buy on the Cash Upgrades board to power up your sushi!"
		end,
		TipIcon = "⬆️",
		Tip = "Upgrades make your sushi heavier and spawn faster!",
		Goal = function() return "Buy an upgrade", nil end,
		Target = function() return boardTop("CashBoard") end,
	},
	{
		Title = "Skill Tree!",
		Text = function()
			local how = ({ touch = "Tap", gamepad = "Select", mouse = "Click" })[inputKind()] or "Click"
			return "Open 🌳 Skills on the left of your screen. " .. how .. " a skill next to Start to unlock it!"
		end,
		TipIcon = "🌳",
		Tip = "Skills are kept when you Prestige!",
		Goal = function()
			-- the cheapest first-ring skill
			local cheapest
			for _, node in ipairs(SkillTreeConfig.List) do
				if node.Prereqs[1] == "START" and (not cheapest or node.Cost < cheapest) then cheapest = node.Cost end
			end
			return cashGoal("Unlock a skill", cheapest or 50)
		end,
		Target = function() return nil end, -- it's a menu now (the Skills button pulses instead)
	},
	{
		Title = "Prestige!",
		Text = "Save up Cash, then press Prestige on the Prestige board to trade it for ⭐ Prestiges!",
		TipIcon = "⭐",
		Tip = "Prestiges buy upgrades that boost every area!",
		Goal = function() return cashGoal("Prestige", PrestigeConfig.MinCash) end,
		Target = function() return boardTop("PrestigeWall") end,
	},
}

local FINALE = {
	Title = "All Done!",
	Text = "You know the basics. Now go build your sushi empire!",
	TipIcon = "📖",
	Tip = "Every new sushi in the Index boosts your Sushi Value!",
}

-- ===== bubble UI =====

local gui: ScreenGui
local holder: Frame
local holderScale: UIScale
local group: CanvasGroup
local bubble: Frame
local ui: any = {}
local slide = Instance.new("NumberValue") -- extra X offset while sliding in/out
local userCompact = false
local compact = false

local function buildMascot(parent)
	local m = new("Frame", { Name = "Mascot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(72, 72), ZIndex = 20 }, parent)
	local sc = new("UIScale", {}, m)
	-- rice
	local rice = new("Frame", { Name = "Rice", BackgroundColor3 = C(255, 255, 255), Position = UDim2.fromOffset(8, 30), Size = UDim2.fromOffset(56, 34), ZIndex = 3 }, m)
	corner(rice, 16)
	stroke(rice, 3, COL.Plum, true)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(244, 236, 240)) }, rice)
	-- salmon slice
	local fish = new("Frame", { Name = "Fish", BackgroundColor3 = C(255, 255, 255), Position = UDim2.fromOffset(4, 10), Size = UDim2.fromOffset(64, 30), Rotation = -4, ZIndex = 4 }, m)
	corner(fish, 15)
	stroke(fish, 3, COL.Plum, true)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 156, 128), C(242, 98, 92)) }, fish)
	for i = 0, 2 do
		local s = new("Frame", { BackgroundColor3 = C(255, 226, 212), BackgroundTransparency = 0.1, BorderSizePixel = 0, Position = UDim2.fromOffset(16 + i * 13, 7), Size = UDim2.fromOffset(5, 16), Rotation = 28 }, fish)
		corner(s, 3)
	end
	-- face
	ui.Eyes = {}
	for _, x in ipairs({ 24, 42 }) do
		local e = new("Frame", { BackgroundColor3 = COL.Plum, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(x, 48), Size = UDim2.fromOffset(6, 8), ZIndex = 6 }, m)
		corner(e)
		new("Frame", { BackgroundColor3 = C(255, 255, 255), BorderSizePixel = 0, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(2, 2) }, e)
		table.insert(ui.Eyes, e)
	end
	for _, x in ipairs({ 14, 49 }) do
		local b = new("Frame", { BackgroundColor3 = C(255, 160, 186), BackgroundTransparency = 0.15, Position = UDim2.fromOffset(x, 52), Size = UDim2.fromOffset(9, 5), ZIndex = 6 }, m)
		corner(b)
	end
	local mouth = new("Frame", { BackgroundColor3 = COL.Plum, Position = UDim2.fromOffset(32, 53), Size = UDim2.fromOffset(8, 5), ZIndex = 6 }, m)
	corner(mouth, 3)
	-- sparkle ticks above its head (like the reference)
	for i, spec in ipairs({ { -4, 4, -45 }, { 8, -6, -18 }, { 22, -9, 8 } }) do
		local s = new("Frame", { Name = "Spark" .. i, BackgroundColor3 = C(255, 214, 90), Position = UDim2.fromOffset(spec[1], spec[2]), Size = UDim2.fromOffset(6, 13), Rotation = spec[3], ZIndex = 2 }, m)
		corner(s)
		stroke(s, 1.5, C(236, 170, 60), true)
	end
	return m, sc
end

local function buildBubble()
	gui = new("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	holder = new("Frame", { Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(W, H) }, gui)
	holderScale = new("UIScale", {}, holder)
	-- CanvasGroup so the whole bubble fades as one; padded so the mascot/tail aren't clipped
	group = new("CanvasGroup", { Name = "Group", BackgroundTransparency = 1, Position = UDim2.fromOffset(-50, -50), Size = UDim2.new(1, 70, 1, 84), GroupTransparency = 1 }, holder)

	bubble = new("Frame", { Name = "Bubble", BackgroundColor3 = COL.Cream, Position = UDim2.fromOffset(50, 50), Size = UDim2.fromOffset(W, H), ZIndex = 2 }, group)
	corner(bubble, 26)
	stroke(bubble, 4.5, COL.Border, true)
	ui.BubbleScale = new("UIScale", {}, bubble)

	-- speech tail (a rotated square tucked under the bottom-left edge)
	ui.Tail = new("Frame", { Name = "Tail", BackgroundColor3 = COL.Cream, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 1, -2), Size = UDim2.fromOffset(20, 20), Rotation = 45, ZIndex = 1 }, bubble)
	corner(ui.Tail, 4)
	stroke(ui.Tail, 4.5, COL.Border, true)
	ui.TailCover = new("Frame", { Name = "TailCover", BackgroundColor3 = COL.Cream, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 34, 1, 0), Size = UDim2.fromOffset(30, 14), ZIndex = 3 }, bubble)

	-- title pill
	ui.TitlePill = new("Frame", { Name = "TitlePill", BackgroundColor3 = COL.TitlePill, Position = UDim2.fromOffset(62, 14), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4 }, bubble)
	corner(ui.TitlePill)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, ui.TitlePill)
	ui.Title = label(ui.TitlePill, { Name = "Title", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = 27, TextColor3 = C(255, 255, 255), ZIndex = 5 })
	stroke(ui.Title, 3, COL.TitleStroke)

	-- step counter
	ui.StepPill = new("Frame", { Name = "StepPill", BackgroundColor3 = COL.StepPill, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 17), Size = UDim2.fromOffset(52, 30), ZIndex = 4 }, bubble)
	corner(ui.StepPill)
	ui.StepText = label(ui.StepPill, { Size = UDim2.fromScale(1, 1), TextSize = 18, TextColor3 = C(255, 255, 255), ZIndex = 5 })

	-- description
	ui.Desc = label(bubble, { Name = "Desc", Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 54), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4 })

	-- tip box
	ui.TipBox = new("Frame", { Name = "Tip", BackgroundColor3 = COL.Tip, Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -32, 0, 46), ZIndex = 4 }, bubble)
	corner(ui.TipBox, 14)
	ui.TipIcon = label(ui.TipBox, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(32, 32), TextSize = 24, ZIndex = 5 })
	new("UITextSizeConstraint", { MaxTextSize = 17 }, ui.Desc)
	ui.TipText = label(ui.TipBox, { Position = UDim2.fromOffset(46, 5), Size = UDim2.new(1, -54, 1, -10), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(128, 86, 206), ZIndex = 5 })

	new("UITextSizeConstraint", { MaxTextSize = 14 }, ui.TipText)

	-- goal pill (blue, fills up with progress)
	ui.Goal = new("Frame", { Name = "Goal", BackgroundColor3 = COL.BlueTrack, Position = UDim2.fromOffset(16, 172), Size = UDim2.new(1, -32, 0, 38), ZIndex = 4 }, bubble)
	corner(ui.Goal)
	ui.GoalStroke = stroke(ui.Goal, 3, COL.BlueEdge, true)
	ui.GoalScale = new("UIScale", {}, ui.Goal)
	ui.Fill = new("Frame", { Name = "Fill", BackgroundColor3 = C(255, 255, 255), Size = UDim2.fromScale(1, 1), ZIndex = 5 }, ui.Goal)
	corner(ui.Fill)
	ui.FillGradient = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.Blue1, COL.Blue2) }, ui.Fill)
	new("UISizeConstraint", { MinSize = Vector2.new(38, 0) }, ui.Fill)
	ui.GoalText = label(ui.Goal, { Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -50, 1, -12), TextScaled = true, TextColor3 = C(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	ui.GoalTextLimit = new("UITextSizeConstraint", { MaxTextSize = 17 }, ui.GoalText)
	ui.GoalTextStroke = stroke(ui.GoalText, 2, COL.BlueEdge)
	-- chevron ">" on the right that nudges forward
	ui.Chevron = new("Frame", { Name = "Chevron", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(16, 18), ZIndex = 6 }, ui.Goal)
	ui.ChevronParts = {}
	for i, rot in ipairs({ 45, -45 }) do
		local arm = new("Frame", { BackgroundColor3 = C(255, 255, 255), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, i == 1 and -4 or 4), Size = UDim2.fromOffset(12, 4.5), Rotation = rot, ZIndex = 7 }, ui.Chevron)
		corner(arm)
		stroke(arm, 1.5, COL.BlueEdge, true)
		table.insert(ui.ChevronParts, arm)
	end

	ui.Mascot, ui.MascotScale = buildMascot(bubble)

	-- click / tap the bubble to shrink or expand it
	local toggle = new("TextButton", { Name = "Toggle", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 }, bubble)
	toggle.Activated:Connect(function()
		userCompact = not userCompact
	end)
end

-- positions everything for the expanded bubble or the compact pill
local function applyLayout(isCompact: boolean)
	compact = isCompact
	local w, h = isCompact and CW or W, isCompact and CH or H
	holder.Size = UDim2.fromOffset(w, h)
	bubble.Size = UDim2.fromOffset(w, h)
	ui.GoalTextLimit.MaxTextSize = isCompact and 15 or 17
	bubble:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, isCompact and 27 or 26)
	for _, inst in ipairs({ ui.TitlePill, ui.Desc, ui.TipBox, ui.Tail, ui.TailCover }) do
		inst.Visible = not isCompact
	end
	ui.StepPill.Visible = not isCompact
	if isCompact then
		ui.Mascot.Position = UDim2.fromOffset(26, 27)
		ui.MascotScale.Scale = 0.62
		ui.Goal.Position = UDim2.fromOffset(54, 9)
		ui.Goal.Size = UDim2.new(1, -64, 0, 36)
	else
		ui.Mascot.Position = UDim2.fromOffset(18, 14)
		ui.MascotScale.Scale = 1
		ui.Goal.Position = UDim2.fromOffset(16, 172)
		ui.Goal.Size = UDim2.new(1, -32, 0, 38)
	end
end

local function setGoalColors(done: boolean)
	ui.FillGradient.Color = done and ColorSequence.new(COL.Green1, COL.Green2) or ColorSequence.new(COL.Blue1, COL.Blue2)
	local edge = done and COL.GreenEdge or COL.BlueEdge
	ui.GoalStroke.Color = edge
	ui.GoalTextStroke.Color = edge
	for _, arm in ipairs(ui.ChevronParts) do arm:FindFirstChildOfClass("UIStroke").Color = edge end
end

local shownStep: number? = nil -- step the bubble shows (1..5), 6 = finale
local lastProgress = -1

local function refreshGoal()
	local step = shownStep and STEPS[shownStep]
	if not step then return end
	local text, progress = step.Goal()
	ui.GoalText.Text = text
	progress = progress and math.clamp(progress, 0, 1) or 1
	ui.Fill.Size = UDim2.fromScale(progress, 1)
	if lastProgress >= 0 and progress > lastProgress + 1e-6 then
		ui.GoalScale.Scale = 1.06
		TweenService:Create(ui.GoalScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	lastProgress = progress
end

local function showContent(index: number)
	shownStep = index
	lastProgress = -1
	local step = STEPS[index] or FINALE
	ui.Title.Text = step.Title
	ui.Desc.Text = if type(step.Text) == "function" then step.Text() else step.Text
	ui.TipIcon.Text = step.TipIcon
	ui.TipText.Text = step.Tip
	ui.StepText.Text = math.min(index, TOTAL) .. "/" .. TOTAL
	setGoalColors(index > TOTAL)
	if index > TOTAL then
		ui.GoalText.Text = "Tutorial complete!"
		ui.Fill.Size = UDim2.fromScale(1, 1)
	else
		refreshGoal()
	end
end

local function appear()
	gui.Enabled = true
	slide.Value = 60
	group.GroupTransparency = 1
	ui.BubbleScale.Scale = 0.85
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(slide, info, { Value = 0 }):Play()
	TweenService:Create(ui.BubbleScale, info, { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	-- mascot pops in slightly after
	ui.MascotScale.Scale = (compact and 0.62 or 1) * 0.3
	TweenService:Create(ui.MascotScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.12), { Scale = compact and 0.62 or 1 }):Play()
	task.wait(0.45)
end

local function disappear()
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(slide, info, { Value = 80 }):Play()
	TweenService:Create(group, info, { GroupTransparency = 1 }):Play()
	task.wait(0.32)
end

-- the current step was just completed: goal turns green, mascot hops
local function celebrate()
	setGoalColors(true)
	ui.GoalText.Text = "Done!"
	TweenService:Create(ui.Fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(1, 1) }):Play()
	ui.GoalScale.Scale = 1.12
	TweenService:Create(ui.GoalScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	ui.BubbleScale.Scale = 1.05
	TweenService:Create(ui.BubbleScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	ui.Hop = os.clock()
	EffectsController.PlaySound("Upgrade", 1.2)
	task.wait(1.2)
end

-- ===== guide arrows =====

local marker: Model
local markerScale = 1
local CHEVRONS = 24
local SPACING = 3
local trailFolder: Folder
local chevrons = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function arrowPart(class: string, size: Vector3, cf: CFrame): BasePart
	return new(class, {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.SmoothPlastic, Color = COL.Arrow, Size = size, CFrame = cf,
	}, marker)
end

local function buildMarker()
	marker = new("Model", { Name = "TutorialArrow" })
	local t = 0.7 -- thickness
	local stem = arrowPart("Part", Vector3.new(t, 1.9, 1.1), CFrame.new(0, 1.6, 0))
	arrowPart("WedgePart", Vector3.new(t, 1.7, 1.5), CFrame.new(0, -0.15, 0.75) * CFrame.Angles(math.pi, 0, 0))
	arrowPart("WedgePart", Vector3.new(t, 1.7, 1.5), CFrame.new(0, -0.15, -0.75) * CFrame.Angles(0, 0, math.pi))
	stem.Name = "Stem"
	marker.WorldPivot = CFrame.new() -- the arrow tip sits ~1 stud under the pivot
	-- soft dark outline so the arrow reads on the light pad
	new("Highlight", {
		FillColor = C(255, 255, 255), FillTransparency = 1,
		OutlineColor = C(40, 22, 70), OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, marker)
	marker.Parent = nil
end

local function buildTrail()
	trailFolder = new("Folder", { Name = "TutorialTrail" }, workspace)
	for i = 1, CHEVRONS do
		local arms = {}
		for _ = 1, 2 do
			table.insert(arms, new("Part", {
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.Neon, Color = COL.Trail, Size = Vector3.new(0.35, 0.12, 1.3), Transparency = 1,
			}, trailFolder))
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

local function updateTrail(root: BasePart, to: Vector3, now: number)
	local from = root.Position
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude - 5
	if dist <= 2 then hideTrail() return end
	local dir = flat.Unit
	local offset = (now * 7) % SPACING
	local filter = { player.Character, trailFolder, marker }
	for _, name in ipairs({ "MySushi", "ClientFX", "GuideTrail" }) do
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
			local fade = math.max(0, 1 - math.min(d - 3, dist - d, 4) / 4)
			local tr = 0.1 + 0.9 * fade
			arms[1].Transparency = tr
			arms[2].Transparency = tr
		end
	end
end

-- ===== per-frame =====

local active = false -- a step (1..5) is on screen and its arrows should show

local function placeBubble()
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	local s = math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.6, 1.1)
	holderScale.Scale = s
	local screenH = gui.AbsoluteSize.Y
	local y
	local wantCompact = userCompact
	if isTouch() then
		-- phones: small pill in the top-right corner, clear of the thumbstick and jump button
		y = 8
		wantCompact = not userCompact -- tap to expand
	else
		-- PC / console: right under the currency bars
		local bottom = screenH * 0.6
		local moneyBar = HudController.GetBar("Money")
		local container = moneyBar and moneyBar.Parent
		if container then
			bottom = 0
			for _, b in ipairs(container:GetChildren()) do
				if b:IsA("Frame") and b.Visible then
					bottom = math.max(bottom, b.AbsolutePosition.Y + b.AbsoluteSize.Y)
				end
			end
		end
		y = bottom + 30 * s
		-- not enough room for the full bubble on short windows: use the pill
		if y + H * s > screenH - 12 then wantCompact = true end
	end
	if wantCompact ~= compact then applyLayout(wantCompact) end
	holder.Position = UDim2.new(1, -18 + slide.Value * s, 0, y)
end

local function step()
	if not gui.Enabled then return end
	local now = os.clock()
	placeBubble()

	-- mascot idle bob + hop on completion, blink now and then
	local hopT = ui.Hop and (now - ui.Hop) or 99
	local hop = hopT < 0.5 and math.sin(hopT / 0.5 * math.pi) * 14 or 0
	local bob = math.sin(now * 2.4) * 2 + hop
	local base = compact and UDim2.fromOffset(26, 27) or UDim2.fromOffset(18, 14)
	ui.Mascot.Position = base - UDim2.fromOffset(0, bob)
	ui.Mascot.Rotation = math.sin(now * 1.7) * 4
	local blink = (now % 3.6) < 0.12
	for _, e in ipairs(ui.Eyes) do e.Size = UDim2.fromOffset(6, blink and 2 or 8) end
	ui.Chevron.Position = UDim2.new(1, -14 + math.sin(now * 5) * 2.5, 0.5, 0)

	-- arrows
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inNight = (player:GetAttribute("Zone") or "Starter") ~= "Starter" -- Sushi Pond / Blood Rift
	local stepDef = active and shownStep and STEPS[shownStep]
	local target = stepDef and root and not inNight and stepDef.Target(root) or nil
	if target and root then
		if not marker.Parent then marker.Parent = workspace end
		local dist = (target - root.Position).Magnitude
		local want = math.clamp(dist / 28, 1, 2.6)
		if math.abs(want - markerScale) > 0.05 then
			markerScale = want
			marker:ScaleTo(markerScale)
		end
		local y = (math.sin(now * 3.2) * 0.5 + 0.5) * 1.1 * markerScale
		marker:PivotTo(CFrame.new(target + Vector3.new(0, y, 0)) * CFrame.Angles(0, now * 1.8, 0))
		updateTrail(root, target, now)
	else
		if marker.Parent then marker.Parent = nil end
		hideTrail()
	end

	-- other areas aren't part of the tutorial: tuck the bubble away while you're there
	group.Visible = not inNight
end

-- ===== step flow =====

local busy = false
local finished = false
local ready = false -- waits for the title card

local function sync()
	if busy or finished or not ready then return end
	if not player:GetAttribute("DataLoaded") or player:GetAttribute("TutorialStep") == nil then return end
	local want = math.min(attr("TutorialStep") + 1, TOTAL + 1)
	if want == shownStep then return end
	busy = true
	task.spawn(function()
		if shownStep == nil then
			if want > TOTAL then
				-- already finished (existing player): never show anything
				finished = true
				gui.Enabled = false
				busy = false
				return
			end
			showContent(want)
			active = true
			appear()
		else
			active = false
			celebrate()
			disappear()
			showContent(want)
			appear()
			if want > TOTAL then
				task.wait(4.5)
				disappear()
				gui.Enabled = false
				if marker then marker.Parent = nil end
				hideTrail()
				finished = true
				busy = false
				return
			end
			active = true
		end
		busy = false
		sync() -- catch up if several steps finished at once
	end)
end

function TutorialController.Init()
	map = workspace:WaitForChild("Map")
	buildBubble()
	applyLayout(false)
	buildMarker()
	buildTrail()

	for _, a in ipairs({ "SushiCollected", "Money" }) do
		player:GetAttributeChangedSignal(a):Connect(function()
			if active and not busy then refreshGoal() end
		end)
	end
	for _, a in ipairs({ "TutorialStep", "DataLoaded" }) do
		player:GetAttributeChangedSignal(a):Connect(sync)
	end
	RunService.RenderStepped:Connect(step)
	task.delay(2.9, function()
		ready = true
		sync()
	end)
end

return TutorialController
