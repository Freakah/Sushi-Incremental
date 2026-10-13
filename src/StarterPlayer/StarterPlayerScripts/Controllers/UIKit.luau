-- UIKit: the game's menu style (grey rounded panels, thick dark outlines,
-- icon + title header, "Close" button, outlined rows, big On/Off buttons).
-- Every menu (Settings, Index, and later Titles/Profile/Shop) is built
-- from these pieces so they all look and animate the same.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MenuManager = require(script.Parent.MenuManager)

local player = Players.LocalPlayer
local UIKit = {}

local C = Color3.fromRGB
UIKit.Colors = {
	Panel = C(88, 88, 94),
	Inner = C(64, 64, 70),
	Row = C(108, 108, 114),
	Outline = C(32, 32, 36),
	Title = C(225, 225, 230),
	Text = C(255, 255, 255),
	Subtle = C(200, 200, 208),
}
UIKit.Gradients = {
	On = { C(90, 245, 70), C(20, 170, 25) },
	Off = { C(255, 80, 80), C(190, 20, 25) },
	Dark = { C(78, 78, 84), C(58, 58, 64) },
	Blue = { C(120, 200, 255), C(50, 130, 235) },
	Gold = { C(255, 225, 90), C(240, 160, 30) },
}
UIKit.Font = Enum.Font.FredokaOne

-- ===== primitives =====

function UIKit.new(className: string, props, parent: Instance?)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end
local new = UIKit.new

function UIKit.Corner(parent, radius: number)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

function UIKit.Stroke(parent, thickness: number, color: Color3?, border: boolean?)
	return new("UIStroke", {
		Thickness = thickness,
		Color = color or UIKit.Colors.Outline,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

function UIKit.Label(parent, props, strokeThickness: number?)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextScaled = true,
		RichText = true,
		TextColor3 = UIKit.Colors.Text,
	}, parent)
	for k, v in pairs(props) do (t :: any)[k] = v end
	if (strokeThickness or 2.5) > 0 then
		UIKit.Stroke(t, strokeThickness or 2.5, C(28, 28, 32))
	end
	return t
end

local function gradient(parent, colors)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(colors[1], colors[2]) }, parent)
end

-- Hover grow, press squish (mouse + touch). Uses a UIScale named "PopScale".
function UIKit.Animate(btn: GuiButton, hoverScale: number?, hoverRotation: number?)
	local sc = btn:FindFirstChild("PopScale") or new("UIScale", { Name = "PopScale" }, btn)
	local hover = false
	local baseRot = btn.Rotation
	local function to(scale, rot)
		TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = scale }):Play()
		if hoverRotation then
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Rotation = rot }):Play()
		end
	end
	btn.MouseEnter:Connect(function() hover = true to(hoverScale or 1.06, baseRot + (hoverRotation or 0)) end)
	btn.MouseLeave:Connect(function() hover = false to(1, baseRot) end)
	btn.MouseButton1Down:Connect(function() to(0.9, baseRot) end)
	btn.MouseButton1Up:Connect(function() to(hover and (hoverScale or 1.06) or 1, baseRot) end)
	btn.Activated:Connect(function()
		sc.Scale = 0.88
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = hover and (hoverScale or 1.06) or 1 }):Play()
	end)
	return sc
end

-- Rounded gradient button with outlined text (Close, On/Off, ...)
function UIKit.Button(parent, props, onClick: (() -> ())?)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C(255, 255, 255) }, parent)
	for k, v in pairs(props) do
		if k ~= "Colors" and k ~= "Label" and k ~= "StrokeColor" then (b :: any)[k] = v end
	end
	UIKit.Corner(b, 12)
	UIKit.Stroke(b, 3, props.StrokeColor, true)
	local g = gradient(b, props.Colors or UIKit.Gradients.Dark)
	local lbl = UIKit.Label(b, { Text = props.Label or "", Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6) }, 3)
	UIKit.Animate(b)
	if onClick then b.Activated:Connect(onClick) end
	local api = { Button = b, Label = lbl, Gradient = g }
	function api.SetColors(colors) g.Color = ColorSequence.new(colors[1], colors[2]) end
	function api.SetText(t) lbl.Text = t end
	return api
