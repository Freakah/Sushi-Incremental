-- SliceConfig: Sushi Slashing's own economy.
--   Every slash that hits the Sushi Boss gives 🍥 Sushi Slices (crits give more).
--   🍥 Slice Upgrades (More Slices / Faster Slashes / Critical Slices / Auto Slash) are bought
--   with Slices on the board in the arena. A Rebirth resets your Slices and Slice Upgrades.
-- Upgrade lists have the same shape as FishConfig / UpgradeConfig, so the world boards draw
-- them with the shared card code.

local Shared = script.Parent.Parent
local NumberFormat = require(Shared.Util.NumberFormat)

local SliceConfig = {}

SliceConfig.BaseCooldown = 0.36  -- seconds between slashes before Faster Slashes (the animation's pace)
SliceConfig.CritChance = 0.05    -- 5% base, multiplied by Critical Slices
SliceConfig.CritMultiplier = 5   -- a critical slash is worth x5 Slices
SliceConfig.AutoInterval = 1     -- Auto Slash: one slash's worth of Slices every second

local function round(n: number): number
	if n < 100 then return math.floor(n + 0.5) end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1) -- 2 significant figures
	return math.floor(n / magnitude + 0.5) * magnitude
end

-- Level 1 = default; cost to go from level L to L+1 = BaseCost * Growth^(L-1).
local function shop(list, attrPrefix: string)
	local s = { List = list, ById = {} }
	for i, u in ipairs(list) do
		u.Order = i
		u.MaxLevel = u.Levels + 1
		u.UnlockAt = 0
		s.ById[u.Id] = u
	end
	function s.GetCost(id: string, level: number): number?
		local u = s.ById[id]
		if not u or level >= u.MaxLevel then return nil end
		return round(u.BaseCost * u.Growth ^ (level - 1))
	end
	function s.GetValue(id: string, level: number?)
		local u = s.ById[id]
		return u.Value(math.clamp(level or 1, 1, u.MaxLevel) - 1)
	end
	function s.AttributeName(id: string): string
		return attrPrefix .. id
	end
	return s
end

local function mult(v) return "x" .. NumberFormat.Format(v) end

-- 🍥 bought with Slices, reset by Rebirth
SliceConfig.Upgrades = shop({
	{
		Id = "SliceAmount", Name = "More Slices", Icon = "🍥", Color = Color3.fromRGB(255, 140, 170),
		Description = "Increase the Slices you get from every slash",
		Levels = 100, BaseCost = 15, Growth = 1.09,
		Value = function(n) return 1 + n end, -- 1 > 2 > ... 101 slices per slash
		Format = function(v) return "+" .. NumberFormat.Format(v) end,
	},
	{
		Id = "SliceSpeed", Name = "Faster Slashes", Icon = "⚡", Color = Color3.fromRGB(255, 225, 90),
		Description = "Slash faster (less time between slashes)",
		Levels = 6, BaseCost = 40, Growth = 2.6,
		Value = function(n) return SliceConfig.BaseCooldown - n * 0.03 end, -- 0.36s > 0.33s > ... 0.18s
		Format = function(v) return string.format("%.2fs", v) end,
	},
	{
		Id = "SliceCrit", Name = "Critical Slices", Icon = "💥", Color = Color3.fromRGB(255, 120, 90),
		Description = "Higher chance for a Critical slash (x5 Slices)",
		Levels = 15, BaseCost = 60, Growth = 1.5,
		Value = function(n) return 1 + n * 0.5 end, -- x1 > x1.5 > ... x8.5 crit chance (5% > 42.5%)
		Format = mult,
	},
	{
		Id = "AutoSlash", Name = "Auto Slash", Icon = "🤖", Color = Color3.fromRGB(190, 150, 255),
		Description = "Earns Slices for you, even away from the arena",
		Levels = 1, BaseCost = 1000, Growth = 1,
		Value = function(n) return n end, -- 0 = off, 1 = on (always on once bought)
		Format = function(v) return v > 0 and "On" or "Off" end,
	},
}, "SliceUp_")

-- everything a slash needs, from the Slice Upgrade levels
function SliceConfig.GetStats(levels)
	levels = levels or {}
	local up = SliceConfig.Upgrades
	return {
		Amount = up.GetValue("SliceAmount", levels.SliceAmount),
		Cooldown = up.GetValue("SliceSpeed", levels.SliceSpeed),
		CritChance = math.min(1, SliceConfig.CritChance * up.GetValue("SliceCrit", levels.SliceCrit)),
		Auto = up.GetValue("AutoSlash", levels.AutoSlash) > 0,
	}
end

-- from a player's replicated attributes (client side: animation pace, previews)
function SliceConfig.StatsFromAttributes(plr: Player)
	local levels = {}
	for _, u in ipairs(SliceConfig.Upgrades.List) do
		levels[u.Id] = plr:GetAttribute(SliceConfig.Upgrades.AttributeName(u.Id))
	end
	return SliceConfig.GetStats(levels)
end

return SliceConfig
