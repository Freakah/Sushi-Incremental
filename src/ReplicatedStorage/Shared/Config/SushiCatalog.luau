-- SushiCatalog: every sushi type and which rarity pool it belongs to.
-- Shape: "Nigiri" (rice + fish slice), "Maki" (nori roll), "Gunkan" (nori cup with topping).
-- Adding a new sushi = adding one entry here.

local C = Color3.fromRGB

local SushiCatalog = {}

SushiCatalog.Types = {
	-- Common
	SalmonNigiri = { Name = "Salmon Nigiri", Rarity = "Common", Shape = "Nigiri", Topping = C(255, 138, 92), Stripes = C(255, 214, 190) },
	TamagoNigiri = { Name = "Tamago Nigiri", Rarity = "Common", Shape = "Nigiri", Topping = C(255, 214, 80), Band = true },
	CucumberMaki = { Name = "Cucumber Maki", Rarity = "Common", Shape = "Maki", Topping = C(120, 200, 90) },
	-- Uncommon
	TunaNigiri = { Name = "Tuna Nigiri", Rarity = "Uncommon", Shape = "Nigiri", Topping = C(214, 48, 70) },
	EbiNigiri = { Name = "Ebi Nigiri", Rarity = "Uncommon", Shape = "Nigiri", Topping = C(255, 170, 130), Stripes = C(255, 90, 60) },
	SalmonMaki = { Name = "Salmon Maki", Rarity = "Uncommon", Shape = "Maki", Topping = C(255, 138, 92) },
	-- Rare
	IkuraGunkan = { Name = "Ikura Gunkan", Rarity = "Rare", Shape = "Gunkan", Topping = C(255, 100, 30), Beads = true },
	UnagiNigiri = { Name = "Unagi Nigiri", Rarity = "Rare", Shape = "Nigiri", Topping = C(140, 78, 40), Band = true, Stripes = C(90, 45, 20) },
	AvocadoMaki = { Name = "Avocado Maki", Rarity = "Rare", Shape = "Maki", Topping = C(170, 220, 90) },
	-- Epic
	OtoroNigiri = { Name = "Otoro Nigiri", Rarity = "Epic", Shape = "Nigiri", Topping = C(255, 150, 170), Stripes = C(255, 230, 235) },
	UniGunkan = { Name = "Uni Gunkan", Rarity = "Epic", Shape = "Gunkan", Topping = C(255, 180, 50) },
	DragonMaki = { Name = "Dragon Maki", Rarity = "Epic", Shape = "Maki", Topping = C(60, 200, 120), Rice = C(210, 255, 220) },
	-- Legendary
	GoldenSalmon = { Name = "Golden Salmon", Rarity = "Legendary", Shape = "Nigiri", Topping = C(255, 200, 40), Stripes = C(255, 245, 180), Material = Enum.Material.Foil },
	GoldenMaki = { Name = "Golden Maki", Rarity = "Legendary", Shape = "Maki", Topping = C(255, 210, 60), Nori = C(200, 150, 20), Material = Enum.Material.Foil },
	-- Mythic
	SakuraNigiri = { Name = "Sakura Nigiri", Rarity = "Mythic", Shape = "Nigiri", Topping = C(255, 120, 190), Stripes = C(255, 220, 240), Material = Enum.Material.Neon },
	CosmicGunkan = { Name = "Cosmic Gunkan", Rarity = "Mythic", Shape = "Gunkan", Topping = C(150, 90, 255), Nori = C(30, 20, 60), Beads = true, Material = Enum.Material.Neon },
	-- Secret
	RainbowRoll = { Name = "Rainbow Roll", Rarity = "Secret", Shape = "Maki", Topping = C(255, 255, 255), Rainbow = true, Material = Enum.Material.Neon },
	DiamondNigiri = { Name = "Diamond Nigiri", Rarity = "Secret", Shape = "Nigiri", Topping = C(170, 240, 255), Stripes = C(255, 255, 255), Material = Enum.Material.Glass, Rice = C(230, 250, 255) },
}

-- Pools[rarity] = every type of that rarity (used by the Sushi Index)
-- ZonePools[zone][rarity] = what can spawn in that zone
SushiCatalog.Pools = {}
SushiCatalog.ZonePools = {}
for id, def in pairs(SushiCatalog.Types) do
	def.Id = id
	def.Zone = def.Zone or "Starter"
	SushiCatalog.Pools[def.Rarity] = SushiCatalog.Pools[def.Rarity] or {}
	table.insert(SushiCatalog.Pools[def.Rarity], id)
	local zp = SushiCatalog.ZonePools[def.Zone] or {}
	SushiCatalog.ZonePools[def.Zone] = zp
	zp[def.Rarity] = zp[def.Rarity] or {}
	table.insert(zp[def.Rarity], id)
end
for _, pool in pairs(SushiCatalog.Pools) do
	table.sort(pool) -- deterministic order
end
for _, zp in pairs(SushiCatalog.ZonePools) do
	for _, pool in pairs(zp) do table.sort(pool) end
end

function SushiCatalog.RandomType(rng: Random, rarityId: string, zoneId: string?): string
	local zp = SushiCatalog.ZonePools[zoneId or "Starter"]
	local pool = (zp and zp[rarityId]) or SushiCatalog.ZonePools.Starter[rarityId]
	return pool[rng:NextInteger(1, #pool)]
end

return SushiCatalog
