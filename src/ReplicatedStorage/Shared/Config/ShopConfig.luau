-- ShopConfig: Robux game passes (permanent perks) and developer products (one-off packs).
--
-- TO GO LIVE: create each pass / product on the Roblox Creator Dashboard
-- (your experience -> Monetization -> Passes / Developer Products), then paste its
-- ID into `Id` below. Items with Id = 0 show in the shop as "Coming soon".
-- `Price` is only a fallback label; the real Robux price is read from Roblox.

local ShopConfig = {}

ShopConfig.Passes = {
	{ Key = "DoubleCash", Name = "2x Cash", Icon = "💵", Desc = "Double all Cash, forever", Id = 0, Price = 199,
		Perks = { Cash = 2 } },
	{ Key = "DoubleSushi", Name = "2x Sushi Value", Icon = "🍣", Desc = "Every sushi weighs double", Id = 0, Price = 149,
		Perks = { KG = 2 } },
	{ Key = "Lucky", Name = "Lucky Chef", Icon = "🍀", Desc = "x1.5 Luck for sushi", Id = 0, Price = 249,
		Perks = { Luck = 1.5 } },
	{ Key = "VIP", Name = "VIP", Icon = "👑", Desc = "x1.25 Cash & Sushi, VIP title, gold name", Id = 0, Price = 399,
		Perks = { Cash = 1.25, KG = 1.25 } },
}

-- Grant: Boost = { Stat, Seconds }
ShopConfig.Products = {
	{ Key = "CashBoost", Name = "Cash Rush", Icon = "⏱️", Desc = "x2 Cash for 15 minutes", Id = 0, Price = 39,
		Grant = { Boost = { "Cash", 900 } } },
	{ Key = "LuckBoost", Name = "Lucky Hour", Icon = "🍀", Desc = "x2 Luck for 15 minutes", Id = 0, Price = 39,
		Grant = { Boost = { "Luck", 900 } } },
}

ShopConfig.PassByKey, ShopConfig.PassById = {}, {}
for _, p in ipairs(ShopConfig.Passes) do
	ShopConfig.PassByKey[p.Key] = p
	if p.Id ~= 0 then ShopConfig.PassById[p.Id] = p end
end
ShopConfig.ProductByKey, ShopConfig.ProductById = {}, {}
for _, p in ipairs(ShopConfig.Products) do
	ShopConfig.ProductByKey[p.Key] = p
	if p.Id ~= 0 then ShopConfig.ProductById[p.Id] = p end
end

-- owned = { [passKey] = true }, boosts = { [stat] = endTime (os.time) }
function ShopConfig.GetPerks(owned, boosts, now: number)
	local e = { Cash = 1, KG = 1, Luck = 1 }
	for key in pairs(owned or {}) do
		local p = ShopConfig.PassByKey[key]
		if p then
			for k, v in pairs(p.Perks) do e[k] *= v end
		end
	end
	for stat, endTime in pairs(boosts or {}) do
		if endTime > now and e[stat] then e[stat] *= 2 end
	end
	return e
end

function ShopConfig.PassAttr(key: string) return "Pass_" .. key end
function ShopConfig.BoostAttr(stat: string) return "BoostEnd_" .. stat end

return ShopConfig
