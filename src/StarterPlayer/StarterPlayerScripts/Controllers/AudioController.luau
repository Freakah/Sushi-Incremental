-- AudioController: background music playlist, UI hover/click sounds on every
-- button, and applying the Music / SFX / Volume settings.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EffectsController = require(script.Parent.EffectsController)
local SettingsState = require(script.Parent.SettingsState)

local player = Players.LocalPlayer
local AudioController = {}

function AudioController.PlayUI(cue: string)
	if SettingsState.Get("SFX") == false then return end
	local theme = require(script.Parent.UIKit).Theme
	local speeds = { Close = 0.85, Error = 0.55, Open = 1.1 }
	EffectsController.PlaySound(theme.Sounds[cue] or "UIClick", speeds[cue])
end

local musicGroup: SoundGroup
local music: Sound
local playlist = {}
local trackIndex = 0

local function shuffle()
	playlist = table.clone(GameConfig.Music)
	for i = #playlist, 2, -1 do
		local j = math.random(1, i)
		playlist[i], playlist[j] = playlist[j], playlist[i]
	end
	trackIndex = 0
end

local function playNext()
	if #GameConfig.Music == 0 then return end
	trackIndex += 1
	if trackIndex > #playlist then shuffle(); trackIndex = 1 end
	music.SoundId = playlist[trackIndex]
	music.Volume = 0
	music:Play()
	TweenService:Create(music, TweenInfo.new(3), { Volume = GameConfig.MusicVolume }):Play()
end

-- ===== UI sounds on every button, including ones created later =====

local hooked = setmetatable({}, { __mode = "k" })
local lastHover = 0

local function hookButton(b: Instance)
	if not b:IsA("GuiButton") or hooked[b] or b:GetAttribute("NoSound") then return end
	hooked[b] = true
	b.MouseEnter:Connect(function()
		if os.clock() - lastHover > 0.06 then
			lastHover = os.clock()
			if not b:GetAttribute("Disabled") and not b:GetAttribute("NoSound") then AudioController.PlayUI("Hover") end
		end
	end)
	b.Activated:Connect(function()
		if not b:GetAttribute("Disabled") and not b:GetAttribute("NoSound") then AudioController.PlayUI("Click") end
	end)
end

function AudioController.Init()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = 1
	musicGroup.Parent = SoundService

	music = Instance.new("Sound")
	music.Name = "BackgroundMusic"
	music.SoundGroup = musicGroup
	music.Parent = SoundService
	music.Ended:Connect(playNext)
	shuffle()
	playNext()

	-- volumes follow the Settings menu (Music / SFX / Volume)
	local function applyVolumes()
		local master = SettingsState.Get("Volume")
		TweenService:Create(musicGroup, TweenInfo.new(0.3), { Volume = (SettingsState.Get("Music") and 1 or 0) * master }):Play()
		EffectsController.GetSfxGroup().Volume = (SettingsState.Get("SFX") and 1 or 0) * master
	end
	SettingsState.Changed:Connect(function(key)
		if key == "Music" or key == "SFX" or key == "Volume" then applyVolumes() end
	end)
	applyVolumes()

	local playerGui = player:WaitForChild("PlayerGui")
	for _, d in ipairs(playerGui:GetDescendants()) do hookButton(d) end
	playerGui.DescendantAdded:Connect(hookButton)
end

return AudioController
