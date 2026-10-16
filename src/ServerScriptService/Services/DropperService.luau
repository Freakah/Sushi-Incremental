-- DropperService: the Sushi Restaurant's droppers (DropperConfig).
--   Builds the shared machine at runtime from the markers in workspace.Map.NekoLayout
--   (DropperConfig.Layout): the U-shaped conveyor with rounded corners and the Neko head (SellCat)
--   at its end, and hides the markers. (The 🐱 Neko Upgrades board is a tagged part in NekoLayout.)
--   Each player's droppers and upgrader gates are private (DropperController draws them and the
--   neko): while a player is in the Dropper zone, every owned dropper drops on a server timer,
--   the server works out the neko's value (gates it will pass), tells that player's client
--   (DropperDrop) and pays 🐱 Neko when it would reach the head. The client never reports sales.
--   Droppers (in order) and gates (any order) are bought on buy pads (validated: zone,
--   distance, price, rate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local DropperConfig = require(ReplicatedStorage.Shared.Config.DropperConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local DropperService = {}

local BUY_COOLDOWN = 0.4
local PAD_TOLERANCE = 4 -- extra studs: the server sees the character slightly behind the client

-- per player: next drop time per dropper, and neko on the belt { At = payout time, Value }
local nextDrop: { [Player]: { [number]: number } } = {}
local onBelt: { [Player]: { { At: number, Value: number } } } = {}
local layout = nil -- DropperConfig.Layout(), once the markers are read
local lastRequest: { [Player]: number } = {}

local function remote(name: string): RemoteEvent
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r :: RemoteEvent
end

-- ===== the shared machine =====

-- a clone of an imported model, every part anchored; marker parts (DropPoint, SellZone) hidden
local function asset(folder: Instance?, name: string): Model?
	local src = folder and folder:FindFirstChild(name)
	if not src then
		warn("[DropperService] missing ReplicatedStorage.Assets.Dropper." .. name)
		return nil
	end
	local m = src:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d.Name == "DropPoint" or d.Name == "SellZone" then
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	return m
end

-- one conveyor piece centred on belt distance `d`, stretched to `len` along the belt
local function belt(parent: Instance, template: Model, L, d: number, len: number)
	local p, dir = L.At(d)
	local yaw = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, math.pi / 2, 0) -- the model's long axis (X) along the belt
	local piece = template:Clone()
	for _, x in ipairs(piece:GetDescendants()) do
		if x:IsA("BasePart") then x.Size = Vector3.new(x.Size.X * len / 4, x.Size.Y, x.Size.Z) end
	end
	piece:PivotTo(CFrame.new(p - Vector3.new(0, DropperConfig.BeltHeight, 0)) * yaw)
	piece.Parent = parent
end

local function buildMachine(L)
	local restaurant = workspace:WaitForChild("Map"):WaitForChild("SushiRestaurant", 60)
	local folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Dropper")
	if not restaurant then
		warn("[DropperService] needs workspace.Map.SushiRestaurant")
		return
	end
	local machine = Instance.new("Model")
	machine.Name = "NekoMachine"

	-- the markers are for Studio only
	for _, m in ipairs(L.Markers) do
		m.Transparency = 1
		m.CanCollide, m.CanQuery, m.CanTouch = false, false, false
		for _, g in ipairs(m:GetDescendants()) do
			if g:IsA("LayerCollector") then g.Enabled = false end
		end
	end

	-- conveyor: straight runs in ~TileLength pieces; corners in thin slices as long as the
	-- outer rail's arc, so the outside never gaps (the inside overlaps, hidden in the frame)
	local conveyor = asset(folder, "SushiConveyor")
	if conveyor then
		local model = Instance.new("Model")
		model.Name = "Conveyor"
		for _, q in ipairs(L.Pieces) do
			if q.Arc then
				local n = math.max(1, math.ceil(math.abs(q.Sweep) / DropperConfig.CornerStep))
				local outer = (q.R + DropperConfig.BeltHalfWidth) * math.abs(q.Sweep) / n
				for k = 1, n do belt(model, conveyor, L, q.Start + q.Length * (k - 0.5) / n, outer) end
			else
				local n = math.max(1, math.round(q.Length / DropperConfig.TileLength))
				for k = 1, n do belt(model, conveyor, L, q.Start + q.Length * (k - 0.5) / n, q.Length / n) end
			end
		end
		model.Parent = machine
	end

	-- the Neko head: mouth over the end of the belt, facing the incoming neko
	local cat = asset(folder, "SellCat")
	if cat then
		local last, dir = L.At(L.Length)
		local zone = cat:FindFirstChild("SellZone", true) :: BasePart?
		local mouth = if zone then cat:GetPivot():PointToObjectSpace(zone.Position) else Vector3.zero
		local rot = CFrame.lookAt(Vector3.zero, -dir)
		local off = rot:VectorToWorldSpace(mouth)
		cat:PivotTo(CFrame.new(last.X - off.X, last.Y - DropperConfig.BeltHeight, last.Z - off.Z) * rot)
		cat.Name = "SellCat"
		cat.Parent = machine
	end

	machine.Parent = restaurant
end

-- ===== droppers =====

local function tick(drop: RemoteEvent)
	local L = layout
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = PlayerDataService.IsLoaded(player) and PlayerDataService.GetDropperStats(player)
		if not stats then continue end
		-- pay what reached the head (also after leaving the zone: it was already on the belt)
		local belt = onBelt[player]
		if belt then
			local earned = 0
			for i = #belt, 1, -1 do
				if belt[i].At <= now then
					earned += belt[i].Value
					table.remove(belt, i)
				end
			end
			if earned > 0 then PlayerDataService.AddNeko(player, earned) end
		end
		if player:GetAttribute("Zone") ~= DropperConfig.Zone then
			nextDrop[player] = nil
			continue
		end
		local timers = nextDrop[player]
		if not timers then
			timers = {}
			nextDrop[player] = timers
		end
		onBelt[player] = onBelt[player] or {}
		for slot = 1, math.min(stats.Slots, #L.Droppers) do
			local t = timers[slot]
			if not t then
				-- stagger the droppers so they don't all drop together
				timers[slot] = now + DropperConfig.DropInterval * (slot - 1) / #DropperConfig.DropperCosts
			elseif now >= t then
				timers[slot] = math.max(t + DropperConfig.DropInterval, now) -- never catch up with a burst
				local d = L.Droppers[slot].D
				local value = stats.ItemValue * DropperConfig.GateMultiplier(L, d, stats.Gates)
				table.insert(onBelt[player], { At = now + DropperConfig.RideTime(L, d, stats.Speed), Value = value })
				drop:FireClient(player, slot, stats.Speed, value)
			end
		end
	end
end

-- standing on (or near) a pad's centre, in the restaurant, not spamming
local function canBuy(player: Player, padPos: Vector3, cooldown: number): boolean
	if not layout or not PlayerDataService.IsLoaded(player) or player:GetAttribute("Zone") ~= DropperConfig.Zone then return false end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < cooldown then return false end
	lastRequest[player] = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	local offset = root.Position - padPos
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= DropperConfig.PadRadius + PAD_TOLERANCE and math.abs(offset.Y) <= 8
end

function DropperService.Start()
	-- falling neko (client-side physics) pass through droppers and each other
	for _, g in ipairs({ DropperConfig.NekoGroup, DropperConfig.DropperGroup }) do
		if not PhysicsService:IsCollisionGroupRegistered(g) then PhysicsService:RegisterCollisionGroup(g) end
	end
	PhysicsService:CollisionGroupSetCollidable(DropperConfig.NekoGroup, DropperConfig.DropperGroup, false)
	PhysicsService:CollisionGroupSetCollidable(DropperConfig.NekoGroup, DropperConfig.NekoGroup, false)

	local drop = remote("DropperDrop")          -- server -> owner: (slot, beltSpeed, value)
	local bought = remote("DropperBought")      -- server -> owner: (slot)
	local gateBought = remote("UpgraderBought") -- server -> owner: (gate)

	remote("RequestBuyDropper").OnServerEvent:Connect(function(player: Player)
		local slot = (player:GetAttribute("NekoSlots") or 0) + 1
		local spot = layout and layout.Droppers[slot]
		if not spot or not canBuy(player, spot.Pad, BUY_COOLDOWN) then return end
		if PlayerDataService.BuyDropperSlot(player) then
			bought:FireClient(player, slot)
		end
	end)

	remote("RequestBuyUpgrader").OnServerEvent:Connect(function(player: Player, i: any)
		if typeof(i) ~= "number" or i ~= math.floor(i) then return end
		local gate = layout and layout.Gates[i]
		if not gate or not canBuy(player, gate.Pad, BUY_COOLDOWN) then return end
		if PlayerDataService.BuyUpgrader(player, i) then
			gateBought:FireClient(player, i)
		end
	end)

	-- 🐱 Neko Upgrades board
	local shop = DropperConfig.Upgrades
	local purchased = remote("NekoUpgradePurchased")
	remote("RequestNekoUpgrade").OnServerEvent:Connect(function(player: Player, id: any, buyMax: any)
		if typeof(id) ~= "string" or not shop.ById[id] or not PlayerDataService.IsLoaded(player) then return end
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.2 then return end
		lastRequest[player] = now
		local n = PlayerDataService.BuyNekoUpgrade(player, id, buyMax == true)
		if n > 0 then
			purchased:FireClient(player, id, player:GetAttribute(shop.AttributeName(id)), n)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		nextDrop[p] = nil
		onBelt[p] = nil
		lastRequest[p] = nil
	end)

	task.spawn(function()
		local L = DropperConfig.Layout()
		buildMachine(L)
		layout = L
		while true do
			task.wait(0.1)
			tick(drop)
		end
	end)
end

return DropperService
