-- RebirthService: validates 🔄 Rebirths (milestones bought with ⭐ Prestiges).
-- The data changes live in PlayerDataService; the pad wipe and walk speed reset react
-- to its StatsChanged("Reset") signal. What each Rebirth unlocks lives in RebirthConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local RebirthService = {}

local lastRequest: { [Player]: number } = {}

function RebirthService.Start()
	local r = Remotes:FindFirstChild("RequestRebirth")
	if not r then
		r = Instance.new("RemoteFunction")
		r.Name = "RequestRebirth"
		r.Parent = Remotes
	end
	;(r :: RemoteFunction).OnServerInvoke = function(player: Player)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 1 then return nil end
		lastRequest[player] = now
		if not PlayerDataService.IsLoaded(player) then return nil end
		return PlayerDataService.Rebirth(player)
	end
	Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil end)
end

return RebirthService
