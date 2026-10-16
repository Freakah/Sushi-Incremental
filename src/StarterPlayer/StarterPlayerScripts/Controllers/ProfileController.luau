-- ProfileController: the Profile menu (like the reference): name + avatar on the left,
-- lifetime stats on the right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local SushiCatalog = require(ReplicatedStorage.Shared.Config.SushiCatalog)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local ProfileController = {}

local C = Color3.fromRGB
local CYAN = C(40, 200, 255)

local window
local rows = {}
local titleLabel: TextLabel

local function attr(name) return player:GetAttribute(name) or 0 end

local function playtime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end

local sushiTypes = 0
for _ in pairs(SushiCatalog.Types) do sushiTypes += 1 end

local function unlockedTitles(): number
	local n = 0
	for _, t in ipairs(TitleConfig.List) do
		local _, ok = TitleConfig.Progress(player, t.Id)
		if ok then n += 1 end
	end
	return n
end

-- { icon, word, color, value() }
local STATS = {
	{ UIKit.Icons.Cash, "Cash", C(90, 255, 110), function() return NumberFormat.Format(attr("TotalMoney")) end },
	{ "⏱️", "Playtime", C(80, 215, 255), function() return playtime(attr("Playtime")) end },
	{ UIKit.Icons.Fish, "Fish", C(110, 200, 255), function() return NumberFormat.Format(attr("TotalFish")) end },
	{ UIKit.Icons.Rebirth, "Rebirths", C(255, 80, 95), function() return NumberFormat.Format(attr("TotalRebirths")) end },
	{ UIKit.Icons.Prestige, "Prestiges", C(255, 215, 70), function() return NumberFormat.Format(attr("TotalPrestiges")) end },
	{ UIKit.Icons.Sushi, "Sushi", C(255, 225, 70), function() return NumberFormat.Format(attr("SushiCollected")) end },
	{ UIKit.Icons.KG, "Weight", C(255, 180, 80), function() return NumberFormat.KG(attr("TotalKG")) end },
	{ UIKit.Icons.Index, "Index", C(95, 185, 255), function() return attr("IndexCount") .. "/" .. sushiTypes end },
	{ "🌸", "Upgrades", C(255, 140, 200), function() return attr("TreeCount") .. "/" .. SkillTreeConfig.Count end },
	{ UIKit.Icons.Titles, "Titles", C(255, 210, 60), function() return unlockedTitles() .. "/" .. #TitleConfig.List end },
	{ "💎", "Robux", C(90, 255, 110), function() return NumberFormat.Format(attr("RobuxSpent")) end },
}

local function refresh()
	for _, r in ipairs(rows) do r.Value.Text = r.Get() end
	local t = TitleConfig.ById[player:GetAttribute("EquippedTitle") or ""] or TitleConfig.ById[TitleConfig.Default]
	titleLabel.Text = "[" .. t.Name .. "]"
	titleLabel.TextColor3 = t.Color
end

function ProfileController.Toggle() window.Toggle() end

function ProfileController.Init()
	window = UIKit.Window({ Name = "Profile", Title = "Profile", Icon = UIKit.Icons.Profile, Accent = CYAN, Size = Vector2.new(860, 560) })
	local body = window.Body
	body:FindFirstChildOfClass("UIStroke").Color = CYAN

	-- left: name, avatar, equipped title
	local left = UIKit.new("Frame", { Name = "Card", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0, 230, 1, -28), BackgroundColor3 = UIKit.Colors.Panel }, body)
	UIKit.Corner(left, 16)
	UIKit.Stroke(left, 3.5, CYAN, true)
	UIKit.Label(left, { Name = "Name", Text = player.Name, TextColor3 = CYAN, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 12) }, 3)
	local frame = UIKit.new("Frame", { Name = "Avatar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(186, 186), BackgroundColor3 = C(255, 255, 255) }, left)
	UIKit.Corner(frame, 24)
	UIKit.Stroke(frame, 4, CYAN, true)
	local img = UIKit.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "" }, frame)
	UIKit.Corner(img, 24)
	task.spawn(function()
		local ok, content = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		if ok then img.Image = content end
	end)
	titleLabel = UIKit.Label(left, { Name = "Title", Text = "", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 262) }, 3)
	UIKit.Label(left, { Name = "Hint", Text = "Change your title in 🏷️ Titles", TextColor3 = UIKit.Colors.Subtle, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 298) }, 2)

	-- right: stat rows
	local holder = UIKit.new("Frame", { Name = "Stats", BackgroundTransparency = 1, Position = UDim2.fromOffset(256, 0), Size = UDim2.new(1, -256, 1, 0) }, body)
	local list = UIKit.List(holder, 8)
	for i, s in ipairs(STATS) do
		local row = UIKit.new("Frame", { Name = s[2], LayoutOrder = i, Size = UDim2.new(1, -6, 0, 62), BackgroundColor3 = UIKit.Colors.Row }, list)
		UIKit.Corner(row, 14)
		UIKit.Stroke(row, 3, CYAN, true)
		UIKit.Icon(row, s[1], { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(12, 9) })
		UIKit.Label(row, { Text = 'Total <font color="#' .. s[3]:ToHex() .. '">' .. s[2] .. "</font>", TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.6, -64, 0, 38), Position = UDim2.fromOffset(64, 12) }, 3)
		local value = UIKit.Label(row, { Text = "", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0.4, -16, 0, 34), Position = UDim2.new(1, -16, 0, 14) }, 3)
		table.insert(rows, { Value = value, Get = s[4] })
	end

	table.insert(window.OnOpen, refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			if window.IsOpen() then refresh() end
		end
	end)
end

return ProfileController
