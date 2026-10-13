-- RuneConfig: runes, rolled at a Rune Altar in each area (only the Fish Pond for now).
--   Stand near an altar and it rolls by itself every RollInterval seconds, as long as
--   you can pay RollCost of that area's currency (Fish at the Fish Pond).
--   A roll checks the rarest rune first: each rune hits with chance Rune Luck / Chance;
--   if none hit you get the area's common rune.
--   Every copy you own makes that rune's boosts stronger, up to its Max copies (rarer
--   runes cap lower: only 10 of the rarest). Past Max you still collect copies, but the
--   boost stays at its maximum. Rune boosts work everywhere and are kept on Rebirth.
-- Boost = the multiplier a rune gives at Max copies (it grows evenly from x1).

local RuneConfig = {}

RuneConfig.RollCost = 50       -- per roll, in the area's currency
RuneConfig.RollInterval = 1    -- seconds between automatic rolls at an altar
RuneConfig.AltarRadius = 16    -- how close you stand (studs from the altar's centre) to roll
RuneConfig.AnnounceOrder = 7   -- Divine and Secret runes are announced to the server

local C = Color3.fromRGB

RuneConfig.Rarities = {
	Common = { Order = 1, Color = C(200, 205, 215) },
	Uncommon = { Order = 2, Color = C(90, 225, 110) },
	Rare = { Order = 3, Color = C(70, 165, 255) },
	Epic = { Order = 4, Color = C(185, 95, 255) },
	Legendary = { Order = 5, Color = C(255, 196, 40) },
	Mythical = { Order = 6, Color = C(255, 75, 125) },
	Divine = { Order = 7, Color = C(110, 255, 235) },
	Secret = { Order = 8, Color = C(255, 255, 255), Rainbow = true },
}

-- the stats a rune can boost
RuneConfig.Stats = {
	{ Id = "Cash", Name = "Cash", Color = C(90, 255, 110) },
	{ Id = "Prestige", Name = "Prestiges", Color = C(255, 205, 70) },
	{ Id = "RuneLuck", Name = "Rune Luck", Color = C(110, 220, 255) },
	{ Id = "TraitLuck", Name = "Trait Luck", Color = C(200, 140, 255) }, -- (used by a later feature)
}

RuneConfig.Areas = {
	{
		Id = "FishPond", Name = "Fish Pond", Icon = "🎣", Currency = "Fish", CurrencyIcon = "🐟",
		Altar = { "Map", "SushiPond", "FishRuneAltar" },
		Runes = {
			{ Id = "Minnow", Name = "Minnow Rune", Rarity = "Common", Chance = 2, Max = 1000, Boost = { Cash = 1.25 } },
			{ Id = "Goldfish", Name = "Goldfish Rune", Rarity = "Uncommon", Chance = 5, Max = 500, Boost = { Cash = 1.5 } },
			{ Id = "Koi", Name = "Koi Rune", Rarity = "Rare", Chance = 15, Max = 250, Boost = { Cash = 1.5, RuneLuck = 1.2 } },
			{ Id = "Puffer", Name = "Puffer Rune", Rarity = "Epic", Chance = 50, Max = 100, Boost = { Cash = 2, TraitLuck = 1.5 } },
			{ Id = "Thunderfin", Name = "Thunderfin Rune", Rarity = "Legendary", Chance = 150, Max = 60, Boost = { Cash = 2, Prestige = 1.25, RuneLuck = 1.3 } },
			{ Id = "GoldenKoi", Name = "Golden Koi Rune", Rarity = "Mythical", Chance = 500, Max = 35, Boost = { Cash = 2.5, Prestige = 1.5, TraitLuck = 2 } },
			{ Id = "Abyssal", Name = "Abyssal Rune", Rarity = "Divine", Chance = 2000, Max = 20, Boost = { Cash = 3, Prestige = 2, RuneLuck = 1.5, TraitLuck = 2.5 } },
			{ Id = "Leviathan", Name = "Celestial Leviathan Rune", Rarity = "Secret", Chance = 10000, Max = 10, Boost = { Cash = 5, Prestige = 3, RuneLuck = 2, TraitLuck = 4 } },
		},
	},
}

RuneConfig.ById = {}
RuneConfig.AreaById = {}
RuneConfig.All = {}
for _, area in ipairs(RuneConfig.Areas) do
	RuneConfig.AreaById[area.Id] = area
	for i, r in ipairs(area.Runes) do
		r.Order = i
		r.Area = area.Id
		RuneConfig.ById[r.Id] = r
		table.insert(RuneConfig.All, r)
	end
end

function RuneConfig.Attr(id: string): string return "Rune_" .. id end

function RuneConfig.RarityOf(rune) return RuneConfig.Rarities[rune.Rarity] end

-- the "1 in N" chance once Rune Luck is applied (the common rune is the fallback, never boosted)
function RuneConfig.EffectiveChance(rune, luck: number): number
	if rune.Order == 1 then return rune.Chance end
	return math.max(rune.Chance / math.max(luck or 1, 1), 1.01)
end

-- one roll at an area's altar: rarest rune first
function RuneConfig.Roll(rng: Random, areaId: string, luck: number)
	local runes = RuneConfig.AreaById[areaId].Runes
	for i = #runes, 2, -1 do
		if rng:NextNumber() < 1 / RuneConfig.EffectiveChance(runes[i], luck) then return runes[i] end
	end
	return runes[1]
end

-- the multiplier one rune gives for `count` copies, for one stat (1 if it doesn't boost it)
function RuneConfig.BoostFor(rune, stat: string, count: number): number
	local top = rune.Boost[stat]
	if not top or count <= 0 then return 1 end
	return 1 + (top - 1) * math.min(count, rune.Max) / rune.Max
end

-- counts = { [runeId] = copies } -> { Cash, Prestige, RuneLuck, TraitLuck }
function RuneConfig.GetBoosts(counts)
	local b = { Cash = 1, Prestige = 1, RuneLuck = 1, TraitLuck = 1 }
	for _, r in ipairs(RuneConfig.All) do
		local n = counts and counts[r.Id] or 0
		if n > 0 then
			for stat in pairs(r.Boost) do b[stat] *= RuneConfig.BoostFor(r, stat, n) end
		end
	end
	return b
end

-- "1/2", "1/150", "1/2.5K"
function RuneConfig.FormatChance(n: number): string
	if n >= 1000 then
		local v = n / 1000
		return "1/" .. (v >= 100 and string.format("%d", math.floor(v + 0.5)) or (string.format("%.1f", v):gsub("%.0$", ""))) .. "K"
	end
	if n >= 10 then return "1/" .. math.floor(n + 0.5) end
	return "1/" .. (string.format("%.1f", n):gsub("0+$", ""):gsub("%.$", ""))
end

return RuneConfig
