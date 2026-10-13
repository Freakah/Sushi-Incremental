-- FishConfig: the Sushi Pond's own economy.
--   Stand on the Fishing Pad (end of the dock) to catch 🐟 Fish every few seconds.
--   🐟 Fish Upgrades (More Fish / Faster Fish / Fish Luck / Auto Fish) are bought with Fish.
--   Fish Multi (a ⭐ Prestige Upgrade) multiplies every catch; a Rebirth resets
--   your Fish and Fish Upgrades.
-- Upgrade lists have the same shape as UpgradeConfig, so the world boards draw them
-- with the shared card code.

local Shared = script.Parent.Parent
local NumberFormat = require(Shared.Util.NumberFormat)

local FishConfig = {}

FishConfig.PadRadius = 3.8          -- studs from the pad's centre that count as standing on it
FishConfig.BaseInterval = 1         -- seconds per catch before Faster Fish
FishConfig.GoldenChance = 0.02      -- 2% base, multiplied by Fish Luck
FishConfig.GoldenMultiplier = 5     -- a golden fish is worth x5

local function round(n: number): number
	if n < 100 then return math.floor(n + 0.5) end -- whole fish
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1) -- 2 significant figures
	return math.floor(n / magnitude + 0.5) * magnitude
end

-- one shop (a board's worth of upgrades). Level 1 = default; cost to go from
-- level L to L+1 = BaseCost * Growth^(L-1).
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

-- 🐟 bought with Fish, reset by Rebirth
FishConfig.Upgrades = shop({
	{
		Id = "FishAmount", Name = "More Fish", Icon = "🐟", Color = Color3.fromRGB(110, 200, 255),
		Description = "Increase the amount of Fish you receive",
		Levels = 100, BaseCost = 15, Growth = 1.09,
		Value = function(n) return 1 + n end, -- 1 > 2 > ... 101 fish per catch
		Format = function(v) return "+" .. NumberFormat.Format(v) end,
	},
	{
		Id = "FishSpeed", Name = "Faster Fish", Icon = "⚡", Color = Color3.fromRGB(255, 225, 90),
		Description = "Decreases the time it takes to receive Fish",
		Levels = 9, BaseCost = 40, Growth = 2.4,
		Value = function(n) return math.max(0.1, FishConfig.BaseInterval - n * 0.1) end, -- 1s > 0.9s > ... 0.1s
		Format = function(v) return NumberFormat.Format(v) .. "s" end,
	},
	{
		Id = "FishLuck", Name = "Fish Luck", Icon = "🌟", Color = Color3.fromRGB(255, 200, 60),
		Description = "Gives you a higher chance to get a Golden Fish",
		Levels = 20, BaseCost = 60, Growth = 1.45,
		Value = function(n) return 1 + n end, -- x1 > x2 > ... x21 golden chance
		Format = mult,
	},
	{
		Id = "AutoFish", Name = "Auto Fish", Icon = "🎣", Color = Color3.fromRGB(150, 210, 255),
		Description = "Catches Fish for you, even away from the pad",
		Levels = 1, BaseCost = 1000, Growth = 1,
		Value = function(n) return n end, -- 0 = off, 1 = on (always on once bought)
		Format = function(v) return v > 0 and "On" or "Off" end,
	},
}, "FishUp_")

-- everything a catch needs: the Fish Upgrade levels + the Fish Multi (Prestige Upgrade)
function FishConfig.GetStats(fishLevels, fishMulti: number?)
	fishLevels = fishLevels or {}
	local up = FishConfig.Upgrades
	return {
		Amount = up.GetValue("FishAmount", fishLevels.FishAmount),
		Interval = up.GetValue("FishSpeed", fishLevels.FishSpeed),
		GoldenChance = math.min(1, FishConfig.GoldenChance * up.GetValue("FishLuck", fishLevels.FishLuck)),
		Multiplier = fishMulti or 1,
		Auto = up.GetValue("AutoFish", fishLevels.AutoFish) > 0, -- keep catching away from the pad
	}
end

return FishConfig
