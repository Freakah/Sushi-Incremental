-- PlayerDataService: owns every player's persistent data (server-authoritative).
-- Currencies are mirrored to Player attributes (read-only for clients) and leaderstats.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local SushiCatalog = require(ReplicatedStorage.Shared.Config.SushiCatalog)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local AscensionConfig = require(ReplicatedStorage.Shared.Config.AscensionConfig)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local SliceConfig = require(ReplicatedStorage.Shared.Config.SliceConfig)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local AutomationConfig = require(ReplicatedStorage.Shared.Config.AutomationConfig)
local RuneConfig = require(ReplicatedStorage.Shared.Config.RuneConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)

local DATA_VERSION = 1
local STORE_NAME = "SushiIncremental_v1"
local AUTOSAVE_INTERVAL = 90

local PlayerDataService = {}

local profiles: { [Player]: any } = {}
local loadedEvent = Instance.new("BindableEvent")
PlayerDataService.PlayerLoaded = loadedEvent.Event
local statsChangedEvent = Instance.new("BindableEvent")
PlayerDataService.StatsChanged = statsChangedEvent.Event -- (player, upgradeId | "Reset" | "Index" | "Prestige" | "Fish" | ...)

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable, progress will not save:", result)
	end
end

local function defaultData()
	return {
		Version = DATA_VERSION,
		KG = 0,
		TotalKG = 0,       -- lifetime KG collected (for future leaderboards/quests)
		Money = 0,
		TotalMoney = 0,    -- lifetime cash earned
		SushiCollected = 0,
		TotalKGSold = 0,   -- lifetime KG sold at the Market (leaderboard)
		HeaviestSushi = 0, -- heaviest single sushi collected in the main area, in kg (leaderboard)
		RarityCounts = {}, -- [rarityId] = count
		Upgrades = {},     -- [upgradeId] = level (Cash Upgrades, reset on Prestige)
		TotalRebirths = 0, -- milestones (see RebirthConfig)
		-- ⭐ Prestige (see PrestigeConfig)
		Prestiges = 0,        -- spendable
		TotalPrestiges = 0,   -- every Prestige ever earned (leaderboard)
		PrestigeCount = 0,    -- times prestiged
		PrestigeUpgrades = {}, -- [id] = level (reset on Rebirth)
		Discovered = {},   -- [sushiTypeId] = times collected (Sushi Index, kept forever)
		Settings = {},     -- [settingKey] = value (see SettingsConfig)
		Tree = {},         -- [nodeId] = level (main skill tree, kept forever; reset on Ascension)
		TreeVersion = 3,   -- 3 = single-purchase hex skill tree
		Playtime = 0,      -- seconds played (Profile)
		RobuxSpent = 0,    -- Profile
		Passes = {},       -- [passKey] = true (Robux game passes)
		Boosts = {},       -- [stat] = os.time() the timed boost ends
		EquippedTitle = TitleConfig.Default,
		Tutorial = 0,      -- onboarding steps completed (0..5, see tutorialDone)
		Ascensions = 0,       -- ✨ times Ascended (leaderboard)
		AscensionPoints = 0,  -- spendable AP (1 per Ascension)
		AscensionUpgrades = {}, -- [id] = level (kept forever)
		Receipts = {},     -- [PurchaseId] = true, so a product is never granted twice
		-- 🎣 Sushi Pond (its own economy, see FishConfig)
		Fish = 0,             -- 🐟 spendable
		TotalFish = 0,        -- lifetime fish caught
		FishUpgrades = {},    -- [id] = level (reset on Rebirth)
		-- 🗡️ Sushi Slashing (its own economy, see SliceConfig)
		Slices = 0,           -- 🍥 spendable
		TotalSlices = 0,      -- lifetime slices
		SliceUpgrades = {},   -- [id] = level (reset on Rebirth)
		-- 🤖 Automation (see AutomationConfig): kept forever
		Automation = {},      -- [id] = true once bought
		AutomationOff = {},   -- [id] = true while switched off
		-- 🔮 Runes (see RuneConfig): kept forever (also through Rebirth)
		Runes = {},           -- [runeId] = copies rolled
		RuneRolls = 0,        -- lifetime rolls
		-- LastPosition = { X, Y, Z, Zone } when "Save Last Position" is on
	}
end

local function reconcile(data)
	-- old (physical) skill tree progress is reset for the new leveled skill tree
	if data.TreeVersion ~= 3 then
		data.Tree = {}
		data.TreeVersion = 3
	end
	local template = defaultData()
	for k, v in pairs(template) do
		if data[k] == nil then data[k] = v end
	end
	return data
end

local function key(player: Player)
	return "Player_" .. player.UserId
end

local function discoveredCount(data): number
	local n = 0
	for id in pairs(data.Discovered) do
		if SushiCatalog.Types[id] then n += 1 end
	end
	return n
end

-- Skill tree effects are cached per data table; rebuilt after a purchase or when
-- lifetime Prestiges change (Veteran / Tycoon scale with them).
local treeCache = setmetatable({}, { __mode = "k" })
local function treeEffects(data)
	local c = treeCache[data]
	if not c or c.Prestiges ~= data.TotalPrestiges then
		c = { Prestiges = data.TotalPrestiges, Effects = SkillTreeConfig.GetEffects(data.Tree, data.TotalPrestiges) }
		treeCache[data] = c
	end
	return c.Effects
