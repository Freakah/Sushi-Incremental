-- EffectsController: reusable feedback effects (sounds, particle bursts, floating text).

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local player = Players.LocalPlayer
local EffectsController = {}

local soundTemplates: { [string]: Sound } = {}
local fxFolder: Folder
local sfxGroup: SoundGroup

local function makeSound(name: string, id: string, volume: number)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	soundTemplates[name] = s
end

function EffectsController.GetSfxGroup(): SoundGroup
	return sfxGroup
end

function EffectsController.Init()
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "SFX"
	sfxGroup.Volume = 1
	sfxGroup.Parent = SoundService
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = workspace
	makeSound("Collect", GameConfig.Sounds.Collect, 0.55)
	makeSound("UIClick", GameConfig.Sounds.UIClick, 0.5)
	makeSound("UIHover", GameConfig.Sounds.UIHover, 0.25)
	makeSound("RareSpawn", GameConfig.Sounds.RareSpawn, 0.7)
	makeSound("Sell", GameConfig.Sounds.Sell, 0.6)
	makeSound("Upgrade", GameConfig.Sounds.Upgrade, 0.6)
end

function EffectsController.PlaySound(name: string, speed: number?)
	local template = soundTemplates[name]
	if not template then return end
	local s = template:Clone()
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 3)
end

function EffectsController.Burst(position: Vector3, color: Color3, amount: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Position = position
	holder.Parent = fxFolder

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 0.6
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.35, 0.6)
	pe.Speed = NumberRange.new(8, 14)
	pe.Drag = 6
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -10, 0)
	pe.Rate = 0
	pe.Parent = holder
	pe:Emit(amount)
	Debris:AddItem(holder, 1)
end

-- Floating "+0.25 kg" in the world
function EffectsController.FloatingText(position: Vector3, text: string, color: Color3, big: boolean?)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain

	local bb = Instance.new("BillboardGui")
	bb.Adornee = att
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(big and 220 or 150, big and 56 or 40)
	bb.StudsOffset = Vector3.new(0, 1.5, 0)
	bb.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(25, 20, 35)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(bb, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4.2, 0) }):Play()
	local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	Debris:AddItem(bb, 0.9)
	Debris:AddItem(att, 0.9)
end

-- Quick FOV kick for big moments (Epic+ pickups). Stacks safely.
local punchActive = false
function EffectsController.CameraPunch(amount: number)
	local cam = workspace.CurrentCamera
	if not cam or punchActive then return end
	if not require(script.Parent.SettingsState).Get("CameraShake") then return end
	punchActive = true
	local base = cam.FieldOfView
	local out = TweenService:Create(cam, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + amount })
	out:Play()
	out.Completed:Once(function()
		local back = TweenService:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		back:Play()
		back.Completed:Once(function() punchActive = false end)
	end)
end

return EffectsController
