-- PrestigeService: validates ⭐ Prestige (Cash -> Prestiges) and Prestige Upgrade purchases.
-- The data changes live in PlayerDataService; the pad wipe and walk speed reset react
-- to its StatsChanged("Reset") signal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local PrestigeService = {}

local lastRequest: { [Player]: number } = {}

local function remote(name: string, className: string)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local function throttled(player: Player, gap: number): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < gap then return true end
	lastRequest[player] = now
	return false
end

function PrestigeService.Start()
	local prestige = remote("RequestPrestige", "RemoteFunction") :: RemoteFunction
	prestige.OnServerInvoke = function(player: Player)
		if not PlayerDataService.IsLoaded(player) or throttled(player, 1) then return 0 end
		return PlayerDataService.Prestige(player)
	end

	local purchased = remote("PrestigeUpgradePurchased", "RemoteEvent") :: RemoteEvent
	;(remote("RequestPrestigeUpgrade", "RemoteEvent") :: RemoteEvent).OnServerEvent:Connect(function(player: Player, id: any, buyMax: any)
		if typeof(id) ~= "string" or not PrestigeConfig.ById[id] then return end
		if not PlayerDataService.IsLoaded(player) or throttled(player, 0.12) then return end
		local bought = PlayerDataService.BuyPrestigeUpgrade(player, id, buyMax == true)
		if bought > 0 then
			purchased:FireClient(player, id, player:GetAttribute(PrestigeConfig.AttributeName(id)), bought)
		end
	end)

	Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil end)
end

return PrestigeService
