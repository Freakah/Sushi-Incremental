-- LeaderboardService: global top-12 boards in the Hall of Fame.
-- * every player's lifetime stats (Player attributes kept by PlayerDataService) are
--   written to one OrderedDataStore per stat every couple of minutes and on leave
-- * boards refresh one at a time (round-robin) to stay inside the DataStore budget
-- * players in this server are always merged in live, so your own progress shows up
--   right away; without DataStore access (Studio) the boards show this server only
-- The boards are drawn here on the server (SurfaceGuis on the "Board" parts), so every
-- client sees the same thing without extra remotes.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)

local LeaderboardService = {}

local C = Color3.fromRGB
local FONT = Enum.Font.FredokaOne
local PANEL = C(34, 34, 46)
local OUTLINE = C(16, 14, 22)
local RANK_COLORS = { C(255, 214, 70), C(214, 222, 238), C(240, 150, 80) }
local RANK_OTHER = C(196, 196, 214)

local stores: { [string]: any } = {}
local storeDown = false -- no DataStore access (Studio without API access): live only
local names: { [number]: string } = {}
local globalTop: { [string]: { { UserId: number, Value: number } } } = {}
local lastSent: { [Player]: { [string]: number } } = {}
local views: { [string]: { any } } = {} -- [statId] = { board views }

-- ===== formatting =====

local function formatTime(seconds: number): string
	seconds = math.floor(seconds)
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if d > 0 then return d .. "d " .. h .. "h" end
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end

local function formatValue(stat, v: number): string
	if stat.Format == "Cash" then return NumberFormat.Cash(v >= 1000 and math.floor(v) or v) end
	if stat.Format == "Time" then return formatTime(v) end
	if stat.Format == "KG" then return NumberFormat.KG(v) end
	if stat.Format == "Robux" then return "R$ " .. NumberFormat.Format(math.floor(v + 0.5)) end
	return NumberFormat.Format(math.floor(v + 0.5))
end

local function nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	if p then return p.Name end
	if names[userId] then return names[userId] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = ok and n or "Player"
	return names[userId]
end

-- ===== drawing =====

local function new(class: string, props, parent: Instance?)
	local inst = Instance.new(class)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function stroke(parent, thickness: number)
	return new("UIStroke", { Thickness = thickness, Color = OUTLINE, LineJoinMode = Enum.LineJoinMode.Round }, parent)
end

local MEDALS = { "🥇", "🥈", "🥉" }

local function buildBoard(board: BasePart, stat)
	local sg = new("SurfaceGui", {
		Name = "LeaderboardGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		MaxDistance = 150,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, board)
	local hex = stat.Color:ToHex()
	local accentDark = stat.Color:Lerp(OUTLINE, 0.55)

	-- title plate: soft gradient, outlined in the stat colour
	local title = new("Frame", { Name = "Title", BackgroundColor3 = C(255, 255, 255), Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 64) }, sg)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, title)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(56, 58, 76), C(30, 31, 42)) }, title)
	new("UIStroke", { Thickness = 4, Color = stat.Color, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, title)
	local tt = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -28, 1, -18),
		Font = FONT, RichText = true, TextScaled = true, TextColor3 = C(255, 255, 255),
		Text = stat.Lead .. ' <font color="#' .. hex .. '">' .. stat.Key .. "</font>",
	}, title)
	stroke(tt, 3)

	-- list panel
	local list = new("Frame", { Name = "List", BackgroundColor3 = C(255, 255, 255), Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78) }, sg)
	new("UICorner", { CornerRadius = UDim.new(0, 24) }, list)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(40, 42, 56), C(24, 25, 34)) }, list)
	new("UIStroke", { Thickness = 3, Color = accentDark, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, list)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, list)
	local rows = {}
	local rowH = 1 / Config.Rows
	for i = 1, Config.Rows do
		local top3 = i <= 3
		local rankColor = RANK_COLORS[i] or RANK_OTHER
		local row = new("Frame", {
			Name = "Row" .. i, Position = UDim2.new(0, 0, (i - 1) * rowH, 1), Size = UDim2.new(1, 0, rowH, -3),
			BackgroundColor3 = if top3 then rankColor else C(255, 255, 255),
			BackgroundTransparency = if top3 then 0.8 else (i % 2 == 0 and 0.95 or 1),
		}, list)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
		if top3 then
			new("UIStroke", { Thickness = 2, Color = rankColor, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
		end
		local rank = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.08), Size = UDim2.new(0, 44, 0.84, 0),
			Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rankColor,
			Text = if top3 then MEDALS[i] else ("#" .. i),
		}, row)
		if not top3 then stroke(rank, 1.5) end
		local headSize = if top3 then 30 else 26
		local head = new("ImageLabel", {
			BackgroundColor3 = C(70, 72, 92), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 50, 0.5, 0), Size = UDim2.fromOffset(headSize, headSize),
			Image = "", Visible = false,
		}, row)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, head)
		if top3 then new("UIStroke", { Thickness = 2, Color = rankColor, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, head) end
		local name = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 88, 0.12, 0), Size = UDim2.new(1, -88 - 112, 0.76, 0),
			Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if top3 then rankColor else C(236, 236, 244), Text = "",
		}, row)
		stroke(name, 1.5)
		local value = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0.12, 0), Size = UDim2.new(0, 106, 0.76, 0),
			Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = stat.Color, Text = "",
		}, row)
		stroke(value, 1.5)
		rows[i] = { Head = head, Name = name, Value = value }
	end
	return { Gui = sg, Rows = rows }
