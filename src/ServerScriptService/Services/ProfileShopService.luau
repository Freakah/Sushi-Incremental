-- ProfileShopService: titles (equip + the "@Name [Title]" tag over every player's head)
-- and the Robux shop (game pass ownership, developer product receipts).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes
local ProfileShopService = {}

local function remote(name: string, className: string)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

-- ===== nametag =====

local function label(parent, name, y, h, size)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Thickness = size
	s.Color = Color3.fromRGB(20, 20, 26)
	s.Parent = l
	l.Parent = parent
	return l, s
end

local function applyTitle(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("Nametag")
	if not tag then return end
	local t = TitleConfig.ById[player:GetAttribute("EquippedTitle") or ""] or TitleConfig.ById[TitleConfig.Default]
	local titleLabel = tag:FindFirstChild("Title")
	titleLabel.Text = "[" .. t.Name .. "]"
	titleLabel.TextColor3 = t.Color
	titleLabel:FindFirstChildOfClass("UIStroke").Color = t.Gold and Color3.fromRGB(120, 80, 0) or Color3.fromRGB(20, 20, 26)
	tag:SetAttribute("Rainbow", t.Rainbow == true) -- clients animate these
	local nameLabel = tag:FindFirstChild("PlayerName")
	nameLabel.TextColor3 = player:GetAttribute(ShopConfig.PassAttr("VIP")) and Color3.fromRGB(255, 215, 60) or Color3.new(1, 1, 1)
end

local function buildTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not head or not humanoid then return end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our tag replaces the default name
	local old = head:FindFirstChild("Nametag")
	if old then old:Destroy() end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nametag"
	bb.Size = UDim2.fromOffset(200, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb:SetAttribute("Owner", player.UserId)
	label(bb, "PlayerName", 0, 0.56, 2.5).Text = "@" .. player.Name
	label(bb, "Title", 0.54, 0.46, 2)
	bb.Parent = head
	applyTitle(player)
end

-- ===== shop =====

local function checkPasses(player: Player)
	for _, p in ipairs(ShopConfig.Passes) do
		if p.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.Id)
			if ok and owns then PlayerDataService.SetPassOwned(player, p.Key) end
		end
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = ShopConfig.ProductById[receipt.ProductId]
	if not player or not product or not PlayerDataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end
	if not PlayerDataService.GrantProduct(player, product, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerDataService.AddRobuxSpent(player, receipt.CurrencySpent)
	Remotes.ShopGranted:FireClient(player, product.Key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ProfileShopService.Start()
	local equip = remote("EquipTitle", "RemoteFunction") :: RemoteFunction
	equip.OnServerInvoke = function(player, id)
		if typeof(id) ~= "string" then return false end
		local ok = PlayerDataService.EquipTitle(player, id)
		if ok then applyTitle(player) end
		return ok
	end
	remote("ShopGranted", "RemoteEvent")

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(c) buildTag(player, c) end)
		if player.Character then task.spawn(buildTag, player, player.Character) end
		player:GetAttributeChangedSignal("EquippedTitle"):Connect(function() applyTitle(player) end)
		player:GetAttributeChangedSignal(ShopConfig.PassAttr("VIP")):Connect(function() applyTitle(player) end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

	PlayerDataService.PlayerLoaded:Connect(function(player) task.spawn(checkPasses, player) end)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.IsLoaded(p) then task.spawn(checkPasses, p) end
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local p = ShopConfig.PassById[passId]
		if purchased and p then
			PlayerDataService.SetPassOwned(player, p.Key)
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
			PlayerDataService.AddRobuxSpent(player, ok and info and info.PriceInRobux or p.Price)
			Remotes.ShopGranted:FireClient(player, p.Key)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return ProfileShopService
