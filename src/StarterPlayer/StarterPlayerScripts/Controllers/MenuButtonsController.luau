-- MenuButtonsController: the square menu tiles on the left of the screen.
-- Add a tile = one entry in TILES.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)
local IndexController = require(script.Parent.IndexController)
local SettingsController = require(script.Parent.SettingsController)
local TitlesController = require(script.Parent.TitlesController)
local ProfileController = require(script.Parent.ProfileController)
local ShopController = require(script.Parent.ShopController)
local SkillTreeUIController = require(script.Parent.SkillTreeUIController)
local RunesMenuController = require(script.Parent.RunesMenuController)

local player = Players.LocalPlayer
local MenuButtonsController = {}

local C = Color3.fromRGB
-- Uploaded tile art (rbxassetid). A tile with an image uses it instead of the drawn tile.
local IMAGES = {
	Index = "rbxassetid://96937370943130",
	Titles = "rbxassetid://117146413677318",
	Profile = "rbxassetid://131863728371191",
	Shop = "rbxassetid://126583145295847",
	Settings = "rbxassetid://75302516623930",
}
local TILES = {
	{ Name = "Index", Icon = "📖", Text = "Index", Colors = { C(125, 205, 255), C(45, 125, 230) }, Open = function() IndexController.Toggle() end, Badge = function() return IndexController.HasNew() end },
	{ Name = "Skills", Icon = "🌳", Text = "Skills", Colors = { C(150, 240, 120), C(30, 160, 110) }, Open = function() SkillTreeUIController.Toggle() end, Badge = function() return SkillTreeUIController.HasAffordable() end },
	{ Name = "Titles", Icon = "🏷️", Text = "Titles", Colors = { C(255, 225, 90), C(230, 160, 20) }, Open = function() TitlesController.Toggle() end, Badge = function() return TitlesController.HasNew() end },
	{ Name = "Runes", Icon = "🔮", Text = "Runes", Colors = { C(150, 235, 255), C(90, 110, 240) }, Open = function() RunesMenuController.Toggle() end, Badge = function() return RunesMenuController.HasNew() end },
	{ Name = "Profile", Icon = "👤", Text = "Profile", Colors = { C(120, 225, 255), C(30, 150, 230) }, Open = function() ProfileController.Toggle() end },
	{ Name = "Shop", Icon = "🛒", Text = "Shop", Colors = { C(130, 240, 110), C(40, 170, 60) }, Open = function() ShopController.Toggle() end },
	{ Name = "Settings", Icon = "⚙️", Text = "Settings", Colors = { C(190, 190, 198), C(110, 110, 120) }, Open = function() SettingsController.Toggle() end },
}

function MenuButtonsController.Init()
	local gui = UIKit.new("ScreenGui", { Name = "MenuButtons", ResetOnSpawn = false, DisplayOrder = 25 }, player:WaitForChild("PlayerGui"))
	local holder = UIKit.new("Frame", {
		Name = "Tiles",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(84 * 2 + 12, 420),
	}, gui)
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(84, 84),
		CellPadding = UDim2.fromOffset(12, 16),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, holder)
	local scale = UIKit.new("UIScale", {}, holder)
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.6, 1.1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	local badges = {}
	for i, t in ipairs(TILES) do
		local image = IMAGES[t.Name]
		local tile = UIKit.Tile(holder, { Name = t.Name, Icon = t.Icon, Text = t.Text, Colors = t.Colors, Order = i, Image = image }, t.Open)
		if t.Badge then table.insert(badges, { Frame = tile.Badge, Check = t.Badge }) end
	end
	RunService.RenderStepped:Connect(function()
		local pulse = 28 * (1 + math.sin(os.clock() * 6) * 0.12)
		for _, b in ipairs(badges) do
			b.Frame.Visible = b.Check()
			if b.Frame.Visible then b.Frame.Size = UDim2.fromOffset(pulse, pulse) end
		end
	end)
end

return MenuButtonsController