end

-- Main-area multipliers (Rebirths, Prestige Upgrades, skill tree, Robux perks, Ascension).
local function multipliers(data)
	local m = RebirthConfig.GetMultipliers(data.TotalRebirths, discoveredCount(data))
	local t = treeEffects(data)
	local s = ShopConfig.GetPerks(data.Passes, data.Boosts, os.time())
	local p = PrestigeConfig.GetBoosts(data.PrestigeUpgrades)
	local r = RuneConfig.GetBoosts(data.Runes)
	m.Cash *= t.Cash * s.Cash * p.Cash * r.Cash
	m.KG *= t.KG * s.KG * p.KG
	m.PrestigeGain *= t.Prestige * p.PrestigeGain * r.Prestige
	m.Runes = r
	m.Luck *= t.Luck * s.Luck
	local a = AscensionConfig.GetBoosts(data.AscensionUpgrades)
	m.Cash *= a.Cash
	m.PrestigeGain *= a.RebirthPoints
	m.Ascension = a
	m.Prestige = p
	m.Shop = s
	m.HeadStart = t.HeadStart
	m.CritChance = t.Bonus
	m.CritMultiplier = RebirthConfig.CritMultiplier + t.BonusMult
	m.AutoInterval = t.AutoInterval
	if a.AutoPickup then
		m.AutoInterval = if m.AutoInterval == 0 then AscensionConfig.AutoPickupInterval else math.min(m.AutoInterval, AscensionConfig.AutoPickupInterval)
	end
	m.Tree = t
	return m
end

local function effectiveSellRate(data): number
	return EconomyConfig.BaseSellRate * multipliers(data).Cash
end

-- 🎓 Tutorial: 1 collect 5 sushi, 2 sell, 3 buy an upgrade, 4 unlock a skill, 5 prestige.
-- Progress only ever goes up, and a later step being done counts the earlier ones
-- as done too (so existing players never see it).
local TUTORIAL_STEPS = 5
local function tutorialDone(data): number
	local done = data.Tutorial or 0
	if done >= TUTORIAL_STEPS then return done end
	local anyUpgrade = false
	for _, level in pairs(data.Upgrades) do
		if level > 1 then anyUpgrade = true break end
	end
	local checks = {
		data.SushiCollected >= 5,
		data.TotalMoney > 0,
		anyUpgrade,
		next(data.Tree) ~= nil,
		data.PrestigeCount > 0,
	}
	for k = TUTORIAL_STEPS, done + 1, -1 do
		if checks[k] then return k end
	end
	return done
end

local function syncTutorial(player: Player, data)
	data.Tutorial = tutorialDone(data)
	if player:GetAttribute("TutorialStep") ~= data.Tutorial then
		player:SetAttribute("TutorialStep", data.Tutorial)
	end
end

