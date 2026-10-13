--[[
	UpgradeService  (ModuleScript in ServerScriptService)
	=====================================================
	Server side of the upgrade boards: keeps each player's currencies and
	upgrade levels, checks and applies purchases and rebirths, and saves.

	Use it from your own server scripts, e.g. when a player collects sushi:
		local UpgradeService = require(game.ServerScriptService.UpgradeService)
		UpgradeService.AwardCash(player, 5)          -- 5 * their cash multiplier
		local stats = UpgradeService.GetStats(player) -- capacity, spawn interval...
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local Service = {}

local REMOTE_NAME = "UpgradeShopRemote"
local lastRequest = {}
local store = nil

--------------------------------------------------------------------------
-- Currencies (leaderstats)
--------------------------------------------------------------------------

-- Reuses your existing leaderstats/Cash if your game already makes them
local function getStat(player, statName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local stat = leaderstats:FindFirstChild(statName)
	if not stat then
		stat = Instance.new("NumberValue")
		stat.Name = statName
		stat.Parent = leaderstats
	end
	return stat
end

function Service.GetCurrency(player, currencyId)
	return getStat(player, Config.Currencies[currencyId].Stat).Value
end

function Service.SetCurrency(player, currencyId, amount)
	getStat(player, Config.Currencies[currencyId].Stat).Value = amount
end

function Service.AddCurrency(player, currencyId, amount)
	local stat = getStat(player, Config.Currencies[currencyId].Stat)
	stat.Value += amount
end

-- Gives cash with the player's multipliers applied; returns the amount given
function Service.AwardCash(player, baseAmount)
	local amount = baseAmount * Config.GetStats(player).CashMultiplier
	Service.AddCurrency(player, "Cash", amount)
	return amount
end

function Service.GetStats(player)
	return Config.GetStats(player)
end

--------------------------------------------------------------------------
-- Buying and rebirthing
--------------------------------------------------------------------------

local function isLoaded(player)
	return player:GetAttribute("UpgradeDataLoaded") == true
end

-- Returns true, levelsBought, amountSpent  or  false, reason, neededAmount
function Service.Buy(player, upgradeId, buyMax)
	local upgrade = Config.Upgrades[upgradeId]
	if not upgrade then
		return false, "Unknown"
	end
	if not isLoaded(player) then
		return false, "Loading"
	end

	local level = Config.GetLevel(player, upgradeId)
	if level >= upgrade.MaxLevel then
		return false, "Maxed"
	end

	local balance = Service.GetCurrency(player, upgrade.Currency)
	local bought, spent = 0, 0
	repeat
		local cost = Config.GetCost(upgradeId, level)
		if balance < cost then
			break
		end
		balance -= cost
		spent += cost
		level += 1
		bought += 1
	until not buyMax or level >= upgrade.MaxLevel

	if bought == 0 then
		return false, "TooPoor", Config.GetCost(upgradeId, level)
	end

	Service.SetCurrency(player, upgrade.Currency, balance)
	player:SetAttribute("Upg_" .. upgradeId, level)
	return true, bought, spent
end

-- Returns true, rebirthsGained  or  false, reason, neededCash
function Service.Rebirth(player)
	if not isLoaded(player) then
		return false, "Loading"
	end
	local requirement = Config.GetRebirthRequirement(player)
	if Service.GetCurrency(player, "Cash") < requirement then
		return false, "TooPoor", requirement
	end

	local gain = Config.GetRebirthGain(player)
	Service.SetCurrency(player, "Cash", 0)
	for upgradeId, upgrade in Config.Upgrades do
		if upgrade.ResetOnRebirth then
			player:SetAttribute("Upg_" .. upgradeId, 0)
		end
	end
	Service.AddCurrency(player, "Rebirths", gain)
	player:SetAttribute("RebirthCount", Config.GetRebirthCount(player) + 1)
	return true, gain
end

--------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------

local function dataKey(player)
	return "Player_" .. player.UserId
end

local function load(player)
	local data = nil
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(dataKey(player))
		end)
		if ok then
			data = result
		else
			warn("[UpgradeService] Could not load data for " .. player.Name .. ": " .. tostring(result))
		end
	end
	data = data or {}

	for upgradeId in Config.Upgrades do
		player:SetAttribute("Upg_" .. upgradeId, (data.Levels and data.Levels[upgradeId]) or 0)
	end
	player:SetAttribute("RebirthCount", data.RebirthCount or 0)
	if data.Rebirths then
		Service.SetCurrency(player, "Rebirths", data.Rebirths)
	end
	if Config.SaveCash and data.Cash then
		Service.SetCurrency(player, "Cash", data.Cash)
	end
	player:SetAttribute("UpgradeDataLoaded", true)
end

local function save(player)
	if not store or not isLoaded(player) then
		return
	end
	local levels = {}
	for upgradeId in Config.Upgrades do
		levels[upgradeId] = Config.GetLevel(player, upgradeId)
	end
	local data = {
		Levels = levels,
		RebirthCount = Config.GetRebirthCount(player),
		Rebirths = Service.GetCurrency(player, "Rebirths"),
		Cash = if Config.SaveCash then Service.GetCurrency(player, "Cash") else nil,
	}
	local ok, err = pcall(function()
		store:SetAsync(dataKey(player), data)
	end)
	if not ok then
		warn("[UpgradeService] Could not save data for " .. player.Name .. ": " .. tostring(err))
	end
end

--------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------

local function onPlayerAdded(player)
	-- Let your own PlayerAdded scripts create leaderstats first, then reuse them
	task.wait()
	getStat(player, Config.Currencies.Cash.Stat)
	getStat(player, Config.Currencies.Rebirths.Stat)
	load(player)
end

function Service.Start()
	if Config.UseDataStore then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStoreName)
		end)
		if ok then
			store = result
		else
			warn("[UpgradeService] DataStores unavailable, progress won't save: " .. tostring(result))
		end
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage

	remote.OnServerInvoke = function(player, action, upgradeId, buyMax)
		-- Ignore spam faster than 20 requests a second
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 0.05 then
			return false, "Slow"
		end
		lastRequest[player] = now

		if action == "Buy" and typeof(upgradeId) == "string" then
			return Service.Buy(player, upgradeId, buyMax == true)
		elseif action == "Rebirth" then
			return Service.Rebirth(player)
		end
		return false, "Unknown"
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		lastRequest[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		task.wait(2)
	end)

	-- Autosave every 2 minutes
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	-- Free test cash in Studio only
	if RunService:IsStudio() and Config.StudioTestIncome > 0 then
		task.spawn(function()
			while true do
				task.wait(1)
				for _, player in Players:GetPlayers() do
					if isLoaded(player) then
						Service.AddCurrency(player, "Cash", Config.StudioTestIncome)
					end
				end
			end
		end)
	end
end

return Service
