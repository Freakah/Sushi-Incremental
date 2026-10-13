-- SkillTreeService: validates skill tree purchases from the Skills menu (works from
-- anywhere); the server checks prerequisites, level and cash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SkillTreeService = {}

local lastRequest: { [Player]: number } = {}

local function onBuy(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then return false, "Invalid" end
	local node = SkillTreeConfig.ById[id]
	if not node then return false, "Invalid" end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.1 then return false, "Busy" end
	lastRequest[player] = now

	return PlayerDataService.BuyTreeNode(player, id)
end

function SkillTreeService.Start()
	local remote = ReplicatedStorage.Remotes:FindFirstChild("BuyTreeNode")
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = "BuyTreeNode"
		remote.Parent = ReplicatedStorage.Remotes
	end
	remote.OnServerInvoke = onBuy
	Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil end)
end

return SkillTreeService