local function syncReplicated(player: Player, data)
	local mults = multipliers(data)
	syncTutorial(player, data)
	player:SetAttribute("KG", data.KG)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("TotalMoney", data.TotalMoney)
	player:SetAttribute("SellRate", effectiveSellRate(data))
	player:SetAttribute("TotalRebirths", data.TotalRebirths)
	player:SetAttribute("RebirthCost", RebirthConfig.Cost(data.TotalRebirths))
	player:SetAttribute("CashMultiplier", mults.Cash)
	player:SetAttribute("KGMultiplier", mults.KG)
	player:SetAttribute("LuckMultiplier", mults.Luck)
	player:SetAttribute("PrestigeMultiplier", mults.PrestigeGain)
	player:SetAttribute("IndexCount", discoveredCount(data))
	-- ⭐ Prestige
	player:SetAttribute("Prestiges", data.Prestiges)
	player:SetAttribute("TotalPrestiges", data.TotalPrestiges)
	player:SetAttribute("PrestigeCount", data.PrestigeCount)
	for _, u in ipairs(PrestigeConfig.List) do
		player:SetAttribute(PrestigeConfig.AttributeName(u.Id), data.PrestigeUpgrades[u.Id] or 1)
	end
	for id in pairs(SushiCatalog.Types) do
		local count = data.Discovered[id]
		if count and player:GetAttribute("Idx_" .. id) ~= count then
			player:SetAttribute("Idx_" .. id, count)
		end
	end
	for _, u in ipairs(UpgradeConfig.List) do
		player:SetAttribute(UpgradeConfig.AttributeName(u.Id), data.Upgrades[u.Id] or 1)
	end
	local t = treeEffects(data)
	player:SetAttribute("CollectRadius", GameConfig.BaseStats.CollectRadius + t.Range)
	local treeCount = 0
	for _, node in ipairs(SkillTreeConfig.List) do
		local lvl = SkillTreeConfig.LevelOf(data.Tree, node.Id)
		treeCount += lvl
		local la = SkillTreeConfig.LevelAttribute(node.Id)
		if player:GetAttribute(la) ~= lvl then
			player:SetAttribute(la, if lvl > 0 then lvl else nil)
		end
		local owned = if lvl > 0 then true else nil
		if player:GetAttribute(SkillTreeConfig.AttributeName(node.Id)) ~= owned then
			player:SetAttribute(SkillTreeConfig.AttributeName(node.Id), owned)
		end
	end
	player:SetAttribute("TreeCount", treeCount)
	-- Profile / Titles / Shop
	player:SetAttribute("SushiCollected", data.SushiCollected)
	player:SetAttribute("TotalKG", data.TotalKG)
	player:SetAttribute("TotalKGSold", data.TotalKGSold)
	-- ✨ Ascension
	player:SetAttribute("Ascensions", data.Ascensions)
	player:SetAttribute("AscensionPoints", data.AscensionPoints)
	for _, u in ipairs(AscensionConfig.Upgrades) do
		player:SetAttribute(AscensionConfig.AttributeName(u.Id), data.AscensionUpgrades[u.Id] or 1)
	end
	-- 🤖 Automation
	for _, a in ipairs(AutomationConfig.List) do
		local owned = data.Automation[a.Id] == true
		player:SetAttribute(AutomationConfig.OwnedAttr(a.Id), owned)
		player:SetAttribute(AutomationConfig.OnAttr(a.Id), owned and not data.AutomationOff[a.Id])
	end
	-- 🔮 Runes
	for _, rune in ipairs(RuneConfig.All) do
		local n = data.Runes[rune.Id]
		if player:GetAttribute(RuneConfig.Attr(rune.Id)) ~= n then player:SetAttribute(RuneConfig.Attr(rune.Id), n) end
	end
	player:SetAttribute("RuneLuck", mults.Runes.RuneLuck)
	player:SetAttribute("TraitLuck", mults.Runes.TraitLuck)
	player:SetAttribute("RuneRolls", data.RuneRolls)
	-- 🎣 Sushi Pond
	player:SetAttribute("Fish", data.Fish)
	player:SetAttribute("TotalFish", data.TotalFish)
	for _, u in ipairs(FishConfig.Upgrades.List) do
		player:SetAttribute(FishConfig.Upgrades.AttributeName(u.Id), data.FishUpgrades[u.Id] or 1)
	end
	-- 🗡️ Sushi Slashing
	player:SetAttribute("Slices", data.Slices)
	player:SetAttribute("TotalSlices", data.TotalSlices)
	for _, u in ipairs(SliceConfig.Upgrades.List) do
		player:SetAttribute(SliceConfig.Upgrades.AttributeName(u.Id), data.SliceUpgrades[u.Id] or 1)
	end
	player:SetAttribute("HeaviestSushi", data.HeaviestSushi)
	player:SetAttribute("Playtime", math.floor(data.Playtime))
	player:SetAttribute("RobuxSpent", data.RobuxSpent)
	player:SetAttribute("EquippedTitle", data.EquippedTitle)
	for _, p in ipairs(ShopConfig.Passes) do
		player:SetAttribute(ShopConfig.PassAttr(p.Key), data.Passes[p.Key] == true)
	end
	for stat, endTime in pairs(data.Boosts) do
		player:SetAttribute(ShopConfig.BoostAttr(stat), endTime)
	end
	for _, s in ipairs(SettingsConfig.List) do
		local v = data.Settings[s.Key]
		if v == nil then v = s.Default end
		player:SetAttribute(SettingsConfig.AttributeName(s.Key), v)
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = NumberFormat.Cash(data.Money)
		ls.KG.Value = NumberFormat.Format(data.KG)
		ls.Rebirths.Value = data.TotalRebirths
	end
end

-- Studio-only: set ServerStorage attribute "DevFreshStart" = true to play as a brand-new
-- player. That session never loads or saves, so your real Studio save is untouched.
local freshSessions: { [Player]: boolean } = {}
local function devFresh(): boolean
	return RunService:IsStudio() and game:GetService("ServerStorage"):GetAttribute("DevFreshStart") == true
end

local function load(player: Player)
	local data
	if devFresh() then
		freshSessions[player] = true
	elseif store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				break
			end
			warn("[PlayerData] load attempt", attempt, "failed:", result)
			if string.find(tostring(result), "Studio") or string.find(tostring(result), "403") then
				warn("[PlayerData] Enable 'Studio Access to API Services' to test saving. Running without saves.")
				store = nil
				break
			end
			task.wait(1)
		end
	end
	data = reconcile(data or defaultData())
	if not player.Parent then return end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cashStat = Instance.new("StringValue")
	cashStat.Name = "Cash"
	cashStat.Parent = ls
	local kgStat = Instance.new("StringValue")
	kgStat.Name = "KG"
	kgStat.Parent = ls
	local rbStat = Instance.new("IntValue")
	rbStat.Name = "Rebirths"
	rbStat.Parent = ls
	ls.Parent = player

	profiles[player] = data
	syncReplicated(player, data)
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, data)
end

local function save(player: Player)
	local data = profiles[player]
	if not data or not store or freshSessions[player] then return end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok then warn("[PlayerData] save failed for", player.Name, err) end
end

-- ===== Public API =====

