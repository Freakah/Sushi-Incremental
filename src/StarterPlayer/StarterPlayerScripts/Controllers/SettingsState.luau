-- SettingsState: the local player's settings. Values come from the server (saved
-- with player data, mirrored to "Set_<Key>" attributes); changes apply locally
-- straight away and are sent to the server to be saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)

local player = Players.LocalPlayer
local SettingsState = {}

local values = {}
local changedEvent = Instance.new("BindableEvent")
SettingsState.Changed = changedEvent.Event -- (key, value)

function SettingsState.Get(key: string): any
	local v = values[key]
	if v == nil then v = player:GetAttribute(SettingsConfig.AttributeName(key)) end
	if v == nil then
		local s = SettingsConfig.ByKey[key]
		v = s and s.Default
	end
	return v
end

-- save = false lets sliders update live and only save on release
function SettingsState.Set(key: string, value: any, save: boolean?)
	local clean = SettingsConfig.Validate(key, value)
	if clean == nil then return end
	if values[key] ~= clean then
		values[key] = clean
		changedEvent:Fire(key, clean)
	end
	if save ~= false then
		ReplicatedStorage.Remotes.SetSetting:FireServer(key, clean)
	end
end

-- server-loaded values arrive as attributes (on join)
for _, s in ipairs(SettingsConfig.List) do
	player:GetAttributeChangedSignal(SettingsConfig.AttributeName(s.Key)):Connect(function()
		local v = player:GetAttribute(SettingsConfig.AttributeName(s.Key))
		if v ~= nil and values[s.Key] ~= v then
			values[s.Key] = v
			changedEvent:Fire(s.Key, v)
		end
	end)
end

return SettingsState
