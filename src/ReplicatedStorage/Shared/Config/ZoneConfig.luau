-- ZoneConfig: every sushi zone. A zone = a pad in the world + a sushi pool
-- (SushiCatalog types with Zone = Id) + multipliers + an unlock requirement.
-- Adding a zone = one entry here + its island under workspace.Map + catalog types.

local AscensionConfig = require(script.Parent.AscensionConfig)

local ZoneConfig = {}

ZoneConfig.List = {
	{
		Id = "Starter", Name = "Sushi Bar", Icon = "🍣", Color = Color3.fromRGB(255, 170, 80),
		RequiredRebirths = 0, KGMultiplier = 1, LuckMultiplier = 1,
		SpawnPath = { "Map", "SushiPad", "SpawnZone" },
		ArrivalPath = { "Map", "Spawn", "Arrival" },
	},
	{
		Id = "Ascension", Name = "Blood Rift", Icon = "🩸", Color = Color3.fromRGB(255, 60, 60),
		-- a small red dimension with the Blood Altar (no sushi pad). Unlocked by the
		-- Ascension requirement instead of rebirths (see AscensionConfig).
		RequiredRebirths = 0, Unlock = "Ascension", KGMultiplier = 1, LuckMultiplier = 1, Look = "Blood",
		Subtitle = "Walk up to the Blood Altar to Ascend",
		ArrivalPath = { "Map", "AscensionRealm", "Arrival" },
	},
	{
		Id = "Fishing", Name = "Sushi Pond", Icon = "🎣", Color = Color3.fromRGB(110, 205, 255),
		-- the fishing area (no sushi pad), reached through the Fishing portal at the end of
		-- the path behind the Sushi Bar; the ReturnPad at the pond's entrance leads back.
		-- Opens at Rebirth 1 (shown as that Rebirth's unlock on the Rebirth board).
		RequiredRebirths = 1, KGMultiplier = 1, LuckMultiplier = 1,
		Subtitle = "The fishing area",
		ArrivalPath = { "Map", "SushiPond", "Arrival" },
	},
	{
		Id = "Slashing", Name = "Sushi Slashing", Icon = "🗡️", Color = Color3.fromRGB(255, 90, 80),
		-- the slashing arena, reached through the torii gate (Map.SlashingPortal) on the
		-- left of the Sushi Bar; the ReturnPad in its entrance leads back.
		RequiredRebirths = 2, KGMultiplier = 1, LuckMultiplier = 1,
		Subtitle = "The slashing arena",
		ArrivalPath = { "Map", "SushiSlashing", "Arrival" },
	},
}

ZoneConfig.ById = {}
for i, z in ipairs(ZoneConfig.List) do
	z.Order = i
	ZoneConfig.ById[z.Id] = z
end

ZoneConfig.Default = "Starter"
ZoneConfig.PortalTag = "ZonePortal" -- CollectionService tag; part has attribute TargetZone
ZoneConfig.PortalRadius = 4.2

-- Is this zone open for a player? `getAttr(name)` reads the player's attributes
-- (works on the server and the client). Returns ok, lock text.
function ZoneConfig.IsUnlocked(zone, getAttr: (string) -> any): (boolean, string)
	if zone.Unlock == "Ascension" then
		local ok = AscensionConfig.CanAscend(function(id) return getAttr("T_" .. id) == true end)
		return ok, "🔒 Needs " .. AscensionConfig.RequiredNodeName
	end
	local rebirths = getAttr("TotalRebirths") or 0
	return rebirths >= zone.RequiredRebirths, "🔒 Needs Rebirth " .. zone.RequiredRebirths
end

-- Resolves a path like {"Map","SushiPad","SpawnZone"} under workspace (waits up to `timeout`).
function ZoneConfig.Resolve(path: { string }, timeout: number?): Instance?
	local node: Instance? = workspace
	for _, name in ipairs(path) do
		node = node and node:WaitForChild(name, timeout or 10)
	end
	return node
end

return ZoneConfig
