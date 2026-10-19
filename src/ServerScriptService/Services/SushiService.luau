-- SushiService: per-player sushi spawning and server-validated collection.
--
-- The server decides every sushi (type, rarity, KG, position) and remembers it.
-- Clients only render them and ask to collect by id; the server checks ownership
-- and that the character is really next to the sushi before granting KG.
--
-- Each player has one pad per zone they have unlocked + visited. Every active pad
-- fills up to the player's capacity; the zone adds its own KG/luck multipliers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local SushiCatalog = require(Shared.Config.SushiCatalog)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local SushiService = {}

type Sushi = { Id: number, Type: string, Rarity: string, KG: number, Pos: Vector3, Slot: number, Zone: string, Golden: boolean? }

local GOLDEN_MULTIPLIER = 5
type ZoneState = { Count: number, NextSpawnAt: number?, Filling: boolean }
type State = {
	Sushi: { [number]: Sushi },
	Zones: { [string]: ZoneState },
	NextId: number,
	Ready: boolean,
	Rng: Random,
	Tokens: number,
	LastTokenRefill: number,
	Rechecking: { [number]: boolean },
	NextAutoAt: number?,
}

local states: { [Player]: State } = {}
local spawnParts: { [string]: BasePart } = {}
local padSlots: { [string]: { Vector3 } } = {}

-- ===== helpers =====

-- Each pad is a grid (like a chess board): one sushi per square, centred on the
-- pad, so sushi never touch and a full pad still looks tidy.
local function buildSlots(part: BasePart): { Vector3 }
	local cell = GameConfig.Spawning.CellSize
	local margin = 2.5
	local cols = math.floor((part.Size.X - margin * 2) / cell) + 1
	local rows = math.floor((part.Size.Z - margin * 2) / cell) + 1
	local slots = {}
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			local x = (c - (cols - 1) / 2) * cell
			local z = (r - (rows - 1) / 2) * cell
			table.insert(slots, (part.CFrame * CFrame.new(x, part.Size.Y / 2, z)).Position)
		end
	end
	return slots
end

local function freeSlot(state: State, zoneId: string): number?
	local taken = {}
	for _, s in pairs(state.Sushi) do
		if s.Zone == zoneId then taken[s.Slot] = true end
	end
	local free = {}
	for i in ipairs(padSlots[zoneId]) do
		if not taken[i] then table.insert(free, i) end
	end
	return if #free > 0 then free[state.Rng:NextInteger(1, #free)] else nil
end

local function toPayload(s: Sushi)
	return { Id = s.Id, Type = s.Type, KG = s.KG, Pos = s.Pos, Golden = s.Golden }
end

local function spawnOne(player: Player, state: State, zoneId: string, isInitial: boolean): boolean
	local zs = state.Zones[zoneId]
	local zone = ZoneConfig.ById[zoneId]
	if not zs or not zone then return false end
	local slot = freeSlot(state, zoneId)
	if not slot then return false end
	local stats = PlayerDataService.GetStats(player)
	local tree = stats.Tree
	local luck = stats.Luck * zone.LuckMultiplier
	local rng = state.Rng
	local pools = SushiCatalog.ZonePools[zoneId] or SushiCatalog.ZonePools.Starter
	local rarity = RarityConfig.Roll(rng, luck, pools)
	-- Skill tree "orders": a chance to guarantee a minimum rarity (best order first)
	if tree then
		local minOrder = 0
		if tree.OrderLegendary > 0 and rng:NextNumber() < tree.OrderLegendary then
			minOrder = 5
		elseif tree.OrderEpic > 0 and rng:NextNumber() < tree.OrderEpic then
			minOrder = 4
		elseif tree.OrderRare > 0 and rng:NextNumber() < tree.OrderRare then
			minOrder = 3
		end
		if rarity.Order < minOrder then rarity = RarityConfig.RollAtLeast(rng, luck, minOrder, pools) end
	end
	local typeId = SushiCatalog.RandomType(rng, rarity.Id, zoneId)
	local value = stats.ValueMultiplier * zone.KGMultiplier
	local golden = false
	if tree then
		if rarity.Order >= 3 then value *= tree.RareValue end
		if rarity.Id == "Secret" then value *= tree.SecretValue end
		local goldenChance = tree.Golden
		if goldenChance > 0 and rng:NextNumber() < goldenChance then
			golden = true
			value *= GOLDEN_MULTIPLIER
		end
	end
	local sushi: Sushi = {
		Id = state.NextId,
		Type = typeId,
		Rarity = rarity.Id,
		KG = RarityConfig.RollKG(rng, rarity, value, tree and tree.MinRoll or 0),
		Pos = padSlots[zoneId][slot],
		Slot = slot,
		Zone = zoneId,
		Golden = golden or nil,
	}
	state.NextId += 1
	state.Sushi[sushi.Id] = sushi
	zs.Count += 1
	Remotes.SushiSpawned:FireClient(player, toPayload(sushi), isInitial)
	return true
end

