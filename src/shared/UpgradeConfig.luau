--[[
	UpgradeConfig  (ModuleScript in ReplicatedStorage)
	===================================================
	Everything about the upgrade boards lives here: currencies, upgrades,
	costs, values, rebirth rules and number formatting. Both the server and
	the client read this, so change numbers here and both sides stay in sync.

	Your own scripts can read a player's upgraded stats with:
		local UpgradeConfig = require(game.ReplicatedStorage.UpgradeConfig)
		local stats = UpgradeConfig.GetStats(player)
		stats.CashMultiplier   -- multiply sushi cash by this
		stats.SushiCapacity    -- max sushi on the pad at once
		stats.SpawnInterval    -- seconds between sushi spawns
		stats.RebirthMultiplier
]]

local Config = {}

-- Folder in Workspace that holds the board parts (see CreateBoards)
Config.BoardsFolderName = "UpgradeBoards"

-- Save upgrade levels & rebirths with DataStores (needs "Enable Studio Access
-- to API Services" in Game Settings > Security to work in Studio)
Config.UseDataStore = true
Config.DataStoreName = "SushiUpgradeShop_v1"
-- Turn this on only if your game does NOT already save Cash somewhere else
Config.SaveCash = false

-- Free cash per second, ONLY when testing in Studio, so you can try the
-- boards straight away. Set to 0 to turn off. Never runs in the real game.
Config.StudioTestIncome = 50

-- Sounds (swap for any sound IDs from the Toolbox, e.g. "rbxassetid://123")
Config.Sounds = {
	Buy = "rbxasset://sounds/electronicpingshort.wav",
	Fail = "rbxasset://sounds/electronicpingshort.wav",
	Rebirth = "rbxasset://sounds/electronicpingshort.wav",
}

--------------------------------------------------------------------------
-- Currencies (stored as leaderstats values with these names)
--------------------------------------------------------------------------

Config.Currencies = {
	Cash = { Stat = "Cash", Icon = "💵", Color = Color3.fromRGB(90, 255, 110) },
	Rebirths = { Stat = "Rebirths", Icon = "🔄", Color = Color3.fromRGB(255, 75, 95) },
}

--------------------------------------------------------------------------
-- Upgrades
--   Value(level)   -> the stat at that level (level 0 = not bought yet)
--   Format(value)  -> how the value is shown, e.g. "x2" or "1.5s"
--   Cost of the next level = BaseCost * CostGrowth ^ currentLevel
--------------------------------------------------------------------------

local function times(v)
	return "x" .. Config.FormatNumber(v)
end

Config.Upgrades = {
	-- Cash upgrades (reset on rebirth)
	SushiValue = {
		Title = "Sushi Value",
		Description = "Every sushi is worth more cash",
		Icon = "🍣",
		Currency = "Cash",
		MaxLevel = 49,
		BaseCost = 25,
		CostGrowth = 1.35,
		ResetOnRebirth = true,
		Value = function(level)
			return 1 + level
		end,
		Format = times,
	},
	SushiCapacity = {
		Title = "Sushi Capacity",
		Description = "More sushi can sit on the pad at once",
		Icon = "🍱",
		Currency = "Cash",
		MaxLevel = 12,
		BaseCost = 50,
		CostGrowth = 1.6,
		ResetOnRebirth = true,
		Value = function(level)
			return 5 + level * 2
		end,
		Format = function(v)
			return Config.FormatNumber(v)
		end,
	},
	SpawnSpeed = {
		Title = "Spawn Speed",
		Description = "Sushi appears on the pad faster",
		Icon = "⏱️",
		Currency = "Cash",
		MaxLevel = 20,
		BaseCost = 40,
		CostGrowth = 1.5,
		ResetOnRebirth = true,
		Value = function(level)
			return math.max(0.2, 2 * 0.89 ^ level)
		end,
		Format = function(v)
			return string.format("%.1fs", v)
		end,
	},

	-- Rebirth upgrades (kept forever)
	MoreCash = {
		Title = "More Cash",
		Description = "Multiplies all cash you earn",
		Icon = "💵",
		Currency = "Rebirths",
		MaxLevel = 6,
		BaseCost = 1,
		CostGrowth = 3,
		Value = function(level)
			return 2 ^ level
		end,
		Format = times,
	},
	MoreRebirths = {
		Title = "More Rebirths",
		Description = "Get more rebirths each time",
		Icon = "🔄",
		Currency = "Rebirths",
		MaxLevel = 4,
		BaseCost = 2,
		CostGrowth = 3,
		Value = function(level)
			return 1 + level
		end,
		Format = times,
	},
	MoreSushi = {
		Title = "More Sushi",
		Description = "Multiplies your sushi capacity",
		Icon = "🍙",
		Currency = "Rebirths",
		MaxLevel = 12,
		BaseCost = 1,
		CostGrowth = 1.8,
		Value = function(level)
			return 1 + level * 0.25
		end,
		Format = times,
	},
}

--------------------------------------------------------------------------
-- Boards: which upgrades go on which board, left to right.
-- Each board needs a Part with the same name inside the boards folder.
--------------------------------------------------------------------------

Config.Boards = {
	{ Id = "CashUpgrades", Currency = "Cash", TitleColor = Color3.fromRGB(90, 255, 110), Upgrades = { "SushiValue", "SushiCapacity", "SpawnSpeed" } },
	{ Id = "RebirthUpgrades", Currency = "Rebirths", TitleColor = Color3.fromRGB(255, 75, 95), Upgrades = { "MoreCash", "MoreRebirths", "MoreSushi" } },
}
Config.RebirthBoardId = "Rebirth"

--------------------------------------------------------------------------
-- Rebirth
--------------------------------------------------------------------------

Config.Rebirth = {
	BaseRequirement = 1000, -- Cash needed for the first rebirth
	RequirementGrowth = 1.5, -- each rebirth needs this much more
	BaseGain = 1, -- rebirths earned, before the More Rebirths multiplier
}

--------------------------------------------------------------------------
-- Helpers (shared by server and client)
--------------------------------------------------------------------------

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s)
	if s:find("%.") then
		s = (s:gsub("0+$", ""))
		s = (s:gsub("%.$", ""))
	end
	return s
