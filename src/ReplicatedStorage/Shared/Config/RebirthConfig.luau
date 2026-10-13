-- RebirthConfig: Rebirths are big milestones, not a repeatable currency.
-- Each Rebirth costs ⭐ Prestiges, resets your progress (Cash, KG, Cash Upgrades,
-- Prestiges + Prestige Upgrades, Fish + Fish Upgrades) and gives a permanent Cash
-- boost (+2x per Rebirth: x2, x4, x6...) plus that Rebirth's unlocks.
-- Unlocks come from ZoneConfig (a zone with RequiredRebirths = n opens at Rebirth n);
-- extra non-zone unlocks can be listed in RebirthConfig.Extra.

local ZoneConfig = require(script.Parent.ZoneConfig)

local RebirthConfig = {}

RebirthConfig.BaseCost = 25             -- ⭐ Prestiges for Rebirth 1...
RebirthConfig.CostGrowth = 4            -- ...x4 for every Rebirth after that
RebirthConfig.CashPerRebirth = 2        -- +2x Cash per Rebirth
RebirthConfig.IndexBonusPerType = 0.03  -- +3% KG per discovered sushi type
RebirthConfig.CritMultiplier = 3

-- [rebirth] = { { Icon, Text } } shown on the Rebirth board (besides zones)
RebirthConfig.Extra = {}

-- ⭐ Prestiges needed for the NEXT Rebirth when you already have `totalRebirths`
function RebirthConfig.Cost(totalRebirths: number?): number
	return RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ (totalRebirths or 0)
end

-- the permanent Cash multiplier from Rebirths
function RebirthConfig.CashBoost(totalRebirths: number?): number
	local n = totalRebirths or 0
	return if n > 0 then RebirthConfig.CashPerRebirth * n else 1
end

-- what Rebirth `n` unlocks: { { Icon, Text } }
function RebirthConfig.UnlocksAt(n: number)
	local list = {}
	for _, zone in ipairs(ZoneConfig.List) do
		if zone.RequiredRebirths == n and n > 0 and not zone.Unlock then
			table.insert(list, { Icon = zone.Icon, Text = zone.Name })
		end
	end
	for _, e in ipairs(RebirthConfig.Extra[n] or {}) do table.insert(list, e) end
	return list
end

-- long-term multipliers from Rebirths + the Sushi Index, same on server and client
function RebirthConfig.GetMultipliers(totalRebirths: number?, discoveredCount: number?)
	return {
		Cash = RebirthConfig.CashBoost(totalRebirths),
		KG = 1 + (discoveredCount or 0) * RebirthConfig.IndexBonusPerType,
		PrestigeGain = 1,
		Luck = 1,
		HeadStart = 0,
		CritChance = 0,
		AutoInterval = 0,
	}
end

return RebirthConfig