-- A pad never holds more sushi than it has grid squares.
local function padStats(stats, zoneId: string): (number, number)
	local cap, interval = stats.Capacity, stats.SpawnInterval
	local slots = padSlots[zoneId]
	return (if slots then math.min(cap, #slots) else cap), interval
end

-- Fills one zone's pad up to capacity, staggered so it pops in nicely.
local function fill(player: Player, state: State, zoneId: string)
	local zs = state.Zones[zoneId]
	if not zs or zs.Filling then return end
	zs.Filling = true
	task.spawn(function()
		while states[player] == state and state.Zones[zoneId] == zs
			and zs.Count < (padStats(PlayerDataService.GetStats(player), zoneId)) do
			if not spawnOne(player, state, zoneId, true) then break end
			task.wait(GameConfig.Spawning.InitialFillDelay)
		end
		zs.Filling = false
	end)
end

local function fillAll(player: Player, state: State)
	for zoneId in pairs(state.Zones) do
		fill(player, state, zoneId)
	end
end

-- ===== collection =====

-- Gives the player a sushi (walk-over or Auto Chef). Rolls Critical Catch here,
-- on the server, so crits can't be faked.
local function grant(player: Player, state: State, sushi: Sushi, isAuto: boolean)
	state.Rechecking[sushi.Id] = nil
	state.Sushi[sushi.Id] = nil
	local zs = state.Zones[sushi.Zone]
	if zs then zs.Count -= 1 end

	local mults = PlayerDataService.GetMultipliers(player)
	local crit = mults.CritChance > 0 and state.Rng:NextNumber() < mults.CritChance
	local kg = sushi.KG
	if crit then
		kg = math.floor(kg * (mults.CritMultiplier or RebirthConfig.CritMultiplier) * 100 + 0.5) / 100
	end
	PlayerDataService.AddKG(player, kg)
	-- Tip Jar: Rare+ sushi also pay part of their sale value right away
	local tip = 0
	local tipRate = mults.Tree and mults.Tree.TipJar or 0
	if tipRate > 0 and RarityConfig.ById[sushi.Rarity].Order >= 3 then
		tip = math.floor(kg * PlayerDataService.GetStats(player).SellRate * tipRate * 100 + 0.5) / 100
		PlayerDataService.AddMoney(player, tip)
	end
	PlayerDataService.RecordCollect(player, sushi.Rarity)
	Remotes.SushiCollected:FireClient(player, sushi.Id, kg, sushi.Rarity, crit, isAuto, tip)
	if PlayerDataService.RecordDiscovery(player, sushi.Type) then
		Remotes.NewDiscovery:FireClient(player, sushi.Type, kg)
	end
	local rarity = RarityConfig.ById[sushi.Rarity]
	if rarity.Order >= GameConfig.GlobalAnnounceOrder then
		Remotes.RareFound:FireAllClients(player.DisplayName, sushi.Type, kg)
	end
end

local function onRequestCollect(player: Player, id: any)
	local state = states[player]
	if not state or typeof(id) ~= "number" then return end

	-- rate limit (token bucket: burst 100, refill 60/s). A max-radius sweep over
	-- a full pad is ~75 legit requests at once, so this only stops floods.
	local now = os.clock()
	state.Tokens = math.min(100, state.Tokens + (now - state.LastTokenRefill) * 60)
	state.LastTokenRefill = now
	local sushi = state.Sushi[id]
	if not sushi then return end
	if state.Tokens < 1 then
		Remotes.SushiSpawned:FireClient(player, toPayload(sushi), false) -- don't leave a ghost
		return
	end
	state.Tokens -= 1
	if state.Rechecking[id] then return end

	-- The server sees the character slightly behind the client (latency), so a
	-- too-far request is re-checked a couple of times before being rejected.
	local attempts = 0
	local function validate()
		if states[player] ~= state or state.Sushi[id] ~= sushi then
			state.Rechecking[id] = nil
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local ok = false
		local rarity = RarityConfig.ById[sushi.Rarity]
		if root and humanoid and humanoid.Health > 0 then
			local stats = PlayerDataService.GetStats(player)
			local tolerance = GameConfig.Collection.ServerRadiusTolerance + stats.WalkSpeed * 0.2
			local allowed = stats.CollectRadius + rarity.Scale * 0.8 + tolerance
			local offset = root.Position - sushi.Pos
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			ok = flat <= allowed and math.abs(offset.Y) <= GameConfig.Collection.MaxVerticalDistance
		end

		if not ok then
			attempts += 1
			if attempts <= 3 and root then
				state.Rechecking[id] = true
				task.delay(0.15, validate)
			else
				state.Rechecking[id] = nil
				Remotes.SushiSpawned:FireClient(player, toPayload(sushi), false) -- put it back
			end
			return
		end

		grant(player, state, sushi, false)
	end
	validate()
end

-- ===== lifecycle =====

-- Starts spawning on a zone's pad for this player (called by ZoneService on travel).
function SushiService.ActivateZone(player: Player, zoneId: string)
	local state = states[player]
	if not state or state.Zones[zoneId] or not spawnParts[zoneId] then return end
	state.Zones[zoneId] = { Count = 0, NextSpawnAt = nil, Filling = false }
	if state.Ready then fill(player, state, zoneId) end
end

local function onClientReady(player: Player)
	local state = states[player]
	if not state or state.Ready then return end
	state.Ready = true
	fillAll(player, state)
end

-- Wipes every pad of the player (used by Prestige / Rebirth so high-value sushi can't be banked).
function SushiService.ResetPad(player: Player)
	local state = states[player]
	if not state then return end
	state.Sushi = {}
	state.Rechecking = {}
	for _, zs in pairs(state.Zones) do
		zs.Count = 0
		zs.NextSpawnAt = nil
	end
	Remotes.SushiCleared:FireClient(player)
	if state.Ready then
		task.delay(0.6, fillAll, player, state)
	end
end

local function createState(player: Player)
	states[player] = {
		Sushi = {},
		Zones = { [ZoneConfig.Default] = { Count = 0, NextSpawnAt = nil, Filling = false } },
		NextId = 1,
		Ready = false,
		Rng = Random.new(),
		Tokens = 100,
		LastTokenRefill = os.clock(),
		Rechecking = {},
	}
	if player:GetAttribute("ClientReadyEarly") then
		onClientReady(player)
	end
end

-- Auto Chef: collects one sushi from the pad of the zone the player is in.
local function autoCollect(player: Player, state: State, now: number)
	local interval = PlayerDataService.GetMultipliers(player).AutoInterval
	if interval <= 0 then
		state.NextAutoAt = nil
		return
	end
	if not state.NextAutoAt then
		state.NextAutoAt = now + interval
		return
	end
	if now < state.NextAutoAt then return end
	state.NextAutoAt = now + interval
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local zoneId = player:GetAttribute("Zone") or ZoneConfig.Default
	-- the oldest sushi first, so fresh rare spawns stay on the pad for the player to grab
	local best: Sushi? = nil
	for id, s in pairs(state.Sushi) do
		if s.Zone == zoneId and not state.Rechecking[id] and (not best or id < best.Id) then
			best = s
		end
	end
	if best then grant(player, state, best, true) end
end

local function tick()
	local now = os.clock()
	for player, state in pairs(states) do
		if state.Ready then
			autoCollect(player, state, now)
			local stats = PlayerDataService.GetStats(player)
			for zoneId, zs in pairs(state.Zones) do
				local cap, interval = padStats(stats, zoneId)
				if zs.Count >= cap then
					zs.NextSpawnAt = nil -- timer restarts once there's room again
				elseif not zs.NextSpawnAt then
					zs.NextSpawnAt = now + interval
				elseif now >= zs.NextSpawnAt then
					-- very fast kitchens can owe more than one sushi per tick
					local owed = math.clamp(math.floor((now - zs.NextSpawnAt) / interval) + 1, 1, 4)
					for _ = 1, owed do
						if zs.Count >= cap then break end
						spawnOne(player, state, zoneId, false)
					end
					zs.NextSpawnAt = if zs.Count < cap then now + interval else nil
				end
			end
		end
	end
end

function SushiService.Start()
	for _, zone in ipairs(ZoneConfig.List) do
		if not zone.SpawnPath then continue end -- e.g. the Blood Rift has no sushi pad
		local part = ZoneConfig.Resolve(zone.SpawnPath, 15)
		if part and part:IsA("BasePart") then
			spawnParts[zone.Id] = part
			padSlots[zone.Id] = buildSlots(part)
		else
			warn("[SushiService] No spawn pad found for zone", zone.Id)
		end
	end

	-- Upgrades apply instantly so purchases feel good
	PlayerDataService.StatsChanged:Connect(function(player, upgradeId)
		local state = states[player]
		if not state or not state.Ready then return end
		if upgradeId == "Tree" then fillAll(player, state) end
		if upgradeId == "Reset" then
			SushiService.ResetPad(player)
		elseif upgradeId == "Capacity" then
			fillAll(player, state)
		elseif upgradeId == "SpawnSpeed" or upgradeId == "Tree" then
			state.NextAutoAt = nil
			local stats = PlayerDataService.GetStats(player)
			for zoneId, zs in pairs(state.Zones) do
				local _, interval = padStats(stats, zoneId)
				if zs.NextSpawnAt then
					zs.NextSpawnAt = math.min(zs.NextSpawnAt, os.clock() + interval)
				end
			end
		end
	end)

	PlayerDataService.PlayerLoaded:Connect(createState)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.IsLoaded(p) and not states[p] then createState(p) end
	end
	Players.PlayerRemoving:Connect(function(p) states[p] = nil end)

	Remotes.ClientReady.OnServerEvent:Connect(function(player)
		if states[player] then
			onClientReady(player)
		else
			player:SetAttribute("ClientReadyEarly", true) -- data still loading
		end
	end)
	Remotes.RequestCollect.OnServerEvent:Connect(onRequestCollect)

	task.spawn(function()
		while true do
			task.wait(0.1)
			tick()
		end
	end)
end

return SushiService
