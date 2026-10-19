-- AdminController: a small admin panel (give currency, teleport to areas). Only shown to
-- the UserIds below; the server (AdminService) checks every request again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local player = Players.LocalPlayer
local AdminController = {}

local ADMINS = { [2643321029] = true }

local INK = Color3.fromRGB(20, 24, 40)
local PANEL = Color3.fromRGB(34, 38, 58)

local CURRENCIES = {
	{ Key = "Cash", Label = "💵 Cash" },
	{ Key = "KG", Label = "⚖️ KG" },
	{ Key = "Prestiges", Label = "⭐ Prestiges" },
	{ Key = "Fish", Label = "🐟 Fish" },
	{ Key = "Slices", Label = "🍥 Slices" },
	{ Key = "AP", Label = "✨ Ascension Pts" },
}

local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }

-- "5m", "2.5b", "1e12", "300000"
local function parseAmount(s: string): number?
	s = string.lower((string.gsub(s, "[%s,]", "")))
	local n = tonumber(s)
	if n then return n end
	local num, suf = string.match(s, "^([%d%.]+)(%a+)$")
	if num and SUFFIX[suf] and tonumber(num) then return tonumber(num) * SUFFIX[suf] end
	return nil
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
end

local function button(parent, text, color, size, onClick)
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.FredokaOne
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	corner(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = b
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = INK
	s.Thickness = 1.5
	s.Parent = b
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

local function label(parent, text, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	return l
end

function AdminController.Init()
	if not ADMINS[player.UserId] then return end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminAction") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(330, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL
	panel.Visible = false
	panel.Active = true
	panel.Draggable = true
	corner(panel, 12)
	local ps = Instance.new("UIStroke")
	ps.Color = INK
	ps.Thickness = 3
	ps.Parent = panel
	local pp = Instance.new("UIPadding")
	for _, k in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do (pp :: any)[k] = UDim.new(0, 10) end
	pp.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	panel.Parent = gui

	local order = 0
	local function row(height)
		order += 1
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, height)
		f.LayoutOrder = order
		f.Parent = panel
		return f
	end

	-- title + close
	local top = row(30)
	label(top, "🛠️ Admin Panel", UDim2.new(1, -40, 1, 0))
	local close = button(top, "X", Color3.fromRGB(220, 70, 80), UDim2.fromOffset(30, 30), function() panel.Visible = false end)
	close.Position = UDim2.new(1, -30, 0, 0)

	-- amount box
	local amountRow = row(32)
	label(amountRow, "Amount", UDim2.new(0.3, 0, 1, -6)).Position = UDim2.fromOffset(0, 3)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.7, 0, 1, 0)
	box.Position = UDim2.fromScale(0.3, 0)
	box.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	box.TextColor3 = INK
	box.Font = Enum.Font.FredokaOne
	box.TextSize = 20
	box.Text = "1m"
	box.PlaceholderText = "e.g. 500k, 2.5b, 1e15"
	box.ClearTextOnFocus = false
	corner(box)
	box.Parent = amountRow

	local function amount(): number?
		local n = parseAmount(box.Text)
		if not n then
			box.TextColor3 = Color3.fromRGB(220, 50, 60)
			task.delay(0.6, function() box.TextColor3 = INK end)
		end
		return n
	end

	-- currencies: + adds, - takes away
	for _, c in ipairs(CURRENCIES) do
		local r = row(30)
		label(r, c.Label, UDim2.new(0.5, 0, 1, -6)).Position = UDim2.fromOffset(0, 3)
		local plus = button(r, "+ Give", Color3.fromRGB(70, 190, 110), UDim2.new(0.3, -4, 1, 0), function()
			local n = amount()
			if n then remote:FireServer("Give", c.Key, n) end
		end)
		plus.Position = UDim2.fromScale(0.5, 0)
		local minus = button(r, "-", Color3.fromRGB(200, 90, 90), UDim2.new(0.2, 0, 1, 0), function()
			local n = amount()
			if n then remote:FireServer("Give", c.Key, -n) end
		end)
		minus.Position = UDim2.fromScale(0.8, 0)
	end
	do
		local r = row(30)
		label(r, "🔄 Rebirths", UDim2.new(0.5, 0, 1, -6)).Position = UDim2.fromOffset(0, 3)
		local set = button(r, "Set to amount", Color3.fromRGB(120, 110, 230), UDim2.new(0.5, 0, 1, 0), function()
			local n = amount()
			if n then remote:FireServer("Give", "Rebirths", n) end
		end)
		set.Position = UDim2.fromScale(0.5, 0)
	end

	-- teleports
	label(row(24), "Teleport", UDim2.new(1, 0, 1, 0))
	local tp = row(0)
	tp.AutomaticSize = Enum.AutomaticSize.Y
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -3, 0, 34)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = tp
	for i, z in ipairs(ZoneConfig.List) do
		local b = button(tp, z.Icon .. " " .. z.Name, z.Color:Lerp(Color3.new(0, 0, 0), 0.25), UDim2.new(), function()
			remote:FireServer("Teleport", z.Id)
		end)
		b.LayoutOrder = i
	end

	-- cinematic: hide every other ScreenGui and the Roblox core UI, leaving only the 🛠️ button
	local StarterGui = game:GetService("StarterGui")
	local playerGui = gui.Parent :: PlayerGui
	local hidden: { ScreenGui } = {}
	local addedConn: RBXScriptConnection?
	local function hide(g: Instance)
		if g:IsA("ScreenGui") and g ~= gui and g.Name ~= "Freecam" and g.Enabled then -- Freecam (Shift+P) is for filming
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local cine
	cine = button(row(30), "🎬 Cinematic: Off", Color3.fromRGB(90, 90, 120), UDim2.fromScale(1, 1), function()
		local on = addedConn == nil
		cine.Text = on and "🎬 Cinematic: On" or "🎬 Cinematic: Off"
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not on)
		if on then
			for _, g in ipairs(playerGui:GetChildren()) do hide(g) end
			addedConn = playerGui.ChildAdded:Connect(hide)
			panel.Visible = false
		else
			(addedConn :: RBXScriptConnection):Disconnect()
			addedConn = nil
			for _, g in ipairs(hidden) do g.Enabled = true end
			table.clear(hidden)
		end
	end)

	-- toggle button (bottom-left)
	local toggle = button(gui, "🛠️", PANEL, UDim2.fromOffset(44, 44), function()
		panel.Visible = not panel.Visible
	end)
	toggle.Name = "AdminToggle"
	toggle.AnchorPoint = Vector2.new(0, 1)
	toggle.Position = UDim2.new(0, 12, 1, -12)
end

return AdminController
