--!strict
-- GameConfig: global tuning values shared by server and client.
-- Per-player values here are the BASE (level 1) stats; upgrades will scale them later.

local GameConfig = {}

GameConfig.BaseStats = {
	Capacity = 5,          -- max sushi alive on the pad at once (per player)
	SpawnInterval = 2,     -- seconds between spawns while below capacity
	Luck = 1,              -- multiplier used by the rarity roll
	ValueMultiplier = 1,   -- multiplies KG of every spawned sushi
	CollectRadius = 3.5,   -- studs (horizontal) from HumanoidRootPart
	WalkSpeed = 16,         -- studs/s (a Walk Speed pad comes later)
}

GameConfig.Collection = {
	ServerRadiusTolerance = 5, -- extra studs the server allows for latency
	MaxVerticalDistance = 12,
}

GameConfig.Spawning = {
	CellSize = 4,           -- the pad is a grid of CellSize-stud squares, one sushi per square
	InitialFillDelay = 0.15, -- stagger when filling the pad on join
}

GameConfig.Sounds = {
	Collect = "rbxassetid://109359226723492",
	RareSpawn = "rbxassetid://135385970610304",
	Sell = "rbxassetid://101396758527961",
	Upgrade = "rbxassetid://1390124665",
	UIClick = "rbxassetid://88442833509532",
	UIHover = "rbxassetid://139719503904449",
}

-- Background music playlist (licensed tracks, shuffled)
GameConfig.Music = {
	"rbxassetid://139974704321055", -- Shibuya Tea Room
	"rbxassetid://108900946659666", -- Soft Japanese Lofi
	"rbxassetid://132218851587815", -- Japanese Lofi for coffee shop
}
GameConfig.MusicVolume = 0.25

-- Rarities at/above this order announce their spawn to the owner
GameConfig.AnnounceSpawnOrder = 7 -- Secret (Diamond); Golden spawns too often to announce
-- Rarities at/above this order are announced to the whole server when collected
GameConfig.GlobalAnnounceOrder = 6 -- Mythic

return GameConfig
