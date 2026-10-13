-- SettingsController: the ⚙️ Settings menu, plus the settings that don't
-- belong to another system (Hide Other Players, Particles).
-- Music/SFX/Volume -> AudioController, Night Mode -> ZoneController,
-- Pickup Popups -> SushiController, Camera Shake -> EffectsController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local SettingsState = require(script.Parent.SettingsState)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local SettingsController = {}

local window
local controls = {}

-- ===== Hide Other Players =====

local function setCharacterHidden(character: Model, hidden: boolean)
	local ltm = hidden and 1 or 0
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = ltm
		end
	end
	-- (the default Roblox name stays off; NametagController hides our "@Name [Title]" tag)
end

local function applyHideOthers()
	local hidden = SettingsState.Get("HideOthers")
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then setCharacterHidden(p.Character, hidden) end
	end
end

-- ===== Particles =====

local hiddenEmitters = setmetatable({}, { __mode = "k" })

local function setEmitter(pe: Instance, on: boolean)
	if not pe:IsA("ParticleEmitter") then return end
	if on then
		if hiddenEmitters[pe] then pe.Enabled = true hiddenEmitters[pe] = nil end
	elseif pe.Enabled then
		pe.Enabled = false
		hiddenEmitters[pe] = true
	end
end

local function applyParticles()
	local on = SettingsState.Get("Particles")
	for _, root in ipairs({ workspace:FindFirstChild("Map"), workspace:FindFirstChild("MySushi") }) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do setEmitter(d, on) end
		end
	end
	local petals = workspace:FindFirstChild("Petals")
	if petals then
		for _, p in ipairs(petals:GetChildren()) do p.Transparency = on and 0 or 1 end
	end
end

-- ===== menu =====

local function build()
	window = UIKit.Window({ Name = "Settings", Title = "Settings", Icon = "⚙️", Size = Vector2.new(640, 720) })
	local list = UIKit.List(window.Body, 10)
	for _, s in ipairs(SettingsConfig.List) do
		local row = UIKit.Row(list, s.Icon, s.Name, s.Order)
		if s.Kind == "Toggle" then
			controls[s.Key] = UIKit.Toggle(row, SettingsState.Get(s.Key), function(v)
				SettingsState.Set(s.Key, v)
			end)
		else
			controls[s.Key] = UIKit.Slider(row, SettingsState.Get(s.Key), function(v, final)
				SettingsState.Set(s.Key, v, final) -- live preview, save when released
			end)
		end
	end
	-- keep the menu in sync if a value arrives from the server later
	SettingsState.Changed:Connect(function(key, value)
		local c = controls[key]
		if c then c.Set(value) end
	end)
end

function SettingsController.Toggle() window.Toggle() end
function SettingsController.Open() window.Open() end
function SettingsController.Close() window.Close() end

function SettingsController.Init()
	build()
	SettingsState.Changed:Connect(function(key)
		if key == "HideOthers" then applyHideOthers()
		elseif key == "Particles" then applyParticles() end
	end)
	-- new characters / new sushi pick up the current settings
	local function hookPlayer(p: Player)
		if p == player then return end
		p.CharacterAdded:Connect(function(character)
			task.wait(1) -- let accessories load
			if SettingsState.Get("HideOthers") then setCharacterHidden(character, true) end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
	Players.PlayerAdded:Connect(hookPlayer)
	task.spawn(function()
		local sushi = workspace:WaitForChild("MySushi", 30)
		if sushi then
			sushi.DescendantAdded:Connect(function(d)
				if not SettingsState.Get("Particles") then setEmitter(d, false) end
			end)
		end
	end)
	task.delay(2, function()
		applyHideOthers()
		applyParticles()
	end)
end

return SettingsController
