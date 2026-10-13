-- UpgradeService: validates and applies upgrade purchases, and applies
-- character-side stats (walk speed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local UpgradeService = {}

local MAX_BATCH = 100 -- safety cap for Buy Max
local lastRequest: { [Player]: number } = {}

local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerDataService.GetStats(player).WalkSpeed
	end
end

-- Buys one level; returns true on success.
local function buyOne(player: Player, u): boolean
	local level = PlayerDataService.GetUpgradeLevel(player, u.Id)
	local cost = UpgradeConfig.GetCost(u.Id, level)
	if not cost then return false end -- maxed
	if not PlayerDataService.SpendMoney(player, cost) then return false end
	PlayerDataService.SetUpgradeLevel(player, u.Id, level + 1)
	return true
end

local function onRequestUpgrade(player: Player, upgradeId: any, buyMax: any)
	if typeof(upgradeId) ~= "string" then return end
	local u = UpgradeConfig.ById[upgradeId]
	if not u or not PlayerDataService.IsLoaded(player) then return end

	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.12 then return end
	lastRequest[player] = now

	if PlayerDataService.GetTotalMoney(player) < u.UnlockAt then return end

	local bought = 0
	local limit = (buyMax == true) and MAX_BATCH or 1
	while bought < limit and buyOne(player, u) do
		bought += 1
	end

	if bought > 0 then
		Remotes.UpgradePurchased:FireClient(player, u.Id, PlayerDataService.GetUpgradeLevel(player, u.Id), bought)
	end
end

local function onPlayerLoaded(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(applyWalkSpeed, player)
	end)
	applyWalkSpeed(player)
end

function UpgradeService.Start()
	Remotes.RequestUpgrade.OnServerEvent:Connect(onRequestUpgrade)
	PlayerDataService.StatsChanged:Connect(function(player, reason)
		if reason == "Reset" or reason == "Tree" then applyWalkSpeed(player) end
	end)
	PlayerDataService.PlayerLoaded:Connect(onPlayerLoaded)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.IsLoaded(p) then onPlayerLoaded(p) end
	end
	Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil end)
end

return UpgradeService
