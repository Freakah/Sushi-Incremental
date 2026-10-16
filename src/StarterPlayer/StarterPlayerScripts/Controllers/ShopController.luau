-- ShopController: the 🛒 Shop menu. Game passes (permanent) and products (one-off packs).
-- Items whose Id is still 0 in ShopConfig show "Coming soon".

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local UIKit = require(script.Parent.UIKit)
local EffectsController = require(script.Parent.EffectsController)
local AnnouncementController = require(script.Parent.AnnouncementController)

local player = Players.LocalPlayer
local ShopController = {}

local C = Color3.fromRGB
local GREEN = C(90, 230, 90)
local CARD_W, CARD_H = 192, 256

local window
local cards = {}
local prices = {} -- [id] = robux price from Roblox

local function mmss(s: number): string
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function refresh()
	local now = workspace:GetServerTimeNow()
	for _, c in ipairs(cards) do
		local item = c.Item
		local owned = c.IsPass and player:GetAttribute(ShopConfig.PassAttr(item.Key)) == true
		if owned then
			c.Button.SetColors(UIKit.Gradients.Gold)
			c.Button.SetText("Owned ✔")
		elseif item.Id == 0 then
			c.Button.SetColors(UIKit.Gradients.Dark)
			c.Button.SetText("Coming soon")
		else
			c.Button.SetColors(UIKit.Gradients.On)
			c.Button.SetText("R$ " .. (prices[item.Id] or item.Price))
		end
		-- boosts: time left
		local boost = item.Grant and item.Grant.Boost
		if boost then
			local left = (player:GetAttribute(ShopConfig.BoostAttr(boost[1])) or 0) - now
			c.Timer.Visible = left > 0
			if left > 0 then c.Timer.Text = "⏱️ " .. mmss(math.floor(left)) .. " left" end
		end
	end
end

local function buy(c)
	local item = c.Item
	if c.IsPass and player:GetAttribute(ShopConfig.PassAttr(item.Key)) then return end
	if item.Id == 0 then
		c.Button.SetText("Soon™ 😉")
		task.delay(1, refresh)
		return
	end
	if c.IsPass then
		MarketplaceService:PromptGamePassPurchase(player, item.Id)
	else
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end
end

-- ui-pack icons for the items that have one (the rest keep their emoji)
local ICONS = { DoubleCash = UIKit.Icons.Cash, DoubleSushi = UIKit.Icons.Sushi, CashBoost = UIKit.Icons.Potion, LuckBoost = UIKit.Icons.Potion }

local function card(parent, item, isPass: boolean, order: number)
	local f = UIKit.new("Frame", { Name = item.Key, LayoutOrder = order, BackgroundColor3 = C(255, 255, 255) }, parent)
	UIKit.Corner(f, 18)
	UIKit.Stroke(f, 3.5, isPass and GREEN or C(120, 200, 255), true)
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(118, 118, 126), C(82, 82, 90)) }, f)
	UIKit.Icon(f, ICONS[item.Key] or item.Icon, { Name = "Icon", Size = UDim2.fromOffset(84, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12) })
	UIKit.Label(f, { Name = "ItemName", Text = item.Name, Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 100),
		TextColor3 = isPass and C(150, 255, 140) or C(150, 215, 255) }, 3)
	UIKit.Label(f, { Name = "Desc", Text = item.Desc, TextColor3 = UIKit.Colors.Subtle, TextWrapped = true,
		Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 136) }, 2)
	local timer = UIKit.Label(f, { Name = "Timer", Text = "", Visible = false, TextColor3 = C(255, 225, 90), ZIndex = 2,
		Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, -6) }, 2.5)
	local c = { Item = item, IsPass = isPass, Timer = timer }
	c.Button = UIKit.Button(f, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 56) },
		function() buy(c) end)
	table.insert(cards, c)
end

local function section(list, text: string, order: number, color: Color3)
	UIKit.Label(list, { Name = text, Text = text, TextColor3 = color, LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -10, 0, 40) }, 3)
	local grid = UIKit.new("Frame", { Name = text .. "Grid", LayoutOrder = order + 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, list)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(CARD_W, CARD_H), CellPadding = UDim2.fromOffset(12, 16),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, grid)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, grid)
	return grid
end

local function loadPrices()
	local function get(id, kind)
		if id == 0 or prices[id] then return end
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, kind)
		if ok and info and info.PriceInRobux then prices[id] = info.PriceInRobux end
	end
	for _, p in ipairs(ShopConfig.Passes) do get(p.Id, Enum.InfoType.GamePass) end
	for _, p in ipairs(ShopConfig.Products) do get(p.Id, Enum.InfoType.Product) end
	if window.IsOpen() then refresh() end
end

function ShopController.Toggle() window.Toggle() end

function ShopController.Init()
	window = UIKit.Window({ Name = "Shop", Title = "Shop", Icon = UIKit.Icons.Shop, Accent = GREEN, Size = Vector2.new(900, 660) })
	local list = UIKit.List(window.Body, 6)
	local passes = section(list, "⭐ Game Passes", 1, C(150, 255, 140))
	for i, p in ipairs(ShopConfig.Passes) do card(passes, p, true, i) end
	local products = section(list, "⚡ Boosts & Packs", 3, C(150, 215, 255))
	for i, p in ipairs(ShopConfig.Products) do card(products, p, false, i) end

	table.insert(window.OnOpen, refresh)
	task.spawn(loadPrices)
	task.spawn(function()
		while true do
			task.wait(1)
			if window.IsOpen() then refresh() end
		end
	end)

	-- purchase went through: celebrate
	task.spawn(function()
		local granted = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopGranted", 30)
		if not granted then return end
		granted.OnClientEvent:Connect(function(key: string)
			local item = ShopConfig.PassByKey[key] or ShopConfig.ProductByKey[key]
			if not item then return end
			AnnouncementController.Show("🎉 Thanks! " .. item.Name .. " " .. item.Icon, C(120, 255, 120), ShopConfig.PassByKey[key] ~= nil)
			EffectsController.PlaySound("Upgrade", 0.8)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then EffectsController.Burst(root.Position, C(255, 220, 80), 30) end
			refresh()
		end)
	end)
end

return ShopController
