local UIKit = require(script.Parent.UIKit)
-- AnnouncementController: top banner when a very rare sushi spawns for you,
-- and a server-wide chat message when anyone collects a Mythic/Secret.

local Players = game:GetService("Players")
local TweenService = UIKit.TweenService
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RarityConfig = require(Shared.Config.RarityConfig)
local SushiCatalog = require(Shared.Config.SushiCatalog)
local NumberFormat = require(Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer
local AnnouncementController = {}

local banner: Frame
local bannerText: TextLabel
local bannerGradient: UIGradient
local queue = {}
local showing = false

local function showNext()
	if #queue>0 then local item=table.remove(queue,1);UIKit.Toast(item.Text,item.Color);showing=false;if #queue>0 then task.defer(showNext) end;return end
	if showing or #queue == 0 then return end
	showing = true
	local item = table.remove(queue, 1)
	bannerText.Text = item.Text
	banner.BackgroundColor3 = item.Rainbow and UIKit.Theme.White or item.Color
	if item.Rainbow then
		local keys = {}
		for i = 0, 6 do
			table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.6, 1)))
		end
		bannerGradient.Color = ColorSequence.new(keys)
		bannerGradient.Rotation = 0
	else
		bannerGradient.Color = ColorSequence.new(UIKit.Theme.White, UIKit.Theme.Colors.Rice.Base)
		bannerGradient.Rotation = 90
	end
	banner.Position = UDim2.new(0.5, 0, 0, -120)
	banner.Visible = true
	EffectsController.PlaySound("RareSpawn")
	local inTween = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 18) })
	inTween:Play()
	task.delay(2.6, function()
		local out = TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -120) })
		out:Play()
		out.Completed:Wait()
		banner.Visible = false
		showing = false
		showNext()
	end)
end

function AnnouncementController.RareSpawned(typeId: string)
	local def = SushiCatalog.Types[typeId]
	local rarity = RarityConfig.ById[def.Rarity]
	table.insert(queue, {
		Text = "✨ A " .. string.upper(rarity.Id) .. " " .. def.Name .. " appeared! ✨",
		Color = rarity.Color,
		Rainbow = rarity.Rainbow,
	})
	showNext()
end

-- Generic banner (used by the Sushi Index for new discoveries)
function AnnouncementController.Show(text: string, color: Color3, rainbow: boolean?)
	table.insert(queue, { Text = text, Color = color, Rainbow = rainbow })
	showNext()
end

local function onRareFound(displayName: string, typeId: string, kg: number)
	local def = SushiCatalog.Types[typeId]
	if not def then return end
	local rarity = RarityConfig.ById[def.Rarity]
	local hex = rarity.Color:ToHex()
	local msg = string.format(
		'<font color="#%s"><b>[%s]</b></font> %s collected a %s (%s)!',
		hex, string.upper(rarity.Id), displayName, def.Name, NumberFormat.KG(kg)
	)
	pcall(function()
		local channel = TextChatService:WaitForChild("TextChannels", 5):WaitForChild("RBXSystem", 5)
		channel:DisplaySystemMessage(msg)
	end)
end

function AnnouncementController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Announcements"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Size = UIKit.Theme.Layout.AnnouncementController.Size1
	banner.Visible = false
	banner.Parent = gui
	Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 16)
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = UIKit.Theme.Colors.Rice.Dark
	st.Parent = banner
	bannerGradient = Instance.new("UIGradient")
	bannerGradient.Color = ColorSequence.new(UIKit.Theme.White, UIKit.Theme.Colors.Rice.Base)
	bannerGradient.Rotation = 90
	bannerGradient.Parent = banner
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = UIKit.Theme.Layout.AnnouncementController.Size2
	sizeLimit.Parent = banner

	bannerText = Instance.new("TextLabel")
	bannerText.BackgroundTransparency = 1
	bannerText.Size = UIKit.Theme.Layout.AnnouncementController.Size3
	bannerText.Position = UDim2.fromOffset(12, 6)
	bannerText.Font = UIKit.Font
	bannerText.TextScaled = true
	bannerText.TextColor3 = UIKit.Theme.White
	bannerText.Parent = banner
	local ts = Instance.new("UIStroke")
	ts.Thickness = 3
	ts.Color = UIKit.Theme.Colors.Rice.Dark
	ts.Parent = bannerText

	ReplicatedStorage.Remotes.RareFound.OnClientEvent:Connect(onRareFound)
end

return AnnouncementController
