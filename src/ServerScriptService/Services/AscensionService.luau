-- AscensionService: the Blood Altar (Ascend), Ascension upgrades and Auto Buy.
-- Ascending is only accepted from inside the Blood Rift, next to the altar, with the
-- requirement met (see AscensionConfig). The data reset lives in PlayerDataService.Ascend.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AscensionConfig = require(ReplicatedStorage.Shared.Config.AscensionConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local AscensionService = {}

local RETURN_DELAY = 2.8 -- seconds of "ascending" (the client fades out) before the teleport home
local lastRequest: { [Player]: number } = {}
local ascending: { [Player]: boolean } = {}

local function throttled(player: Player, gap: number): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < gap then return true end
	lastRequest[player] = now
	return false
end

local function altarPosition(): Vector3?
	local realm = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AscensionRealm")
	local altar = realm and realm:FindFirstChild("BloodAltar")
	return altar and altar:GetPivot().Position
end

local function nearAltar(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = altarPosition()
	if not root or not pos then return false end
	local offset = root.Position - pos
	-- generous: the server sees the character slightly behind the client
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= AscensionConfig.AltarRadius + 8 and math.abs(offset.Y) < 25
end

local function sendHome(player: Player)
	local character = player.Character
	local arrival = ZoneConfig.Resolve(ZoneConfig.ById[ZoneConfig.Default].ArrivalPath, 5)
	if character and arrival and arrival:IsA("BasePart") then
		character:PivotTo(arrival.CFrame + Vector3.new(0, 3, 0))
	end
	player:SetAttribute("Zone", ZoneConfig.Default)
end

local function onRequestAscend(player: Player)
	if ascending[player] or throttled(player, 2) then return false end
	if player:GetAttribute("Zone") ~= "Ascension" or not nearAltar(player) then return false end
	local count = PlayerDataService.Ascend(player)
	if not count then return false end
	ascending[player] = true
	task.delay(RETURN_DELAY, function()
		ascending[player] = nil
		if player.Parent then sendHome(player) end
	end)
	return true, count, player:GetAttribute("AscensionPoints")
end

local function onRequestUpgrade(player: Player, id: any)
	if typeof(id) ~= "string" or not AscensionConfig.ById[id] then return end
	if throttled(player, 0.25) then return end
	if PlayerDataService.BuyAscensionUpgrade(player, id) then
		Remotes.AscensionUpgradePurchased:FireClient(player, id, player:GetAttribute(AscensionConfig.AttributeName(id)), 1)
	end
end

-- 🤖 Auto Buy: every second, buy the cheapest Cash Upgrade you can afford (a few per tick)
local function autoBuy(player: Player)
	if not PlayerDataService.IsLoaded(player) then return end
	if not PlayerDataService.GetMultipliers(player).Ascension.AutoBuy then return end
	if PlayerDataService.GetSetting(player, "AutoBuy") == false then return end
	local total = PlayerDataService.GetTotalMoney(player)
	for _ = 1, 10 do
		local best, bestCost
		for _, u in ipairs(UpgradeConfig.List) do
			if total >= u.UnlockAt then
				local cost = UpgradeConfig.GetCost(u.Id, PlayerDataService.GetUpgradeLevel(player, u.Id))
				if cost and (not bestCost or cost < bestCost) then best, bestCost = u, cost end
			end
		end
		if not best or not PlayerDataService.SpendMoney(player, bestCost) then break end
		PlayerDataService.SetUpgradeLevel(player, best.Id, PlayerDataService.GetUpgradeLevel(player, best.Id) + 1)
	end
end

function AscensionService.Start()
	Remotes.RequestAscend.OnServerInvoke = onRequestAscend
	Remotes.RequestAscensionUpgrade.OnServerEvent:Connect(onRequestUpgrade)
	Players.PlayerRemoving:Connect(function(p)
		lastRequest[p] = nil
		ascending[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(autoBuy, p)
				if not ok then warn("[AutoBuy]", err) end
			end
		end
	end)
end

return AscensionService