end

-- ===== window =====
-- opts: Name, Title, Icon, Accent (Color3?), Size (Vector2), DisplayOrder
function UIKit.Window(opts)
	local size: Vector2 = opts.Size
	local accent: Color3? = opts.Accent
	local gui = new("ScreenGui", {
		Name = opts.Name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = opts.DisplayOrder or 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	local backdrop = new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(0, 0, 0),
		BackgroundTransparency = 1,
	}, gui)
	backdrop:SetAttribute("NoSound", true)

	local frame = new("Frame", {
		Name = "Window",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = UIKit.Colors.Panel,
	}, gui)
	UIKit.Corner(frame, 26)
	UIKit.Stroke(frame, 5, accent or UIKit.Colors.Outline, true)
	-- invisible button under the content so clicks inside the window never reach the backdrop (which closes it)
	local sink = new("TextButton", { Name = "Sink", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, frame)
	sink:SetAttribute("NoSound", true)
	local scale = new("UIScale", {}, frame)

	-- header
	UIKit.Label(frame, { Name = "Icon", Text = opts.Icon or "", Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(22, 16) }, 0)
	local title = UIKit.Label(frame, {
		Name = "Title",
		Text = opts.Title,
		TextColor3 = accent or UIKit.Colors.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -290, 0, 58),
		Position = UDim2.fromOffset(90, 16),
	}, 4)
	local close = UIKit.Button(frame, {
		Name = "Close",
		Label = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(170, 60),
		Colors = UIKit.Gradients.Dark,
		StrokeColor = accent or C(150, 150, 156),
	})

	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(22, 92),
		Size = UDim2.new(1, -44, 1, -114),
		BackgroundColor3 = UIKit.Colors.Inner,
	}, frame)
	UIKit.Corner(body, 20)
	UIKit.Stroke(body, 3, UIKit.Colors.Outline, true)

	local win = { Gui = gui, Frame = frame, Body = body, Title = title, OnOpen = {}, OnClose = {} }
	local isOpen = false

	local function baseScale(): number
		local vp = workspace.CurrentCamera.ViewportSize
		return math.clamp(math.min(vp.X * 0.92 / size.X, vp.Y * 0.86 / size.Y), 0.4, 1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if isOpen then scale.Scale = baseScale() end
	end)

	function win.IsOpen() return isOpen end

	function win.Open()
		if isOpen then return end
		MenuManager.Opening(opts.Name)
		isOpen = true
		for _, f in ipairs(win.OnOpen) do task.spawn(f) end
		gui.Enabled = true
		local base = baseScale()
		scale.Scale = base * 0.7
		frame.Position = UDim2.fromScale(0.5, 0.54)
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
		TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
	end

	function win.Close()
		if not isOpen then return end
		isOpen = false
		for _, f in ipairs(win.OnClose) do task.spawn(f) end
		local base = baseScale()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = base * 0.75 }):Play()
		local fade = TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			if not isOpen then gui.Enabled = false end
		end)
	end

	function win.Toggle()
		if isOpen then win.Close() else win.Open() end
	end

	close.Button.Activated:Connect(win.Close)
	backdrop.Activated:Connect(win.Close)
	MenuManager.Register(opts.Name, win.Close)
	return win
end

-- A padded vertical scrolling list inside a window body
function UIKit.List(parent, padding: number?)
	local scroll = new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C(170, 170, 176),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
	}, scroll)
	new("UIListLayout", { Padding = UDim.new(0, padding or 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
	return scroll
end

-- An outlined row: icon + text on the left, a control on the right
function UIKit.Row(parent, icon: string, text: string, order: number)
	local row = new("Frame", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 74),
		BackgroundColor3 = UIKit.Colors.Row,
	}, parent)
	UIKit.Corner(row, 16)
	UIKit.Stroke(row, 3, UIKit.Colors.Outline, true)
	UIKit.Label(row, { Name = "Icon", Text = icon, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(14, 12) }, 0)
	UIKit.Label(row, {
		Name = "Text",
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -300, 0, 42),
		Position = UDim2.fromOffset(76, 16),
	}, 3)
	return row
