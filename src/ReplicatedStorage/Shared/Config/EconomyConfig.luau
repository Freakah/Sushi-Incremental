-- EconomyConfig: KG -> Cash conversion tuning.
-- 1 kg = BaseSellRate cash, times your Cash multipliers (Rebirths, Cash Multi, skills...).

local EconomyConfig = {}

EconomyConfig.BaseSellRate = 10 -- $ per 1 kg before multipliers
EconomyConfig.SellRates = { EconomyConfig.BaseSellRate }

EconomyConfig.SellZoneRadius = 11       -- client: panel opens inside this
EconomyConfig.ServerSellRadius = 130    -- server: you can click the market's Sell button from anywhere you can see it
EconomyConfig.SellCooldown = 0.35
EconomyConfig.GuideTrailKG = 5          -- show the trail to the market above this KG...
EconomyConfig.GuideTrailMaxLifetimeCash = 5000 -- ...until the player has earned this much


function EconomyConfig.GetSellRate(level: number): number
	level = math.clamp(math.floor(level or 1), 1, #EconomyConfig.SellRates)
	return EconomyConfig.SellRates[level]
end

-- Cash is kept to cents so tiny sales still count.
function EconomyConfig.RoundCash(n: number): number
	return math.floor(n * 100 + 1e-6) / 100
end

return EconomyConfig
