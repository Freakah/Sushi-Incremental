local UIKit = require(script.Parent.UIKit)
-- TitlesController: the 🏷️ Titles menu. Every title with its requirement, a progress
-- bar and an Equip button. The equipped title shows in brackets under your name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer
local TitlesController = {}

local GOLD = UIKit.Theme.Colors.Primary.Base

local window
local rows = {}
local rainbows = {}
local busy = false
local seen = {} -- titles unlocked when the menu was last open (for the "!" badge)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, UIKit.Theme.Colors.Danger.Base),
	ColorSequenceKeypoint.new(0.2, UIKit.Theme.Colors.Primary.Base),
	ColorSequenceKeypoint.new(0.4, UIKit.Theme.Colors.Success.Base),
	ColorSequenceKeypoint.new(0.6, UIKit.Theme.Currency.Fish.Base),
	ColorSequenceKeypoint.new(0.8, UIKit.Theme.Currency.Fish.Base),
	ColorSequenceKeypoint.new(1, UIKit.Theme.Colors.Danger.Base),
})
TitlesController.RAINBOW = RAINBOW

local function reqValue(t): string
	local v = TitleConfig.Value(player, t.Req[1])
	local need = t.Req[2]
	if need <= 1 then return v >= 1 and "1/1" or "0/1" end
	local fmt = t.Req[1] == "TotalMoney" and NumberFormat.Format or function(n) return NumberFormat.Format(math.floor(n)) end
	if t.Req[1] == "Playtime" then
		return math.floor(math.min(v, need) / 3600) .. "h/" .. math.floor(need / 3600) .. "h"
	end
	return fmt(math.min(v, need)) .. "/" .. fmt(need)
end

local function refresh()
	local equipped = player:GetAttribute("EquippedTitle") or TitleConfig.Default
	for _, r in ipairs(rows) do
		local t = r.Title
		local p, ok = TitleConfig.Progress(player, t.Id)
		r.Fill.Size = UDim2.fromScale(p, 1)
		r.Count.Text = t.Req and reqValue(t) or ""
		r.Bar.Visible = t.Req ~= nil
		if t.Id == equipped then
			r.Button.SetColors(UIKit.Gradients.Gold)
			r.Button.SetText("Equipped")
		elseif ok then
			r.Button.SetColors(UIKit.Gradients.On)
			r.Button.SetText("Equip")
		else
			r.Button.SetColors(UIKit.Gradients.Dark)
			r.Button.SetText("🔒 " .. math.floor(p * 100) .. "%")
		end
		r.Frame.BackgroundColor3 = ok and UIKit.Colors.Row or UIKit.Theme.Colors.Rice.Base
		if window.IsOpen() and ok then seen[t.Id] = true end
	end
end

local function equip(id: string)
	if busy then return end
	local _, ok = TitleConfig.Progress(player, id)
	if not ok or player:GetAttribute("EquippedTitle") == id then return end
	busy = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipTitle")
	local ok, equipped = pcall(remote.InvokeServer, remote, id)
	if ok and equipped then EffectsController.PlaySound("Upgrade", 1.25) end
	busy = false
	refresh()
end

function TitlesController.Toggle() window.Toggle() end

-- "!" on the tile when a title unlocked that you haven't seen yet
local seeded = false
function TitlesController.HasNew(): boolean
	if not seeded then return false end
	for _, t in ipairs(TitleConfig.List) do
		if not seen[t.Id] then
			local _, ok = TitleConfig.Progress(player, t.Id)
			if ok then return true end
		end
	end
	return false
end

function TitlesController.Init()
	window = UIKit.Window({ Name = "Titles", Title = "Titles", Icon = "🏷️", Accent = GOLD, Size = UIKit.Theme.Layout.TitlesController.Size1 })
	local list = UIKit.List(window.Body, 10)
	for i, t in ipairs(TitleConfig.List) do
		local row = UIKit.new("Frame", { Name = t.Id, LayoutOrder = i, Size = UIKit.Theme.Layout.TitlesController.Size2, BackgroundColor3 = UIKit.Colors.Row }, list)
		UIKit.Corner(row, 16)
		UIKit.Stroke(row, 3, t.Gold and GOLD or UIKit.Colors.Outline, true)
		local name = UIKit.Label(row, { Name = "TitleName", Text = "[" .. t.Name .. "]", TextColor3 = t.Color, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UIKit.Theme.Layout.TitlesController.Size3, Position = UDim2.fromOffset(18, 8) }, t.Gold and 0 or 3)
		if t.Gold then UIKit.Stroke(name, 3, UIKit.Theme.Colors.Danger.Base) end
		if t.Rainbow then
			table.insert(rainbows, UIKit.new("UIGradient", { Color = RAINBOW }, name))
		end
		UIKit.Label(row, { Name = "Req", Text = t.Text, TextColor3 = UIKit.Colors.Subtle, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UIKit.Theme.Layout.TitlesController.Size4, Position = UDim2.fromOffset(18, 52) }, 2)
		-- progress bar
		local bar = UIKit.new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -10, 0, 63),
			Size = UIKit.Theme.Layout.TitlesController.Size5, BackgroundColor3 = UIKit.Theme.Muted }, row)
		UIKit.Corner(bar, 9)
		UIKit.Stroke(bar, 2.5, UIKit.Colors.Outline, true)
		local fill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UIKit.Theme.White }, bar)
		UIKit.Corner(fill, 9)
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.Gradients.Gold[1], UIKit.Gradients.Gold[2]) }, fill)
		local count = UIKit.Label(bar, { Name = "Count", Text = "", Size = UIKit.Theme.Layout.TitlesController.Size6, Position = UDim2.fromOffset(0, -2), ZIndex = 2 }, 2)
		local btn = UIKit.Button(row, { Name = "Equip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UIKit.Theme.Layout.TitlesController.Size7 },
			function() equip(t.Id) end)
		table.insert(rows, { Title = t, Frame = row, Bar = bar, Fill = fill, Count = count, Button = btn })
		local function layout()
			local phone=window.Frame.AbsoluteSize.X<700
			row.Size=UDim2.new(1,-10,0,phone and 170 or 86)
			name.Size=UDim2.new(1,phone and -36 or -250,0,36)
			row.Req.Size=UDim2.new(1,phone and -36 or -300,0,30)
			bar.Position=phone and UDim2.fromOffset(18,90) or UDim2.new(0.5,-10,0,63)
			bar.Size=phone and UDim2.new(1,-36,0,18) or UDim2.new(0.5,-230,0,18)
			btn.Button.Position=phone and UDim2.new(1,-14,1,-34) or UDim2.new(1,-14,0.5,0)
			btn.Button.Size=UDim2.fromOffset(phone and 160 or 190,48)
		end
		table.insert(window.OnLayout,layout)
	end

	window.Layout()
	table.insert(window.OnOpen, refresh)
	player:GetAttributeChangedSignal("EquippedTitle"):Connect(function() if window.IsOpen() then refresh() end end)
	RunService.RenderStepped:Connect(function()
		if not window.IsOpen() or UIKit.ReducedMotion() then return end
		local x = (os.clock() * 0.35) % 2 - 1
		for _, g in ipairs(rainbows) do g.Offset = Vector2.new(x, 0) end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if window.IsOpen() then refresh() end
		end
	end)
	-- titles you already have when you join don't count as "new"
	task.delay(4, function()
		for _, t in ipairs(TitleConfig.List) do
			local _, ok = TitleConfig.Progress(player, t.Id)
			if ok then seen[t.Id] = true end
		end
		seeded = true
	end)
end

return TitlesController