end

-- Big green On / red Off button on the right of a row
function UIKit.Toggle(row, initial: boolean, onChange: (boolean) -> ())
	local value = initial
	local btn
	local function render()
		btn.SetColors(value and UIKit.Gradients.On or UIKit.Gradients.Off)
		btn.SetText(value and "On" or "Off")
	end
	btn = UIKit.Button(row, {
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 54),
	}, function()
		value = not value
		render()
		onChange(value)
	end)
	render()
	return {
		Button = btn.Button,
		Set = function(v: boolean) value = v render() end,
	}
end

-- Slider on the right of a row. onChange(value 0..1, final: boolean)
function UIKit.Slider(row, initial: number, onChange: (number, boolean) -> ())
	local track = new("TextButton", {
		Name = "Slider",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.fromOffset(230, 18),
		BackgroundColor3 = C(40, 40, 46),
	}, row)
	track:SetAttribute("NoSound", true)
	UIKit.Corner(track, 9)
	UIKit.Stroke(track, 3, UIKit.Colors.Outline, true)
	local fill = new("Frame", { Size = UDim2.fromScale(initial, 1), BackgroundColor3 = C(255, 255, 255) }, track)
	UIKit.Corner(fill, 9)
	gradient(fill, UIKit.Gradients.On)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(initial, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C(245, 245, 250),
	}, track)
	UIKit.Corner(knob, 17)
	UIKit.Stroke(knob, 3, UIKit.Colors.Outline, true)
	local pct = UIKit.Label(row, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -262, 0.5, 0),
		Size = UDim2.fromOffset(70, 34),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, 2.5)

	local value = initial
	local function render()
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		pct.Text = math.floor(value * 100 + 0.5) .. "%"
	end
	render()

	local dragging = false
	local function setFromX(x: number, final: boolean)
		local a, w = track.AbsolutePosition.X, track.AbsoluteSize.X
		value = math.clamp((x - a) / w, 0, 1)
		render()
		onChange(value, final)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X, false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X, false)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			onChange(value, true)
		end
	end)
	return { Set = function(v: number) value = v render() end }
end

-- ===== HUD tile (square menu button on the left) =====
function UIKit.Tile(parent, props, onClick: () -> ())
	local b = new("TextButton", {
		Name = props.Name,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = C(255, 255, 255),
		LayoutOrder = props.Order or 0,
	}, parent)
	if props.Image and props.Image ~= "" then
		-- hand-drawn tile art (icon, colours and caption are all in the image)
		b.BackgroundTransparency = 1
		new("ImageLabel", {
			Name = "Art",
			BackgroundTransparency = 1,
			Image = props.Image,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.12, 1.12),
		}, b)
	else
		UIKit.Corner(b, 20)
		UIKit.Stroke(b, 3.5, UIKit.Colors.Outline, true)
		gradient(b, props.Colors)
		-- glossy top highlight
		local gloss = new("Frame", { Size = UDim2.new(1, -10, 0.42, 0), Position = UDim2.fromOffset(5, 4), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.78 }, b)
		UIKit.Corner(gloss, 16)
		UIKit.Label(b, { Name = "Icon", Text = props.Icon, Size = UDim2.new(1, -18, 1, -26), Position = UDim2.fromOffset(9, 4) }, 0)
		UIKit.Label(b, {
			Name = "Caption",
			Text = props.Text,
			Size = UDim2.new(1, 10, 0, 24),
			Position = UDim2.new(0, -5, 1, -24),
		}, 3)
	end
	local badge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = C(235, 55, 55),
		Visible = false,
		ZIndex = 3,
	}, b)
	UIKit.Corner(badge, 14)
	UIKit.Stroke(badge, 3, UIKit.Colors.Outline, true)
	UIKit.Label(badge, { Text = "!", Size = UDim2.fromScale(1, 0.9), ZIndex = 3 }, 2)
	UIKit.Animate(b, 1.08, -5)
	b.Activated:Connect(onClick)
	return { Button = b, Badge = badge }
end

return UIKit