end

-- 1234 -> "1.23K", 411.314 -> "411.31"
function Config.FormatNumber(n)
	if n ~= n or n == math.huge then
		return "∞"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. trimZeros(string.format("%.2f", n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text
	if scaled >= 100 then
		text = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		text = trimZeros(string.format("%.1f", scaled))
	else
		text = trimZeros(string.format("%.2f", scaled))
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

function Config.GetLevel(player, upgradeId)
	return player:GetAttribute("Upg_" .. upgradeId) or 0
end

function Config.GetCost(upgradeId, level)
	local upgrade = Config.Upgrades[upgradeId]
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level + 0.5)
end

function Config.GetValue(player, upgradeId)
	return Config.Upgrades[upgradeId].Value(Config.GetLevel(player, upgradeId))
end

function Config.GetStats(player)
	return {
		CashMultiplier = Config.GetValue(player, "SushiValue") * Config.GetValue(player, "MoreCash"),
		SushiCapacity = math.floor(Config.GetValue(player, "SushiCapacity") * Config.GetValue(player, "MoreSushi")),
		SpawnInterval = Config.GetValue(player, "SpawnSpeed"),
		RebirthMultiplier = Config.GetValue(player, "MoreRebirths"),
	}
end

function Config.GetRebirthCount(player)
	return player:GetAttribute("RebirthCount") or 0
end

function Config.GetRebirthRequirement(player)
	local r = Config.Rebirth
	return math.floor(r.BaseRequirement * r.RequirementGrowth ^ Config.GetRebirthCount(player) + 0.5)
end

function Config.GetRebirthGain(player)
	return Config.Rebirth.BaseGain * Config.GetValue(player, "MoreRebirths")
end

return Config
