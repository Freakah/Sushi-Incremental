-- AscensionController: the Blood Altar in the Blood Rift.
-- * walking up onto the altar shows a confirm panel (what resets, what you keep, the reward)
-- * confirming plays the Ascension: the screen floods red, fades to black with
--   "ASCENDED", the server sends you home, and the screen fades back in at the spawn
-- * while you're in the Blood Rift the watcher and shards bob and the runes pulse

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AscensionConfig = require(ReplicatedStorage.Shared.Config.AscensionConfig)
local EffectsController = require(script.Parent.EffectsController)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local AscensionController = {}

local C = Color3.fromRGB
local FONT = Enum.Font.FredokaOne
local RED = C(255, 70, 70)
local DARK = C(20, 6, 9)
local GOOD = C(140, 255, 150)
local BAD = C(255, 150, 150)

local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local overlay: Frame
local bigText: TextLabel
local subText: TextLabel
local ui: any = {}
local open = false
local busy = false
local dismissedUntil = 0

local function new(class: string, props, parent: Instance?)
	local inst = Instance.new(class)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function stroke(parent, thickness: number, color: Color3?)
	return new("UIStroke", { Thickness = thickness, Color = color or C(10, 0, 2), LineJoinMode = Enum.LineJoinMode.Round }, parent)
end

local function label(parent, props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextScaled = true, RichText = true, TextColor3 = C(255, 255, 255) }, parent)
	for k, v in pairs(props) do (t :: any)[k] = v end
	stroke(t, 2)
	return t
end

local function button(parent, text: string, colorA: Color3, colorB: Color3, props, onClick)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C(255, 255, 255) }, parent)
	for k, v in pairs(props) do (b :: any)[k] = v end
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	local s = stroke(b, 3)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(colorA, colorB) }, b)
	label(b, { Text = text, Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6) })
	local sc = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.06 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	b.Activated:Connect(onClick)
	return b
end

local function altar(): Model?
	local map = workspace:FindFirstChild("Map")
	local realm = map and map:FindFirstChild("AscensionRealm")
	return realm and realm:FindFirstChild("BloodAltar") :: Model?
end

local function canAscend(): boolean
	return AscensionConfig.CanAscend(function(id) return player:GetAttribute("T_" .. id) == true end)
end

-- ===== confirm panel =====

