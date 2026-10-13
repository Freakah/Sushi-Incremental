-- UpgradeConfig: the 💵 Cash Upgrades (reset on every Prestige and Rebirth).
-- Level 1 = the free starting value; a card shows (level-1)/(MaxLevel-1), e.g. 0/49.
-- Cost to go from level L to L+1 = BaseCost * Growth^(L-1).
-- Progression rates are taken from the reference game.

local Shared = script.Parent.Parent
local NumberFormat = require(Shared.Util.NumberFormat)

local UpgradeConfig = {}

UpgradeConfig.List = {
	{
		Id = "SushiValue", Stat = "ValueMultiplier",
		Name = "Sushi Value", Icon = "🍣", Color = Color3.fromRGB(90, 255, 110),
		Description = "Every sushi weighs more KG",
		Levels = 49, BaseCost = 2, Growth = 1.6,
		Value = function(n) return 1 + n end, -- x1 > x2 > ... x50
		Format = function(v) return "x" .. NumberFormat.Format(v) end,
	},
	{
		Id = "Capacity", Stat = "Capacity",
		Name = "Sushi Capacity", Icon = "🍚", Color = Color3.fromRGB(255, 190, 90),
		Description = "More sushi can sit on the pad at once",
		Levels = 24, BaseCost = 3, Growth = 5,
		Value = function(n) return 5 + n * 2 end, -- 5 > 7 > ... 53
		Format = function(v) return tostring(v) end,
	},
	{
		Id = "SpawnSpeed", Stat = "SpawnInterval",
		Name = "Spawn Speed", Icon = "⏱️", Color = Color3.fromRGB(110, 200, 255),
		Description = "New sushi appear faster",
		Levels = 10, BaseCost = 3, Growth = 1.8,
		Value = function(n) return math.max(0.1, 2 - n * 0.2) end, -- 2s > 1.8s > ... instant
		Format = function(v) return NumberFormat.Format(v) .. "s" end,
	},
}

UpgradeConfig.ById = {}
for i, u in ipairs(UpgradeConfig.List) do
	u.Order = i
	u.MaxLevel = u.Levels + 1
	u.UnlockAt = 0
	UpgradeConfig.ById[u.Id] = u
end

local function round(n: number): number
	if n < 100 then return math.floor(n * 100 + 0.5) / 100 end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 2) -- 3 significant figures
	return math.floor(n / magnitude + 0.5) * magnitude
end

function UpgradeConfig.GetCost(upgradeId: string, level: number): number?
	local u = UpgradeConfig.ById[upgradeId]
	if not u or level >= u.MaxLevel then return nil end
	return round(u.BaseCost * u.Growth ^ (level - 1))
end

function UpgradeConfig.GetValue(upgradeId: string, level: number)
	local u = UpgradeConfig.ById[upgradeId]
	return u.Value(math.clamp(level, 1, u.MaxLevel) - 1)
end

function UpgradeConfig.AttributeName(upgradeId: string): string
	return "Up_" .. upgradeId
end

return UpgradeConfig
