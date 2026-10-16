-- SettingsConfig: every player setting, in menu order. Saved with player data.
-- Kind "Toggle" = boolean, "Slider" = number 0..1.

local SettingsConfig = {}

SettingsConfig.List = {
	{ Key = "ReduceMotion", Name = "Reduce Motion", Icon = "◉", Kind = "Toggle", Default = false },
	{ Key = "Music", Name = "Music", Icon = "🎵", Kind = "Toggle", Default = true },
	{ Key = "SFX", Name = "SFX", Icon = "🔊", Kind = "Toggle", Default = true },
	{ Key = "Volume", Name = "Volume", Icon = "🎚️", Kind = "Slider", Default = 0.8 },
	{ Key = "PickupPopups", Name = "Pickup Popups", Icon = "❗", Kind = "Toggle", Default = true },
	{ Key = "HideOthers", Name = "Hide Other Players", Icon = "👤", Kind = "Toggle", Default = false },
	{ Key = "NightMode", Name = "Night Mode", Icon = "🌙", Kind = "Toggle", Default = false },
	{ Key = "Particles", Name = "Particles", Icon = "✨", Kind = "Toggle", Default = true },
	{ Key = "CameraShake", Name = "Camera Shake", Icon = "📷", Kind = "Toggle", Default = true },
	{ Key = "SavePosition", Name = "Save Last Position", Icon = "💾", Kind = "Toggle", Default = true },
	{ Key = "AutoBuy", Name = "Auto Buy (Ascension)", Icon = "🤖", Kind = "Toggle", Default = true },
}

SettingsConfig.ByKey = {}
for i, s in ipairs(SettingsConfig.List) do
	s.Order = i
	SettingsConfig.ByKey[s.Key] = s
end

function SettingsConfig.AttributeName(key: string): string
	return "Set_" .. key
end

-- Returns a sanitised value, or nil if it isn't valid for that setting
function SettingsConfig.Validate(key: any, value: any): any
	local s = typeof(key) == "string" and SettingsConfig.ByKey[key]
	if not s then return nil end
	if s.Kind == "Toggle" then
		return if typeof(value) == "boolean" then value else nil
	elseif s.Kind == "Slider" then
		if typeof(value) ~= "number" or value ~= value then return nil end
		return math.clamp(math.floor(value * 100 + 0.5) / 100, 0, 1)
	end
	return nil
end

return SettingsConfig