end

local function draw(stat, entries)
	for _, view in ipairs(views[stat.Id] or {}) do
		for i, row in ipairs(view.Rows) do
			local e = entries[i]
			if e then
				row.Name.Text = e.Name
				row.Value.Text = formatValue(stat, e.Value)
				row.Head.Image = "rbxthumb://type=AvatarHeadShot&id=" .. e.UserId .. "&w=48&h=48"
				row.Head.Visible = true
			else
				row.Name.Text = ""
				row.Value.Text = ""
				row.Head.Visible = false
			end
		end
	end
end

-- ===== data =====

local function store(stat)
	if storeDown then return nil end
	if stores[stat.Id] == nil then
		local ok, s = pcall(function()
			return DataStoreService:GetOrderedDataStore("LB_" .. stat.Id .. "_" .. Config.StoreVersion)
		end)
		stores[stat.Id] = ok and s or false
	end
	return stores[stat.Id] or nil
end

local function markDown(err)
	if storeDown then return end
	local msg = tostring(err)
	if msg:find("Studio") or msg:find("403") or msg:find("not allowed") then
		storeDown = true
		warn("[Leaderboards] No DataStore access (Studio): boards show this server's players only.")
	end
end

local function valueOf(player: Player, stat): number
	local v = player:GetAttribute(stat.Attr)
	return typeof(v) == "number" and v or 0
end

-- top entries = the stored global list with this server's players merged in live
local function entriesFor(stat)
	local byUser: { [number]: number } = {}
	for _, e in ipairs(globalTop[stat.Id] or {}) do byUser[e.UserId] = e.Value end
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("DataLoaded") then
			local v = valueOf(p, stat)
			if v > 0 then byUser[p.UserId] = math.max(byUser[p.UserId] or 0, v) end
		end
	end
	local list = {}
	for userId, v in pairs(byUser) do table.insert(list, { UserId = userId, Value = v }) end
	table.sort(list, function(a, b) return a.Value > b.Value end)
	local out = {}
	for i = 1, math.min(#list, Config.Rows) do
		local e = list[i]
		table.insert(out, { UserId = e.UserId, Value = e.Value, Name = nameOf(e.UserId) })
	end
	return out
end

local function fetch(stat)
	local s = store(stat)
	if not s then return end
	local ok, result = pcall(function()
		return s:GetSortedAsync(false, Config.Rows):GetCurrentPage()
	end)
	if not ok then
		markDown(result)
		return
	end
	local list = {}
	for _, item in ipairs(result) do
		local userId = tonumber(item.key)
		if userId then table.insert(list, { UserId = userId, Value = Config.Decode(item.value) }) end
	end
	globalTop[stat.Id] = list
end

local function submit(player: Player)
	if storeDown or not player:GetAttribute("DataLoaded") or player.UserId <= 0 then return end
	local sent = lastSent[player] or {}
	lastSent[player] = sent
	for _, stat in ipairs(Config.Stats) do
		local v = valueOf(player, stat)
		if v > 0 and v ~= sent[stat.Id] then
			local s = store(stat)
			if not s then return end
			local ok, err = pcall(function()
				s:SetAsync(tostring(player.UserId), Config.Encode(v))
			end)
			if ok then
				sent[stat.Id] = v
			else
				markDown(err)
				if storeDown then return end
			end
		end
	end
end

function LeaderboardService.Start()
	for _, board in ipairs(CollectionService:GetTagged("Leaderboard")) do
		local stat = board:IsA("BasePart") and Config.ById[board:GetAttribute("Stat")]
		if stat then
			views[stat.Id] = views[stat.Id] or {}
			table.insert(views[stat.Id], buildBoard(board, stat))
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		submit(player)
		lastSent[player] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do task.spawn(submit, p) end
		task.wait(2)
	end)

	-- write everyone's values now and then
	task.spawn(function()
		while true do
			task.wait(Config.SubmitInterval)
			for _, p in ipairs(Players:GetPlayers()) do
				submit(p)
				task.wait(1)
			end
		end
	end)

	-- round-robin refresh: one board reads the DataStore every few seconds, but every
	-- board redraws with the live values of the players in this server
	task.spawn(function()
		task.wait(3)
		local i = 0
		while true do
			i = i % #Config.Stats + 1
			fetch(Config.Stats[i])
			for _, stat in ipairs(Config.Stats) do
				draw(stat, entriesFor(stat))
			end
			task.wait(storeDown and 5 or Config.RefreshSpacing)
		end
	end)
end

return LeaderboardService