local function buildPanel()
	panel = new("Frame", {
		Name = "AscendPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 330), BackgroundColor3 = C(30, 8, 12), BackgroundTransparency = 0.05, Visible = false,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 24) }, panel)
	local ps = stroke(panel, 4, C(170, 25, 35))
	ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelScale = new("UIScale", {}, panel)
	label(panel, { Text = "🩸 ASCEND? 🩸", TextColor3 = RED, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 42) })
	ui.Lose = label(panel, { Position = UDim2.fromOffset(24, 66), Size = UDim2.new(1, -48, 0, 44), TextWrapped = true,
		Text = '<font color="#FF9696">You lose:</font> Cash, Sushi KG, Cash Upgrades and your Skill Tree' })
	ui.Keep = label(panel, { Position = UDim2.fromOffset(24, 114), Size = UDim2.new(1, -48, 0, 44), TextWrapped = true,
		Text = '<font color="#8CFF96">You keep:</font> Rebirths, Prestiges, Automation and your Index' })
	ui.Reward = label(panel, { Position = UDim2.fromOffset(24, 166), Size = UDim2.new(1, -48, 0, 34), TextColor3 = C(255, 215, 120) })
	ui.Lock = label(panel, { Position = UDim2.fromOffset(24, 204), Size = UDim2.new(1, -48, 0, 24), TextColor3 = BAD, Visible = false })
	ui.Yes = button(panel, "ASCEND", C(255, 90, 90), C(190, 20, 35), { Position = UDim2.new(0.5, -190, 1, -84), Size = UDim2.fromOffset(200, 60) }, function()
		AscensionController.Ascend()
	end)
	button(panel, "Not yet", C(120, 110, 120), C(80, 70, 82), { Position = UDim2.new(0.5, 24, 1, -84), Size = UDim2.fromOffset(166, 60) }, function()
		dismissedUntil = os.clock() + 6
		AscensionController.SetOpen(false)
	end)
end

function AscensionController.SetOpen(want: boolean)
	if want == open then return end
	open = want
	if want then
		local next = (player:GetAttribute("Ascensions") or 0) + 1
		ui.Reward.Text = "Reward: +1 ✨ Ascension Point  (Ascension #" .. next .. ")"
		local ok = canAscend()
		ui.Lock.Visible = not ok
		ui.Lock.Text = "🔒 You need " .. AscensionConfig.RequiredNodeName .. " in the Skill Tree"
		ui.Yes.Visible = ok
		panel.Visible = true
		local vp = workspace.CurrentCamera.ViewportSize
		local base = math.clamp(math.min(vp.X / 1300, vp.Y / 800), 0.7, 1.1)
		panelScale.Scale = base * 0.6
		TweenService:Create(panelScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
		EffectsController.PlaySound("RareSpawn", 0.5)
	else
		panel.Visible = false
	end
end

-- ===== the Ascension itself =====

function AscensionController.Ascend()
	if busy then return end
	busy = true
	AscensionController.SetOpen(false)
	local ok, count = Remotes.RequestAscend:InvokeServer()
	if not ok then
		busy = false
		return
	end
	EffectsController.PlaySound("Upgrade", 0.6)
	EffectsController.CameraPunch(8)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then EffectsController.Burst(root.Position, RED, 60) end
	-- flood the screen red, then black with the title
	overlay.Visible = true
	overlay.BackgroundColor3 = C(255, 40, 40)
	overlay.BackgroundTransparency = 1
	bigText.TextTransparency = 1
	subText.TextTransparency = 1
	bigText.Text = "✨ ASCENDED ✨"
	subText.Text = "Ascension #" .. tostring(count) .. "  •  +1 Ascension Point"
	TweenService:Create(overlay, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
	task.wait(1.1)
	TweenService:Create(overlay, TweenInfo.new(0.8), { BackgroundColor3 = C(10, 0, 3) }):Play()
	TweenService:Create(bigText, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	task.delay(0.3, function() TweenService:Create(subText, TweenInfo.new(0.6), { TextTransparency = 0 }):Play() end)
	-- wait for the server to send us home
	local t0 = os.clock()
	repeat task.wait(0.1) until player:GetAttribute("Zone") ~= "Ascension" or os.clock() - t0 > 6
	task.wait(0.3)
	require(script.Parent.ZoneController).FaceForward()
	task.wait(0.6)
	local out = TweenInfo.new(1.2)
	TweenService:Create(overlay, out, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(bigText, out, { TextTransparency = 1 }):Play()
	TweenService:Create(subText, out, { TextTransparency = 1 }):Play()
	task.wait(1.25)
	overlay.Visible = false
	busy = false
end

-- ===== per frame =====

local floating: { { Part: BasePart, Base: CFrame, Phase: number } } = {}
local glow: { BasePart } = {}
local cached = false

local function cacheAltar(a: Model)
	cached = true
	local f = a:FindFirstChild("Floating")
	if f then
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") then
				local phase = string.find(p.Name, "shard") and (p.Position.Y * 0.7) or 0
				table.insert(floating, { Part = p, Base = p.CFrame, Phase = phase })
			end
		end
	end
	local g = a:FindFirstChild("Glow")
	if g then
		for _, p in ipairs(g:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.3 then table.insert(glow, p) end
		end
	end
end

local function step()
	local inRift = player:GetAttribute("Zone") == "Ascension"
	local a = inRift and altar() or nil
	if not a then
		if open then AscensionController.SetOpen(false) end
		return
	end
	if not cached then cacheAltar(a) end
	local now = os.clock()
	-- the watcher and its shards drift; runes breathe
	for _, f in ipairs(floating) do
		f.Part.CFrame = f.Base + Vector3.new(0, math.sin(now * 1.3 + f.Phase) * 0.35, 0)
	end
	local pulse = 0.15 + (math.sin(now * 2.2) * 0.5 + 0.5) * 0.25
	for _, p in ipairs(glow) do p.Transparency = pulse end
	-- on the altar? show the confirm panel
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or busy then return end
	local pivot = a:GetPivot().Position
	local off = root.Position - pivot
	local onTop = Vector3.new(off.X, 0, off.Z).Magnitude <= AscensionConfig.AltarRadius and off.Y > 3
	if onTop and not open and os.clock() > dismissedUntil then
		AscensionController.SetOpen(true)
	elseif not onTop and open then
		AscensionController.SetOpen(false)
	end
end

function AscensionController.Init()
	gui = new("ScreenGui", { Name = "Ascension", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))
	overlay = new("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, gui)
	bigText = label(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.6, 0.1), TextColor3 = C(255, 90, 90), TextTransparency = 1, ZIndex = 11 })
	subText = label(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.45, 0.045), TextColor3 = C(255, 215, 150), TextTransparency = 1, ZIndex = 11 })
	buildPanel()
	RunService.RenderStepped:Connect(step)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not open then return end
		if input.KeyCode == Enum.KeyCode.ButtonA and ui.Yes.Visible then AscensionController.Ascend() end
		if input.KeyCode == Enum.KeyCode.ButtonB then
			dismissedUntil = os.clock() + 6
			AscensionController.SetOpen(false)
		end
	end)
end

return AscensionController
