-- LeaderboardConfig: the global leaderboards in the Hall of Fame (under the rock arch, south-east of the spawn).
-- Each board reads a Player attribute that PlayerDataService keeps in sync, so adding
-- a board later (Ascensions...) is one line here + a slot in the Hall.
--   Id     = OrderedDataStore key (never rename once live)
--   Attr   = Player attribute with the lifetime value
--   Lead / Key = title "<Lead> <Key>" (Key drawn in Color, like the reference boards)
--   Format = "Cash" | "Int" | "Time" | "KG" | "Robux"
--   Slot   = where it stands in the Hall (Back1-3 facing the gate, Left1-4 west wall,
--            Right1-4 east wall; Right1 is kept for Ascensions)

local LeaderboardConfig = {}

local C = Color3.fromRGB
LeaderboardConfig.Stats = {
	{ Id = "Cash", Attr = "TotalMoney", Lead = "Total", Key = "Cash", Color = C(110, 240, 110), Format = "Cash", Slot = "Back2" },
	{ Id = "Rebirths", Attr = "TotalRebirths", Lead = "Total", Key = "Rebirths", Color = C(255, 95, 120), Format = "Int", Slot = "Back1" },
	{ Id = "Playtime", Attr = "Playtime", Lead = "Time", Key = "Played", Color = C(90, 220, 255), Format = "Time", Slot = "Back3" },
	{ Id = "Collected", Attr = "SushiCollected", Lead = "Sushi", Key = "Collected", Color = C(255, 170, 90), Format = "Int", Slot = "Left4" },
	{ Id = "Heaviest", Attr = "HeaviestSushi", Lead = "Heaviest", Key = "Sushi", Color = C(255, 215, 80), Format = "KG", Slot = "Left3" },
	{ Id = "Sold", Attr = "TotalKGSold", Lead = "Sushi", Key = "Sold", Color = C(255, 150, 200), Format = "KG", Slot = "Left2" },
	{ Id = "Robux", Attr = "RobuxSpent", Lead = "Robux", Key = "Spent", Color = C(120, 255, 170), Format = "Robux", Slot = "Right4" },
	{ Id = "Prestiges", Attr = "TotalPrestiges", Lead = "Total", Key = "Prestiges", Color = C(255, 215, 70), Format = "Int", Slot = "Right2" },
	{ Id = "Ascensions", Attr = "Ascensions", Lead = "Total", Key = "Ascensions", Color = C(255, 90, 90), Format = "Int", Slot = "Right1" },
}

LeaderboardConfig.Rows = 12
LeaderboardConfig.StoreVersion = "v1"
LeaderboardConfig.RefreshSpacing = 12 -- seconds between two board refreshes (round-robin, keeps us under the DataStore budget)
LeaderboardConfig.SubmitInterval = 120 -- seconds between writing everyone's values

LeaderboardConfig.ById = {}
for _, s in ipairs(LeaderboardConfig.Stats) do LeaderboardConfig.ById[s.Id] = s end

-- OrderedDataStores only hold integers (< 2^63) and cash goes way past that, so values
-- are stored as log10(1 + v) with 13 decimals of precision.
local SCALE = 1e13
function LeaderboardConfig.Encode(v: number): number
	return math.floor(math.log10(1 + math.max(v, 0)) * SCALE)
end
function LeaderboardConfig.Decode(n: number): number
	return 10 ^ (n / SCALE) - 1
end

return LeaderboardConfig
