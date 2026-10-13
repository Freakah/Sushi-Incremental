-- EconomyService: server-validated KG -> Cash selling at any sell stall.
-- Sell stalls are parts tagged "SellZone" (one per zone).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local EconomyService = {}

local SELL_TAG = "SellZone"
local lastSell: { [Player]: number } = {}

local function isAtMarket(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	for _, sellZone in ipairs(CollectionService:GetTagged(SELL_TAG)) do
		if sellZone:IsA("BasePart") and sellZone:IsDescendantOf(workspace) then
			local offset = root.Position - sellZone.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= EconomyConfig.ServerSellRadius and math.abs(offset.Y) < 60 then
				return true
			end
		end
	end
	return false
end

local function onRequestSell(player: Player)
	local now = os.clock()
	if now - (lastSell[player] or 0) < EconomyConfig.SellCooldown then return end
	lastSell[player] = now
	if not isAtMarket(player) then return end

	local kg, cash, bonus = PlayerDataService.SellAllKG(player)
	if kg > 0 then
		Remotes.Sold:FireClient(player, kg, cash, bonus)
	end
end

function EconomyService.Start()
	Remotes.RequestSell.OnServerEvent:Connect(onRequestSell)
	Players.PlayerRemoving:Connect(function(p) lastSell[p] = nil end)
end

return EconomyService