function PlayerDataService.Get(player: Player)
	return profiles[player]
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.GetSetting(player: Player, settingKey: string): any
	local data = profiles[player]
	local s = SettingsConfig.ByKey[settingKey]
	if not data or not s then return nil end
	local v = data.Settings[settingKey]
	if v == nil then return s.Default end
	return v
end

-- Effective gameplay stats for a player: base stats overridden by upgrade levels.
function PlayerDataService.GetStats(player: Player)
	local stats = table.clone(GameConfig.BaseStats)
	local data = profiles[player]
	local levels = data and data.Upgrades or {}
	for _, u in ipairs(UpgradeConfig.List) do
		stats[u.Stat] = UpgradeConfig.GetValue(u.Id, levels[u.Id] or 1)
	end
	if data then
		local mults = multipliers(data)
		local t = mults.Tree
		stats.ValueMultiplier *= mults.KG
		stats.Luck *= mults.Luck
		stats.SellRate = effectiveSellRate(data)
		stats.Capacity += t.Capacity
		stats.SpawnInterval = math.max(0.05, stats.SpawnInterval / t.Spawn)
		stats.CollectRadius += t.Range
		stats.WalkSpeed += t.Walk
		stats.Tree = t
	end
	return stats
end

function PlayerDataService.AddKG(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 then return end
	data.KG = math.floor((data.KG + amount) * 100 + 0.5) / 100
	data.TotalKG = math.floor((data.TotalKG + amount) * 100 + 0.5) / 100
	if amount > data.HeaviestSushi then data.HeaviestSushi = amount end -- one sushi per call
	syncReplicated(player, data)
end

function PlayerDataService.RecordCollect(player: Player, rarityId: string)
	local data = profiles[player]
	if not data then return end
	data.SushiCollected += 1
	data.RarityCounts[rarityId] = (data.RarityCounts[rarityId] or 0) + 1
	player:SetAttribute("SushiCollected", data.SushiCollected)
	syncTutorial(player, data)
end

-- Records a sushi type for the Sushi Index. Returns true the first time it's found.
function PlayerDataService.RecordDiscovery(player: Player, typeId: string): boolean
	local data = profiles[player]
	if not data or not SushiCatalog.Types[typeId] then return false end
	local isNew = data.Discovered[typeId] == nil
	data.Discovered[typeId] = (data.Discovered[typeId] or 0) + 1
	syncReplicated(player, data)
	if isNew then statsChangedEvent:Fire(player, "Index") end
	return isNew
end

-- Converts ALL of the player's KG to cash at their current rate.
-- Returns kgSold, cashEarned (0, 0 if nothing to sell).
function PlayerDataService.SellAllKG(player: Player): (number, number, boolean)
	local data = profiles[player]
	if not data or data.KG <= 0 then return 0, 0, false end
	local kg = data.KG
	local cash = EconomyConfig.RoundCash(kg * effectiveSellRate(data))
	-- Negotiation / Wholesale / High Roller: chance for a double-pay sale
	local bonus = math.random() < treeEffects(data).SellBonus
	if bonus then cash = EconomyConfig.RoundCash(cash * 2) end
	data.KG = 0
	data.TotalKGSold = math.floor((data.TotalKGSold + kg) * 100 + 0.5) / 100
	data.Money = EconomyConfig.RoundCash(data.Money + cash)
	data.TotalMoney = EconomyConfig.RoundCash(data.TotalMoney + cash)
	syncReplicated(player, data)
	return kg, cash, bonus
end

-- Adds cash directly (Tip Jar). Counts toward lifetime cash.
function PlayerDataService.AddMoney(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 then return end
	data.Money = EconomyConfig.RoundCash(data.Money + amount)
	data.TotalMoney = EconomyConfig.RoundCash(data.TotalMoney + amount)
	syncReplicated(player, data)
end

-- ===== ✨ Ascension =====

function PlayerDataService.CanAscend(player: Player): boolean
	local data = profiles[player]
	return data ~= nil and AscensionConfig.CanAscend(function(id) return SkillTreeConfig.LevelOf(data.Tree, id) > 0 end)
end

-- Ascends: resets Cash, KG, Cash Upgrades and the main Skill Tree; keeps Rebirths, Prestiges and
-- everything else. Gives 1 Ascension Point. Returns the new Ascension count (nil if not allowed).
function PlayerDataService.Ascend(player: Player): number?
	local data = profiles[player]
	if not data or not PlayerDataService.CanAscend(player) then return nil end
	for id in pairs(data.Tree) do
		player:SetAttribute(SkillTreeConfig.AttributeName(id), nil)
		player:SetAttribute(SkillTreeConfig.LevelAttribute(id), nil)
	end
	data.Tree = {}
	treeCache[data] = nil
	data.Money = 0
	data.KG = 0
	data.Upgrades = {}
	data.Ascensions += 1
	data.AscensionPoints += 1
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Tree", "RESET")
	statsChangedEvent:Fire(player, "Reset") -- wipes the pad and resets walk speed
	return data.Ascensions
end

-- Buys one level of an Ascension upgrade (1 AP each). Returns true on success.
function PlayerDataService.BuyAscensionUpgrade(player: Player, id: string): boolean
	local data = profiles[player]
	if not data or not AscensionConfig.ById[id] then return false end
	local level = data.AscensionUpgrades[id] or 1
	local cost = AscensionConfig.GetCost(id, level)
	if not cost or data.AscensionPoints < cost then return false end
	data.AscensionPoints -= cost
	data.AscensionUpgrades[id] = level + 1
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Ascension")
	return true
end

-- ===== 🎣 Sushi Pond =====

function PlayerDataService.GetFishStats(player: Player)
	local data = profiles[player]
	if not data then return nil end
	return FishConfig.GetStats(data.FishUpgrades, PrestigeConfig.GetBoosts(data.PrestigeUpgrades).Fish)
end

-- a catch (called many times a second at max speed, so only the fish attributes are touched)
function PlayerDataService.AddFish(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 then return end
	data.Fish += amount
	data.TotalFish += amount
	player:SetAttribute("Fish", data.Fish)
	player:SetAttribute("TotalFish", data.TotalFish)
end

-- ===== 🗡️ Sushi Slashing =====

function PlayerDataService.GetSliceStats(player: Player)
	local data = profiles[player]
	if not data then return nil end
	return SliceConfig.GetStats(data.SliceUpgrades)
end

-- slices from a slash (or Auto Slash); only the slice attributes are touched
function PlayerDataService.AddSlices(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 then return end
	data.Slices += amount
	data.TotalSlices += amount
	player:SetAttribute("Slices", data.Slices)
	player:SetAttribute("TotalSlices", data.TotalSlices)
end

-- 🍥 Slice Upgrades (paid in Slices). One level, or as many as affordable. Returns levels bought.
function PlayerDataService.BuySliceUpgrade(player: Player, id: string, buyMax: boolean): number
	local data = profiles[player]
	local shop = SliceConfig.Upgrades
	local u = shop.ById[id]
	if not data or not u then return 0 end
	local bought = 0
	for _ = 1, (buyMax and u.Levels or 1) do
		local level = data.SliceUpgrades[id] or 1
		local cost = shop.GetCost(id, level)
		if not cost or data.Slices < cost then break end
		data.Slices -= cost
		data.SliceUpgrades[id] = level + 1
		bought += 1
	end
	if bought > 0 then
		syncReplicated(player, data)
		statsChangedEvent:Fire(player, "Slices")
	end
	return bought
end

-- the cheapest Slice Upgrade level you can afford right now (for Auto Slice Upgrades)
function PlayerDataService.CheapestSliceUpgrade(player: Player): string?
	local data = profiles[player]
	if not data then return nil end
	local best, bestCost = nil, math.huge
	for _, u in ipairs(SliceConfig.Upgrades.List) do
		local cost = SliceConfig.Upgrades.GetCost(u.Id, data.SliceUpgrades[u.Id] or 1)
		if cost and cost <= data.Slices and cost < bestCost then best, bestCost = u.Id, cost end
	end
	return best
end

-- 🔮 One rune roll at an area's altar: pays RollCost of the area's currency, adds the rune.
-- Returns the rune and how many copies you now have (nil if you can't afford it).
function PlayerDataService.RollRune(player: Player, areaId: string, rng: Random)
	local data = profiles[player]
	local area = RuneConfig.AreaById[areaId]
	if not data or not area or (data[area.Currency] or 0) < RuneConfig.RollCost then return nil end
	data[area.Currency] -= RuneConfig.RollCost
	local luck = RuneConfig.GetBoosts(data.Runes).RuneLuck
	local rune = RuneConfig.Roll(rng, areaId, luck)
	local count = (data.Runes[rune.Id] or 0) + 1
	data.Runes[rune.Id] = count
	data.RuneRolls += 1
	if count <= rune.Max then
		-- the rune's boosts just grew: refresh everything that depends on them
		syncReplicated(player, data)
		statsChangedEvent:Fire(player, "Runes")
	else
		player:SetAttribute(area.Currency, data[area.Currency])
		player:SetAttribute(RuneConfig.Attr(rune.Id), count)
		player:SetAttribute("RuneRolls", data.RuneRolls)
	end
	return rune, count
end

-- 🐟 Fish Upgrades (paid in Fish). One level, or as many as affordable. Returns levels bought.
function PlayerDataService.BuyFishUpgrade(player: Player, id: string, buyMax: boolean): number
	local data = profiles[player]
	local shop = FishConfig.Upgrades
	local u = shop.ById[id]
	if not data or not u then return 0 end
	local bought = 0
	for _ = 1, (buyMax and u.Levels or 1) do
		local level = data.FishUpgrades[id] or 1
		local cost = shop.GetCost(id, level)
		if not cost or data.Fish < cost then break end
		data.Fish -= cost
		data.FishUpgrades[id] = level + 1
		bought += 1
	end
	if bought > 0 then
		syncReplicated(player, data)
		statsChangedEvent:Fire(player, "Fish")
	end
	return bought
end

-- ===== 🤖 Automation =====

function PlayerDataService.IsAutomationOn(player: Player, id: string): boolean
	local data = profiles[player]
	return data ~= nil and data.Automation[id] == true and not data.AutomationOff[id]
		and AutomationConfig.IsUnlocked(id, data.TotalRebirths)
end

-- Buys an automation with Prestiges (its area must be unlocked). Returns true on success.
function PlayerDataService.BuyAutomation(player: Player, id: string): boolean
	local data = profiles[player]
	local a = AutomationConfig.ById[id]
	if not data or not a or data.Automation[id] then return false end
	if not AutomationConfig.IsUnlocked(id, data.TotalRebirths) or data.Prestiges < a.Cost then return false end
	data.Prestiges -= a.Cost
	data.Automation[id] = true
	data.AutomationOff[id] = nil
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Automation")
	return true
end

-- Switches an owned automation on or off.
function PlayerDataService.SetAutomation(player: Player, id: string, on: boolean)
	local data = profiles[player]
	if not data or not data.Automation[id] then return end
	data.AutomationOff[id] = if on then nil else true
	player:SetAttribute(AutomationConfig.OnAttr(id), on)
	statsChangedEvent:Fire(player, "Automation")
end

-- the cheapest Fish Upgrade level you can afford right now (for Auto Fish Upgrades)
function PlayerDataService.CheapestFishUpgrade(player: Player): string?
	local data = profiles[player]
	if not data then return nil end
	local best, bestCost = nil, math.huge
	for _, u in ipairs(FishConfig.Upgrades.List) do
		local cost = FishConfig.Upgrades.GetCost(u.Id, data.FishUpgrades[u.Id] or 1)
		if cost and cost <= data.Fish and cost < bestCost then best, bestCost = u.Id, cost end
	end
	return best
end

-- ===== ⭐ Prestige =====

-- Exchanges ALL your Cash for Prestiges (see PrestigeConfig.Gain). Resets Cash, KG and
-- Cash Upgrades (skills are kept). Returns Prestiges gained (0 = not enough Cash).
function PlayerDataService.Prestige(player: Player): number
	local data = profiles[player]
	if not data then return 0 end
	local mults = multipliers(data)
	local gain = PrestigeConfig.Gain(data.Money, mults.PrestigeGain)
	if gain <= 0 then return 0 end
	data.Prestiges += gain
	data.TotalPrestiges += gain
	data.PrestigeCount += 1
	data.Money = mults.HeadStart
	data.KG = 0
	data.Upgrades = {}
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Reset") -- wipes the pad and resets walk speed
	return gain
end

-- ===== 🔄 Rebirth =====

-- A milestone: costs RebirthConfig.Cost Prestiges and resets your progress (Cash, KG,
-- Cash Upgrades, Prestiges + Prestige Upgrades, Fish + Fish Upgrades, Slices + Slice
-- Upgrades). Skills, the Index,
-- lifetime stats and unlocked areas are kept. Returns the new Rebirth count, or nil.
function PlayerDataService.Rebirth(player: Player): number?
	local data = profiles[player]
	if not data then return nil end
	local cost = RebirthConfig.Cost(data.TotalRebirths)
	if data.Prestiges < cost then return nil end
	data.TotalRebirths += 1
	data.Prestiges = 0
	data.PrestigeUpgrades = {}
	data.Money = multipliers(data).HeadStart
	data.KG = 0
	data.Upgrades = {}
	data.Fish = 0
	data.FishUpgrades = {}
	data.Slices = 0
	data.SliceUpgrades = {}
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Reset") -- wipes the pad and resets walk speed
	statsChangedEvent:Fire(player, "Rebirth")
	return data.TotalRebirths
end

-- ⭐ Prestige Upgrades (paid in Prestiges; locked ones need their Rebirth first).
-- One level, or as many as affordable. Returns levels bought.
function PlayerDataService.BuyPrestigeUpgrade(player: Player, id: string, buyMax: boolean): number
	local data = profiles[player]
	local u = PrestigeConfig.ById[id]
	if not data or not u or not PrestigeConfig.IsUnlocked(id, data.TotalRebirths) then return 0 end
	local bought = 0
	for _ = 1, (buyMax and u.Levels or 1) do
		local level = data.PrestigeUpgrades[id] or 1
		local cost = PrestigeConfig.GetCost(id, level)
		if not cost or data.Prestiges < cost then break end
		data.Prestiges -= cost
		data.PrestigeUpgrades[id] = level + 1
		bought += 1
	end
	if bought > 0 then
		syncReplicated(player, data)
		statsChangedEvent:Fire(player, "Prestige")
	end
	return bought
end

-- ===== Profile / Titles / Shop =====

-- equips a title if its requirement is met (checked against the live attributes)
function PlayerDataService.EquipTitle(player: Player, id: string): boolean
	local data = profiles[player]
	if not data or not TitleConfig.ById[id] then return false end
	local _, unlocked = TitleConfig.Progress(player, id)
	if not unlocked then return false end
	data.EquippedTitle = id
	player:SetAttribute("EquippedTitle", id)
	return true
end

function PlayerDataService.SetPassOwned(player: Player, key: string)
	local data = profiles[player]
	if not data or data.Passes[key] then return end
	data.Passes[key] = true
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Shop")
end

function PlayerDataService.AddRobuxSpent(player: Player, amount: number)
	local data = profiles[player]
	if not data or not amount or amount <= 0 then return end
	data.RobuxSpent += amount
	player:SetAttribute("RobuxSpent", data.RobuxSpent)
end

-- developer product rewards (called from the purchase receipt handler)
function PlayerDataService.GrantProduct(player: Player, product, purchaseId: string?): boolean
	local data = profiles[player]
	if not data then return false end
	if purchaseId then
		if data.Receipts[purchaseId] then return true end -- already granted
		data.Receipts[purchaseId] = true
	end
	local g = product.Grant
	if g.Boost then
		local stat, seconds = g.Boost[1], g.Boost[2]
		local now = os.time()
		data.Boosts[stat] = math.max(data.Boosts[stat] or 0, now) + seconds -- stacks
	end
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Shop")
	return true
end

-- re-sync after timed boosts run out (their multipliers change)
function PlayerDataService.RefreshBoosts()
	local now = os.time()
	for player, data in pairs(profiles) do
		local changed = false
		for stat, endTime in pairs(data.Boosts) do
			if endTime <= now then
				data.Boosts[stat] = nil
				player:SetAttribute(ShopConfig.BoostAttr(stat), nil)
				changed = true
			end
		end
		if changed then syncReplicated(player, data) end
	end
end

-- ===== Skill tree =====

function PlayerDataService.GetTree(player: Player)
	local data = profiles[player]
	return data and data.Tree or {}
end

-- Buys the next level of a skill. Returns true, or false + reason ("Maxed"/"Locked"/"Cash").
function PlayerDataService.BuyTreeNode(player: Player, id: string): (boolean, string?)
	local data = profiles[player]
	local node = SkillTreeConfig.ById[id]
	if not data or not node then return false, "Invalid" end
	local state = SkillTreeConfig.GetState(id, data.Tree, data.TotalRebirths)
	if state ~= "Available" then return false, state end
	local level = SkillTreeConfig.LevelOf(data.Tree, id)
	local cost = SkillTreeConfig.GetCost(id, level)
	if not cost then return false, "Maxed" end
	if data.Money < cost then return false, "Cash" end
	data.Money = EconomyConfig.RoundCash(data.Money - cost)
	data.Tree[id] = level + 1
	treeCache[data] = nil
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Tree", id)
	return true
end

function PlayerDataService.GetMoney(player: Player): number
	local data = profiles[player]
	return data and data.Money or 0
end

-- Atomic spend; returns true if the player could afford it.
function PlayerDataService.SpendMoney(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount < 0 or data.Money < amount then return false end
	data.Money = EconomyConfig.RoundCash(data.Money - amount)
	syncReplicated(player, data)
	return true
end

function PlayerDataService.GetUpgradeLevel(player: Player, upgradeId: string): number
	local data = profiles[player]
	return data and (data.Upgrades[upgradeId] or 1) or 1
end

function PlayerDataService.SetUpgradeLevel(player: Player, upgradeId: string, level: number)
	local data = profiles[player]
	if not data then return end
	data.Upgrades[upgradeId] = level
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, upgradeId)
end

function PlayerDataService.GetTotalMoney(player: Player): number
	local data = profiles[player]
	return data and data.TotalMoney or 0
end

-- ===== Rebirth =====

function PlayerDataService.GetMultipliers(player: Player)
	local data = profiles[player]
	if data then return multipliers(data) end
	local m = RebirthConfig.GetMultipliers(0, 0)
	m.CritMultiplier = RebirthConfig.CritMultiplier
	m.Tree = SkillTreeConfig.GetEffects({}, 0)
	m.Shop = ShopConfig.GetPerks({}, {}, os.time())
	return m
end

-- ===== Admin (AdminService checks who is allowed) =====

-- Adds `amount` (can be negative) of a currency; "Rebirths" sets the count instead.
function PlayerDataService.AdminGive(player: Player, key: string, amount: number): boolean
	local data = profiles[player]
	if not data then return false end
	local function add(field: string, total: string?)
		local before = data[field]
		data[field] = math.max(0, before + amount)
		if total and data[field] > before then data[total] += data[field] - before end
	end
	if key == "Cash" then add("Money", "TotalMoney")
	elseif key == "KG" then add("KG", "TotalKG")
	elseif key == "Prestiges" then add("Prestiges", "TotalPrestiges")
	elseif key == "Fish" then add("Fish", "TotalFish")
	elseif key == "Slices" then add("Slices", "TotalSlices")
	elseif key == "AP" then add("AscensionPoints")
	elseif key == "Rebirths" then data.TotalRebirths = math.max(0, math.floor(amount))
	else return false end
	syncReplicated(player, data)
	statsChangedEvent:Fire(player, "Admin")
	return true
end

function PlayerDataService.Start()
	-- Studio-only test hook: ServerStorage.DevTools.Grant:Invoke(player, cash, kg)
	if RunService:IsStudio() then
		local tools = Instance.new("Folder")
		tools.Name = "DevTools"
		tools.Parent = game:GetService("ServerStorage")
		local grant = Instance.new("BindableFunction")
		grant.Name = "Grant"
		grant.OnInvoke = function(player: Player, cash: number?, kg: number?, prestiges: number?, fish: number?)
			local data = profiles[player]
			if not data then return false end
			data.Money += cash or 0
			data.TotalMoney += cash or 0
			data.KG += kg or 0
			data.Prestiges += prestiges or 0
			data.Fish += fish or 0
			syncReplicated(player, data)
			return true
		end
		grant.Parent = tools

		-- Studio-only chat commands for testing: /cash 300000  /kg 50  /rebirths 2  /prestiges 10
		local function onChat(player: Player, message: string)
			local data = profiles[player]
			if not data then return end
			local cmd, arg = string.match(string.lower(message), "^/(%a+)%s*([%d%.]*)")
			local n = tonumber(arg) or 0
			if cmd == "cash" then
				data.Money += n
				data.TotalMoney += n
			elseif cmd == "kg" then
				data.KG += n
			elseif cmd == "rebirths" then
				data.TotalRebirths = math.max(0, math.floor(n))
			elseif cmd == "prestiges" then
				data.Prestiges += math.floor(n)
			elseif cmd == "treeall" then
				for _, node in ipairs(SkillTreeConfig.List) do data.Tree[node.Id] = node.Max end
				treeCache[data] = nil
				statsChangedEvent:Fire(player, "Tree", "ALL")
			elseif cmd == "ascendready" then
				local function grantNode(id)
					if SkillTreeConfig.IsMaxed(id, data.Tree) then return end
					for _, pre in ipairs(SkillTreeConfig.ById[id].Prereqs) do
						if pre ~= "START" then grantNode(pre) end
					end
					data.Tree[id] = SkillTreeConfig.ById[id].Max
				end
				grantNode(AscensionConfig.RequiredNode)
				treeCache[data] = nil
				statsChangedEvent:Fire(player, "Tree", "ALL")
			elseif cmd == "indexall" then
				-- discover every sushi in the Index (counts as 1 collected)
				for id in pairs(SushiCatalog.Types) do
					if not data.Discovered[id] then data.Discovered[id] = 1 end
				end
				statsChangedEvent:Fire(player, "Index")
			elseif cmd == "ap" then
				data.AscensionPoints += math.floor(n)
			elseif cmd == "treereset" then
				for id in pairs(data.Tree) do
					player:SetAttribute(SkillTreeConfig.AttributeName(id), nil)
					player:SetAttribute(SkillTreeConfig.LevelAttribute(id), nil)
				end
				data.Tree = {}
				treeCache[data] = nil
				statsChangedEvent:Fire(player, "Tree", "RESET")
			else
				return
			end
			syncReplicated(player, data)
			print("[DevTools]", player.Name, cmd, n)
		end
		local TextChatService = game:GetService("TextChatService")
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local folder = Instance.new("Folder")
			folder.Name = "DevCommands"
			folder.Parent = TextChatService
			for _, alias in ipairs({ "/cash", "/kg", "/rebirths", "/prestiges", "/treeall", "/treereset", "/ascendready", "/ap", "/indexall" }) do
				local command = Instance.new("TextChatCommand")
				command.Name = alias
				command.PrimaryAlias = alias
				command.Parent = folder
				command.Triggered:Connect(function(source: TextSource, message: string)
					local player = Players:GetPlayerByUserId(source.UserId)
					if player then onChat(player, message) end
				end)
			end
		else
			local function hook(player: Player)
				player.Chatted:Connect(function(msg) onChat(player, msg) end)
			end
			Players.PlayerAdded:Connect(hook)
			for _, p in ipairs(Players:GetPlayers()) do hook(p) end
		end
	end
	Players.PlayerAdded:Connect(load)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(load, p) end
	-- settings changed from the Settings menu (validated against SettingsConfig)
	local setRemote = ReplicatedStorage.Remotes:FindFirstChild("SetSetting")
	if not setRemote then
		setRemote = Instance.new("RemoteEvent")
		setRemote.Name = "SetSetting"
		setRemote.Parent = ReplicatedStorage.Remotes
	end
	setRemote.OnServerEvent:Connect(function(player, settingKey, value)
		local data = profiles[player]
		local clean = SettingsConfig.Validate(settingKey, value)
		if not data or clean == nil then return end
		data.Settings[settingKey] = clean
		player:SetAttribute(SettingsConfig.AttributeName(settingKey), clean)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local data = profiles[player]
		if data then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if PlayerDataService.GetSetting(player, "SavePosition") and root then
				local p = root.Position
				data.LastPosition = { X = p.X, Y = p.Y, Z = p.Z, Zone = player:GetAttribute("Zone") }
			else
				data.LastPosition = nil
			end
		end
		save(player)
		profiles[player] = nil
		freshSessions[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not store then return end
		local threads = {}
		for player in pairs(profiles) do
			table.insert(threads, task.spawn(save, player))
		end
		task.wait(2)
	end)
	-- playtime (Profile / "Dedicated" title) + timed boost expiry
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(10)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, data in pairs(profiles) do
				data.Playtime += dt
				player:SetAttribute("Playtime", math.floor(data.Playtime))
			end
			PlayerDataService.RefreshBoosts()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(save, player)
			end
		end
	end)
end

return PlayerDataService
