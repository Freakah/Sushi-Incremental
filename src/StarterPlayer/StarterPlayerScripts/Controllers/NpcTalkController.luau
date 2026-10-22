-- NpcTalkController: "Talk" prompt on NPCs tagged TalkNPC (CollectionService).
-- The NPC model's TalkLine attribute is typed out above its head, letter by letter, with a blip per letter.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local EffectsController = require(script.Parent:WaitForChild("EffectsController"))

local player = Players.LocalPlayer
local NpcTalkController = {}

local CHAR_DELAY = 0.045
local HOLD_TIME = 2.5

local function say(npc: Model, prompt: ProximityPrompt)
	local head = npc:FindFirstChild("Head") or npc.PrimaryPart
	local text = npc:GetAttribute("TalkLine") or "..."
	prompt.Enabled = false

	local bb = Instance.new("BillboardGui")
	bb.Name = "TalkBubble"
	bb.Adornee = head
	bb.Size = UDim2.fromScale(12, 3) -- studs, so it scales with distance like world text
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true -- the apple tree's leaves hang over his head
	bb.MaxDistance = 80
	bb.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 16, 28)
	stroke.Parent = label

	for i = 1, utf8.len(text) or #text do
		label.MaxVisibleGraphemes = i
		if not string.sub(text, i, i):match("%s") then
			EffectsController.PlaySound("UIHover", 0.9 + math.random() * 0.3)
		end
		task.wait(CHAR_DELAY)
	end

	task.wait(HOLD_TIME)
	local fade = TweenInfo.new(0.3)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.wait(0.3)
	bb:Destroy()
	prompt.Enabled = true
end

local function register(npc: Instance)
	if not npc:IsA("Model") then return end
	local root = npc:WaitForChild("HumanoidRootPart", 10) or npc.PrimaryPart
	if not root then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		task.spawn(say, npc, prompt)
	end)
end

function NpcTalkController.Init()
	for _, npc in ipairs(CollectionService:GetTagged("TalkNPC")) do
		task.spawn(register, npc)
	end
	CollectionService:GetInstanceAddedSignal("TalkNPC"):Connect(register)
end

return NpcTalkController
