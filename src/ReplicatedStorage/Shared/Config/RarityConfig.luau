-- RarityConfig: every sushi rarity, its odds, KG range and look.
-- Weight = relative chance at Luck 1. LuckPower controls how much Luck boosts it
-- (weight * Luck ^ LuckPower), so luck upgrades favour the rarest tiers most.

local RarityConfig = {}

RarityConfig.List = {
	{
		Id = "Common", Order = 1, Weight = 70, LuckPower = 0,
		MinKG = 0.1, MaxKG = 0.5,
		Color = Color3.fromRGB(200, 205, 215), Scale = 1.0,
		Ring = false, Light = false, Particles = false, Highlight = false,
	},
	{
		Id = "Uncommon", Order = 2, Weight = 20, LuckPower = 0.5,
		MinKG = 0.5, MaxKG = 1.2,
		Color = Color3.fromRGB(90, 220, 110), Scale = 1.1,
		Ring = true, Light = false, Particles = false, Highlight = false,
	},
	{
		Id = "Rare", Order = 3, Weight = 7, LuckPower = 1,
		MinKG = 1.2, MaxKG = 3,
		Color = Color3.fromRGB(70, 160, 255), Scale = 1.2,
		Ring = true, Light = true, Particles = false, Highlight = false,
	},
	{
		Id = "Epic", Order = 4, Weight = 2.4, LuckPower = 1.3,
		MinKG = 3, MaxKG = 7,
		Color = Color3.fromRGB(180, 90, 255), Scale = 1.35,
		Ring = true, Light = true, Particles = true, Highlight = true,
	},
	{
		-- Golden Salmon Maki: ~1 in 13 spawns at Luck 1
		Id = "Legendary", Order = 5, Weight = 6, LuckPower = 0.6,
		MinKG = 2, MaxKG = 5,
		Color = Color3.fromRGB(255, 196, 40), Scale = 1.55,
		Ring = true, Light = true, Particles = true, Highlight = true,
	},
	{
		Id = "Mythic", Order = 6, Weight = 0.09, LuckPower = 2,
		MinKG = 15, MaxKG = 40,
		Color = Color3.fromRGB(255, 70, 120), Scale = 1.8,
		Ring = true, Light = true, Particles = true, Highlight = true,
	},
	{
		-- Diamond Salmon Maki: ~1 in 50 spawns at Luck 1, ~50x a common's KG
		Id = "Secret", Order = 7, Weight = 1.5, LuckPower = 0.8,
		MinKG = 10, MaxKG = 25,
		Color = Color3.fromRGB(255, 255, 255), Scale = 2.1, Rainbow = true,
		Ring = true, Light = true, Particles = true, Highlight = true,
	},
}

RarityConfig.ById = {}
for _, r in ipairs(RarityConfig.List) do
	RarityConfig.ById[r.Id] = r
end

-- Weighted roll. `rng` is a Random object, `luck` >= 1.
-- `pools` (rarity id -> types, e.g. a zone's pool) skips rarities with nothing to spawn.
function RarityConfig.Roll(rng: Random, luck: number, pools: { [string]: any }?)
	local total = 0
	local weights = table.create(#RarityConfig.List)
	for i, r in ipairs(RarityConfig.List) do
		local w = (pools and not pools[r.Id]) and 0 or r.Weight * (luck ^ r.LuckPower)
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	for i, r in ipairs(RarityConfig.List) do
		pick -= weights[i]
		if pick <= 0 and weights[i] > 0 then
			return r
		end
	end
	return RarityConfig.List[1]
end

-- KG roll, skewed toward the low end so big rolls feel special.
-- `minRoll` (0-1, Fresh Catch) lifts the bottom of the range.
function RarityConfig.RollKG(rng: Random, rarity, valueMultiplier: number, minRoll: number?): number
	local t = rng:NextNumber() ^ 1.6
	if minRoll and minRoll > 0 then t = minRoll + (1 - minRoll) * t end
	local kg = (rarity.MinKG + (rarity.MaxKG - rarity.MinKG) * t) * valueMultiplier
	return math.floor(kg * 100 + 0.5) / 100
end

-- Weighted roll restricted to rarities of at least `minOrder` (Rare/Premium/Master Orders).
-- With `pools`, falls back to a normal roll when no allowed rarity is that high.
function RarityConfig.RollAtLeast(rng: Random, luck: number, minOrder: number, pools: { [string]: any }?)
	local total, last = 0, nil
	for _, r in ipairs(RarityConfig.List) do
		if r.Order >= minOrder and not (pools and not pools[r.Id]) then
			total += r.Weight * (luck ^ r.LuckPower)
			last = r
		end
	end
	if not last then return RarityConfig.Roll(rng, luck, pools) end
	local pick = rng:NextNumber() * total
	for _, r in ipairs(RarityConfig.List) do
		if r.Order >= minOrder and not (pools and not pools[r.Id]) then
			pick -= r.Weight * (luck ^ r.LuckPower)
			if pick <= 0 then return r end
		end
	end
	return last
end

-- Chance (0-1) of each rarity for a given luck; handy for a future odds UI.
function RarityConfig.GetOdds(luck: number)
	local total, odds = 0, {}
	for _, r in ipairs(RarityConfig.List) do
		total += r.Weight * (luck ^ r.LuckPower)
	end
	for _, r in ipairs(RarityConfig.List) do
		odds[r.Id] = r.Weight * (luck ^ r.LuckPower) / total
	end
	return odds
end

return RarityConfig
