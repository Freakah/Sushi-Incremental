-- PrestigeConfig: ⭐ Prestige, the repeatable progression.
--   Exchange your Cash for Prestiges: resets Cash, KG and Cash Upgrades (skills are kept).
--   The more Cash, the more Prestiges, with diminishing returns (square root), so
--   hoarding cash doesn't explode: $30K = 1, $120K = 2, $3M = 10, $30M = 31 (x More Prestiges).
--   Tuned together with the Skill Tree costs (balancing sim): first Prestige ~4 min,
--   Rebirth 1 ~20-25 min in the main area.
--   Prestiges buy the Prestige Upgrades, which boost every area until your next Rebirth.
--   An upgrade with RequiredRebirths stays locked until you reach that Rebirth.
-- Upgrades have the same shape as UpgradeConfig, so the Prestige wall draws them
-- with the shared card code.

local Shared = script.Parent.Parent
local NumberFormat = require(Shared.Util.NumberFormat)

local PrestigeConfig = {}

PrestigeConfig.MinCash = 30000 -- Cash needed to Prestige at all
PrestigeConfig.CashUnit = 30000 -- gain = floor(sqrt(cash / CashUnit) * More Prestiges)

-- Prestiges you'd get for `cash` with a `mult` (More Prestiges etc.) bonus
function PrestigeConfig.Gain(cash: number, mult: number?): number
	if cash < PrestigeConfig.MinCash then return 0 end
	return math.max(1, math.floor(math.sqrt(cash / PrestigeConfig.CashUnit) * (mult or 1) + 1e-6))
end

local function round(n: number): number
	if n < 100 then return math.floor(n + 0.5) end -- whole Prestiges
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1) -- 2 significant figures
	return math.floor(n / magnitude + 0.5) * magnitude
end

local function mult(v) return "x" .. NumberFormat.Format(v) end

-- Level 1 = default; cost to go from level L to L+1 = BaseCost * Growth^(L-1).
PrestigeConfig.List = {
	{
		Id = "CashMulti", Name = "Cash Multi", Icon = "💵", Color = Color3.fromRGB(90, 255, 110),
		Description = "Multiplies the Cash you get",
		Levels = 100, BaseCost = 1, Growth = 1.25,
		Value = function(n) return 1 + n * 0.5 end, -- x1 > x1.5 > ... x51
		Format = mult,
	},
	{
		Id = "MorePrestiges", Name = "More Prestiges", Icon = "⭐", Color = Color3.fromRGB(255, 215, 70),
		Description = "Increases the Prestiges you get per Prestige",
		Levels = 100, BaseCost = 2, Growth = 1.3,
		Value = function(n) return 1 + n * 0.1 end, -- x1 > x1.1 > ... x11
		Format = mult,
	},
	{
		Id = "SushiMulti", Name = "Sushi Multi", Icon = "🍣", Color = Color3.fromRGB(255, 180, 80),
		Description = "Multiplies how much your sushi weighs",
		Levels = 50, BaseCost = 1, Growth = 1.3,
		Value = function(n) return 1 + n * 0.5 end, -- x1 > x1.5 > ... x26
		Format = mult,
	},
	{
		Id = "FishMulti", Name = "Fish Multi", Icon = "🐟", Color = Color3.fromRGB(110, 200, 255),
		Description = "Multiplies the Fish you catch",
		Levels = 50, BaseCost = 3, Growth = 1.3,
		Value = function(n) return 1 + n * 0.5 end, -- x1 > x1.5 > ... x26
		Format = mult,
		RequiredRebirths = 1, -- the Sushi Pond opens at Rebirth 1
	},
}

-- locked teaser cards at the end of the wall (no upgrade behind them yet)
PrestigeConfig.Teasers = {
	{ Icon = "🔒", Title = "Next World", Text = "Unlocks upgrades for the next world!" },
}

PrestigeConfig.ById = {}
for i, u in ipairs(PrestigeConfig.List) do
	u.Order = i
	u.MaxLevel = u.Levels + 1
	u.UnlockAt = 0
	PrestigeConfig.ById[u.Id] = u
end

function PrestigeConfig.GetCost(id: string, level: number): number?
	local u = PrestigeConfig.ById[id]
	if not u or level >= u.MaxLevel then return nil end
	return round(u.BaseCost * u.Growth ^ (level - 1))
end

function PrestigeConfig.GetValue(id: string, level: number?)
	local u = PrestigeConfig.ById[id]
	return u.Value(math.clamp(level or 1, 1, u.MaxLevel) - 1)
end

function PrestigeConfig.AttributeName(id: string): string
	return "PUp_" .. id
end

function PrestigeConfig.IsUnlocked(id: string, totalRebirths: number?): boolean
	local u = PrestigeConfig.ById[id]
	return u ~= nil and (totalRebirths or 0) >= (u.RequiredRebirths or 0)
end

-- every Prestige Upgrade's effect from a { [id] = level } table
function PrestigeConfig.GetBoosts(levels)
	levels = levels or {}
	return {
		Cash = PrestigeConfig.GetValue("CashMulti", levels.CashMulti),
		PrestigeGain = PrestigeConfig.GetValue("MorePrestiges", levels.MorePrestiges),
		KG = PrestigeConfig.GetValue("SushiMulti", levels.SushiMulti),
		Fish = PrestigeConfig.GetValue("FishMulti", levels.FishMulti),
	}
end

return PrestigeConfig
