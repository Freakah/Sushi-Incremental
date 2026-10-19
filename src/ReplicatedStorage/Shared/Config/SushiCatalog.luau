-- SushiCatalog: every sushi type and which rarity pool it belongs to.
-- Shape: "Nigiri" (rice + fish slice), "Maki" (nori roll), "Gunkan" (nori cup with topping).
-- Adding a new sushi = adding one entry here.

local C = Color3.fromRGB

local SushiCatalog = {}

SushiCatalog.Types = {
	-- The Sushi Bar pad spawns only these five (3D models in Shared.SushiMeshes).
	-- Old types were removed; their Discovered counts stay in player data.
	CucumberMaki = { Name = "Cucumber Maki", Rarity = "Common", Shape = "Maki", Topping = C(120, 200, 90) },
	TunaMaki = { Name = "Tuna Maki", Rarity = "Common", Shape = "Maki", Topping = C(214, 48, 70) },
	SalmonMaki = { Name = "Salmon Maki", Rarity = "Common", Shape = "Maki", Topping = C(255, 138, 92) },
	GoldenSalmonMaki = { Name = "Golden Salmon Maki", Rarity = "Legendary", Shape = "Maki", Topping = C(255, 210, 60), Nori = C(200, 150, 20), Material = Enum.Material.Foil },
	DiamondSalmonMaki = { Name = "Diamond Salmon Maki", Rarity = "Secret", Shape = "Maki", Topping = C(170, 240, 255), Rice = C(230, 250, 255), Material = Enum.Material.Glass },
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
